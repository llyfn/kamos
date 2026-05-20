-- 010_hash_verification_tokens.sql
-- Stage 0 / SEC-004: store only SHA-256 hashes of verification tokens.
--
-- Background: previously `email_verifications.token` held the raw token
-- string the user clicks through their email. A DB read or backup leak
-- exposes the live verification URL until the 24-hour expiry. This
-- migration moves to the same hashed-secret discipline already used for
-- refresh_tokens.token_hash.
--
-- Strategy:
--   1. Add nullable `token_hash` column.
--   2. Backfill `digest(token, 'sha256')` (pgcrypto is enabled in 001).
--   3. Add UNIQUE partial index on token_hash for live (unused, unexpired)
--      rows so the existing per-user-stack pattern keeps O(1) lookup.
--   4. Drop the plaintext `token` column.
--
-- Outstanding-token caveat: between (3) and the deploy of the matching
-- application code, any pre-migration plaintext token is no longer
-- claimable because the new code looks up by hash. Users with a live
-- verify email in their inbox at the moment of deploy will need to
-- re-request via /v1/auth/resend-verification. Acceptable: the token's
-- 24h life-span makes this a single-day window.
--
-- Append-only.

BEGIN;

ALTER TABLE email_verifications
  ADD COLUMN token_hash BYTEA;

-- Backfill existing rows so the column is non-null before we drop the
-- plaintext source.
UPDATE email_verifications
SET token_hash = digest(token, 'sha256')
WHERE token_hash IS NULL;

-- Now require it.
ALTER TABLE email_verifications
  ALTER COLUMN token_hash SET NOT NULL;

-- Unique among UNUSED verification rows. We don't filter on expires_at
-- in the predicate because NOW() is not IMMUTABLE and Postgres refuses
-- the index. used_at IS NULL is enough — the email-verification-cleanup
-- job hard-deletes rows after the 24h window, and the application
-- layer (FindUserByVerificationToken) still re-checks expires_at on
-- read. Token entropy is 256 bits so a clash on an expired-but-unused
-- row is astronomically unlikely.
CREATE UNIQUE INDEX idx_email_verifications_token_hash
  ON email_verifications (token_hash)
  WHERE used_at IS NULL;

-- Drop the unique index on the plaintext column (idx_email_verifications_token
-- created in migration 001) so the column drop below succeeds without an
-- index-rename dance.
DROP INDEX IF EXISTS idx_email_verifications_token;

-- Drop the plaintext column. Any application read path that referenced
-- it must move to token_hash before this migration is applied.
ALTER TABLE email_verifications
  DROP COLUMN token;

COMMIT;
