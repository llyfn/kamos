# QA Report — Phase 0 Cross-Layer Cleanup

Date: 2026-05-14
Scope: Phase 0 of post-MVP roadmap (`~/.claude/plans/mutable-juggling-cook.md`).
Verdict: **PASS**

Phase 0 closes the QA-deferred MINOR backlog from `qa_report_final.md`. No new feature surface, no schema changes, no new dependencies.

---

## MIN-A — 10 unused OpenAPI endpoints (decision: all KEEP)

Each endpoint was retained and labelled with a `// Status: scaffold-for-Phase{N}` comment on the handler plus a matching `description:` block in `openapi.yaml`. The "scaffold" label is intentional — every endpoint is pre-wired for a phase on the roadmap.

| operationId | Path | Phase |
|---|---|---|
| `getCheckin` | GET /v1/check-ins/{id} | 5, 6 |
| `updateCheckin` | PATCH /v1/check-ins/{id} | 5 |
| `deleteCheckin` | DELETE /v1/check-ins/{id} | 5 |
| `addCheckinPhoto` | POST /v1/check-ins/{id}/photos | 3 |
| `getBeverageCheckins` | GET /v1/beverages/{id}/check-ins | 5, 6 |
| `getUserFollowers` | GET /v1/users/{username}/followers | 6 |
| `getUserFollowing` | GET /v1/users/{username}/following | 6 |
| `getCategories` | GET /v1/categories | 5 |
| `submitBeverageRequest` | POST /v1/beverage-requests | 5 |
| `updateCollectionEntry` | PATCH /v1/collections/{id}/entries/{beverage_id} | 6 |

Verified: `grep -c 'scaffold-for-Phase' openapi.yaml` → 10; `grep -rc 'scaffold-for-Phase' internal/handlers/` → 10.

---

## MIN-D — 7 backend cosmetics

| # | Item | Status | Notes |
|---|---|---|---|
| 1 | `Brewery.beverage_count` exposed in OpenAPI + populated by repo | DONE | Correlated subquery in `BreweryRepo.List`/`Detail`; `BreweryRef` (search/nested) intentionally omits the count, documented in the schema. |
| 2 | omitempty / nullable drift reconciled on Brewery / Beverage / UpdateMeRequest | DONE | `Beverage.avg_rating` is the only field intentionally `nullable: true + required: true` (always present, sometimes null); the rest match Go's `omitempty` semantics. |
| 3 | `I18nText.KO,omitempty` behavior | NO-OP (correct as is) | Flutter `resolveI18n` treats absent and empty `ko` identically. |
| 4 | `/v1/search` cursor exact across mixed-type pages | DONE | Cursor extended with `Type` discriminator; handler drains beverages then breweries; new integration test `TestSearchTypelessCursor` covers page-1 → page-2 → page-3 with every item returned exactly once. |
| 5 | UpdateCheckin double-decode dead branch | REMOVED | `bytesReader` helper also removed from `handlers/helpers.go`. |
| 6 | `LocalizedDefaultCollections` localized | DONE | `ja` → インベントリー/ウィッシュリスト, `ko` → 인벤토리/위시리스트, en + unknown → Inventory/Wishlist. Unit test covers all branches. |
| 7 | `GoogleClientSecret` removed from `Config` and docs | DONE | The ID-token-verification flow doesn't need the client secret; SPEC invariant unchanged (Flutter still never holds a client ID/secret). |

---

## MIN-B — Flutter ARB i18n cleanup (decision: 11 wired, 4 pruned)

| Key | Decision | Wired into / Removed |
|---|---|---|
| `errorUnauthorized` | WIRE | `auth_interceptor.dart` publishes toast via `apiToastBusProvider`; localized in `app.dart` `_ApiToastListener`. |
| `errorNetwork` | WIRE | Same interceptor on `connectionTimeout` / `connectionError`. |
| `collectionsBottleCountOne` / `Other` | WIRE | `collections_list_screen.dart` card subtitle. |
| `searchResultCountOne` / `Other` | WIRE | `search_screen.dart` header. |
| `checkInReviewTooLong` | WIRE | `check_in_screen.dart` review-field `errorText`. |
| `checkInPostFailed` | WIRE | Same screen, submit-error snackbar. |
| `actionPost` | WIRE | Same screen, submit button label. |
| `actionRetry` | WIRE | `state_views.dart` `ErrorView`. |
| `actionEndOfFeed` | WIRE | `feed_screen.dart` end-of-list footer. |
| `collectionsCustom` | PRUNE | Not surfaced anywhere on the roadmap. |
| `collectionsDefault` | PRUNE | Same. |
| `searchRecent` | PRUNE | No recent-search history feature on the roadmap. |
| `checkInSubmit` | PRUNE | Newly orphaned by `actionPost` wiring; removed in the same commit (orphan-cleanup rule). |

Net ARB delta: −5 keys + 5 new `verifyEmail*` keys = parity preserved (158 → 158 per locale). `arb_parity_test.dart` PASS.

---

## MIN-C — `/auth/verify-email` route registered

- New screen: `lib/features/auth/screens/verify_email_screen.dart` (loading → success/failure with retry-to-`/auth`).
- Router: registered with explicit exempt logic so unauth users hitting the deep link aren't bounced to `/auth`.
- New ARB keys (en/ja/ko): `verifyEmailTitle`, `verifyEmailLoading`, `verifyEmailSuccess`, `verifyEmailFailure`, `verifyEmailBackToAuth`.
- Widget tests: 2 scenarios (loading → success, loading → failure).

---

## STUB — flavor-tag picker on check-in screen

`check_in_screen.dart` previously hardcoded English flavor-tag labels. Now uses a Riverpod provider that calls `GET /v1/flavor-tags` and renders chips with locale-resolved `I18nText` labels (same `resolveI18n` helper used by beverage names). Selection state sends `tag.slug` to the server. One new widget test covers locale-resolved label rendering.

---

## Verification — actually ran locally

Backend (`_workspace/02_backend/api`):

```
go build ./...           clean
go vet ./...             clean
go test -count=1 ./...   74 PASS
go test -tags=integration -count=1 ./tests/integration/...   34 PASS (was 33; +TestSearchTypelessCursor)
```

Frontend (`_workspace/03_frontend`):

```
flutter analyze   No issues found! (1.7s)
flutter test      21/21 PASS (was 18; +TestFlavorTagChipsRenderLocaleResolved, +TestVerifyEmailLoadingToSuccess, +TestVerifyEmailLoadingToFailure)
```

Cross-layer:

- 0 references to the 5 pruned ARB keys in `lib/`, `test/`, or `l10n/`
- All 10 scaffold endpoints have BOTH a handler comment AND an OpenAPI description
- `GoogleClientSecret` / `GOOGLE_CLIENT_SECRET` 0 hits across the repo
- 12/12 SPEC invariants from `qa_report_final.md` still PASS

---

## Anti-scope hits (none)

Phase 0 deliberately touches only the QA-deferred MINOR backlog. No work on the four SPEC §9 items reopened on 2026-05-14 (venue/Foursquare, comments, public collections, user-submitted beverages) — those are Phases 4–6.

---

## Carry-forward to Phase 1

- The orphaned `_ = strings.Contains` / `_ = errors.Is` sentinel guards at the bottom of `repository/beverages.go` were left alone (scope discipline); pick up in Phase 1 style pass if it happens.
- `bytesReader` helper removal in `handlers/helpers.go` cleared the only `bytes` import; ensure Phase 1 metrics work doesn't re-introduce it accidentally.
- The cursor `Type` discriminator is backward-compatible — existing cursors decode with `Type=""` and behave as before.
