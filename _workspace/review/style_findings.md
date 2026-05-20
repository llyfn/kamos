# Style Findings — Phase 4 (Venues + Foursquare)

Reviewer: style-review (Opus 4.7)
Date: 2026-05-16
Scope: commits `be82d83..2c72f0f`
Severity policy: style reviewer issues MEDIUM / LOW / SUGGESTION only; HIGH/CRITICAL belong to arch/security/perf.

QA-flagged minors already at-or-below the severity I would assign are listed as **BACKGROUND** without a STYLE-NNN number. New findings or escalations get a STYLE-NNN entry.

Prioritization: walked the Foursquare client + the check-in handler venue branch first (most-touched), then the picker / providers, then OpenAPI + ARB.

---

### STYLE-001 — `Place` vs `FoursquarePlace` vs `Venue` vs `VenueRef`: Go side drops the `Foursquare` prefix that every other layer carries [LOW]
**File:** `_workspace/02_backend/api/internal/foursquare/client.go:77`
**Issue:** The Go package exports `foursquare.Place` while OpenAPI exports `FoursquarePlace`, the Dart model is `FoursquarePlace`, and `domain.CheckinVenue.FoursquareID` plus the `venue.foursquare_id` JSON tag. The Go-side single-word `Place` is locally idiomatic ("the package name carries the qualifier") but every other layer in the repo uses the fully-qualified noun. A grep for `Place` in Go now collides with the unexported `Place` struct inside `repository/places.go`-style files going forward; that's not a problem today but it cuts against the otherwise-consistent naming.
The handler also defines a separate envelope `venueSearchResponse{Items []foursquare.Place}` at `handlers/venues.go:22` — the only place the bare type `Place` leaks outside the package. The wire shape names it `FoursquarePlace`; the JSON shape is fine because tags handle it, but a future reader will wonder why the Go field is `[]foursquare.Place` and the OpenAPI schema is `FoursquarePlace`.
**Recommendation:** Keep `foursquare.Place` (it IS idiomatic Go), but add a one-line WHY comment at `client.go:77` noting "Wire name is `FoursquarePlace`; bare `Place` is the package-qualified Go form." Cheap, prevents future renames.

### STYLE-002 — `client.go:209` auth-failure error format is testable only by `strings.Contains` [LOW]
**File:** `_workspace/02_backend/api/internal/foursquare/client.go:209`
**Issue:** `return nil, fmt.Errorf("fetchOnce: auth failed (%d)", resp.StatusCode)` — string-only, no sentinel. `client_test.go:100` matches it via `strings.Contains(err.Error(), "auth failed")`. The pattern works but is fragile (any rephrasing breaks the test), and it diverges from `ErrDisabled` / `ErrRateLimited` / `*upstreamServerError` in the same file, which are all typed. The backend QA report already flagged this as MINOR/defer. I agree with the severity; flagging here because the test file is the only consumer that distinguishes auth from "unexpected status", so the typed-sentinel upgrade is essentially zero-risk and would let the test use `errors.Is`.
**Recommendation:** Add `var ErrAuth = errors.New("foursquare auth failed")`; return `fmt.Errorf("fetchOnce: auth failed (%d): %w", status, ErrAuth)`; have the test use `errors.Is(err, ErrAuth)`. Two-line change. Not blocking.

### STYLE-003 — `_FakeRepo` in `check_in_screen_photo_upload_test.dart` was updated for the new `create` signature but does not exercise the new `venue` arg [LOW]
**File:** `_workspace/03_frontend/test/check_in_screen_photo_upload_test.dart:52`
**Issue:** The `create` override added `Map<String, dynamic>? venue` to the signature (so the test compiles) but the test body never sets it. There is no widget-level assertion that the screen passes `_venue?.toCheckinVenueJson()` through to `create`. Without that, a future regression where `_pickVenue` mutates `_venue` but `_submit` forgets to pass it would slip through the existing tests. The new `venue_picker_sheet_test.dart` covers the picker → place flow in isolation, and `venue_search_repository_test.dart` covers the wire, but the screen-to-controller-to-repo handoff for venue has zero coverage in the existing suite.
**Recommendation:** Extend the existing photo-upload test (or add one alongside) that uses `initialVenue: const FoursquarePlace(foursquareId: 'fsq-x', name: 'X')`, submits, and asserts on a captured `venue` arg in `_FakeRepo.create`. Five-line addition; locks in the wiring.

