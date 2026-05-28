-- 020_notifications_check_in_comment_fk_cascade.sql
-- Phase 1 QA follow-up to 019_notifications.sql.
--
-- The original 019 declared notifications.check_in_id and comment_id as
-- ON DELETE SET NULL while notifications_refs_match_type CHECK requires:
--   type = 'toast'   → check_in_id IS NOT NULL
--   type = 'comment' → check_in_id IS NOT NULL AND comment_id IS NOT NULL
-- The two contradict each other: any hard-delete on a referenced check-in
-- or comment triggers the FK's SET NULL cascade, which writes NULL into a
-- column the CHECK forbids, which raises 23514 and aborts the parent
-- DELETE. No app code hard-deletes today, but a TTL/archive job is on the
-- roadmap and would silently break the moment it ran.
--
-- Same shape as the migration-013 incident (comments.user_id FK had no
-- ON DELETE clause, so the username-hold purge silently failed on every
-- comment author). The lesson then and now: when a CHECK forbids NULL
-- on an FK, the FK must CASCADE — never SET NULL.
--
-- Fix: switch both FKs to ON DELETE CASCADE. A hard-deleted check-in or
-- comment is a deliberate purge; wiping the orphaned notification row is
-- the intended behavior (the tap target is gone, the event is gone).
-- actor_user_id stays ON DELETE SET NULL — the row must survive an actor
-- hard-purge so the UI can render the localized "Deleted user" placeholder
-- per SPEC §5.4.
--
-- Soft-deletes do NOT fire CASCADE (the row stays, only deleted_at is
-- set), so SPEC §5.4's "soft-deleting the referenced check-in or comment
-- preserves the notification" still holds — the rendering just stops
-- resolving to a tap target on the Flutter side.
--
-- Append-only — does not edit 019 or any earlier migration.

BEGIN;

ALTER TABLE notifications
DROP CONSTRAINT notifications_check_in_id_fkey;

ALTER TABLE notifications
ADD CONSTRAINT notifications_check_in_id_fkey
FOREIGN KEY (check_in_id)
REFERENCES check_ins (id)
ON DELETE CASCADE;

ALTER TABLE notifications
DROP CONSTRAINT notifications_comment_id_fkey;

ALTER TABLE notifications
ADD CONSTRAINT notifications_comment_id_fkey
FOREIGN KEY (comment_id)
REFERENCES comments (id)
ON DELETE CASCADE;

COMMIT;
