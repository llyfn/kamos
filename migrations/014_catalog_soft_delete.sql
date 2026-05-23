-- 014_catalog_soft_delete.sql
-- Admin catalog CRUD — add soft-delete to beverages and breweries.
--
-- The admin SPA gains direct create/update/soft-delete endpoints for the
-- canonical catalog. Soft-delete is preferred over hard-delete because:
--   * `check_ins.beverage_id` and `collection_entries.beverage_id` are
--     ON DELETE RESTRICT (001) — hard-deleting a beverage that has any
--     history would fail.
--   * `beverages.brewery_id` is also ON DELETE RESTRICT — same story for
--     breweries with live beverages. The brewery soft-delete handler runs a
--     preflight that returns 409 BREWERY_HAS_LIVE_BEVERAGES if any
--     non-soft-deleted beverage still references the brewery.
--   * Admin "restore" is a documented requirement; only soft-delete preserves
--     the row for that.
--
-- All existing public-read indexes on these tables are rebuilt as partial
-- (WHERE deleted_at IS NULL) so the planner keeps using them on the hot
-- public catalog path without having to filter the soft-deleted rows
-- post-fetch. Column orders and operator classes match the canonical
-- definitions in 001_initial.sql verbatim — verified before writing this
-- migration.
--
-- Apply window: this migration DROPs five indexes on `beverages` and one on
-- `breweries`, then recreates them as partial. Between the DROP and the
-- CREATE there is a brief window where queries that would have hit those
-- indexes fall back to seq-scan. For the current hosted env (single Fly
-- region, small catalog, off-hours apply per docs/runbooks/deploy.md §2)
-- that's acceptable. If catalog volume grows, switch to CREATE INDEX
-- CONCURRENTLY in a follow-up migration outside any transaction block.
--
-- `idx_breweries_prefecture` remains deferred per docs/db/indexes.md §breweries —
-- browse-by-prefecture is not a current requirement.
--
-- Append-only.

BEGIN;

-- ---------------------------------------------------------------------------
-- Soft-delete columns.
-- ---------------------------------------------------------------------------
ALTER TABLE beverages ADD COLUMN deleted_at TIMESTAMPTZ;
ALTER TABLE breweries ADD COLUMN deleted_at TIMESTAMPTZ;

-- ---------------------------------------------------------------------------
-- Rebuild beverage indexes as partial (WHERE deleted_at IS NULL).
-- Definitions mirror 001_initial.sql exactly — column orders, opclass,
-- and tsvector concatenation are preserved.
-- ---------------------------------------------------------------------------
DROP INDEX idx_beverages_brewery;
DROP INDEX idx_beverages_category;
DROP INDEX idx_beverages_name_gin;
DROP INDEX idx_beverages_name_tsv;
DROP INDEX idx_beverages_avg_rating_desc;

CREATE INDEX idx_beverages_brewery
ON beverages (brewery_id)
WHERE deleted_at IS NULL;

CREATE INDEX idx_beverages_category
ON beverages (category_id)
WHERE deleted_at IS NULL;

CREATE INDEX idx_beverages_name_gin
ON beverages USING gin (name_i18n jsonb_path_ops)
WHERE deleted_at IS NULL;

CREATE INDEX idx_beverages_name_tsv
ON beverages USING gin (
  to_tsvector(
    'simple',
    coalesce(name_i18n ->> 'en', '') || ' '
    || coalesce(name_i18n ->> 'ja', '') || ' '
    || coalesce(name_i18n ->> 'ko', '')
  )
)
WHERE deleted_at IS NULL;

CREATE INDEX idx_beverages_avg_rating_desc
ON beverages (category_id, avg_rating DESC NULLS LAST)
WHERE deleted_at IS NULL AND check_in_count >= 3;

-- ---------------------------------------------------------------------------
-- Rebuild brewery FTS index as partial.
-- ---------------------------------------------------------------------------
DROP INDEX idx_breweries_name_tsv;

CREATE INDEX idx_breweries_name_tsv
ON breweries USING gin (
  to_tsvector(
    'simple',
    coalesce(name_i18n ->> 'en', '') || ' '
    || coalesce(name_i18n ->> 'ja', '') || ' '
    || coalesce(name_i18n ->> 'ko', '')
  )
)
WHERE deleted_at IS NULL;

-- ---------------------------------------------------------------------------
-- "Trash" helper indexes — used only by admin `include_deleted` queries.
-- Partial WHERE deleted_at IS NOT NULL keeps them tiny; the dominant write
-- path (deleted_at IS NULL) never touches these.
-- ---------------------------------------------------------------------------
CREATE INDEX idx_beverages_deleted_at
ON beverages (deleted_at)
WHERE deleted_at IS NOT NULL;

CREATE INDEX idx_breweries_deleted_at
ON breweries (deleted_at)
WHERE deleted_at IS NOT NULL;

COMMIT;
