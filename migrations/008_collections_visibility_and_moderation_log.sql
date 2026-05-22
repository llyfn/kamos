-- 008_collections_visibility_and_moderation_log.sql
-- Phase 6a, part 1.
--
-- Two append-only additions:
--   (1) collections.visibility — public/private toggle for the discovery feed
--       that lands later in this phase.
--   (2) moderation_log         — audit trail for every admin action. Phase 5a
--       deferred this; the QA backlog called it out explicitly. We backfill
--       the table here so the comments + suspend + role-change paths can
--       INSERT into it from the start of Phase 6.
--
-- Append-only — does not touch 001..007. Both DBs (kamos_local + kamos_test)
-- must be migrated to this file before the Go code is rebuilt.

BEGIN;

-- ---------------------------------------------------------------------------
-- Public collections — visibility enum on collections.
-- ---------------------------------------------------------------------------
-- The discovery feed (GET /v1/collections/public, defined in Go in commit 3
-- of Phase 6a) filters on (visibility = 'public' AND deleted_at IS NULL).
-- A partial index keeps that filter cheap.
CREATE TYPE collection_visibility AS ENUM ('private', 'public');

ALTER TABLE collections
ADD COLUMN visibility collection_visibility NOT NULL DEFAULT 'private';

-- Discovery feed: most-recent-first cursor on (created_at, id), partial on
-- the discoverable rows only. Mirrors the same shape as
-- idx_check_ins_created_global (migration 001).
CREATE INDEX idx_collections_public_recent
ON collections (created_at DESC, id DESC)
WHERE visibility = 'public' AND deleted_at IS NULL;

-- ---------------------------------------------------------------------------
-- Moderation log — every admin moderation action writes a row.
-- ---------------------------------------------------------------------------
-- target_type covers the four surfaces a moderator can touch:
--   'check_in'         — soft-delete a check-in (POST /v1/admin/check-ins/{id}/moderate)
--   'comment'          — soft-delete a comment  (POST /v1/admin/comments/{id}/moderate
--                        from commit 5 of Phase 6a)
--   'user'             — suspend a user / change their role
--   'beverage_request' — approve/reject a user-submitted beverage addition
--                        request (Phase 5a admin queue)
--
-- action distinguishes the things a moderator can do beyond a generic
-- soft-delete:
--   'soft_delete' — the row is hidden via deleted_at = NOW()
--   'role_change' — user.role rewritten
--   'suspend'     — admin-initiated soft-delete on a user (carries
--                   metadata: { "username_release_at": "..." })
--   'approve'     — beverage_addition_request → approved (carries
--                   metadata: { "beverage_id": "..." })
--   'reject'      — beverage_addition_request → rejected
--
-- moderator_id is ON DELETE SET NULL so hard-purging an ex-admin (after the
-- 30-day hold) doesn't blow away the audit trail. target_id is NOT
-- constrained to any specific table — moderation can outlive its target
-- (e.g. a comment is soft-deleted, then the parent check-in is cascade-
-- deleted on user purge; the log row still tells us who did what when).
CREATE TYPE moderation_target_type AS ENUM ('check_in', 'comment', 'user', 'beverage_request');
CREATE TYPE moderation_action_type AS ENUM (
  'soft_delete', 'role_change', 'suspend', 'approve', 'reject'
);

CREATE TABLE moderation_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  moderator_id uuid REFERENCES users (id) ON DELETE SET NULL,
  target_type moderation_target_type NOT NULL,
  target_id uuid NOT NULL,
  action moderation_action_type NOT NULL,
  notes text,
  metadata jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT moderation_log_notes_length
  CHECK (notes IS NULL OR char_length(notes) <= 1000)
);

-- "Show me every action ever taken on this row" — admin UI surface.
CREATE INDEX idx_moderation_log_target
ON moderation_log (target_type, target_id, created_at DESC);

-- "Show me everything this moderator did" — audit / abuse-of-power surface.
CREATE INDEX idx_moderation_log_moderator
ON moderation_log (moderator_id, created_at DESC);

COMMIT;
