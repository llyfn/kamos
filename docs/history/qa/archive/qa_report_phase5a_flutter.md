# QA Report — Phase 5 Flutter (in-flight, per-layer; backend slice not yet landed)

Date: 2026-05-16
Scope: New `lib/core/models/beverage_request.dart` (freezed, hand-rolled `toJson`); new `lib/features/beverage_requests/{exceptions,repository,providers,screens}/`; new `/beverage-requests/new` route in `lib/app/router.dart`; settings menu entry at `features/profile/screens/settings_screen.dart:89-93`; empty-state CTA at `features/search/screens/search_screen.dart:196-200`; 11 new ARB keys × 3 locales; 3 new test files.
Verdict: **PASS WITH MINOR**

`flutter analyze` → "No issues found! (ran in 1.9s)". 45/45 PASS across the full suite (10 new tests + 35 unchanged).

---

## Lens 1 — Integration boundaries

- **OpenAPI ↔ Dart wire shape**: PASS. `openapi.yaml:1089-1095` requires `{ payload: object }`; server `domain.BeverageRequest.Validate` (`internal/domain/types.go:812-816`) requires `len(Payload) > 0`. `beverage_request.dart::toJson` always emits `{"payload": {name, brewery_name, category_slug, notes?}}` — three guaranteed non-empty keys, so the request will never trip the server's "payload is required" 422. The four inner field names are a client-side admin contract, not a wire contract (server takes `additionalProperties: true`).
- **`notes` omission**: PASS. `toJson` drops `notes` when the trimmed value is empty or null. Tested in `beverage_request_model_test.dart:28-50`. Screen also short-circuits to `null` before constructor (`submit_beverage_request_screen.dart:92`); double-trim is defensive but harmless.
- **ARB parity**: PASS. en/ja/ko each carry 184 translatable keys, zero asymmetry. All 11 new keys (`submitBeverageRequestTitle/NameLabel/BreweryLabel/CategoryLabel/NotesLabel/SubmitButton/SuccessToast/ErrorGeneric/NameRequired/BreweryRequired` + `searchSuggestMissingCta`) present in all three. No placeholders → no `@key` metadata required, consistent with how this codebase scopes `@` blocks (9 entries per file, all for placeholder messages).
- **Category strings via SPEC invariants**: PASS. The form's segmented control passes `categoryLabel(context, slug)` for each `CategorySlug` (`submit_beverage_request_screen.dart:262`), which routes through ARB keys `categoryNihonshu`/`categoryShochu`/`categoryLiqueur`. SPEC §2.1 strings (`Nihonshu (Sake)` / `日本酒` / `니혼슈 (사케)` etc.) preserved character-exact. Wire payload uses the lowercase slug (`nihonshu`/`shochu`/`liqueur`) via `categorySlugToWire`. Display and wire layers are correctly separated.
- **go_router**: PASS. `/beverage-requests/new` registered at `router.dart:129-132`. Two entry hooks resolved:
  - `settings_screen.dart:92` → `context.push('/beverage-requests/new')`.
  - `search_screen.dart:197-198` → `context.push('/beverage-requests/new')` from the no-results empty state.
- **SPEC invariants intact**: PASS. Category strings, rating widget (unaffected), cursor pagination (unaffected), secure-storage discipline (no JWT touched), and the username/soft-delete rules are unmodified.

## Lens 2 — Architecture

