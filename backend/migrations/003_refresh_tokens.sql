-- 003_refresh_tokens.sql
--
-- Phase 2 (post-MVP roadmap): rotating refresh tokens
-- with re-use detection.
--
-- Design:
--   * `token_hash` is the SHA-256 of the raw secret. The raw secret is the only
--     value clients ever see; it is hashed before persistence and never logged.
--   * Tokens form a chain: each rotation links to its predecessor via
--     `parent_id`; the originating token of a chain (issued at login) carries
--     `family_id = id` (set by the application on insert).
--   * `revoked_at` is set on rotation (predecessor) and on logout (single or
--     all). Re-use of a revoked token revokes the entire family.
--   * `expires_at` is enforced by the application; the partial index helps the
--     periodic cleanup job find candidates without scanning revoked rows.
BEGIN;

CREATE TABLE refresh_tokens (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash    BYTEA NOT NULL UNIQUE,           -- SHA-256 of the raw secret. Raw never stored.
  parent_id     UUID REFERENCES refresh_tokens(id) ON DELETE SET NULL,  -- previous token in the rotation chain
  family_id     UUID NOT NULL,                   -- top-of-chain marker; all rotations in a chain share it
  issued_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at    TIMESTAMPTZ NOT NULL,
  revoked_at    TIMESTAMPTZ,
  device_label  TEXT,
  -- user-agent ish; not currently exposed on wire, future
  user_agent    TEXT,
  ip            INET
);

CREATE INDEX idx_refresh_tokens_user_active ON refresh_tokens(user_id) WHERE revoked_at IS NULL;
CREATE INDEX idx_refresh_tokens_family ON refresh_tokens(family_id);
CREATE INDEX idx_refresh_tokens_expires ON refresh_tokens(expires_at) WHERE revoked_at IS NULL;

COMMIT;
