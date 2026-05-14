# QA Report — Phase 4 Flutter (in-flight, before cross-layer QA)

Date: 2026-05-14
Scope: New `lib/core/models/venue.dart` + freezed; new `lib/features/venues/{repository,providers,widgets}`; `Checkin.venue` + `FeedItem.venue` defensive adds; check-in screen "Where?" row; feed card venue footer; 9 ARB keys × 3 locales; updated check-in repo/controller/fake; 3 new test files; README Venues section.
Verdict: **PASS WITH MINOR**

`flutter analyze` → "No issues found! (ran in 2.1s)". 35/35 PASS.

---

## Lens 1 — Integration boundaries

- **OpenAPI ↔ Dart model alignment**: PASS.
  - `FoursquarePlace` Dart (`venue.dart:57-80`) vs `openapi.yaml:1606-1621` — fields `foursquare_id, name, address, lat, lng, country, prefecture, locality` match exactly; both spec `required:[foursquare_id, name]`; Dart `fromJson` falls back to `''` for missing required strings (defensive, doesn't break server contract).
  - `VenueRef` Dart (`venue.dart:40-54`) vs `openapi.yaml:1559-1569` — `id, name, locality, country` match; required `id, name` match.
  - `Venue` Dart (`venue.dart:12-37`) vs `openapi.yaml:1571-1585` — full row schema match (drops `created_at`/`updated_at` since Flutter never displays them and the model is unused at the wire today; consistent with how `Brewery` etc. are modeled).
- **`toCheckinVenueJson()` ↔ `CheckinVenueInput`**: PASS. `venue.dart:85-95` emits exactly the 8 optional fields in `openapi.yaml:1595-1604`. `foursquare_id` and `name` are always emitted, the rest conditional-on-populated — matches "any subset is accepted" contract documented at `openapi.yaml:1587-1594`.
- **`GET /v1/venues/search` query forwarding**: PASS. `venue_repository.dart:52-60` uses Dart 3.x null-aware spread (`'lat': ?lat`) — when `lat` is null, the key is omitted entirely; Dio doesn't serialize it. Verified by `venue_search_repository_test.dart:96-97` asserting the param round-trips. `locale='en'` default matches OpenAPI default.
- **ARB parity**: PASS. en/ja/ko all 173 keys, zero asymmetry. All 9 new keys present in all three locales. `feedCardAtVenue` swaps argument order in `ko` ("{locality} · {name}에서") vs en/ja — generated signature identical across locales.
- **go_router**: PASS. No new routes added; the picker is invoked via `showModalBottomSheet` only.
- **SPEC invariants intact**: PASS. Category-strings, rating widget, cursor pagination, secure-storage discipline — all unchanged.

## Lens 2 — Architecture

- **Layer separation**: PASS.
  - `lib/features/venues/widgets/` → no `package:dio` imports. Sheet imports only `material`, `flutter_riverpod`, app theme, models, l10n, providers, and the repository (for the typed exception classes only — see MINOR).
  - `lib/features/venues/repository/venue_repository.dart` is the only file under `features/venues/` that touches Dio.
  - `lib/core/models/venue.dart` imports only `freezed_annotation`. Models stay leaf.
- **No premature abstraction**: PASS. No `VenueProvider` interface; concrete `VenueRepository`.
- **MINOR — repository-exception leak into widget**: `venue_picker_sheet.dart:17` imports `venue_repository.dart` solely to reference the typed exceptions in the `error:` branch of `results.when` (lines 146, 165). Functionally fine; strict reading would relocate the exceptions to a shared `lib/features/venues/exceptions.dart`. Defer.

## Lens 3 — Coding conventions

- **Naming**: PASS. `Venue`, `VenueRef`, `FoursquarePlace`, `VenueRepository`, `venueRepositoryProvider`, `venueSearchProvider`, `VenueSearchQuery`, `VenueSearchNotifier`, `showVenuePicker`, `VenuePickerSheet` — consistent with existing patterns.
- **Error handling**: PASS. Typed exceptions discriminated by HTTP status (503) AND server `code` field, with secondary path through `ApiException` if the interceptor wrapped first. No `catch (_) {}`. Each error branch in the sheet maps to a distinct localized string + UX.
- **Magic values**: PASS.
  - `venueSearchDebounce = Duration(milliseconds: 300)` (`venue_providers.dart:15`) — top-level const with leading comment explaining intent.
  - `_maxResultsOnScreen = 30` (`venue_picker_sheet.dart:19`) — file-private const. **MINOR**: no "WHY" comment.
- **Dead code**: PASS. `_FakeRepo` updated to new `create` signature.
- **Comments**: PASS. File headers explain WHY; no trivial WHAT narration.
- **Test coverage**: PASS. Repository: 200 happy + 503 disabled + 503 rate-limited. Sheet: empty-state + debounce + list + tap-to-pick. Model: null + populated decode, `toCheckinVenueJson` drops empties.

## Lens 4 — Performance

- **Debounce + cancellation**: PASS. `VenueSearchNotifier._epoch` increments on every `setQuery` and `_run`; results dropped if epoch shifted. `Timer` cancelled on each new query and on dispose. Empty queries short-circuit with no network call.
- **TextField uses LOCAL controller**: PASS. Keystrokes don't rebuild the sheet via Riverpod.
- **List recycling**: PASS. `ListView.separated` (lazy + recycled). Capped at 30 results.
- **No `setState` in `build`**: PASS.
- **No synchronous I/O on UI thread**: PASS.
- **MINOR — disposed-notifier hazard**: `venueSearchProvider` is `AsyncNotifierProvider.autoDispose`. In-flight `_run` future not explicitly cancelled — only result discarded via epoch check. Riverpod 3.x handles this; defer.

---

## BLOCKERs — none

## MAJORs — none

`FeedItem.venue` Dart-side addition is intentional defensive decoding (forward-compat). Backend QA flagged the missing projection as their MAJOR; orchestrator fixed it inline. **Don't remove the Flutter field.**

## MINORs

1. `venue_picker_sheet.dart:19` — `_maxResultsOnScreen = 30` lacks a one-line WHY comment.
2. `venue_picker_sheet.dart:17` — widget imports repository for typed exceptions. Optional relocate to `lib/features/venues/exceptions.dart`.
3. `feed/widgets/check_in_card.dart:176-187` — venue footer renders `feedCardAtVenue(name, locality)` or `feedCardAtVenueNoLocality(name)`; `country` is intentionally ignored at the card level. Defer.
4. `venue_model_test.dart:63-70` — `FeedItem.venue absent → null` test only exercises the current backend. A `venue: {...}` positive-decode test would lock in the forward-compat contract.
5. `_FakeRepo` only updates the `create` signature; doesn't exercise the venue path.

## Backlog (cosmetic, defer)

- `venue_repository.dart:62` — `if (data is! Map<String, dynamic>) return const [];` silently returns empty on malformed responses. Optionally log/throw.
- `venue_picker_sheet.dart:71-73` — `DraggableScrollableSheet` initial/min/max child sizes (0.7/0.5/0.95) inline magic numbers.
- `VenueSearchQuery` (`venue_providers.dart:17`) is hand-coded `==` / `hashCode`. Defer.

---

**Net:** ship-ready. Zero blockers, zero majors. 5 minors are all polish.
