-- 004_comment_edited_at.sql
-- KAMOS — add `edited_at` to comments (SPEC §5.4 post-create editability).
--
-- Rationale: comment authors may edit their own comment body after
-- creation (SPEC §5.4 flat-comments, post-MVP v1.1). The column is
-- rendering-only ("edited" marker next to the timestamp); never sorted or
-- filtered server-side, so no index is created. NULL means the row has
-- not been touched since creation. The backend sets it in the same
-- transaction as any body change (see docs/db/query_patterns.md §19
-- "Edit a comment"). Append-only; one transaction.

BEGIN;

ALTER TABLE comments ADD COLUMN edited_at TIMESTAMPTZ NULL;

COMMIT;
