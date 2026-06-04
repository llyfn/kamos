-- 003_post_mvp_columns.sql
-- KAMOS — additive columns for the post-MVP "editability + producer images"
-- batch (SPEC §4.4, §5.4, post-MVP producer image).
--
-- Three rendering-only nullable columns:
--   1. check_ins.edited_at — set when a tracked field changes on a PATCH
--      (SPEC §4.4 author-edit on own check-in); surfaces the "edited"
--      marker next to the timestamp. Touch pattern: docs/db/query_patterns
--      §7 ("Edit a check-in"). Never sorted / filtered server-side; no
--      index. NULL means the row has not been touched since creation.
--
--   2. comments.edited_at — same semantics for comments (SPEC §5.4 flat
--      comments, author-edit). Touch pattern: query_patterns §19 ("Edit a
--      comment"). NULL means untouched.
--
--   3. producers.image_url — optional admin-uploaded image (logo / brewery
--      photo / label collage). Uploaded via the existing R2 presign flow
--      with `purpose: "producer"`. Surfaced on the Flutter producer
--      detail hero and as an optional 16-dp thumbnail in the check-in
--      card's producer row. Never filtered / sorted server-side, so no
--      index. No length CHECK: R2 URLs vary and the value is already
--      sanitized at the handler edge. NULL means no image.
--
-- All three are append-only ALTER TABLE … ADD COLUMN … NULL. No CHECK
-- constraints (no new business rule beyond "set when row changes" /
-- "set when admin uploads"). One transaction.

BEGIN;

ALTER TABLE check_ins ADD COLUMN edited_at TIMESTAMPTZ NULL;
ALTER TABLE comments ADD COLUMN edited_at TIMESTAMPTZ NULL;
ALTER TABLE producers ADD COLUMN image_url TEXT NULL;

COMMIT;
