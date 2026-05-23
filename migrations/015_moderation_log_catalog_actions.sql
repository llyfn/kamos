-- 015_moderation_log_catalog_actions.sql
-- Extend the moderation_log enums (008) so admin catalog CRUD writes
-- audit rows in the same shape as the existing comment/check-in/user
-- moderation paths.
--
-- Two enum types defined in 008_collections_visibility_and_moderation_log.sql
-- gain three new values combined:
--   moderation_target_type += 'beverage', 'brewery'
--   moderation_action_type += 'create', 'update', 'restore'
-- (`soft_delete` already exists and is reused for the delete path.)
--
-- Transactionality note: `ALTER TYPE … ADD VALUE` cannot run inside a
-- transaction block on Postgres < 12. Postgres 18 (our target) relaxes this,
-- but only if the newly added value is not USED in the same transaction.
-- To stay portable and trivially safe under either rule:
--   * no BEGIN/COMMIT wrapper in this file;
--   * each statement is on its own line so `scripts/migrate.sh` (which runs
--     `psql -f`) submits them as separate implicit transactions;
--   * this migration is ADDITIVE ONLY — it does not INSERT into
--     moderation_log or otherwise reference the new values. The Go layer
--     (admin_beverages.go / admin_breweries.go) is what eventually writes
--     log rows carrying the new values, and that runs in its own
--     transactions long after this migration commits.
--
-- IF NOT EXISTS guards make this migration safe to re-apply against any
-- DB that may have been hand-patched.
--
-- Append-only.

ALTER TYPE moderation_target_type ADD VALUE IF NOT EXISTS 'beverage';
ALTER TYPE moderation_target_type ADD VALUE IF NOT EXISTS 'brewery';
ALTER TYPE moderation_action_type ADD VALUE IF NOT EXISTS 'create';
ALTER TYPE moderation_action_type ADD VALUE IF NOT EXISTS 'update';
ALTER TYPE moderation_action_type ADD VALUE IF NOT EXISTS 'restore';
