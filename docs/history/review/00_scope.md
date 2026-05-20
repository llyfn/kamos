# Code Review Scope — Phase 4 (Venues + Foursquare)

Date: 2026-05-16
Stack: Go 1.26 + Flutter 3.41 + PostgreSQL 18
Scope: diff (3-commit range `be82d83..2c72f0f` on `main`)
Trigger: pre-Phase-5 cleanup pass — Phase 4 already shipped with PASS WITH MINOR per-layer QA. This review is a deeper second pass focused on the angles QA didn't drill into.

## Diff stat

51 files changed, +3,785 / −73 LOC. 3 commits:
- `be82d83 feat(backend): Phase 4 — venues + Foursquare search proxy`
- `b45fbba feat(frontend): Phase 4 — venue picker on check-in + feed card venue footer`
- `2c72f0f chore(qa): add Phase 4 per-layer + final QA reports` (QA reports — not reviewed)

## Files under review

### Backend (Go 1.26)
- `_workspace/02_backend/api/internal/foursquare/client.go` (new, 275 LOC)
- `_workspace/02_backend/api/internal/foursquare/client_test.go` (new, 197 LOC)
- `_workspace/02_backend/api/internal/handlers/venues.go` (new, 126 LOC)
- `_workspace/02_backend/api/internal/handlers/checkins.go` (venue branch, +48)
- `_workspace/02_backend/api/internal/handlers/handlers.go` (DI wiring, +47)
- `_workspace/02_backend/api/internal/repository/venues.go` (new, 89 LOC) — **upsert by `foursquare_id`, look hard at TOCTOU**
- `_workspace/02_backend/api/internal/repository/checkins.go` (venue link, +37)
- `_workspace/02_backend/api/internal/repository/feed.go` (LEFT JOIN venues, +12)
- `_workspace/02_backend/api/internal/repository/repository.go` (Venues field, +2)
- `_workspace/02_backend/api/internal/domain/types.go` (Venue/VenueRef/FoursquarePlace/FeedItem.Venue, +66)
- `_workspace/02_backend/api/internal/apierror/apierror.go` (+13)
- `_workspace/02_backend/api/internal/config/config.go` (Foursquare env, +7)
- `_workspace/02_backend/api/internal/server/router.go` (route mount, +4)
- `_workspace/02_backend/api/cmd/server/main.go` (wiring, +15)
- `_workspace/02_backend/api/migrations/005_venues.sql` (new)
- `_workspace/02_backend/db/migrations/005_venues.sql` (mirror — verify identical)
- `_workspace/02_backend/api/openapi.yaml` (+151 — Venue, VenueRef, FoursquarePlace, CheckinVenueInput, FeedItem.venue, GET /v1/venues/search)
- `_workspace/02_backend/api/tests/integration/venues_integration_test.go` (new, 216 LOC)

### Flutter
- `_workspace/03_frontend/lib/core/models/venue.dart` (new) + `venue.freezed.dart` (generated)
- `_workspace/03_frontend/lib/core/models/checkin.dart` (+9) + `checkin.freezed.dart` (regen)
- `_workspace/03_frontend/lib/features/venues/repository/venue_repository.dart` (new, 90 LOC)
- `_workspace/03_frontend/lib/features/venues/providers/venue_providers.dart` (new, 92 LOC) — **debounce + epoch cancellation**
- `_workspace/03_frontend/lib/features/venues/widgets/venue_picker_sheet.dart` (new, 237 LOC)
- `_workspace/03_frontend/lib/features/check_in/screens/check_in_screen.dart` ("Where?" row, +93)
- `_workspace/03_frontend/lib/features/check_in/repository/checkin_repository.dart` (+2)
- `_workspace/03_frontend/lib/features/check_in/providers/checkin_providers.dart` (+2)
- `_workspace/03_frontend/lib/features/feed/widgets/check_in_card.dart` (venue footer, +12)
- `_workspace/03_frontend/l10n/intl_{en,ja,ko}.arb` (9 new keys × 3 locales)
- `_workspace/03_frontend/lib/l10n/app_localizations{,_en,_ja,_ko}.dart` (generated)
- `_workspace/03_frontend/test/venue_model_test.dart` (new, 72 LOC)
- `_workspace/03_frontend/test/venue_picker_sheet_test.dart` (new, 130 LOC)
- `_workspace/03_frontend/test/venue_search_repository_test.dart` (new, 135 LOC)

### Out of scope
- `_workspace/04_qa/*` reports — already produced by qa-inspector

## Focus areas (per reviewer briefs)

1. **Foursquare client invariants** — `client.go` retry, timeout, LRU cache TTL/size, error typing, 5xx vs 4xx handling, context propagation, header injection safety.
2. **Venue upsert TOCTOU** — `repository/venues.go` UpsertByFoursquareID under concurrent inserts with the same `foursquare_id`. Race against the UNIQUE constraint, error mapping, transaction boundary.
3. **`/v1/venues/search` authz** — currently behind `requireAuth`. Is per-user rate limit applied? IDOR-shaped surface? Information leak via place names? Required role for post-Phase-5?
4. **Flutter picker memory/cancellation** — `VenueSearchNotifier`: epoch cancellation, Timer dispose, autoDispose semantics, in-flight HTTP cancellation under rapid query churn (>10 keystrokes/s).
5. **ARB locale parity** — confirm all 9 new keys (`pickVenue`, `whereWasIt`, `feedCardAtVenue`, `feedCardAtVenueNoLocality`, etc.) exist in en/ja/ko with matching placeholders.

## Severity scale

- **CRITICAL** — unsafe/broken in prod; ship blocker
- **HIGH** — must fix before next phase; correctness or material risk
- **MEDIUM** — fix this pass; quality drag
- **LOW** — defer or note in backlog

QA-already-known minors are background — escalate only if severity is actually higher than QA called.

## Outputs

- `_workspace/review/arch_findings.md`
- `_workspace/review/security_findings.md`
- `_workspace/review/perf_findings.md`
- `_workspace/review/style_findings.md`
- `_workspace/review/REVIEW_REPORT.md` (synthesized)
