-- 013_comments_user_fk_cascade.sql
-- Stage 7 (M-12.2).
--
-- The original comments.user_id FK (migration 009) had no ON DELETE clause,
-- so PostgreSQL defaulted to NO ACTION. When the username-hold sweep
-- (jobs/username_hold.go) eventually hard-purges a long-deleted user, the
-- delete hits 23503 on every comment they ever posted. The sweep job
-- catches this only as "released = 0" — the FK fails silently, the
-- usernames stay reserved, and the audit trail looks healthy.
--
-- Trade-off picked: SET NULL. The alternative CASCADE would delete the
-- comment row, losing thread context for everyone else. SET NULL keeps
-- the body + timestamps in place; the Flutter card renders an "anonymous"
-- author for orphaned rows.
--
-- Append-only — does not edit 009 or any earlier migration.

BEGIN;

ALTER TABLE comments
  DROP CONSTRAINT comments_user_id_fkey;

ALTER TABLE comments
  ALTER COLUMN user_id DROP NOT NULL;

ALTER TABLE comments
  ADD CONSTRAINT comments_user_id_fkey
  FOREIGN KEY (user_id)
  REFERENCES users(id)
  ON DELETE SET NULL;

COMMIT;
