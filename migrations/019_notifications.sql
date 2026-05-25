-- 019_notifications.sql
-- In-app notifications inbox (SPEC §5.4). Five event types: toast, comment,
-- follow, follow_request, follow_approved. Push is deferred to v1.1.
--
-- Inserted at the app layer in the same transaction as the source event
-- (matches the comments-insert pattern from 009): toast insert → toast row;
-- comment insert → comment row; follow insert (status='accepted') → follow
-- row; follow insert (status='pending') → follow_request row; follow update
-- (pending→accepted) → follow_approved row for the requester. No triggers
-- here — every emit path is explicit in repository code so reviewers can
-- audit the SPEC §5.4 "self-actions never produce a notification" rule.
--
-- Soft-delete semantics:
--   * Recipient hard-delete: ON DELETE CASCADE wipes the recipient's inbox.
--   * Actor delete: ON DELETE SET NULL preserves the row; UI renders
--     "Deleted user" placeholder (SPEC §5.4).
--   * Referenced check-in or comment delete: ON DELETE SET NULL preserves
--     the row; the UI still renders the action but the tap-target stops
--     resolving to the (now-gone) source.
--
-- Append-only. One transaction.

BEGIN;

CREATE TABLE notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  recipient_user_id UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  type TEXT NOT NULL,
  actor_user_id UUID REFERENCES users (id) ON DELETE SET NULL,
  check_in_id UUID REFERENCES check_ins (id) ON DELETE SET NULL,
  comment_id UUID REFERENCES comments (id) ON DELETE SET NULL,
  read_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

  -- SPEC §5.4: only the five canonical event types. TEXT + CHECK chosen over
  -- a Postgres enum so adding a sixth type later (e.g. v1.1 push echo) is a
  -- one-line CHECK rewrite instead of an ALTER TYPE coordinating with every
  -- replica's cached enum oid.
  CONSTRAINT notifications_type_allowed
  CHECK (
    type IN ('toast', 'comment', 'follow', 'follow_request', 'follow_approved')
  ),

  -- SPEC §5.4: "Self-actions never produce a notification." Belt-and-
  -- suspenders against a service-layer bug. actor_user_id NULL is allowed
  -- (soft-deleted actor) and bypasses the check.
  CONSTRAINT notifications_no_self
  CHECK (actor_user_id IS NULL OR actor_user_id <> recipient_user_id),

  -- Per-type reference-column shape. Every emit path knows exactly which
  -- references it must populate; this CHECK rejects malformed rows the
  -- moment they hit the DB instead of letting them rot in the inbox.
  --   toast           → check_in_id required, comment_id NULL
  --   comment         → check_in_id + comment_id both required
  --   follow*         → both check_in_id and comment_id NULL (the actor and
  --                     the recipient are the only meaningful references)
  CONSTRAINT notifications_refs_match_type
  CHECK (
    (type = 'toast' AND check_in_id IS NOT NULL AND comment_id IS NULL)
    OR (type = 'comment' AND check_in_id IS NOT NULL AND comment_id IS NOT NULL)
    OR (
      type IN ('follow', 'follow_request', 'follow_approved')
      AND check_in_id IS NULL
      AND comment_id IS NULL
    )
  )
);

-- ---------------------------------------------------------------------------
-- Dedupe partial unique indexes (per SPEC §5.4 "Deduped on (recipient, type,
-- actor, check_in_id) where applicable").
-- ---------------------------------------------------------------------------

-- toast: a recipient sees at most one toast notification per (actor,
-- check_in). Toggling a toast off and back on must not spam — the second
-- INSERT collapses to ON CONFLICT DO NOTHING in the app layer.
CREATE UNIQUE INDEX idx_notifications_toast_unique
ON notifications (recipient_user_id, actor_user_id, check_in_id)
WHERE type = 'toast';

-- follow: re-following after an unfollow does NOT spam. Once a follow
-- notification exists between (recipient, actor), no second one is ever
-- created (MVP rule; revisit if user feedback wants every re-follow to
-- surface). actor_user_id is in the index because the dedupe is per
-- (recipient, actor) pair, and the same recipient can have many follow
-- notifications from different actors.
CREATE UNIQUE INDEX idx_notifications_follow_unique
ON notifications (recipient_user_id, actor_user_id)
WHERE type = 'follow';

-- follow_approved: one row per (recipient, actor) per approval-event
-- lifetime. If the relationship resets (unfollow → re-request → approve),
-- a *new* row is desirable, but the DB has no view of that lifecycle.
-- MVP picks the simpler invariant (one per pair, ever) and accepts that
-- a unique-violation on re-approval is swallowed by ON CONFLICT DO NOTHING
-- in the app. Acceptable because the same notification still represents
-- the same logical "your follow was approved" event for the requester.
CREATE UNIQUE INDEX idx_notifications_follow_approved_unique
ON notifications (recipient_user_id, actor_user_id)
WHERE type = 'follow_approved';

-- comment: NO unique dedupe — every comment is a distinct event even when
-- the same actor comments multiple times on the same check_in. The natural
-- key would be comment_id, which is already the FK target, so a unique
-- index would be redundant with a (comment_id) lookup.
--
-- follow_request: NO partial unique. The lifecycle is:
--   request (create row) → approve (app deletes row, writes follow_approved)
--                       OR decline (app deletes row)
--                       OR cancel  (app deletes row)
-- The app deletes the follow_request notification on every terminal state,
-- so a second request from the same actor inserts cleanly. A partial unique
-- "where the underlying follows row is still pending" is not expressible in
-- a Postgres partial-index predicate (would need a subquery, not IMMUTABLE).
-- Rely on the application cleanup. Document in docs/db/schema.md.

-- ---------------------------------------------------------------------------
-- Read path indexes
-- ---------------------------------------------------------------------------

-- Primary cursor index for GET /v1/notifications: keyset pagination on
-- (created_at DESC, id DESC) per recipient. Mirrors the established feed /
-- comments / inbox cursor shape from 001 + 009.
CREATE INDEX idx_notifications_recipient_created
ON notifications (recipient_user_id, created_at DESC, id DESC);

-- Unread-count + unread-dot path. Partial keeps the index tiny — most
-- rows in a healthy inbox are read. GET /v1/notifications/unread-count is
-- a count over this index; the badge dot is `EXISTS` over the same.
CREATE INDEX idx_notifications_recipient_unread
ON notifications (recipient_user_id)
WHERE read_at IS NULL;

COMMIT;
