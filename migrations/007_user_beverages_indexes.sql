-- 007_user_beverages_indexes.sql
-- KAMOS — index audit for Slice D (user-beverages aggregation).
--
-- The new GET /v1/users/{username}/beverages endpoint aggregates a
-- single user's check-ins grouped by beverage. The hot predicate is
--
--   WHERE user_id = $1 AND deleted_at IS NULL
--   GROUP BY beverage_id
--
-- The existing partial index `idx_check_ins_user_created` (user_id,
-- created_at DESC, id DESC) is a fine seed for the WHERE leading
-- column, but the planner has to hash-aggregate post-scan to satisfy
-- GROUP BY beverage_id. A second partial index on
-- (user_id, beverage_id) lets a power user with hundreds of check-ins
-- skip the hash step entirely — the planner can index-only-scan
-- straight into the grouped projection.
--
-- Index is created with the same `WHERE deleted_at IS NULL`
-- predicate so it stays dense and lines up with the public read
-- path's deleted_at filter.
--
-- Outside-of-transaction DDL: CONCURRENTLY can't run inside BEGIN/
-- COMMIT, so this migration omits the transaction wrapper. If the
-- create fails midway the partial index won't be marked valid and
-- the next apply attempt will tidy up (CONCURRENTLY guarantees no
-- table lock while building).

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_check_ins_user_beverage
ON check_ins (user_id, beverage_id)
WHERE deleted_at IS NULL;
