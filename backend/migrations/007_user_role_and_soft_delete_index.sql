-- 007_user_role_and_soft_delete_index.sql
-- Phase 5a — RBAC foundation + SEC-006 (soft-delete JWT revocation) support.
--
-- RBAC choice: single-column enum on `users`. We start with three roles
-- (user / moderator / admin) and only escalate to a relational user_roles
-- table if real granularity (per-resource permissions, multiple concurrent
-- roles per user) actually appears. YAGNI applies — the enum gives us
-- typed validation, postgres-side referential safety, and a 1-column read
-- on every admin request.
--
-- SEC-006 support: the in-memory soft-delete cache (auth/soft_delete_cache.go)
-- refreshes its set every refreshInterval from
--   SELECT id FROM users WHERE deleted_at > now() - INTERVAL '30 minutes'
-- This partial index makes that query indexable; with millions of users the
-- naive seq-scan would dominate the refresh loop's cost.

BEGIN;

CREATE TYPE user_role AS ENUM ('user', 'moderator', 'admin');

ALTER TABLE users
  ADD COLUMN role user_role NOT NULL DEFAULT 'user';

CREATE INDEX idx_users_deleted_at_recent ON users (deleted_at)
  WHERE deleted_at IS NOT NULL;

COMMIT;
