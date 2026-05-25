-- 017_rename_brewery_to_producer_and_drop_serving_style.sql
-- Two unrelated catalog cleanups bundled into one append-only migration:
--
-- 1. Rename `breweries` → `producers` (and `beverages.brewery_id` →
--    `beverages.producer_id`). "Brewery" reads as sake-centric, but the same
--    catalog row type already holds shochu distilleries and liqueur makers —
--    none of which "brew" anything. "Producer" is the neutral term that
--    covers all three categories in EN and KO (the KO ARB ships 생산자 from
--    this change forward). JA stays 蔵元 in the UI: this is a locale choice
--    in the ARB layer, not a column choice. The migration itself is
--    locale-agnostic; only the relation/column/index/constraint identifiers
--    change.
--
--    The schema rename touches:
--      * table `breweries` → `producers`
--      * column `beverages.brewery_id` → `beverages.producer_id`
--      * indexes `idx_beverages_brewery`, `idx_breweries_name_tsv`,
--        `idx_breweries_deleted_at`, `idx_breweries_prefecture_id` →
--        their `producer(s)` analogues
--      * CHECK constraint `breweries_beverage_count_nonneg`
--        → `producers_beverage_count_nonneg`
--      * FK constraint `beverages_brewery_id_fkey`
--        → `beverages_producer_id_fkey` (PostgreSQL auto-named the original
--        in 001_initial.sql because the REFERENCES clause was inline-anonymous;
--        ALTER COLUMN RENAME does not rename the FK, so we do it explicitly)
--      * enum value `moderation_target_type 'brewery'` → `'producer'`
--        (introduced in 015_moderation_log_catalog_actions.sql)
--
--    User has explicitly authorized downtime for this rename, so we do it
--    in-place with `ALTER TABLE … RENAME` rather than table-copy. No data
--    moves, no FKs invalidate; pg_catalog updates and we're done.
--
-- 2. Drop `check_ins.serving_style`. Removed from MVP scope — the column
--    and its accompanying CHECK constraint (`check_ins_serving_style_allowed`,
--    column-bound, declared in 001_initial.sql) disappear together when the
--    column is dropped. No data migration; whatever values were stored go
--    away. Audit confirms no indexes reference `serving_style` (only the
--    inline CHECK), so the column drop is sufficient.
--
-- Validation: apply on a fresh test DB and verify with
--   \d+ producers         -- table exists, FK & indexes attached
--   \d+ beverages         -- producer_id column + producer FK present
--   \d+ check_ins         -- no serving_style column
--   \dT+ moderation_target_type  -- enum has 'producer', not 'brewery'
--   \di idx_producers_*   -- four producer indexes present
--
-- Append-only. One transaction. ALTER TYPE RENAME VALUE works inside a
-- transaction on PostgreSQL 18 (unlike ADD VALUE, which was the wrinkle in
-- migration 015), so this whole migration stays atomic.

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. Rename the table: breweries → producers.
-- ---------------------------------------------------------------------------
ALTER TABLE breweries RENAME TO producers;

-- ---------------------------------------------------------------------------
-- 2. Rename the FK column on beverages: brewery_id → producer_id.
--    PostgreSQL updates the FK constraint's referenced column metadata
--    automatically, but the FK *name* is unchanged — we rename it below.
-- ---------------------------------------------------------------------------
ALTER TABLE beverages RENAME COLUMN brewery_id TO producer_id;

ALTER TABLE beverages
RENAME CONSTRAINT beverages_brewery_id_fkey TO beverages_producer_id_fkey;

-- ---------------------------------------------------------------------------
-- 3. Rename indexes so identifiers stay self-documenting.
--    Order is alphabetical-by-old-name for easy diffing against pg_indexes.
-- ---------------------------------------------------------------------------
ALTER INDEX idx_beverages_brewery RENAME TO idx_beverages_producer;
ALTER INDEX idx_breweries_deleted_at RENAME TO idx_producers_deleted_at;
ALTER INDEX idx_breweries_name_tsv RENAME TO idx_producers_name_tsv;
ALTER INDEX idx_breweries_prefecture_id RENAME TO idx_producers_prefecture_id;

-- ---------------------------------------------------------------------------
-- 4. Rename the non-neg CHECK constraint.
--    Defined in 011_counter_caches.sql alongside the `beverage_count` column,
--    which keeps its name — only the parent table is renamed, the counter is
--    still a count of beverages on that producer.
-- ---------------------------------------------------------------------------
ALTER TABLE producers
RENAME CONSTRAINT breweries_beverage_count_nonneg TO producers_beverage_count_nonneg;

-- ---------------------------------------------------------------------------
-- 5. Rename the moderation enum value: 'brewery' → 'producer'.
--    Added to moderation_target_type in 015_moderation_log_catalog_actions.sql.
--    Renaming the enum value rewrites existing moderation_log rows in place
--    (the enum is stored as an oid, not as text), so the historical audit
--    trail is preserved with the new label.
-- ---------------------------------------------------------------------------
ALTER TYPE moderation_target_type RENAME VALUE 'brewery' TO 'producer';

-- ---------------------------------------------------------------------------
-- 6. Drop check_ins.serving_style.
--    The column-bound CHECK constraint `check_ins_serving_style_allowed`
--    (declared inline in 001_initial.sql) is auto-dropped with the column.
--    No indexes reference serving_style — audit confirmed by grepping the
--    migrations/ directory — so no orphan indexes remain after this drop.
-- ---------------------------------------------------------------------------
ALTER TABLE check_ins DROP COLUMN serving_style;

COMMIT;
