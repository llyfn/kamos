-- 011_counter_caches.sql
-- Stage 5: counter-cache columns + triggers to eliminate correlated subqueries.
--
-- Background: the feed query in repository/feed.go shipped with four
-- correlated subqueries per row (toasts, comments, photos, you_toasted).
-- The first three are O(rows × feed_page_size) — at 20 items per feed
-- page that's 60 extra index scans per fetch. The brewery list and
-- collection list share the same anti-pattern in different shapes.
--
-- Strategy: denormalize the four counts that the feed actually needs
-- onto their parent row, then maintain via triggers that mirror the
-- existing trg_check_ins_aggregate_sync pattern in migration 001.
-- you_toasted stays a per-viewer EXISTS — it can't be denormalized
-- because the answer depends on the requesting user.
--
-- Photos: we keep photos as a join-table fetch (PhotosFor batch) rather
-- than denormalizing the count, because the feed now ships the actual
-- photo URLs (not just the count) and that batch fetch is already O(1)
-- per page via the partial index idx_check_in_photos_check_in.
--
-- Append-only; backfill is a one-shot UPDATE … FROM that runs in this
-- migration. The triggers fire from the first row inserted post-deploy.

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. Add counter columns. DEFAULT 0 + NOT NULL on the new columns means we
--    can apply this migration even on an empty DB without backfill ordering
--    grief.
-- ---------------------------------------------------------------------------
ALTER TABLE check_ins
  ADD COLUMN toast_count   INT NOT NULL DEFAULT 0,
  ADD COLUMN comment_count INT NOT NULL DEFAULT 0;

ALTER TABLE breweries
  ADD COLUMN beverage_count INT NOT NULL DEFAULT 0;

ALTER TABLE collections
  ADD COLUMN entry_count INT NOT NULL DEFAULT 0;

-- ---------------------------------------------------------------------------
-- 2. Sanity CHECK constraints — counts can never go negative. If a future
--    bug in the trigger flips one of these to -1, the constraint trips the
--    transaction and the developer sees it immediately instead of a
--    silently wrong feed count weeks later.
-- ---------------------------------------------------------------------------
ALTER TABLE check_ins
  ADD CONSTRAINT check_ins_toast_count_nonneg   CHECK (toast_count   >= 0),
  ADD CONSTRAINT check_ins_comment_count_nonneg CHECK (comment_count >= 0);

ALTER TABLE breweries
  ADD CONSTRAINT breweries_beverage_count_nonneg CHECK (beverage_count >= 0);

ALTER TABLE collections
  ADD CONSTRAINT collections_entry_count_nonneg CHECK (entry_count >= 0);

-- ---------------------------------------------------------------------------
-- 3. Backfill each counter from the source-of-truth aggregate. One UPDATE
--    per counter, written as UPDATE … FROM (SELECT … GROUP BY …) so the
--    aggregate scan runs once and the join is a hash-join, not per-row
--    correlated.
-- ---------------------------------------------------------------------------

-- toast_count: COUNT of toasts per check-in.
UPDATE check_ins ci
SET toast_count = sub.cnt
FROM (
  SELECT check_in_id, COUNT(*)::int AS cnt
  FROM toasts
  GROUP BY check_in_id
) sub
WHERE ci.id = sub.check_in_id;

-- comment_count: COUNT of live (non-soft-deleted) comments per check-in.
UPDATE check_ins ci
SET comment_count = sub.cnt
FROM (
  SELECT check_in_id, COUNT(*)::int AS cnt
  FROM comments
  WHERE deleted_at IS NULL
  GROUP BY check_in_id
) sub
WHERE ci.id = sub.check_in_id;

-- beverage_count: COUNT of beverages per brewery.
UPDATE breweries br
SET beverage_count = sub.cnt
FROM (
  SELECT brewery_id, COUNT(*)::int AS cnt
  FROM beverages
  GROUP BY brewery_id
) sub
WHERE br.id = sub.brewery_id;

