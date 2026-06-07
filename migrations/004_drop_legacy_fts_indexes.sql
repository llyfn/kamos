-- Drop the two FTS GIN indexes seeded by 001_initial.sql. Migration 003
-- replaced the FTS search path with pg_bigm (`search_text` + bigm GIN), so
-- these indexes are dead weight — no query uses them and they cost GIN
-- maintenance on every beverages / producers write.
--
-- WHY a separate migration instead of in-place edit of 001: 001 has
-- already been applied on prod (and every fresh env applies it from
-- scratch). The append-only convention means we add a small cleanup
-- migration rather than mutate history; fresh environments create the
-- indexes in 001 and drop them here, prod just runs the drops.
BEGIN;

-- WHY noqa: PG01 — plain DROP INDEX (not CONCURRENTLY) so this stays
-- in a single transaction with itself. The lock window is metadata-only;
-- not worth the bare-statement file split for two drops.
DROP INDEX IF EXISTS idx_beverages_name_tsv;  -- noqa: PG01
DROP INDEX IF EXISTS idx_producers_name_tsv;  -- noqa: PG01

COMMIT;