- **Layer separation**: PASS.
  - Widget (`submit_beverage_request_screen.dart`) imports `material`, `services` (for `FilteringTextInputFormatter`), `flutter_riverpod`, `go_router`, theme tokens, i18n category helper, the model, l10n, and the providers. No `package:dio` import. Repository reached only through provider.
  - Repository (`beverage_request_repository.dart`) is the sole Dio touch-point.
  - Model (`beverage_request.dart`) imports only `freezed_annotation`. Leaf.
  - Exceptions live in `exceptions.dart` and are imported by both the repository (throw site) and the test (catch assertion) — mirrors the venues convention established in Phase 4 (Phase 4 QA report MINOR #2 explicitly called this pattern out as the desired layout; Phase 5 adopts it from day one). Widget itself does NOT import `exceptions.dart` because the screen never pattern-matches by exception type — it just reacts to `state.hasError`. Cleaner than venues. PASS.
- **Provider/notifier shape**: PASS. `SubmitBeverageRequestNotifier` is `AsyncNotifier<void>` with idle build, `submit` mutating to loading then guard-wrapped result, and a `reset()` escape hatch. Provider is `.autoDispose` — state clears on screen pop. The `reset()` method appears unused by callers (the autoDispose covers re-entry); not removing because the doc-comment names its purpose explicitly. **MINOR**: dead code unless wired into a "Try again" affordance.
- **No premature abstraction**: PASS. No `BeverageRequestService` interface; concrete `BeverageRequestRepository`.

## Lens 3 — Coding conventions

- **Naming**: PASS. Consistent with venues feature — `BeverageRequest`, `BeverageRequestRepository`, `beverageRequestRepositoryProvider`, `submitBeverageRequestProvider`, `SubmitBeverageRequestNotifier`, `SubmitBeverageRequestScreen`, `BeverageRequestSubmissionException`. ARB key prefix `submitBeverageRequest*` is also internally consistent. Settings menu uses `l.submitBeverageRequestTitle` ("Suggest a beverage") as the menu label and as the AppBar title — semantically dual-purpose but readable. **MINOR**: a dedicated `settingsSuggestBeverage` ARB key would let the menu use shorter, sentence-style copy and the screen keep the imperative title.
- **Error handling**: PASS. Typed exception, no `catch (_) {}`, no swallowed errors. Repository rethrows wrapped `DioException`. Screen reacts to `state.hasError` and renders `submitBeverageRequestErrorGeneric` inline — screen stays open for retry (covered by `submit_beverage_request_screen_test.dart:120-147`). The exception's `cause` is held but never displayed to the user; it would surface in any logging adapter.
- **Magic values**: PASS.
  - `_kNameMax = 200`, `_kBreweryMax = 200`, `_kNotesMax = 500` (`submit_beverage_request_screen.dart:31-33`) — top-level file-private consts with a leading comment explaining derivation ("name ≤ 200 mirrors beverages.name; notes ≤ 500 mirrors check_ins.review"). 
  - Control-character regex strings are inline at the two call sites; a leading code comment at line 15-16 explains intent.
- **Dead code**: PASS at user-facing surface. **MINOR** at `beverage_request_providers.dart:32-34` — `reset()` is not wired to any caller.
- **Test coverage**: PASS.
  - Model: 4 cases — happy path with notes, null notes omitted, whitespace-only notes omitted, notes trimmed when present.
  - Repository: 3 cases — 202 happy with body capture, 422 → exception, 500 → exception.
  - Screen: 3 cases — empty form blocks submit, filled form sends wire-shape payload + shows toast + fires `onSubmittedForTest`, repo failure renders inline error and keeps screen open.
  - Total: 10 new tests, all passing.

## Lens 4 — Performance / security spot-checks

- **Form input bounds**: PASS. `maxLength: _kNameMax (200)` / `_kBreweryMax (200)` / `_kNotesMax (500)` enforced via `TextField.maxLength` (Flutter material caps the buffer hard, not just visually). Backend has no length validation today (`Validate` checks only non-empty) — Flutter is strict-by-design on the way out.
- **Control-character rejection**: PASS. Two regexes — `[\x00-\x1F\x7F]` on name/brewery (denies all C0 controls + DEL), and `[\x00-\x09\x0B\x0C\x0E-\x1F\x7F]` on notes (preserves `\n` / `\r` so paragraph breaks work). Matches the venues feature's `name/locality/country` filter convention from Phase 4. Backend doesn't enforce this here, but consistency stands.
- **No JWT / secret leak**: PASS. `BeverageRequestSubmissionException.toString()` includes `cause` (the `DioException`) — Dio's default `toString` does NOT include request headers. JWT is attached via `api_client.dart` interceptor and never enters the exception payload. Verified by inspection.
- **Form rebuilds**: PASS. The notifier is read via `ref.watch(submitBeverageRequestProvider)` only inside the screen's own `build`. The form fields use local `TextEditingController`s — keystrokes call `setState(() {})` to refresh inline error state, which rebuilds only this screen (the rest of the tree is above the route boundary). Parent doesn't churn. Submit button gating (`_isValid`) is computed each rebuild but only reads two controller texts.
- **`onChanged: (_) => setState(() {})`**: technically rebuilds on every keystroke even when the form is already valid (no-op rebuild). Trade-off: drives the inline error clearing and the FilledButton disabled→enabled transition. Acceptable for a 4-field form. **MINOR**: could be scoped to a separate `ValueNotifier<bool>` for `_isValid` and only call `setState` when crossing the threshold; not worth it at this size.
- **Search empty-state CTA cold-start**: the CTA is shown for both "user typed a query → empty results" and "feed bootstrap returned zero beverages" (early dev / empty seed environment). The latter is unusual in production but could confuse first-launch users in test environments. **MINOR**: gate the CTA on `_q.text.isNotEmpty || _category != null` so cold-start shows the existing empty copy without the "suggest" affordance. Defer.
- **Settings menu hidden behind `meProvider` data branch**: if `/v1/me` errors, the settings page shows an error view and the suggest-beverage route is unreachable from there. The search-screen entry still works. **MINOR**: surface the menu item outside `async.when` so it's always reachable. Defer; non-blocking.

---

## BLOCKERs — none

## MAJORs — none

The Phase 5 backend slice is not yet landed; once it does, re-verify that:
1. The handler accepts `{"payload": {...}}` and returns 202 with `{ id }`.
2. The handler does not require any of the four inner fields (`name`, `brewery_name`, `category_slug`, `notes`) — Flutter pins them client-side, server should remain free-form.
3. Auth requirement matches expectation (user must be signed in; anonymous suggestions should 401).

## MINORs

1. **`SubmitBeverageRequestNotifier.reset()` is dead code.** `submitBeverageRequestProvider` is `.autoDispose`, so screen pop already resets state. Either wire it to a "Try again" / "Reset form" affordance, or drop the method. (`beverage_request_providers.dart:32-34`)
2. **Settings menu label reuses the screen title `submitBeverageRequestTitle` ("Suggest a beverage").** Works, but a dedicated `settingsSuggestBeverage` ARB key would let the menu use sentence-style copy ("Suggest a beverage we're missing") and the screen keep its imperative title. Defer. (`settings_screen.dart:90`)
3. **Search empty-state CTA shows on cold-start too.** `state.items.isEmpty` fires both for "no results for query X" and "no beverages exist yet". Gate on `_q.text.isNotEmpty || _category != null` if the cold-start variant should be quiet. (`search_screen.dart:191-200`)
4. **Suggest-beverage menu unreachable when `meProvider` errors.** The settings menu is inside `async.when(data:)`, so if profile fetch errors, the settings page shows only `ErrorView` and the suggest-beverage route can't be opened from there. Search-screen entry still works. (`settings_screen.dart:31-141`)
5. **`BeverageRequest.categorySlug` is typed `String`, not `CategorySlug`.** Model accepts any string. The screen always passes `categorySlugToWire(_category)` (one of three values), but the repository test in isolation could send `'sake'` and the model would not complain. Tightening would require the model to import `core/i18n/category_labels.dart` — likely not worth the dependency direction reversal. Defer with intent.
6. **`onChanged: (_) => setState(() {})` rebuilds on every keystroke.** Drives inline-error clearing and FilledButton enabled-state. Acceptable for 4-field form; mention only for future scaling. (`submit_beverage_request_screen.dart:142, 154, 175`)

## Backlog (cosmetic, defer)

- `submit_beverage_request_screen.dart:88-92` — `notes: _notes.text.trim().isEmpty ? null : _notes.text.trim()` calls `trim()` twice. Hoist to a local.
- `submit_beverage_request_screen.dart:120` — `hasError` is read but `state.error` is never displayed; a debug logger hook would be useful for observability.
- Test file `submit_beverage_request_screen_test.dart:89` — `findsNWidgets(3)` asserts on raw TextField count, which will silently break if a future field is added. A more semantic finder (by ARB-label text) would lock the intent.

## Test counts

- New: 10 tests across 3 files
  - `beverage_request_model_test.dart` — 4 tests
  - `beverage_request_repository_test.dart` — 3 tests
  - `submit_beverage_request_screen_test.dart` — 3 tests
- Full suite after this slice: 45 tests, all passing
- `flutter analyze`: clean

---

**Net:** ship-ready on the Flutter side. Zero blockers, zero majors. 6 minors + 3 backlog notes, all polish. Holds the line on SPEC invariants, the venues-feature exception-extract convention, and the established naming pattern.
