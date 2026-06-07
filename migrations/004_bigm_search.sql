-- WHY: Split across 004 + 004a. CREATE INDEX CONCURRENTLY cannot run inside
-- a transaction block (companion to 004a). Mirrors the 003 / 003a split.
-- WHY: pg_trgm is intentionally left installed even though every trigram
-- index from 003/003a is dropped in 004a. similarity() / word_similarity()
-- remain available as plain expressions (e.g. for future ORDER BY ranking),
-- and the extension carries no runtime cost on its own.
BEGIN;

CREATE EXTENSION IF NOT EXISTS pg_bigm;

ALTER TABLE beverages DROP COLUMN search_tsv;
ALTER TABLE beverages ADD COLUMN search_text TEXT;

ALTER TABLE producers DROP COLUMN search_tsv;
ALTER TABLE producers ADD COLUMN search_text TEXT;

-- WHY: 003's helpers built a tsvector; 004 swaps to a lowercased plain
-- string so the query side is `search_text LIKE '%' || lower($1) || '%'`
-- (no function-on-column, planner picks the gin_bigm_ops index).
-- Renamed `_tsv` → `_text` because the body and return shape changed; the
-- triggers below were updated to call the new names in the same migration.
CREATE OR REPLACE FUNCTION kamos_compute_beverage_search_text(beverage_uuid uuid)
RETURNS void AS $$
BEGIN
  UPDATE beverages b
  SET search_text = lower(concat_ws(' ',
    b.name_i18n ->> 'en',
    b.name_i18n ->> 'ja',
    b.name_i18n ->> 'ko',
    (SELECT p.name_i18n ->> 'en' FROM producers p WHERE p.id = b.producer_id),
    (SELECT p.name_i18n ->> 'ja' FROM producers p WHERE p.id = b.producer_id),
    (SELECT p.name_i18n ->> 'ko' FROM producers p WHERE p.id = b.producer_id),
    (SELECT pf.name_i18n ->> 'en' FROM prefectures pf JOIN producers p ON p.prefecture_id = pf.id WHERE p.id = b.producer_id),
    (SELECT pf.name_i18n ->> 'ja' FROM prefectures pf JOIN producers p ON p.prefecture_id = pf.id WHERE p.id = b.producer_id),
    (SELECT pf.name_i18n ->> 'ko' FROM prefectures pf JOIN producers p ON p.prefecture_id = pf.id WHERE p.id = b.producer_id)
  ))
  WHERE b.id = beverage_uuid;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION kamos_compute_producer_search_text(producer_uuid uuid)
RETURNS void AS $$
BEGIN
  UPDATE producers p
  SET search_text = lower(concat_ws(' ',
    p.name_i18n ->> 'en',
    p.name_i18n ->> 'ja',
    p.name_i18n ->> 'ko',
    (SELECT pf.name_i18n ->> 'en' FROM prefectures pf WHERE pf.id = p.prefecture_id),
    (SELECT pf.name_i18n ->> 'ja' FROM prefectures pf WHERE pf.id = p.prefecture_id),
    (SELECT pf.name_i18n ->> 'ko' FROM prefectures pf WHERE pf.id = p.prefecture_id)
  ))
  WHERE p.id = producer_uuid;
END;
$$ LANGUAGE plpgsql;

-- WHY: 003's trigger wrappers stay attached to the same tables; only the
-- body changes to call the renamed helpers. The 003 helpers
-- (`_compute_*_search_tsv`) become unreferenced after this migration; DROP
-- FUNCTION at the bottom removes them so a stale call from a future write
-- path raises immediately instead of silently writing the wrong shape.
CREATE OR REPLACE FUNCTION kamos_trg_beverages_search_tsv()
RETURNS TRIGGER AS $$
BEGIN
  PERFORM kamos_compute_beverage_search_text(NEW.id);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION kamos_trg_producers_search_tsv()
RETURNS TRIGGER AS $$
DECLARE
  bid uuid;
BEGIN
  PERFORM kamos_compute_producer_search_text(NEW.id);
  FOR bid IN SELECT id FROM beverages WHERE producer_id = NEW.id LOOP
    PERFORM kamos_compute_beverage_search_text(bid);
  END LOOP;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION kamos_trg_prefectures_search_tsv()
RETURNS TRIGGER AS $$
DECLARE
  pid uuid;
  bid uuid;
BEGIN
  FOR pid IN SELECT id FROM producers WHERE prefecture_id = NEW.id LOOP
    PERFORM kamos_compute_producer_search_text(pid);
    FOR bid IN SELECT id FROM beverages WHERE producer_id = pid LOOP
      PERFORM kamos_compute_beverage_search_text(bid);
    END LOOP;
  END LOOP;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS kamos_compute_beverage_search_tsv(uuid);
DROP FUNCTION IF EXISTS kamos_compute_producer_search_tsv(uuid);

-- Backfill. Producers first (the beverage backfill reads producer.name_i18n
-- directly, not producer.search_text, so the ordering is for readability
-- and to keep both tables consistent if a reader looks mid-migration).
UPDATE producers SET search_text = lower(concat_ws(' ',
  name_i18n ->> 'en',
  name_i18n ->> 'ja',
  name_i18n ->> 'ko',
  (SELECT pf.name_i18n ->> 'en' FROM prefectures pf WHERE pf.id = producers.prefecture_id),
  (SELECT pf.name_i18n ->> 'ja' FROM prefectures pf WHERE pf.id = producers.prefecture_id),
  (SELECT pf.name_i18n ->> 'ko' FROM prefectures pf WHERE pf.id = producers.prefecture_id)
));

UPDATE beverages SET search_text = lower(concat_ws(' ',
  name_i18n ->> 'en',
  name_i18n ->> 'ja',
  name_i18n ->> 'ko',
  (SELECT p.name_i18n ->> 'en' FROM producers p WHERE p.id = beverages.producer_id),
  (SELECT p.name_i18n ->> 'ja' FROM producers p WHERE p.id = beverages.producer_id),
  (SELECT p.name_i18n ->> 'ko' FROM producers p WHERE p.id = beverages.producer_id),
  (SELECT pf.name_i18n ->> 'en' FROM prefectures pf JOIN producers p ON p.prefecture_id = pf.id WHERE p.id = beverages.producer_id),
  (SELECT pf.name_i18n ->> 'ja' FROM prefectures pf JOIN producers p ON p.prefecture_id = pf.id WHERE p.id = beverages.producer_id),
  (SELECT pf.name_i18n ->> 'ko' FROM prefectures pf JOIN producers p ON p.prefecture_id = pf.id WHERE p.id = beverages.producer_id)
));

COMMIT;