### STYLE-004 — Missing 422 test for the `lat`-without-`lng` validation branch [LOW]
**File:** `_workspace/02_backend/api/internal/handlers/venues.go:55-58`
**Issue:** The XOR check `(latStr == "") != (lngStr == "")` returns 422 VALIDATION when only one of lat/lng is supplied. There is no test (`foursquare/client_test.go` is below the handler; `tests/integration/venues_integration_test.go` only tests 503-when-disabled and the check-in upsert paths — no `/v1/venues/search` 422 case at all). Backend QA report flagged this; agreeing with LOW. The whole `/v1/venues/search` handler has zero tests under the integration tag — every `/v1/venues/search` test cannot pass while the test harness leaves `FOURSQUARE_API_KEY` unset, so the only path that ever runs is the 503 branch. That is a real coverage gap, not just one missing test.
**Recommendation:** Either (a) add a handler-level unit test (no integration tag, no Foursquare config required) that calls `VenueSearch` with `q=foo&lat=10` and asserts 422, plus the empty-`q` case; or (b) when an integration env eventually has the key set, add the 422 cases there. (a) is the lower-effort fix and avoids depending on credentials. Repurposable for the empty-`q` 422 branch too.

### STYLE-005 — `_maxResultsOnScreen = 30` has no WHY [LOW]
**File:** `_workspace/03_frontend/lib/features/venues/widgets/venue_picker_sheet.dart:19`
**Issue:** Flat constant, top-of-file. The other Phase-4 constants — `venueSearchDebounce` (`venue_providers.dart:15`), `venueSearchLimit` (`handlers/venues.go:16`), every Foursquare client const (`client.go:39-72`) — all carry an explanatory comment. This one is the outlier.
Backend `venueSearchLimit = 50` (the server's own cap), Foursquare `maxLimit = 50`, and Dart `_maxResultsOnScreen = 30` are also a quietly mismatched chain: the server will return up to 50, the picker only renders 30. That is fine — it's a UI cap — but the WHY ("the sheet is finger-scrollable but anything past ~30 turns into a wall of identical names without map context") is exactly the kind of thing the rest of the file documents. The mismatch with the upstream cap is what you want commented; not the number.
**Recommendation:**
```dart
// Sheet renders at most this many; results beyond ~30 lose discoverability
// without a map view (Phase 4 has no map). Server still returns up to 50.
const _maxResultsOnScreen = 30;
```

### STYLE-006 — `feedCardAtVenue` placeholder order differs across locales without a generator note [LOW]
**File:** `_workspace/03_frontend/l10n/intl_ko.arb:73` (versus `intl_en.arb:73`, `intl_ja.arb:73`)
**Issue:** ARB placeholder order: en `"at {name} · {locality}"`, ja `"{name} · {locality}にて"`, ko `"{locality} · {name}에서"`. The generated method signature is `feedCardAtVenue(String name, String locality)` — Flutter's intl tooling extracts placeholders from the `@feedCardAtVenue` block, not from positional order in the format string, so the swap in `ko` is functionally correct. But:
1. ARB hygiene convention is to either keep placeholder order stable across locales, OR add an `@feedCardAtVenue.description` noting "argument order may swap per language". Neither is present.
2. A future translator copying the en string into a new locale could accidentally swap the placeholders and not notice in code review.
3. The Flutter QA report (Phase 4 Lens 1) already noted this as PASS, but flagged the swap; that report did not call out the missing description metadata.
**Recommendation:** Add to each of the three `@feedCardAtVenue` blocks:
```json
"description": "Feed card venue footer. Word order varies — placeholder order in the format string may differ between locales; method signature is positional (name, locality)."
```
One line per locale.

### STYLE-007 — `apierror.WriteFrom` venue branch is unreachable safety-net code with no test [LOW]
**File:** `_workspace/02_backend/api/internal/apierror/apierror.go:105-110`
**Issue:** Branches `errors.Is(err, ErrVenueSearchDisabled)` and `errors.Is(err, ErrVenueRateLimited)`. The only caller path that hits `apierror.WriteFrom` for these is the `default:` arm in `handlers/venues.go:91` (`h.writeErr(...)`), but the explicit `case`s above always intercept these sentinels before `default:` fires. So this is dead code in practice — backend QA called it "harmless safety net". I agree it is harmless; flagging because:
1. The `VENUE_RATE_LIMITED` branch in `WriteFrom` does NOT set the `Retry-After` header that the actual handler sets at `venues.go:86`. If a future endpoint routes a `foursquare.ErrRateLimited` through `WriteFrom` (e.g., reusing the sentinel in a different handler) the client would silently lose the `Retry-After: 1` signal. That's a subtle behavior drift hidden behind "they look like equivalent paths".
2. No test exercises either `apierror` branch.
**Recommendation:** Either delete the two dead branches in `WriteFrom` (since the handler always handles them inline) — preferred, simplest, removes the divergence — or add a comment at `apierror.go:106` stating "Reserved for callers that don't need to set Retry-After; handlers/venues.go bypasses this and sets the header directly." The fact that the QA report had to flag this as "dead safety net" is the bug here: future readers won't know which path is authoritative.

### STYLE-008 — `venue_repository.dart:62` silently swallows malformed response shape [LOW]
**File:** `_workspace/03_frontend/lib/features/venues/repository/venue_repository.dart:62`
**Issue:** `if (data is! Map<String, dynamic>) return const [];` — returns an empty result rather than throwing. If the backend ever ships an envelope change (e.g., wraps in `{ data: { items: ... } }` for some reason) the UI will silently show "no venues found" forever and there will be no signal in logs/Sentry. The Phase-4 contract is fixed by OpenAPI, so this is genuinely defensive; the same file's `503 with wrong code` path also silently `rethrow`s, which IS correct (preserves the error type), but the malformed-200 path eats the error without telemetry.
The Phase 4 QA report flagged this as backlog/cosmetic; I'm leaving it at LOW with the same recommendation: tiny risk, but consistent with the rest of the codebase ("never `catch (_) {}`" — see `style-review` SKILL.md). The same `catch (_) {}` pattern exists at `check_in_screen.dart:167-169` (image picker no-op) — that one is justified (test environments), this one is not.
**Recommendation:** Change to `throw FormatException('venues/search: unexpected response shape')` so DioInterceptor / Sentry capture the issue, OR `Sentry.captureMessage('venues/search malformed response')` + return `const []`. Either is one line.

### STYLE-009 — `VenueRepository` exception classes live in the repository file; the widget imports the repository solely to reference them [LOW]
**File:** `_workspace/03_frontend/lib/features/venues/widgets/venue_picker_sheet.dart:17`
**Issue:** `import '../repository/venue_repository.dart';` is used only to reference `VenueSearchDisabledException` and `VenueRateLimitedException` in two `if (err is …)` branches. The widget never instantiates the repository — Riverpod hands it the typed `AsyncValue<List<FoursquarePlace>>` through `venueSearchProvider`. So the widget is coupled to the Dio-touching file solely for two type imports.
Flutter QA called this "architecturally borderline; functionally fine" at MINOR. I agree with severity. Flagging because pulling the exceptions out into `lib/features/venues/exceptions.dart` (or a re-export from `core/models/venue.dart`) would remove the coupling at the cost of one file. The same pattern will repeat for every domain in Phases 5/6 (storage disabled exceptions already do this — see `checkin_repository.dart`'s `StorageDisabledException`), so the team has a chance to set the convention here. → SendMessage to `arch-reviewer` because this is a small instance of a recurring structural decision.
**Recommendation:** Move the two `*Exception` classes to a new `lib/features/venues/exceptions.dart`; have both `venue_repository.dart` and `venue_picker_sheet.dart` import it.

### STYLE-010 — `_FakeRepo` extending `CheckInRepository` (a concrete class) requires constructing a real Dio just to be discarded [LOW]
**File:** `_workspace/03_frontend/test/check_in_screen_photo_upload_test.dart:46`
**Issue:** `_FakeRepo() : super(dio: Dio(), rawDio: Dio());` — the parent constructor takes two real `Dio` instances solely so subclasses can override every method. The objects are never used. This is a class-extension pattern in a codebase that otherwise uses interface implementation (e.g., `_StubVenueRepo implements VenueRepository` in `venue_picker_sheet_test.dart:16`). Two-style coverage in adjacent files makes the next test author guess.
**Recommendation:** Either extract a `CheckInRepository` interface (slight refactor, lets tests `implements` it cleanly) or document the chosen pattern in `style-review` skill. Not in-scope for Phase 4 cleanup; flagging for the consistency backlog.

### STYLE-011 — Domain doc states the venue silent-drop contract but the integration test for an empty venue body and the integration test for an `{ id }` lookup are in the same file at different fidelity [LOW]
**File:** `_workspace/02_backend/api/internal/domain/types.go:392-398` + `tests/integration/venues_integration_test.go:193-216`
**Issue:** The `CreateCheckinRequest.Venue` doc lists three accepted shapes: `{ id }`, `{ foursquare_id, name, ... }`, and `null / empty → silent drop`. The integration test asserts the empty-object silent drop (line 193), but does NOT cover the variants that should ALSO silent-drop per the seam in `handlers/checkins.go:299-329`:
- `{ foursquare_id }` without `name` → should silent-drop (today's code does, but no test).
- `{ name }` without `foursquare_id` → should silent-drop.
- `{ id: "" }` (empty-string, not null) → should silent-drop (the `*v.ID != ""` guard at `checkins.go:303` handles it, but no test).

These are all "permissive on incomplete" silent-drop branches; one test asserts the most-empty case, leaving three branches uncovered.
**Recommendation:** Extend `TestCreateCheckinWithEmptyVenueIsSilentDrop` into a table-driven test that runs each of the four shapes and asserts `venue` is absent on the response. ~30 LOC.

---

## Background — agreeing with prior QA severities (no escalation)

The following items were already flagged in `qa_report_phase4_backend.md` / `qa_report_phase4_flutter.md` at MINOR. I confirmed each and agree with the severity; not re-listing as separate STYLE-NNN entries:

- `client_test.go:182` `clone.URL = &(*req.URL)` pointer dance — cosmetic, real `c := *req.URL; clone.URL = &c` would read better.
- `cacheSize = 1000` per-pod note — already documented as comment at `client.go:56-58`; no action needed at Phase 4.
- `resolveLocale` silent map of invalid locale to `"en"` — friendly default, defer.
- `check_in_card.dart` venue footer ignores `country` — product call, not style.
- `DraggableScrollableSheet` 0.7/0.5/0.95 inline numbers in `venue_picker_sheet.dart:71-73` — Flutter idiom is inline sizes; cosmetic.
- `VenueSearchQuery` hand-coded `==` / `hashCode` — fine while the class is one provider's input.

## Cross-domain SendMessage notes

- **arch-reviewer**: STYLE-009 surfaces a structural question (should typed exceptions live in a separate `exceptions.dart` file, separating widget→exceptions from widget→repository). Same shape will repeat in Phase 5 / 6 features; this is the chance to set the convention.
- **security-reviewer**: no swallowed-auth or swallowed-validation patterns to escalate. The `auth failed` string-vs-sentinel issue (STYLE-002) does NOT mask auth telemetry — the error still propagates through `writeErr` → `WriteFrom` → 500 INTERNAL, which is the intended behavior (auth failure to the upstream means our config is wrong, not the user's request). No escalation.

## Summary

11 findings, all LOW. No HIGH/MEDIUM. Phase 4 venue slice is in good style shape; the items above are polish + one or two real coverage gaps (STYLE-003, STYLE-004, STYLE-011) that would benefit from being closed before Phase 5 adds more callers.
