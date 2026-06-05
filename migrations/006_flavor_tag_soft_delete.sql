-- 006_flavor_tag_soft_delete.sql
-- Slice C, post-MVP polish batch.
--
-- 1. Add `flavor_tags.deleted_at` so the admin can soft-delete unused tags
--    (mirrors the pattern used on beverages/producers/subcategories). The
--    application layer blocks deletion when `check_in_flavor_tags` still
--    references the tag, so this is a polish/cleanup primitive, not a
--    cascading destructive op.
-- 2. Extend the `moderation_target_type` enum with `subcategory` and
--    `flavor_tag` so the admin CRUD handlers added in this slice can
--    write audit rows alongside their mutations (same pattern as
--    'beverage' / 'producer' from migration 014).
--
-- Both changes are additive — no existing index or trigger needs to move.
-- The partial unique index on `slug` is preserved (slugs stay globally
-- unique even after soft-delete; admins must rename before deleting if
-- they want to free the slug, which is fine: the seed slugs are stable).
--
-- One transaction. Append-only.

BEGIN;

-- ---------------------------------------------------------------------------
-- flavor_tags.deleted_at
-- ---------------------------------------------------------------------------
ALTER TABLE flavor_tags
ADD COLUMN deleted_at TIMESTAMPTZ;

-- Public taxonomy reads should never include tombstones. The existing
-- idx_flavor_tags_dimension and idx_flavor_tags_slug are full-table
-- indexes; the partial below lets the admin "active only" filter (the
-- default) hit a smaller index. We keep the original idx_flavor_tags_slug
-- intact so the slug uniqueness invariant survives even across
-- soft-delete/re-create churn.
CREATE INDEX idx_flavor_tags_active
ON flavor_tags (dimension, sort_order)
WHERE deleted_at IS NULL;

-- ---------------------------------------------------------------------------
-- moderation_target_type — add 'subcategory' + 'flavor_tag'
-- ---------------------------------------------------------------------------
-- Postgres enum extension is non-transactional inside a CREATE TYPE
-- variant, but ALTER TYPE ... ADD VALUE *does* run inside a tx as of PG12+
-- as long as the new value isn't used in the same tx. We don't use the
-- new values until later runtime, so this is safe.
ALTER TYPE MODERATION_TARGET_TYPE ADD VALUE IF NOT EXISTS 'subcategory';
ALTER TYPE MODERATION_TARGET_TYPE ADD VALUE IF NOT EXISTS 'flavor_tag';

COMMIT;