-- entry_count: COUNT of collection_entries per live collection.
-- Soft-deleted collections still get counted from the join table — the
-- query layer filters them out at read time, and a future un-delete (if
-- we add one) would want the count to be already-correct on re-surface.
UPDATE collections c
SET entry_count = sub.cnt
FROM (
  SELECT collection_id, COUNT(*)::int AS cnt
  FROM collection_entries
  GROUP BY collection_id
) sub
WHERE c.id = sub.collection_id;

-- ---------------------------------------------------------------------------
-- 4. Trigger functions. One per counter, named after the source table so
--    pg_trigger inspection is self-explanatory. Each follows the same
--    AFTER-row shape as trg_check_ins_aggregate_sync in 001_initial.sql.
-- ---------------------------------------------------------------------------

-- toast_count: ±1 on INSERT/DELETE of a toasts row.
CREATE OR REPLACE FUNCTION trg_toasts_count_sync()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE check_ins SET toast_count = toast_count + 1
    WHERE id = NEW.check_in_id;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE check_ins SET toast_count = toast_count - 1
    WHERE id = OLD.check_in_id;
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_toasts_count
  AFTER INSERT OR DELETE ON toasts
  FOR EACH ROW EXECUTE FUNCTION trg_toasts_count_sync();

-- comment_count: ±1 on INSERT/DELETE; also tracks UPDATE of deleted_at
-- so that soft-delete decrements and un-delete (admin restore) re-increments.
-- The trigger fires AFTER UPDATE OF deleted_at — Postgres optimizes column-
-- scoped UPDATE triggers so an unrelated body edit (we don't currently
-- allow that, but defensive) doesn't pay the trigger cost.
CREATE OR REPLACE FUNCTION trg_comments_count_sync()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    -- Newly inserted rows are always live (deleted_at default is NULL).
    UPDATE check_ins SET comment_count = comment_count + 1
    WHERE id = NEW.check_in_id;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    -- Hard delete: only decrement when the row was live at delete time.
    IF OLD.deleted_at IS NULL THEN
      UPDATE check_ins SET comment_count = comment_count - 1
      WHERE id = OLD.check_in_id;
    END IF;
    RETURN OLD;
  ELSIF TG_OP = 'UPDATE' THEN
    -- Soft-delete: live → deleted. Decrement.
    IF OLD.deleted_at IS NULL AND NEW.deleted_at IS NOT NULL THEN
      UPDATE check_ins SET comment_count = comment_count - 1
      WHERE id = NEW.check_in_id;
    -- Un-delete (admin restore): deleted → live. Re-increment.
    ELSIF OLD.deleted_at IS NOT NULL AND NEW.deleted_at IS NULL THEN
      UPDATE check_ins SET comment_count = comment_count + 1
      WHERE id = NEW.check_in_id;
    END IF;
    RETURN NEW;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_comments_count
  AFTER INSERT OR DELETE ON comments
  FOR EACH ROW EXECUTE FUNCTION trg_comments_count_sync();

CREATE TRIGGER trg_comments_count_update
  AFTER UPDATE OF deleted_at ON comments
  FOR EACH ROW EXECUTE FUNCTION trg_comments_count_sync();

-- beverage_count: ±1 on INSERT/DELETE of a beverages row.
CREATE OR REPLACE FUNCTION trg_beverages_count_sync()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE breweries SET beverage_count = beverage_count + 1
    WHERE id = NEW.brewery_id;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE breweries SET beverage_count = beverage_count - 1
    WHERE id = OLD.brewery_id;
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_beverages_count
  AFTER INSERT OR DELETE ON beverages
  FOR EACH ROW EXECUTE FUNCTION trg_beverages_count_sync();

-- entry_count: ±1 on INSERT/DELETE of a collection_entries row.
CREATE OR REPLACE FUNCTION trg_collection_entries_count_sync()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE collections SET entry_count = entry_count + 1
    WHERE id = NEW.collection_id;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE collections SET entry_count = entry_count - 1
    WHERE id = OLD.collection_id;
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_collection_entries_count
  AFTER INSERT OR DELETE ON collection_entries
  FOR EACH ROW EXECUTE FUNCTION trg_collection_entries_count_sync();

COMMIT;
