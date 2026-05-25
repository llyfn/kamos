-- 018_update_beverage_count_trigger_for_producers.sql
-- Migration 017 renamed `breweries` → `producers` and `beverages.brewery_id`
-- → `beverages.producer_id`, but PostgreSQL stores function bodies as text
-- and re-resolves identifiers at execution time — so the `TRG_BEVERAGES_COUNT_SYNC`
-- trigger function defined in 011_counter_caches.sql kept its old body and
-- broke on the first INSERT/DELETE against `beverages` after 017 applied
-- (`relation "breweries" does not exist`).
--
-- CREATE OR REPLACE the function with the post-017 identifiers. The trigger
-- binding (`CREATE TRIGGER trg_beverages_count ... EXECUTE FUNCTION ...`) is
-- unchanged; only the function body is rewritten.
--
-- This is the only object that needed a body rewrite — a sweep of pg_proc
-- and pg_views confirmed no other functions/views reference the renamed
-- identifiers.
--
-- Append-only. One transaction.

BEGIN;

CREATE OR REPLACE FUNCTION TRG_BEVERAGES_COUNT_SYNC()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE producers SET beverage_count = beverage_count + 1
    WHERE id = NEW.producer_id;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE producers SET beverage_count = beverage_count - 1
    WHERE id = OLD.producer_id;
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

COMMIT;
