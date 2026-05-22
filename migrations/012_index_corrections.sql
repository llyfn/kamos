-- 012_index_corrections.sql
-- Stage 5: index corrections for keyset pagination + dead-index removal.
--
-- Three independent fixes bundled because they all touch indexes and
-- carry no application-level dependency on each other:
--
-- 1. idx_beverages_popularity_keyset — gives the beverage list the
--    proper (check_in_count, created_at, id) ordering so the popularity
--    cursor is stable across ties. Today the list orders on
--    (check_in_count DESC, id DESC) which produces inconsistent pages
--    whenever the count column mutates underneath an active cursor
--    (PERF-003).
--
-- 2. idx_follows_followed_accepted_keyset — covers Inbox /
--    Followers / Following's tuple keyset on
--    (followed_id, accepted_at DESC, follower_id DESC). The plain
--    idx_follows_followed_accepted that 001 created can't seek by the
--    accepted_at tail (PERF-013/014).
--
-- 3. Drop idx_check_ins_created_global — no production query reads
--    check-ins globally without a user_id filter (the feed JOINs the
--    follow set; profile and beverage paths filter on user_id /
--    beverage_id). The global index costs every write but pays for no
--    read (PERF-026).
--
-- NOTE on idx_users_email_live: the plan called for a rebuild from a
-- plain `email` column to `LOWER(email)`. Inspection of migration 001
-- line 114 shows the index was already created on `LOWER(email)` —
-- this was already correct and no rebuild is needed. Leaving a paper
-- trail here so a future audit doesn't try to re-fix it.
--
-- Append-only.

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. Popularity keyset on beverages.
-- ---------------------------------------------------------------------------
-- The existing idx_beverages_avg_rating_desc covers a different sort
-- (avg_rating among beverages with ≥3 check-ins) and is partial. The
-- popularity-list path needs a full-table index because the unfiltered
-- list excludes nothing.
--
-- Composite key: (check_in_count DESC, created_at DESC, id DESC). The
-- triple is what the cursor encodes — (CheckInCount, CreatedAt, ID) —
-- so a forward seek `WHERE (check_in_count, created_at, id) < ($1, $2, $3)`
-- can walk the index in order.
CREATE INDEX idx_beverages_popularity_keyset
ON beverages (check_in_count DESC, created_at DESC, id DESC);

-- ---------------------------------------------------------------------------
-- 2. Follows accepted keyset.
-- ---------------------------------------------------------------------------
-- Inbox uses (created_at, follower_id); Followers/Following use
-- (accepted_at, follower_id|followed_id). The shared physical index
-- supports the accepted_at tail because all 'accepted' rows have
-- accepted_at NOT NULL (CHECK in 001). Partial on status = 'accepted'
-- keeps the index lean — pending rows are rare and read by a
-- separate inbox-specific path.
CREATE INDEX idx_follows_followed_accepted_keyset
ON follows (followed_id, accepted_at DESC, follower_id DESC)
WHERE status = 'accepted';

-- ---------------------------------------------------------------------------
-- 3. Drop the unused global check-in index.
-- ---------------------------------------------------------------------------
-- PERF-026: no current query reads check_ins without a user_id or
-- beverage_id filter; idx_check_ins_user_created and
-- idx_check_ins_beverage_created cover those. Dropping the global
-- index removes one write amplification factor for every check-in
-- insert/update.
DROP INDEX IF EXISTS idx_check_ins_created_global;

COMMIT;
