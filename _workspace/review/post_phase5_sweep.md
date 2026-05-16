# Post-Phase-5 Cumulative MINOR Sweep

Date: 2026-05-16
Trigger: user instruction "Review all the QA reports from the previous phases, apply all the reasonable fixes, and remember to do this after every phase from now."
Pattern captured at: `~/.claude/projects/-Users-eomtii-Desktop-kamos/memory/feedback_post_phase_minor_sweep.md`

This is the first sweep. Future sweeps fire after each phase's final cross-layer QA returns PASS.

## Commits applied (7 in this sweep)

| # | Commit | Layer | Closes |
|---|---|---|---|
| 1 | `a5e6eac` | backend | Phase 0 carry-forward — dead `_ = strings.Contains` / `_ = errors.Is` sentinel-import guards in `repository/beverages.go` |
| 2 | `143db79` | backend | Phase 2 backlog — Sentry `BeforeSend` body scrubber for `/v1/auth/{login,register,refresh,logout}`; Authorization + Cookie headers always scrubbed; 4 new unit tests in `internal/observability/sentry_test.go` |
| 3 | `bd2acc1` | backend | Phase 4 STYLE-011 — `TestCreateCheckinSilentDropVenueBranches` covers 3 silent-drop venue shapes (foursquare_id-only, name-only, empty-string id); cross-case DB assertion that no orphan venue rows leak |
| 4 | `98101de` | flutter | Phase 2 carry-over (`authContinueGoogle` ARB key dead) + Phase 5 MINOR #1 (`SubmitBeverageRequestNotifier.reset()` dead) |
| 5 | `8fe14bc` | flutter | Phase 4 STYLE-008 (`venue_repository.dart:62` Sentry hook on malformed 200) + Phase 4 STYLE-006 (`@feedCardAtVenue.description` metadata in all 3 ARBs) |
| 6 | `795ece4` | flutter | Phase 5 MINOR #2 (dedicated `settingsSuggestBeverage` ARB key) + Phase 5 MINOR #3 (search empty-state CTA gating) + Phase 4 STYLE-003 (`_FakeRepo` venue-path test coverage) |
| 7 | `db37cce` | admin | Phase 5 MINOR #4 (wire `RoleGuard` per-route on `/queue`, `/users`, `/checkins`; renders friendly "Insufficient privileges" panel on role mismatch) |

## Commits skipped (stale premise — agents correctly refused to invent work)

| Phase / item | Why skipped |
|---|---|
| Phase 3 wire-shape #2 (Sentry-go SDK header-shape check) | Already `map[string]string` — fix is "do nothing" |
| Phase 3 wire-shape #3 (Flutter `PhotoRef.id` required) | Backend `domain.PhotoRef` is `{URL, SortOrder}` — `id` is NOT in the contract per OpenAPI. Tightening the Flutter model would break every attach/feed photo decode. Documented carry-over is stale. |

## Test counts (cumulative after sweep)

| Suite | Before sweep | After sweep | Δ |
|---|---|---|---|
| Backend unit | 121 | **125** | +4 (sentry scrubber tests) |
| Backend integration | 71 | **72** | +1 (silent-drop branches) |
| Flutter | 45 | **46** | +1 (venue-path repo capture) |
| Admin client (Vitest) | 5 | **8** | +3 (RoleGuard match/mismatch/loading) |
| **Total** | 242 | **251** | **+9** |

All green: `go build ./...`, `go test ./...`, `flutter analyze`, `flutter test`, `tsc --noEmit`, `vite build`.

ARB parity intact at 184/184/184 (net zero — pruned `authContinueGoogle`, added `settingsSuggestBeverage`).

## Items DEFERRED explicitly (judgment calls — not invented work)

These were considered and consciously left for a future product/architecture decision, not silently dropped:

| Phase | Item | Reason |
|---|---|---|
| 2 | Logout partial-failure ordering | Race window (briefly two valid tokens during rotation) is documented in the handler comment and acceptable per SPEC. |
| 3 | R2 HEAD-verify before promoting `pending → attached` | Real work; production-hardening item, not a one-line fix. Defer until R2 credentials land + a real production volume justifies the tighter loop. |
| 3 | `password_reset.*` + `email_change.*` email templates | Phase 5+ — user-facing reset/change screens don't exist yet. Templates without callers would rot. |
| 4 | STYLE-001 (`Place` vs `FoursquarePlace` naming) | Local Go package-qualified idiom (`foursquare.Place`) is correct convention; only the wire schema name carries the vendor prefix. |
| 4 | STYLE-010 (two test-fake conventions) | Needs a codebase-wide test convention decision (`extends` vs `implements`). Not a one-line fix. |
| 4 | `feedCardAtVenue` ignores `country` | Product call — display fidelity decision. |
| 4 | `resolveLocale` invalid → en | Defensive default; intentional friendly behavior. |
| 4 | `cacheSize = 1000` per-pod | Operational decision (Redis vs in-process); needs scale data, not a fix. |
| 4 | `VenueSearchQuery` hand-coded `==`/`hashCode` | Cosmetic; only one provider input today. |
| 4 | `DraggableScrollableSheet` 0.7/0.5/0.95 inline magic numbers | Standard Flutter idiom — sizing values are not named constants in the Flutter SDK. |
| 4 | `client_test.go:182` pointer-dance cosmetic | Pure cosmetic; the existing code works. |
| 5 | `/v1/users/me` returns `role` for soft-deleted users in race window | Documented in OpenAPI description; SoftDeleteCache closes the window within 60s. |
| 5 | Approve vs Reject response shape inconsistency (`{request_id, beverage_id}` vs `{request_id, status, notes}`) | Cosmetic shape difference; admin client already handles both. Defer until v2 of admin API. |
| 5 | `include_deleted` enum strings `"0"/"1"` | Cosmetic; matches existing pattern across the API for boolean-shaped query params. |

If any of these are re-flagged in a future phase's QA, they escalate to a real fix per the sweep-rule memory.

## SPEC invariants — still 12/12 PASS

Sweep was deliberately surgical (per the orchestrator's "no surprise refactors" rule); no invariant touched.

## What's next

Pattern is now standing: after every phase's final cross-layer QA returns PASS, run this same sweep before declaring the phase fully done.

Next: Phase 6 — Public collections + flat comments on check-ins.
