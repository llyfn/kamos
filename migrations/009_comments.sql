-- 009_comments.sql
-- Phase 6a, part 2: flat comments on check-ins.
--
-- One row per comment. No threading (SPEC §9 keeps threaded comments
-- anti-scope; flat is reopened in v1.1 per the post-MVP roadmap). The check
-- on body length mirrors the SPEC §6.7 review-text cap (≤ 500 chars). The
-- "no control character" check matches the venue-name pattern from
-- migration 006 — defense in depth against poisoned UTF-8 reaching the
-- shared comment surface.
--
-- Append-only. Comments are soft-deleted (deleted_at), then hard-purged
-- via CASCADE when the parent check-in is hard-deleted (which only happens
-- for ON DELETE CASCADE from the user soft-delete sweep job — for normal
-- moderation we soft-delete only).

BEGIN;

CREATE TABLE comments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  check_in_id UUID NOT NULL REFERENCES check_ins (id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users (id),
  body TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ,

  CONSTRAINT comments_body_length
  CHECK (char_length(body) BETWEEN 1 AND 500),

  -- Reject NUL byte + all C0 control chars except tab (0x09) and LF (0x0a).
  -- Same defensive shape as the venue value-constraint pattern from
  -- migration 006. The application validator (domain.CreateCommentRequest)
  -- is the primary line of defense; this is the DB-level backstop.
  CONSTRAINT comments_body_no_control
  CHECK (body !~ E'[\\x00-\\x08\\x0b\\x0c\\x0e-\\x1f]')
);

-- Most-recent-first list by (check_in, created_at, id); cursor pagination
-- pattern matches feed/profile keyset indexes from 001. Partial filter
-- keeps the index lean by skipping soft-deleted rows.
CREATE INDEX idx_comments_checkin_recent
ON comments (check_in_id, created_at DESC, id DESC)
WHERE deleted_at IS NULL;

-- Per-author audit (rare: admin queries / abuse triage). Not partial so it
-- covers soft-deleted rows too — they're the ones an admin most often wants
-- to inspect.
CREATE INDEX idx_comments_user_created
ON comments (user_id, created_at DESC);

-- Note: we intentionally do NOT add a counter-cache column on check_ins.
-- The feed-projection query in repository/feed.go uses a correlated
-- subquery to compute comment_count, mirroring the existing toasts-count
-- pattern. If the per-row subquery cost shows up in p95 dashboards
-- post-launch, the cleanup pass is a single ALTER + a trigger pair — same
-- approach as beverages.check_in_count.

COMMIT;
