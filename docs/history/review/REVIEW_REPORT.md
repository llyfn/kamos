# Code Review Report — Phase 4 (Venues + Foursquare)

Date: 2026-05-16
Scope: commits `be82d83..2c72f0f` on `main` (51 files, +3,785 / −73 LOC)
Reviewers: arch · security · perf · style — all 4 completed
Pre-existing QA artefacts: `qa_report_phase4_{backend,flutter,final}.md` (PASS WITH MINOR)

## Executive Summary

| Domain | CRITICAL | HIGH | MEDIUM | LOW | INFO |
|---|---|---|---|---|---|
| Architecture | 0 | 0 | 2 | 5 | — |
| Security | 0 | 3 | 2 | 4 | 3 |
| Performance | — | 0 | 6 | 13 | — |
| Style | — | — | 0 | 11 | — |
| **Total** | **0** | **3** | **10** | **33** | **3** |

**Verdict:** 0 ship blockers. **3 HIGH security findings** must be addressed before Phase 5 begins meaningful new schema work, because Phase 5 RBAC will inherit the same user-input → DB persistence paths.

**Must-fix before Phase 5:** SEC-001, SEC-002, SEC-004.
**Strong-recommend bundle with above:** PERF-001, PERF-003, PERF-019 (Foursquare client polish, very cheap), ARCH-003 / STYLE-009 (Flutter exceptions extract, 1-file refactor), PERF-014 (sheet rebuild scope).
**Defer to Phase 5:** SEC-006 (soft-deleted JWT validity — pre-existing global concern, properly belongs with admin/RBAC work where soft-delete tooling is consolidated).

---

## Critical & High Priority

### SEC-001 — Unbounded venue name + address persistence enables stored-XSS sink + DB bloat [HIGH]
**Files:** `internal/handlers/checkins.go:299-329`, `internal/repository/venues.go:38-67`, `migrations/005_venues.sql:9-25`
Client-supplied venue strings persist into shared rows with no length cap, no charset filter, no control-char rejection. Strings surface via `FeedItem.venue.name` and `Checkin.venue.name`. Mobile renders safely today; the Phase 5 admin web client will not.

**Fix bundle:**
1. Add `(*domain.CheckinVenue).Validate()` — bounded runes per field, reject `<0x20` except space, reject NUL.
2. New migration `006_venue_value_constraints.sql` with `CHECK (char_length(name) <= 200)` etc. as DB backstop.
3. Call validator from `resolveCheckinVenue` → 422 VALIDATION on fail.

### SEC-002 — Venue upsert lets ANY authed user overwrite shared venue's mutable columns (last-writer-wins) [HIGH]
**File:** `internal/repository/venues.go:38-67` — `ON CONFLICT … DO UPDATE SET name = EXCLUDED.name, address = …, lat = …, lng = …`
Once a `foursquare_id` row exists, the next check-in with the same id silently overwrites every column with whatever the client claims. Last writer wins; a single client poisons the canonical row until another legitimate user picks the same venue. **Cross-domain:** ARCH-001 (vendor type as wire DTO) flagged at MEDIUM by arch-reviewer reinforces this — the bypass exists because the upsert path doesn't share the Foursquare-truth boundary the search proxy establishes.

**Fix:** Change to first-writer-wins. `ON CONFLICT (foursquare_id) DO UPDATE SET updated_at = now() RETURNING id`. Stale Foursquare data becomes a separate refresh problem (post-MVP); no single user can rewrite a shared row.

### SEC-004 — `/v1/venues/search` shares the generic 60 rps/burst-120 per-user limit + `RATE_LIMIT_DISABLED=1` foot-gun [HIGH]
**Files:** `internal/server/router.go:101-127`, `internal/config/config.go:85,127`
A single user can hit Foursquare 120× per second with a varying `q` (cache-miss every time), exhausting the paid upstream budget. Worse: `RATE_LIMIT_DISABLED=1` silently kills the brute-force backstop on `/v1/auth/login` if leaked into production.

**Fix bundle:**
1. Dedicated `RateLimitByUser(log, 5, 10)` on JUST `/v1/venues/search` (stacked under the global authed limiter).
2. `config.Load` refuses to boot when `APP_ENV=production && RATE_LIMIT_DISABLED=1`.
3. (Bonus) cap `?limit=` on venue search to 20 (was 50).

---

## Medium Priority

### Architecture (2)
- **ARCH-001** — `venueSearchResponse.Items []foursquare.Place` makes the vendor package own the wire shape. Introduce `handlers.venueSearchItem` (or `domain.VenueSearchResult`) and map at the handler boundary.
- **ARCH-003** — Widget→repository import in `venue_picker_sheet.dart:17` for typed exceptions crosses the documented layer boundary. Extract `lib/features/venues/exceptions.dart`. (Cross-domain with STYLE-009.)

