-- Search infrastructure: materialized lowercased `search_text` columns on
-- beverages + producers (covering beverage name + producer name + prefecture
-- name in en/ja/ko), maintained by triggers, plus `gin_bigm_ops` indexes on
-- everything searched. Substitutes the FTS+trigram approach evaluated
-- earlier in the same PR; goes straight to the bigm-final shape because
-- prod hadn't applied any interim state.
--
-- pg_bigm is supplied by the custom kamos-db image (db/Dockerfile,
-- runbook §1a). Plain CREATE INDEX (no CONCURRENTLY) is intentional:
-- the migration runs as one transaction so failures roll back cleanly,
-- and at current corpus size the brief write lock is a non-issue.
BEGIN;

CREATE EXTENSION IF NOT EXISTS pg_bigm;

ALTER TABLE beverages ADD COLUMN search_text text;
ALTER TABLE producers ADD COLUMN search_text text;

-- Beverage helper reads producer + prefecture JSONB directly (not the
-- producer's search_text), so the trigger ordering on the two tables is
-- trivially independent.
CREATE OR REPLACE FUNCTION kamos_compute_beverage_search_text(beverage_uuid uuid)
RETURNS void AS $$
BEGIN
  UPDATE beverages b
  SET search_text = lower(concat_ws(' ',
    b.name_i18n ->> 'en',
    b.name_i18n ->> 'ja',
    b.name_i18n ->> 'ko',
    (SELECT p.name_i18n ->> 'en' FROM producers AS p WHERE p.id = b.producer_id),
    (SELECT p.name_i18n ->> 'ja' FROM producers AS p WHERE p.id = b.producer_id),
    (SELECT p.name_i18n ->> 'ko' FROM producers AS p WHERE p.id = b.producer_id),
    (SELECT pf.name_i18n ->> 'en' FROM prefectures AS pf INNER JOIN producers AS p ON pf.id = p.prefecture_id WHERE p.id = b.producer_id),
    (SELECT pf.name_i18n ->> 'ja' FROM prefectures AS pf INNER JOIN producers AS p ON pf.id = p.prefecture_id WHERE p.id = b.producer_id),
    (SELECT pf.name_i18n ->> 'ko' FROM prefectures AS pf INNER JOIN producers AS p ON pf.id = p.prefecture_id WHERE p.id = b.producer_id)
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
    (SELECT pf.name_i18n ->> 'en' FROM prefectures AS pf WHERE pf.id = p.prefecture_id),
    (SELECT pf.name_i18n ->> 'ja' FROM prefectures AS pf WHERE pf.id = p.prefecture_id),
    (SELECT pf.name_i18n ->> 'ko' FROM prefectures AS pf WHERE pf.id = p.prefecture_id)
  ))
  WHERE p.id = producer_uuid;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION kamos_trg_beverages_search_text()
RETURNS trigger AS $$
BEGIN
  PERFORM kamos_compute_beverage_search_text(NEW.id);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_beverages_search_text
AFTER INSERT OR UPDATE OF name_i18n, producer_id ON beverages
FOR EACH ROW EXECUTE FUNCTION kamos_trg_beverages_search_text();

CREATE OR REPLACE FUNCTION kamos_trg_producers_search_text()
RETURNS trigger AS $$
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

CREATE TRIGGER trg_producers_search_text
AFTER INSERT OR UPDATE OF name_i18n, prefecture_id ON producers
FOR EACH ROW EXECUTE FUNCTION kamos_trg_producers_search_text();

CREATE OR REPLACE FUNCTION kamos_trg_prefectures_search_text()
RETURNS trigger AS $$
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

CREATE TRIGGER trg_prefectures_search_text
AFTER UPDATE OF name_i18n ON prefectures
FOR EACH ROW EXECUTE FUNCTION kamos_trg_prefectures_search_text();

-- Backfill. Producers first (the beverage backfill reads producer JSONB
-- directly so the ordering is for readability + mid-migration consistency).
UPDATE producers SET search_text = lower(concat_ws(
  ' ',
  name_i18n ->> 'en',
  name_i18n ->> 'ja',
  name_i18n ->> 'ko',
  (
    SELECT pf.name_i18n ->> 'en' FROM prefectures AS pf
    WHERE pf.id = producers.prefecture_id
  ),
  (
    SELECT pf.name_i18n ->> 'ja' FROM prefectures AS pf
    WHERE pf.id = producers.prefecture_id
  ),
  (
    SELECT pf.name_i18n ->> 'ko' FROM prefectures AS pf
    WHERE pf.id = producers.prefecture_id
  )
));

UPDATE beverages SET search_text = lower(concat_ws(
  ' ',
  name_i18n ->> 'en',
  name_i18n ->> 'ja',
  name_i18n ->> 'ko',
  (
    SELECT p.name_i18n ->> 'en' FROM producers AS p
    WHERE p.id = beverages.producer_id
  ),
  (
    SELECT p.name_i18n ->> 'ja' FROM producers AS p
    WHERE p.id = beverages.producer_id
  ),
  (
    SELECT p.name_i18n ->> 'ko' FROM producers AS p
    WHERE p.id = beverages.producer_id
  ),
  (
    SELECT pf.name_i18n ->> 'en' FROM prefectures AS pf INNER JOIN producers AS p ON pf.id = p.prefecture_id
    WHERE p.id = beverages.producer_id
  ),
  (
    SELECT pf.name_i18n ->> 'ja' FROM prefectures AS pf INNER JOIN producers AS p ON pf.id = p.prefecture_id
    WHERE p.id = beverages.producer_id
  ),
  (
    SELECT pf.name_i18n ->> 'ko' FROM prefectures AS pf INNER JOIN producers AS p ON pf.id = p.prefecture_id
    WHERE p.id = beverages.producer_id
  )
));

-- WHY: plain (non-CONCURRENTLY) CREATE INDEX so the whole migration runs as
-- one transaction — CREATE INDEX CONCURRENTLY can't run inside a tx block.
-- At current corpus size each GIN build takes <1s and blocks writes briefly.
-- users.username is lowercase by SPEC invariant (§3.2 / §6.3) so no lower()
-- projection. display_name is mixed-case and must be lowered.
CREATE INDEX idx_beverages_search_bigm  -- noqa: PG01
ON beverages USING gin (search_text gin_bigm_ops)
WHERE deleted_at IS NULL;

CREATE INDEX idx_producers_search_bigm  -- noqa: PG01
ON producers USING gin (search_text gin_bigm_ops)
WHERE deleted_at IS NULL;

CREATE INDEX idx_users_username_bigm  -- noqa: PG01
ON users USING gin (username gin_bigm_ops);

CREATE INDEX idx_users_display_name_bigm  -- noqa: PG01
ON users USING gin (lower(display_name) gin_bigm_ops)
WHERE display_name IS NOT NULL;

COMMIT;
