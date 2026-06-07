-- WHY: Split across 003 + 003a. CREATE INDEX CONCURRENTLY cannot run inside a
-- transaction block, and the project convention (and migrate.sh's psql -f
-- driver) treats each migration file as one atomic unit when an explicit
-- BEGIN/COMMIT wraps it (see 001_initial.sql). 003 carries the
-- transactional pieces (extension, columns, functions, triggers, backfill);
-- 003a carries the bare-statement CONCURRENTLY index swap.
BEGIN;

CREATE EXTENSION IF NOT EXISTS pg_trgm;

ALTER TABLE beverages ADD COLUMN search_tsv tsvector;
ALTER TABLE producers ADD COLUMN search_tsv tsvector;

-- WHY: One helper per entity. The beverage helper pulls the producer +
-- prefecture names directly from their JSONB so a beverage row's vector
-- never depends on producer.search_tsv being current — keeps the trigger
-- ordering trivially correct regardless of which row writes first.
CREATE OR REPLACE FUNCTION kamos_compute_beverage_search_tsv(beverage_uuid uuid)
RETURNS void AS $$
BEGIN
  UPDATE beverages b
  SET search_tsv = to_tsvector('simple',
    coalesce(b.name_i18n ->> 'en', '') || ' ' ||
    coalesce(b.name_i18n ->> 'ja', '') || ' ' ||
    coalesce(b.name_i18n ->> 'ko', '') || ' ' ||
    coalesce((SELECT p.name_i18n ->> 'en' FROM producers p WHERE p.id = b.producer_id), '') || ' ' ||
    coalesce((SELECT p.name_i18n ->> 'ja' FROM producers p WHERE p.id = b.producer_id), '') || ' ' ||
    coalesce((SELECT p.name_i18n ->> 'ko' FROM producers p WHERE p.id = b.producer_id), '') || ' ' ||
    coalesce((SELECT pf.name_i18n ->> 'en' FROM prefectures pf JOIN producers p ON p.prefecture_id = pf.id WHERE p.id = b.producer_id), '') || ' ' ||
    coalesce((SELECT pf.name_i18n ->> 'ja' FROM prefectures pf JOIN producers p ON p.prefecture_id = pf.id WHERE p.id = b.producer_id), '') || ' ' ||
    coalesce((SELECT pf.name_i18n ->> 'ko' FROM prefectures pf JOIN producers p ON p.prefecture_id = pf.id WHERE p.id = b.producer_id), '')
  )
  WHERE b.id = beverage_uuid;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION kamos_compute_producer_search_tsv(producer_uuid uuid)
RETURNS void AS $$
BEGIN
  UPDATE producers p
  SET search_tsv = to_tsvector('simple',
    coalesce(p.name_i18n ->> 'en', '') || ' ' ||
    coalesce(p.name_i18n ->> 'ja', '') || ' ' ||
    coalesce(p.name_i18n ->> 'ko', '') || ' ' ||
    coalesce((SELECT pf.name_i18n ->> 'en' FROM prefectures pf WHERE pf.id = p.prefecture_id), '') || ' ' ||
    coalesce((SELECT pf.name_i18n ->> 'ja' FROM prefectures pf WHERE pf.id = p.prefecture_id), '') || ' ' ||
    coalesce((SELECT pf.name_i18n ->> 'ko' FROM prefectures pf WHERE pf.id = p.prefecture_id), '')
  )
  WHERE p.id = producer_uuid;
END;
$$ LANGUAGE plpgsql;

-- Beverage self-trigger: recompute on INSERT or on UPDATE of the inputs.
CREATE OR REPLACE FUNCTION kamos_trg_beverages_search_tsv()
RETURNS TRIGGER AS $$
BEGIN
  PERFORM kamos_compute_beverage_search_tsv(NEW.id);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_beverages_search_tsv
  AFTER INSERT OR UPDATE OF name_i18n, producer_id ON beverages
  FOR EACH ROW EXECUTE FUNCTION kamos_trg_beverages_search_tsv();

