-- WHY: CREATE INDEX CONCURRENTLY cannot run inside a transaction block, and
-- DROP INDEX paired with it must run outside one for symmetry. This file
-- carries only bare-statement DDL; do NOT wrap in BEGIN/COMMIT. Companion
-- to 003_search_indexes.sql.

DROP INDEX IF EXISTS idx_beverages_name_tsv;
DROP INDEX IF EXISTS idx_producers_name_tsv;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_beverages_search_tsv
  ON beverages USING GIN (search_tsv)
  WHERE deleted_at IS NULL;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_beverages_search_trgm
  ON beverages USING GIN ((search_tsv::text) gin_trgm_ops)
  WHERE deleted_at IS NULL;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_producers_search_tsv
  ON producers USING GIN (search_tsv)
  WHERE deleted_at IS NULL;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_producers_search_trgm
  ON producers USING GIN ((search_tsv::text) gin_trgm_ops)
  WHERE deleted_at IS NULL;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_users_username_trgm
  ON users USING GIN (username gin_trgm_ops);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_users_display_name_trgm
  ON users USING GIN (display_name gin_trgm_ops)
  WHERE display_name IS NOT NULL;
