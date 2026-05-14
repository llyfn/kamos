# QA Report — Phase 4 Final Cross-Layer

Date: 2026-05-14
Scope: Phase 4 (Venue / Foursquare) end-to-end.
Verdict: **PASS WITH MINOR**

This report consolidates the per-layer reports and the live cross-layer smoke. Per-layer QA fired in parallel with the still-running layer per the new orchestrator pattern (memory: `feedback_per_layer_qa_in_parallel.md`).

## Per-layer verdicts

| Layer | Report | Verdict | BLOCKER / MAJOR / MINOR |
|---|---|---|---|
| Backend | `qa_report_phase4_backend.md` | PASS WITH MINOR | 0 / 1 / 6 |
| Flutter | `qa_report_phase4_flutter.md` | PASS WITH MINOR | 0 / 0 / 5 |

The 1 backend MAJOR (`FeedItem.venue` doc/code drift) was fixed inline by the orchestrator:
- `domain.FeedItem.Venue *VenueRef` added
- `repository/feed.go` LEFT JOIN venues + project `id, name, locality, country`
- `openapi.yaml` `FeedItem` schema gained `venue` property
- Build + 53 integration tests re-verified after fix

The Flutter `FeedItem.venue` defensive decoder was already in place — once the backend fix landed, the contract reconciles with no further Flutter changes needed.

## Live cross-layer smoke (this run, against local Postgres 18)

```
$ GET /v1/venues/search?q=Daikoku   (FOURSQUARE_API_KEY unset)
  → 503  {"code":"VENUE_SEARCH_DISABLED","error":"venue search not configured..."}
  ✓ Feature flag gating works.

$ register venue_smoke, venue_friend
$ venue_smoke follows venue_friend
$ venue_friend POST /v1/check-ins
    body: { beverage_id, rating, review, venue: {
              foursquare_id: "fsq_xyz_001",
              name: "Daikoku Bar Tokyo",
              address, lat, lng, country: "JP",
              prefecture: "Tokyo", locality: "Ginza" } }
  → 201; venue row upserted with foursquare_id; check_in linked.
  ✓ Upsert-by-fsq-id path works WITHOUT Foursquare credentials
    (the upsert is a pure DB operation; only the search endpoint is gated).

$ venue_smoke GET /v1/feed
  → 200; feed item carries venue:
      { id: <uuid>, name: "Daikoku Bar Tokyo", locality: "Ginza", country: "JP" }
  ✓ M1 fix verified end-to-end: VenueRef projects to FeedItem.

$ SELECT * FROM venues
  → 1 row: (id, fsq_xyz_001, "Daikoku Bar Tokyo", Ginza, JP)
  ✓ DB state matches wire.
```

## SPEC invariants — still 12/12 PASS

Phase 4 added a `venues` table and a nullable `check_ins.venue_id` FK. No change to category strings, rating semantics, photo cap, cursor pagination, soft-delete filtering, or JWT-in-secure-storage.

## Test counts after Phase 4

| Suite | Phase 3 → Phase 4 | Notes |
|---|---|---|
| Backend unit | 102 → **109** | +7 in `internal/foursquare/` |
| Backend integration | 49 → **53** | +4 in `tests/integration/venues_integration_test.go` |
| Flutter | 27 → **35** | +8 across `venue_model_test`, `venue_search_repository_test`, `venue_picker_sheet_test` |

## Outstanding minors (none blocking)

Backend (6):
1. `resolveLocale` silently maps invalid → en (friendly to clients but hides typos). Defer.
2. `client.go:209` auth failure: `fmt.Errorf` string vs typed sentinel. Defer.
3. No test for the `lat-without-lng` 422 branch. Add when convenient.
4. `client_test.go:182` cosmetic pointer dance. Cosmetic.
5. `cacheSize = 1000` per-pod. Document when multi-pod becomes a concern.
6. `apierror.WriteFrom` venue branch is dead safety net. Harmless.

Flutter (5):
1. `_maxResultsOnScreen = 30` no WHY comment.
2. Widget imports repository for typed exceptions (architecturally borderline; functionally fine).
3. `feed/widgets/check_in_card.dart` venue footer ignores `country`. Product call.
4. `venue_model_test.dart` only exercises the absent case; add positive-decode test now that backend ships venue.
5. `_FakeRepo` doesn't exercise the venue path.

Backlog (carry-over from prior phases, still open): Sentry BeforeSend body scrubber (Phase 2); `authContinueGoogle` ARB orphan (Phase 2); R2 HEAD-verify (Phase 3); `password_reset` + `email_change` templates (Phase 3).

## What's still owed from the user

- **Foursquare developer.foursquare.com signup + API key** (cookbook §C5)
- Once `FOURSQUARE_API_KEY` is in `local.env`, `GET /v1/venues/search` flips on with no code changes.

The check-in venue upsert path works **today** without that signup.
