# Phase 4 Review — Applied / Deferred

Working note, not committed. See `REVIEW_REPORT.md` for the source findings.

## Applied

| Finding | Severity | Commit |
|---|---|---|
| ARCH-003 / STYLE-009 (extract `lib/features/venues/exceptions.dart`) | MEDIUM/LOW | `70d7d7c` |
| PERF-014 (move `ref.watch` into `_Results` Consumer) | MEDIUM | `70d7d7c` |
| PERF-013 (no-op guard in `setQuery`) | LOW | `70d7d7c` |
| STYLE-005 (`_maxResultsOnScreen` WHY comment) | LOW | `70d7d7c` |
| SEC-001 (venue field validation) | HIGH | `65f37ee` |
| SEC-002 (first-writer-wins upsert) | HIGH | `65f37ee` |
| PERF-012 (drop unused `idx_venues_name_tsv`) | MEDIUM | `65f37ee` |
| SEC-004 (dedicated venue-search rate limit + production guard) | HIGH | `d5141ad` |
| SEC-007 (q max-length + venueSearchLimit lowered to 20) | MEDIUM | `d5141ad` |
| SEC-012 (auth-required regression test) | LOW | `d5141ad` |
| PERF-001 (pooled `*http.Transport`) | MEDIUM | `20a8fb7` |
| PERF-003 (singleflight around cache miss) | MEDIUM | `20a8fb7` |
| PERF-019 (jittered retry backoff) | MEDIUM | `20a8fb7` |
| SEC-003 (TrimSpace API key on construction) | MEDIUM | `20a8fb7` |
| STYLE-002 (typed `ErrAuth` sentinel) | LOW | `20a8fb7` |
| STYLE-007 (delete dead apierror venue branches) | LOW | `20a8fb7` |

Migration 006 (`006_venue_value_constraints.sql`) applied to `kamos_local` and `kamos_test` as part of `65f37ee`.

## Deferred

| Finding | Severity | Reason |
|---|---|---|
| SEC-006 (soft-deleted-user JWT validity) | HIGH | Phase 5 admin/RBAC owns soft-delete tooling consolidation — fixing it inside Phase 4's scope without the RBAC primitives risks duplicating the eventual revocation surface. |
| ARCH-001 (vendor `foursquare.Place` as wire DTO) | MEDIUM | Out of fix-bundle scope; needs a `handlers.venueSearchItem` mapping pass at the handler boundary. Tracked for the next backend cleanup pass. |
| PERF-010 (venue upsert outside the check-in tx) | MEDIUM | Orphan cost is acknowledged in migration commentary; not a blocker. |
| PERF-017 / PERF-018 / STYLE-005 / STYLE-008 | LOW | Backlog — low-cost, low-yield individually. |
| ARCH-002/004/005/006/007 | LOW | Explicitly deferred by task constraints. |

## Test counts

| Suite | Before | After | Delta |
|---|---|---|---|
| Backend unit (`go test ./...`) | 109 | 116 | +7 |
| Backend integration (`-tags=integration`) | 53 | 57 | +4 |
| Flutter (`flutter test`) | 35 | 35 | unchanged (refactor only) |

New tests:

Unit (handlers + config + foursquare):
- `handlers_test::TestVenueSearch_EmptyQuery`
- `handlers_test::TestVenueSearch_QueryTooLong`
- `handlers_test::TestVenueSearch_LatWithoutLng`
- `config::TestLoadRejectsRateLimitDisabledInProduction`
- `config::TestLoadAllowsRateLimitDisabledOutsideProduction`
- `foursquare::TestNewTrimsAPIKey`
- `foursquare::TestNewWhitespaceKeyIsDisabled`

Integration (venues):
- `TestVenueSearchRequiresAuth` (SEC-012)
- `TestCheckinVenueValidation_RejectsOversizedName` (SEC-001)
- `TestCheckinVenueValidation_RejectsControlChars` (SEC-001)
- `TestVenueUpsertIsFirstWriterWins` (SEC-002)
