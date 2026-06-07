-- WHY: CREATE / DROP INDEX CONCURRENTLY cannot run inside a transaction
-- block. This file carries only bare-statement DDL; do NOT wrap in
-- BEGIN/COMMIT. Companion to 004_bigm_search.sql.

DROP INDEX CONCURRENTLY IF EXISTS idx_beverages_search_tsv;
DROP INDEX CONCURRENTLY IF EXISTS idx_beverages_search_trgm;
DROP INDEX CONCURRENTLY IF EXISTS idx_producers_search_tsv;
DROP INDEX CONCURRENTLY IF EXISTS idx_producers_search_trgm;
DROP INDEX CONCURRENTLY IF EXISTS idx_users_username_trgm;
DROP INDEX CONCURRENTLY IF EXISTS idx_users_display_name_trgm;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_beverages_search_bigm
  ON beverages USING gin (search_text gin_bigm_ops)
  WHERE deleted_at IS NULL;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_producers_search_bigm
  ON producers USING gin (search_text gin_bigm_ops)
  WHERE deleted_at IS NULL;

-- WHY: users.username is stored lowercase by SPEC invariant (§3.2 / §6.3),
-- so no lower() projection is needed here. display_name is mixed-case and
-- must be lowered for case-insensitive substring search.
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_users_username_bigm
  ON users USING gin (username gin_bigm_ops);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_users_display_name_bigm
  ON users USING gin (lower(display_name) gin_bigm_ops)
  WHERE display_name IS NOT NULL;
