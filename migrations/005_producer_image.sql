-- 005_producer_image.sql
-- KAMOS — add `image_url` to producers (admin-uploaded optional image).
--
-- Rationale: producers may carry one optional image (logo / brewery photo /
-- label collage) uploaded by admins via the existing R2 presign flow with
-- `purpose: "producer"`. The column is rendering-only — surfaced on the
-- Flutter producer detail hero and as an optional 16-dp thumbnail in the
-- check-in card's producer row. Never filtered or sorted server-side, so
-- no index is created. NULL means no image has been uploaded; the mobile
-- app renders a calm kinari-tile on the detail screen and omits the
-- thumbnail entirely on the feed card (no placeholder). No length CHECK:
-- R2 URLs vary and the value is already sanitized at the handler edge.
-- Append-only; one transaction.

BEGIN;

ALTER TABLE producers ADD COLUMN image_url TEXT NULL;

COMMIT;
