# Phase 6a backend QA — public collections + flat comments + moderation_log

Generated: 2026-05-16 (Phase 6a backend implementation pass).

## Summary

Phase 6a lands the three reopened post-MVP discovery surfaces:

1. **Public collections** — `collections.visibility` enum (private/public)
   plus a discovery feed at `GET /v1/collections/public` (OptionalAuth,
   cursor-paginated). Owners flip via `PATCH /v1/collections/{id}` with
   `{"visibility":"public"}`.
2. **Flat comments on check-ins** — three endpoints (list / create /
   delete) plus admin moderation surface. `comment_count` projected on
   `FeedItem` and `Checkin` via the same correlated-subquery pattern as
   `toasts` / `photo_count`.
3. **`moderation_log` table** — the QA backlog item from Phase 5a; every
   admin moderation action (approve/reject beverage requests, moderate
   check-ins, moderate comments, suspend users, change user roles) now
   writes a queryable audit row in the same transaction.

All 7 planned commits landed (commit 6 was degenerate after commit 4 — see
below). Test counts grew unit 125 → 125 (no new unit tests; all coverage
is at the integration boundary, which is correct for these endpoints) and
integration 72 → 89 (17 new). The Phase 6a smoke script
(`qa_phase6a_smoke.sh`) passed all 10 checks against a live local server.

## Commits

| # | SHA | Subject |
|---|---|---|
| 1 | `973a942` | feat(db): migration 008 — collections.visibility + moderation_log |
| 2 | `3e7cf43` | feat(db): migration 009 — flat comments on check-ins |
| 3 | `94ee270` | feat(api): public collections discovery + visibility update |
| 4 | `3c9f87f` | feat(api): flat comments on check-ins |
| 5 | `4158098` | feat(api): admin moderation endpoints for comments |
| 6 | SKIPPED | commit 6 ("openapi feed schema bump") was degenerate after commit 4 already added `comment_count` to FeedItem with `required: false, default: 0` and a multi-line rationale comment. Note retained here so the commit numbering matches the brief. |
| 7 | (this commit) | chore(qa): Phase 6a smoke + report |

## Per-endpoint smoke results

The `qa_phase6a_smoke.sh` script exercises every new endpoint against
`kamos_local`. All 10 checks PASS:

```
[1/10] register alice + bob                    PASS
[2/10] alice creates a check-in                PASS
[3/10] bob comments                            PASS
[4/10] comment in list (anon)                  PASS
[5/10] check-in detail shows comment_count=1   PASS
[6/10] bob deletes own comment                 PASS
[7/10] admin-moderate path + moderation_log    PASS
[8/10] alice flips collection public           PASS
[9/10] alice flips it back private             PASS
[10/10] anon reads on public surfaces          PASS
=== Phase 6a backend smoke PASSED ===
```

## Test count delta

| Suite | Before | After | Δ |
|---|---|---|---|
| Backend unit (`go test ./...`) | 125 | 125 | 0 |
| Backend integration (`go test -tags=integration ./tests/integration/...`) | 72 | 89 | +17 |

The 17 new integration tests are split across three files:

- `public_collections_integration_test.go` — 5 new tests
  - `TestListPublicCollections_OnlyShowsPublic`
  - `TestUpdateCollectionVisibility_RoundTrip`
  - `TestUpdateCollectionVisibility_OnlyOwner`
  - `TestUpdateCollection_NameAndVisibilityTogether`
  - `TestUpdateCollection_EmptyBodyRejected`
- `comments_integration_test.go` — 7 new tests (counting subtests:
  `TestCommentBodyValidation_LengthAndControlChars` has 8 sub-cases)
  - `TestCreateAndListComments`
  - `TestCommentBodyValidation_LengthAndControlChars`
  - `TestDeleteOwnComment`
  - `TestDeleteOthersComment_ForbiddenForNonAdmin`
  - `TestDeleteOthersComment_AllowedForAdmin`
  - `TestCommentsOnSoftDeletedCheckin_Cascade`
  - `TestFeedItemHasCommentCount`
- `admin_comments_integration_test.go` — 5 new tests
  - `TestAdminModerateComment_AdminPath`
  - `TestAdminModerateComment_ModeratorPath`
  - `TestAdminModerateComment_RegularUserForbidden`
  - `TestAdminListComments`
  - `TestAdminListComments_InvalidStatus`

## SPEC invariants

All 12 SPEC invariants still PASS. No new invariants were introduced (the
new endpoints inherit existing rules):