### Security (2)
- **SEC-003** — `TrimSpace` Foursquare API key on construction; doc as secret-never-logged.
- **SEC-007 (escalated alongside SEC-004)** — Cap `q` query param to 100 runes — otherwise LRU cache memory explodes and Foursquare quota burns on long unique queries.

### Performance (6, all wrapped into one foursquare-client polish pass)
- **PERF-001** — Default `http.Transport` gives only 2 idle conns/host → custom Transport with `MaxIdleConnsPerHost: 32`, `MaxConnsPerHost: 64`, `IdleConnTimeout: 90s`, `ForceAttemptHTTP2: true`.
- **PERF-003** — No singleflight around the cache miss → thundering herd. Wrap in `golang.org/x/sync/singleflight`.
- **PERF-010** — Venue upsert outside the check-in tx (2 RTTs + orphan risk). Defer; orphan cost acknowledged in migration comment.
- **PERF-012** — `idx_venues_name_tsv` (GIN) has no current reader → measurable write cost. Drop in migration 006 alongside the value-constraint backstop.
- **PERF-014** — Picker sheet `build()` rebuilds TextField on every notifier transition. Move `ref.watch(venueSearchProvider)` into the `_Results` subtree via `Consumer`.
- **PERF-019** — Fixed 200 ms retry, no jitter → aligned retry storms during Foursquare outages. Add uniform jitter `[backoff, 2*backoff]`.

---

## Low Priority & Suggestions

(Selectively rolled into the cleanup pass where bundled cost is near zero.)

- **SEC-012** — Add `TestVenueSearchRequiresAuth` (one-liner regression guard).
- **PERF-013** — `setQuery` no-op guard (`if (q == _query) return;`).
- **PERF-017** — `omitempty` on `FeedItem.venue` — confirm tag set.
- **PERF-018** — `VenueRepo.Exists(ctx, id)` instead of `GetByID` in `resolveCheckinVenue` (saves wasted hydrate).
- **STYLE-002** — Promote auth failure to `ErrAuth` sentinel.
- **STYLE-005** — Comment for `_maxResultsOnScreen = 30`.
- **STYLE-007** — Delete the two dead `apierror.WriteFrom` venue branches.
- **STYLE-008** — Sentry breadcrumb on malformed venue search response (or throw).

(All remaining LOW items deferred to backlog: ARCH-002/004/005/006/007, PERF-002/004/005/006/007/008/009/011/015/016, SEC-005/008, STYLE-001/003/004/006/010/011.)

---

## Cross-Domain Findings

| File:line | Cited by | Joint angle |
|---|---|---|
| `internal/repository/venues.go::UpsertByFoursquareID` | SEC-002 (HIGH), ARCH-001 (MEDIUM), PERF-010 (MEDIUM) | The same bypass produces a data-poisoning risk, a vendor-truth-boundary violation, and a non-transactional 2-RTT hot path. Fix-bundle target. |
| `venue_picker_sheet.dart:17` | ARCH-003 (MEDIUM), STYLE-009 (LOW) | Widget→repository import for typed exceptions; recurring pattern across feature packages — set the convention now via `lib/features/venues/exceptions.dart`. |
| `client.go` (whole) | PERF-001 + PERF-003 + PERF-019 + SEC-003 | One client-polish pass: custom Transport, singleflight, jitter, TrimSpace key. |

---

## Recommended Fix Order

1. **SEC-001 + SEC-002 + new migration 006** — single commit. Adds `Validate()`, switches upsert to first-writer-wins, CHECK constraints + drops `idx_venues_name_tsv` (PERF-012). Server-side input contract hardened.
2. **SEC-004 + SEC-007** — dedicated `/v1/venues/search` limiter, prod-safety guard in `config.Load`, q-length cap. Single commit.
3. **Foursquare client polish** — PERF-001 (Transport) + PERF-003 (singleflight) + PERF-019 (jitter) + SEC-003 (TrimSpace) + STYLE-002 (`ErrAuth`). Single commit.
4. **Flutter polish** — ARCH-003/STYLE-009 (extract `exceptions.dart`) + PERF-014 (sheet rebuild scope) + PERF-013 (setQuery no-op guard) + STYLE-005 (`_maxResultsOnScreen` comment). Single commit.
5. **Tests** — SEC-012 (auth-required regression), STYLE-004 (handler-level 422 unit test), STYLE-011 (silent-drop table-driven test). Single commit.
6. **Defer to Phase 5**: SEC-006 (soft-deleted JWT validity — belongs with admin/RBAC tooling). Note in plan.

---

## Full Findings

- Architecture: `_workspace/review/arch_findings.md`
- Security: `_workspace/review/security_findings.md`
- Performance: `_workspace/review/perf_findings.md`
- Style: `_workspace/review/style_findings.md`