-- Producer self-trigger + sweep of dependent beverages.
CREATE OR REPLACE FUNCTION kamos_trg_producers_search_tsv()
RETURNS TRIGGER AS $$
DECLARE
  bid uuid;
BEGIN
  PERFORM kamos_compute_producer_search_tsv(NEW.id);
  FOR bid IN SELECT id FROM beverages WHERE producer_id = NEW.id LOOP
    PERFORM kamos_compute_beverage_search_tsv(bid);
  END LOOP;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_producers_search_tsv
  AFTER INSERT OR UPDATE OF name_i18n, prefecture_id ON producers
  FOR EACH ROW EXECUTE FUNCTION kamos_trg_producers_search_tsv();

-- Prefecture rename: sweep every producer + transitive beverage.
CREATE OR REPLACE FUNCTION kamos_trg_prefectures_search_tsv()
RETURNS TRIGGER AS $$
DECLARE
  pid uuid;
  bid uuid;
BEGIN
  FOR pid IN SELECT id FROM producers WHERE prefecture_id = NEW.id LOOP
    PERFORM kamos_compute_producer_search_tsv(pid);
    FOR bid IN SELECT id FROM beverages WHERE producer_id = pid LOOP
      PERFORM kamos_compute_beverage_search_tsv(bid);
    END LOOP;
  END LOOP;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_prefectures_search_tsv
  AFTER UPDATE OF name_i18n ON prefectures
  FOR EACH ROW EXECUTE FUNCTION kamos_trg_prefectures_search_tsv();

-- Backfill. Producers first so the table read in the beverage backfill sees
-- current producer rows; the beverage helper reads producer.name_i18n
-- directly (not producer.search_tsv) so ordering is for readability.
UPDATE producers SET search_tsv = to_tsvector('simple',
  coalesce(name_i18n ->> 'en', '') || ' ' ||
  coalesce(name_i18n ->> 'ja', '') || ' ' ||
  coalesce(name_i18n ->> 'ko', '') || ' ' ||
  coalesce((SELECT pf.name_i18n ->> 'en' FROM prefectures pf WHERE pf.id = producers.prefecture_id), '') || ' ' ||
  coalesce((SELECT pf.name_i18n ->> 'ja' FROM prefectures pf WHERE pf.id = producers.prefecture_id), '') || ' ' ||
  coalesce((SELECT pf.name_i18n ->> 'ko' FROM prefectures pf WHERE pf.id = producers.prefecture_id), '')
);

UPDATE beverages SET search_tsv = to_tsvector('simple',
  coalesce(name_i18n ->> 'en', '') || ' ' ||
  coalesce(name_i18n ->> 'ja', '') || ' ' ||
  coalesce(name_i18n ->> 'ko', '') || ' ' ||
  coalesce((SELECT p.name_i18n ->> 'en' FROM producers p WHERE p.id = beverages.producer_id), '') || ' ' ||
  coalesce((SELECT p.name_i18n ->> 'ja' FROM producers p WHERE p.id = beverages.producer_id), '') || ' ' ||
  coalesce((SELECT p.name_i18n ->> 'ko' FROM producers p WHERE p.id = beverages.producer_id), '') || ' ' ||
  coalesce((SELECT pf.name_i18n ->> 'en' FROM prefectures pf JOIN producers p ON p.prefecture_id = pf.id WHERE p.id = beverages.producer_id), '') || ' ' ||
  coalesce((SELECT pf.name_i18n ->> 'ja' FROM prefectures pf JOIN producers p ON p.prefecture_id = pf.id WHERE p.id = beverages.producer_id), '') || ' ' ||
  coalesce((SELECT pf.name_i18n ->> 'ko' FROM prefectures pf JOIN producers p ON p.prefecture_id = pf.id WHERE p.id = beverages.producer_id), '')
);

COMMIT;
