-- 003_check_in_edited_at.sql
-- KAMOS — add `edited_at` to check_ins (SPEC §4.4 post-create editability).
--
-- Rationale: an author may edit rating / review / tags / photos / price /
-- purchase_type on their own check-in after creation (SPEC §4.4). The
-- column is rendering-only ("edited" marker next to the timestamp); never
-- sorted or filtered server-side, so no index is created. NULL means the
-- row has not been touched since creation. The backend sets it in the same
-- transaction as any tracked-field change (see docs/db/query_patterns.md
-- §7 "Edit a check-in"). Append-only; one transaction.

BEGIN;

ALTER TABLE check_ins ADD COLUMN edited_at TIMESTAMPTZ NULL;

COMMIT;
