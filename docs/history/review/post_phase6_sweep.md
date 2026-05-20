# Post-Phase-6 Cumulative MINOR Sweep

Date: 2026-05-17
Pattern: `~/.claude/projects/-Users-eomtii-Desktop-kamos/memory/feedback_post_phase_minor_sweep.md`

## Commits applied (3 in this sweep)

| # | Commit | Layer | Closes |
|---|---|---|---|
| 1 | `ed4d9e7` | backend | MINOR-3 (correct smoke report `ALTER TYPE` claim — no post-deploy lock-stall risk; single `CREATE TYPE` includes all 4 enum values) |
| 2 | `37b675c` | flutter | MINOR #1 (`CollectionOwner.displayName` field added to Dart model, matches OpenAPI required-string), MINOR #5 (tighten `comment_providers.dart` doc-comment — describes pessimistic-then-prepend, not "optimistic") |
| 3 | `f69a728` | flutter | MINOR #4 (`commentsInvalidBody` — client-side control-char filter on comment body before submission), MINOR #7 (`commentsRateLimited` — typed 429 exception + dedicated localized toast) |

## Commits skipped (premise stale — agents correctly refused to invent work)

| Item | Why skipped |
|---|---|
| Backend MINOR-4 — delete `commentsViewerID` dead helper | The helper became live during the BLOCKER fix (`28f6403` — parent-privacy gate landed). Calling it now would break the privacy join. |

## Test counts

| Suite | Before sweep | After sweep | Δ |
|---|---|---|---|
| Backend unit | 125 | **125** | 0 (no Go source touched) |
| Backend integration | 96 | **96** | 0 |
| Flutter | 93 | **99** | +6 (model fixture + composer control-char + repo 429 branch + toast translation × 3) |
| Admin client (Vitest) | 11 | **11** | 0 |
| **Total** | 325 | **331** | **+6** |

All green: `go build ./...`, `flutter analyze`, `flutter test`, `tsc --noEmit`, `vite build`.

ARB parity: **206/206/206** after Phase 6 + sweep (the Phase 6 Flutter QA report inflated the baseline; agent verified the actual count was 204 pre-sweep + 2 new keys = 206).

## Items DEFERRED explicitly (judgment calls)

| Phase | Item | Reason |
|---|---|---|
| 6 backend MINOR-2 | Hard-delete sweep job doesn't handle comments on user purge | The 30-day soft-delete hold completion sweep is a Phase 7+ concern; FK on `comments.user_id` has no cascade so the hold completion would error today. Defer until the username_hold_cleanup job grows comment-cleanup logic. |
| 6 backend MINOR-6 | `idx_comments_user_created` is non-partial; lists soft-deleted rows | Write cost is small at MVP scale; revisit if profiling shows index bloat. |
| 6 flutter MINOR #6 | `commentMaxChars = 500` duplicated in composer + repo | Different cohesion concerns (widget vs data); cross-layer constant only adds an import for one number. Accept. |
| 6 flutter MINOR #2 | Pessimistic-not-optimistic post — implementation could be made truly optimistic | Bigger change; current pessimistic-then-prepend matches the doc-comment after this sweep. Defer. |

## SPEC invariants — still 12/12 PASS

No invariant touched.

## Cumulative state after sweep

Total Phase 6 commit chain: 18 commits (4 Flutter Phase 6 + 6 backend Phase 6a + 2 Flutter MAJOR fix + 3 backend BLOCKER+MAJOR fix + 1 Flutter follow-up + 2 admin client + 3 sweep + QA-report-commit). 12/12 SPEC invariants. 331 tests.

## What's next

**Phase 7 — Caching.** M (~1 week). Driven by Phase 1 Grafana p95 latency metrics. Likely targets: `/v1/categories`, `/v1/beverages/{id}`, `/v1/breweries/{id}`, `/v1/users/{username}`. HTTP `Cache-Control` + `ETag` + in-process LRU. No new vendor required.
