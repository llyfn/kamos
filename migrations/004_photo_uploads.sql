-- 004_photo_uploads.sql — Phase 3.
--
-- Tracks presigned-PUT photo uploads to Cloudflare R2 (or any S3-compatible
-- backend). Lifecycle:
--   'pending'  → presigned URL issued, client has NOT yet PUT
--   'attached' → POST /v1/check-ins/{id}/photos linked it to a check_in_photo
--                row. The Phase 3 handler promotes 'pending' → 'attached'
--                directly (trusting the client claim that the PUT succeeded);
--                the orphan-cleanup job sweeps anything that never reaches
--                'attached'.
--   'orphaned' → never attached within 24h. Object deleted from R2, row kept
--                for audit.
-- The 'uploaded' value is reserved for a future server-side HEAD-verify step
-- (we don't use it in Phase 3 but keeping it in the enum avoids a migration
-- later).
BEGIN;

CREATE TYPE photo_upload_status AS ENUM ('pending', 'uploaded', 'attached', 'orphaned');

CREATE TABLE photo_uploads (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  blob_key        TEXT NOT NULL UNIQUE,
  content_type    TEXT NOT NULL,
  byte_size       INTEGER NOT NULL CHECK (byte_size > 0 AND byte_size <= 10 * 1024 * 1024),
  status          photo_upload_status NOT NULL DEFAULT 'pending',
  check_in_id     UUID REFERENCES check_ins(id) ON DELETE SET NULL,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  attached_at     TIMESTAMPTZ,
  orphaned_at     TIMESTAMPTZ
);

CREATE INDEX idx_photo_uploads_user ON photo_uploads(user_id);
CREATE INDEX idx_photo_uploads_orphan_candidates ON photo_uploads(created_at)
  WHERE status IN ('pending', 'uploaded');

COMMIT;