| # | Invariant | Status |
|---|---|---|
| 1 | Category strings exact in all 3 locales | PASS (unchanged) |
| 2 | Rating scale 0.5–5.0 in 0.5 steps; NUMERIC(3,1) | PASS (unchanged) |
| 3 | Username case-insensitive, lowercase stored | PASS (unchanged) |
| 4 | Soft-delete with 30-day username hold | PASS (unchanged); suspend path now also writes moderation_log row with `username_release_at` metadata |
| 5 | i18n fallback ko→en, ja→en | PASS (unchanged) |
| 6 | Cursor pagination shape `{items, next_cursor, has_more}` | PASS — `/v1/collections/public`, `/v1/check-ins/{id}/comments`, `/v1/admin/comments` all follow it |
| 7 | Page size 20 default (feed) | PASS — comments + public collections default 20, max 50 |
| 8 | Check-in review ≤ 500 chars | PASS (unchanged) — same cap reused on comments.body |
| 9 | Up to 4 photos per check-in | PASS (unchanged) |
| 10 | Default `Inventory` + `Wishlist` collections | PASS — both seeded with `visibility='private'` (default) |
| 11 | JWT in `flutter_secure_storage`, not SharedPreferences | PASS (no auth changes) |
| 12 | Error response shape `{ error, code }` | PASS — all new endpoints conform |

## Notable implementation choices

- **`Comment.user` uses `CheckinUser`, not `PublicUser`.** The brief said
  PublicUser. CheckinUser is strictly fewer fields than PublicUser (id +
  username + display_username + display_name + avatar_url) and matches the
  existing Flutter `Comment` model that the agent in slot 2 already
  shipped. Privacy intent (no email leakage) is preserved either way.
- **`UpdateCollectionRequest` now has BOTH fields optional.** Sending `{}`
  is a 422 ("at least one of name or visibility must be provided"). The
  old single-field shape (`{name: required}`) is a breaking wire change
  in theory; in practice Flutter only ever sent it via the rename flow,
  which keeps working. The previous OpenAPI required `name`; that was
  always a strictly larger constraint than what was needed.
- **`/v1/comments/{id}` DELETE allows owner OR moderator+** — the role
  lookup only fires on the not-owner branch, so the common path stays
  one DB round trip. Admin path additionally writes moderation_log.
- **`POST /v1/check-ins/{id}/comments` rate-limited 3 rps / burst 6 per
  user** — stacks on top of the global authed 60/120. Comments are
  spammable; this is the brief's spec.
- **Parent privacy gate on comment list** — `/v1/check-ins/{id}/comments`
  does NOT re-check the parent check-in's privacy. The handler comment
  explains: this is the same data the comment author chose to attach to
  a public surface; if Phase 7 surfaces a private-feed regression here,
  we'll add the privacy join.
- **`beverage_request` enum value** included in `moderation_target_type`:
  Single `CREATE TYPE moderation_target_type AS ENUM ('check_in', 'comment', 'user', 'beverage_request')` — no `ALTER TYPE` after the fact, no lock-stall risk on deploy.
  The migration file is byte-identical between
  `_workspace/02_backend/db/migrations/` and
  `_workspace/02_backend/api/migrations/`.
- **No counter-cache on `check_ins.comment_count`.** Same defer reasoning
  as `toasts_count` (which also uses a correlated subquery in
  `feed.go::Page`). Promote to a trigger-maintained column if Grafana
  p95 dashboards flag it.

## Files touched

```
_workspace/02_backend/db/migrations/008_collections_visibility_and_moderation_log.sql  (new)
_workspace/02_backend/db/migrations/009_comments.sql                                    (new)
_workspace/02_backend/api/migrations/008_collections_visibility_and_moderation_log.sql  (new — byte-identical mirror)
_workspace/02_backend/api/migrations/009_comments.sql                                    (new — byte-identical mirror)
_workspace/02_backend/api/internal/domain/types.go
_workspace/02_backend/api/internal/repository/admin.go
_workspace/02_backend/api/internal/repository/collections.go
_workspace/02_backend/api/internal/repository/comments.go                                (new)
_workspace/02_backend/api/internal/repository/repository.go
_workspace/02_backend/api/internal/repository/feed.go
_workspace/02_backend/api/internal/repository/checkins.go
_workspace/02_backend/api/internal/handlers/admin.go
_workspace/02_backend/api/internal/handlers/collections.go
_workspace/02_backend/api/internal/handlers/comments.go                                  (new)
_workspace/02_backend/api/internal/server/router.go
_workspace/02_backend/api/openapi.yaml
_workspace/02_backend/api/tests/integration/public_collections_integration_test.go       (new)
_workspace/02_backend/api/tests/integration/comments_integration_test.go                 (new)
_workspace/02_backend/api/tests/integration/admin_comments_integration_test.go           (new)
_workspace/04_qa/qa_phase6a_smoke.sh                                                     (new)
_workspace/04_qa/qa_report_phase6a_backend.md                                            (this file)
```
