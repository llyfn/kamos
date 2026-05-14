# QA Report — Final cross-layer integration (Phase 4)

Date: 2026-05-11
Scope: Design ↔ DB ↔ API ↔ Flutter, end-to-end.
Status: **PASS WITH MINOR**

Verdict rationale: every SPEC blocker invariant is consistently enforced in all five layers (DB CHECK + Go validation + OpenAPI schema + Dart model + widget step/cap). `go build / vet / test` clean. `flutter analyze` clean. 18/18 Flutter tests pass. No BLOCKERs. Two MAJORs are MVP-deferred and explicitly punted (SMTP, blob storage, both carried over from `qa_report_backend.md`); a third MAJOR (server-emitted email field on public profiles) is a privacy hazard but is gated by client-side rendering. MINORs are dead i18n keys, unused endpoints (spec-vs-consumer drift), and known omitempty/nullable cosmetics from the backend QA.

The build is clear to proceed to Phase 5 (deployment artifacts).

---

## BLOCKERs

(none)

---

## MAJORs

### M1 — Photo upload is URL-by-reference; no presigned-URL / blob storage exists
- Severity: MAJOR (deferred — OK for MVP scaffolding)
- Boundary: `internal/handlers/checkins.go:174` ↔ `openapi.yaml /v1/check-ins/{id}/photos` ↔ Flutter has `image_picker` wired in `lib/features/check_in/screens/check_in_screen.dart:14` but no upload call.
- Carried from `qa_report_backend.md`. Server accepts `{"url": "..."}` and stores it as-is; no presigned PUT endpoint, no domain allowlist, no orphan cleanup. The 4-photo cap is enforced; the storage layer is not. Flutter has `image_picker: ^1.1.2` in `pubspec.yaml:33` and uses it in the check-in screen, but no `addPhoto` call is wired anywhere in `lib/`.
- Fix: pre-public-beta work, not pre-MVP-shipping. `backend-engineer` to wire presigned URL endpoint; `flutter-engineer` to swap the local file path for the presigned URL result.

### M2 — Verification email is logged, not sent (SMTP not wired)
- Severity: MAJOR (deferred)
- Boundary: `internal/handlers/auth.go:75-80`, `:295-298`, `:370-373`
- Carried from `qa_report_backend.md`. `Register`, `ResendVerification`, `EmailChange` create the token row and log the link only. SMTP via `cfg.SMTPHost/Port/User/Pass` must be wired before a public deploy. Frontend wiring is correct.

### M3 — `GET /v1/users/{username}` returns the target user's `email` to any caller
- Severity: MAJOR (privacy)
- Boundary: `internal/handlers/users.go:71-77` (`publicProfile` embeds `domain.User` which includes `email`) ↔ `openapi.yaml#/components/schemas/User` lists `email` as required.
- Flutter mitigates by NOT rendering `user.email` on the `OtherProfileScreen` (see `lib/core/models/user.dart:3-7` doc-comment), but the wire response still leaks email to any logged-in caller of a public profile. SPEC §3.2 does not explicitly say email is private; convention says it is.
- Fix: `backend-engineer` — introduce `PublicUser` (no email, no email_verified) in `domain` and the OpenAPI schema, or zero the email field in `publicProfile`. Flutter handles the change transparently because `user.email` is nullable in `User.fromJson` already.

---

## MINORs (grouped)

### MIN-A — Unused OpenAPI endpoints (no Flutter caller)
Severity: MINOR (drift between contract and consumer)

| operationId | OpenAPI path | Why unused |
|---|---|---|
| `getCheckin` | `GET /v1/check-ins/{id}` | No detail screen for a single check-in in MVP UI; feed cards render in place. |
| `updateCheckin` | `PATCH /v1/check-ins/{id}` | No edit-check-in screen wired (SPEC §4.4 allows edit, MVP didn't surface it). |
| `deleteCheckin` | `DELETE /v1/check-ins/{id}` | No delete affordance in UI. |
| `addCheckinPhoto` | `POST /v1/check-ins/{id}/photos` | Tied to M1; no presigned upload yet. |
| `getBeverageCheckins` | `GET /v1/beverages/{id}/check-ins` | `BeverageDetailScreen` uses only the `recent_check_ins` returned inline by `getBeverage`. |
| `getUserFollowers` | `GET /v1/users/{username}/followers` | No followers list screen. |
| `getUserFollowing` | `GET /v1/users/{username}/following` | No following list screen. |
| `getCategories` | `GET /v1/categories` | Flutter uses local `kCategoryStrings` (`lib/core/i18n/category_labels.dart:44-54`) — same constants, no round-trip needed. |
| `submitBeverageRequest` | `POST /v1/beverage-requests` | No "request a beverage" UI in MVP. |
| `renameCollection` (PATCH `/v1/collections/{id}`) | wired — `CollectionRepository.rename` | OK |
| `updateCollectionEntry` | `PATCH /v1/collections/{id}/entries/{beverage_id}` | No note-edit UI on collection entries. |

Repository methods present but unconsumed by a Riverpod provider: `ProfileRepository.userCheckins` (no user check-ins list on `OtherProfileScreen`). Document each as a punch list item; not blocking the gate.

Fix: either (a) prune unused operations from the OpenAPI for MVP and re-add post-MVP, or (b) accept the wider contract as "future-proofing" and add a `Status: scaffold` tag. Recommendation: **(b)** — the backend is correct and pre-built; the missing UI is the MVP scope decision, not an API bug.

### MIN-B — Unused ARB keys (dead i18n copy)
Severity: MINOR
Source: full grep across `lib/` for each en key.

```
actionEndOfFeed, actionPost, actionRetry, checkInPostFailed,
checkInReviewTooLong, collectionsBottleCountOne, collectionsBottleCountOther,
collectionsCustom, collectionsDefault, errorNetwork, errorUnauthorized,
searchRecent, searchResultCountOne, searchResultCountOther
```

14 keys × 3 locales = 42 lines of dead copy. Several look load-bearing (`errorUnauthorized`, `errorNetwork`, `collectionsBottleCount*`, `searchResultCount*`) — they imply screens were planned but not finished wiring through. None block MVP since the screens render without them, but they should either be wired (collection screen showing bottle count; search header showing result count; error toast on 401/network) or pruned.

Fix: `flutter-engineer` — for the next pass, wire `errorUnauthorized` to the API 401 toast (currently the auth interceptor clears the token silently); wire `collectionsBottleCountOne/Other` to the collection list tile; wire `searchResultCountOne/Other` to the search header. Cheap polish, not blocking.

### MIN-C — Router doc-comment lists `/auth/verify-email` but no route is registered
- Severity: MINOR
- Location: `lib/app/router.dart:5` says `/auth/verify-email   post-registration banner` but `routes:` (lines 55-114) only registers `/auth`.
- The redirect on lines 50-52 would correctly send unauth users to `/auth`, but if anything navigates to `/auth/verify-email` directly, `go_router` will hit a 404.
- Fix: either register the route with a screen, or remove the line from the doc comment. The `AuthScreen` already includes a verify banner conditionally.

### MIN-D — Carried from backend QA (still open)
All seven backend MINORs from `qa_report_backend.md` carry forward unchanged. Headlines:
- `Brewery.BeverageCount` in Go domain but not in OpenAPI (`types.go:271` ↔ schema)
- `omitempty` vs `nullable: true` on optional fields (Brewery / Beverage / UpdateMeRequest)
- `I18nText.KO,omitempty` drops empty Korean strings — Flutter `resolveI18n` handles both, see `beverage_name.dart:24`, OK
- `/v1/search` mixed beverage+brewery cursor is approximate past page 1
- `UpdateCheckin` strict-then-loose double-decode is dead code
- `LocalizedDefaultCollections` returns English for all locales (`types.go:660-666`)
- `GoogleClientSecret` loaded in `Config` but never used (dead docs)

Fix owners: `backend-engineer` for all seven; `designer` for the localized-default-collections strings.

---

## SPEC invariant trace table

Each row traces an invariant through all five layers (DB / Go / OpenAPI / Dart / Widget). PASS means byte-identical or equivalent semantics.

| Invariant | DB | Go | OpenAPI | Dart model | Widget / runtime | Result |
|---|---|---|---|---|---|---|
| Rating 0.5–5.0, 0.5 steps, optional | `migrations/001_initial.sql:351` `NUMERIC(3,1)` + `:364-370` CHECK `(rating*10)::int % 5 = 0` | `internal/domain/types.go:332` `*float64`, `:349-362` `ValidRating` | `openapi.yaml:1182-1188` `type: number, nullable: true, minimum: 0.5, maximum: 5.0` | `lib/core/models/checkin.dart:52` `double? rating` | `lib/shared/widgets/stars_input.dart:23-25,64-77` 0.5 / 1.0 steps, clears to null | **PASS** |
| Review text ≤ 500 chars | `001_initial.sql:374-376` CHECK `char_length(review_text) <= 500` | `types.go:371,429` `len([]rune) > 500` | `openapi.yaml:1190,1222` `maxLength: 500` | `checkin.dart:53,100` `String? review` | check-in screen (limits via TextField/maxLength) | **PASS** |
| Photo cap ≤ 4 per check-in | DB unique `sort_order BETWEEN 0..3`; handler+repo enforce 4-cap | `types.go:374`, `repository/checkins.go:67,400` | `openapi.yaml:1196,1228` `maxItems: 4` | `checkin.dart:55` `List<PhotoRef>` (cap enforced at UI) | `intl_en.arb:43-46` `checkInPhotosLabel: "Photos · up to 4"` + `checkInPhotoCounter "{count} / 4"` | **PASS** |
| Username `^[A-Za-z0-9_]{3,30}$`, case-insensitive | `001_initial.sql:56,60,64` two-column + coherence CHECK | `types.go:102` regex, `repository/users.go:103` LOWER() store | `openapi.yaml:1028-1031` pattern + minLength/maxLength | `user.dart:33-34` `username` + `displayUsername` | `intl_en.arb:84` `authUsernameHelper` matches | **PASS** |
| Cursor pagination, never offset | n/a (query patterns: WHERE id < cursor) | 11/11 list endpoints use `cursor.Cursor`/`cursor.Page[T]` | `openapi.yaml:1330-1337` `PageBase {items, next_cursor, has_more}` | `lib/core/models/page.dart:12-16` `Page<T> {items, nextCursor, hasMore}` | Feed/list providers consume `hasMore`/`nextCursor`; no `?page=` calls | **PASS** |
| Soft-delete excluded from reads | `001_initial.sql` `deleted_at TIMESTAMPTZ` on users/check_ins/collections | 41 `deleted_at IS NULL` filters in `repository/*.go` | not on wire (server-filtered) | Flutter has no `deletedAt` field anywhere — trusts server | screens render server response as-is | **PASS** |
| Default Inventory + Wishlist on signup | `001_initial.sql` `collections` table; seeding via transaction | `repository/users.go:70-92` `CreateUserWithDefaults` (also called from Google OAuth at `auth.go:232`) | not on wire (server-side seeding) | n/a | n/a — names default to English until designer pins ja/ko (`types.go:660-666`) | **PASS** (function), **MINOR** (localization deferred — MIN-D) |
| JWT in `flutter_secure_storage`, never `SharedPreferences` | n/a | n/a | `bearerFormat: JWT` | `lib/core/storage/secure_storage.dart:17-34` only place tokens live | grep `SharedPreferences` returns 0 token hits (only `encryptedSharedPreferences:true` keychain option) | **PASS** |
| OAuth client **secret** never reaches the device | n/a | `config.go:20,39` server-only env | n/a | grep for `GOOGLE_CLIENT_SECRET\|clientSecret\|client_secret` in Flutter returns 0 hits | `api_config.dart:14-17` ships only `KAMOS_GOOGLE_CLIENT_ID` | **PASS** |
| Category strings character-exact (SPEC §2.1) | `migrations/002_seed_taxonomy.sql:14-22` | server returns from DB | `openapi.yaml:951-964` enum + doc-comment | `lib/core/i18n/category_labels.dart:44-54` `kCategoryStrings` map | ARB rows: `intl_en.arb:6-8`, `intl_ja.arb` 日本酒/焼酎/リキュール, `intl_ko.arb` 니혼슈 (사케)/쇼츄/리큐어 — verified byte-for-byte | **PASS** |
| i18n `ko→en` / `ja→en` fallback | n/a (returns I18nText verbatim) | `I18nText.Resolve` exists, unused in handlers | `openapi.yaml:939-949` `en` required, `ja`/`ko` optional | `lib/core/i18n/beverage_name.dart` `resolveI18n` | tested in `test/beverage_name_fallback_test.dart` (5 cases PASS) | **PASS** |
| Out-of-scope features absent | n/a | grep across `_workspace/02_backend` for `venue\|barcode\|apple ?sign\|public collection\|push notification\|block user` returns 0 hits | n/a | grep across `_workspace/03_frontend/lib` same set returns 0 hits | n/a | **PASS** |

All 12 invariants PASS.

---

## Endpoint coverage matrix

`operationId` → Flutter consumer (file + method). `—` means defined in OpenAPI but no Flutter caller (see MIN-A).

| operationId | Method + path | Flutter consumer |
|---|---|---|
| `healthCheck` | GET /health | — (deployment check only) |
| `register` | POST /v1/auth/register | `auth_repository.dart:30 register()` |
| `login` | POST /v1/auth/login | `auth_repository.dart:16 login()` |
| `googleLogin` | POST /v1/auth/google | `auth_repository.dart:54 google()` |
| `verifyEmail` | POST /v1/auth/verify-email | `auth_repository.dart:73 verifyEmail()` |
| `resendVerification` | POST /v1/auth/resend-verification | `auth_repository.dart:82 resendVerification()` |
| `passwordChange` | POST /v1/auth/password-change | `auth_repository.dart:86 changePassword()` |
| `emailChange` | POST /v1/auth/email-change | `auth_repository.dart:99 changeEmail()` |
| `getMe` | GET /v1/users/me | `profile_repository.dart:20 me()` |
| `updateMe` | PATCH /v1/users/me | `profile_repository.dart:25 updateMe()` |
| `deleteMe` | DELETE /v1/users/me | `profile_repository.dart:45 deleteMe()` |
| `getUser` | GET /v1/users/{username} | `profile_repository.dart:49 getProfile()` |
| `getUserCheckins` | GET /v1/users/{username}/check-ins | `profile_repository.dart:54 userCheckins()` (method exists, not wired to provider/screen — MIN-A) |
| `getUserFollowers` | GET /v1/users/{username}/followers | — |
| `getUserFollowing` | GET /v1/users/{username}/following | — |
| `listBeverages` | GET /v1/beverages | `beverage_repository.dart:14 list()` |
| `getBeverage` | GET /v1/beverages/{id} | `beverage_repository.dart:35 get()` |
| `getBeverageCheckins` | GET /v1/beverages/{id}/check-ins | — |
| `listBreweries` | GET /v1/breweries | — (only `getBrewery` is used) |
| `getBrewery` | GET /v1/breweries/{id} | `brewery_repository.dart:23 get()` |
| `createCheckin` | POST /v1/check-ins | `checkin_repository.dart:17 create()` |
| `getCheckin` | GET /v1/check-ins/{id} | — |
| `updateCheckin` | PATCH /v1/check-ins/{id} | — |
| `deleteCheckin` | DELETE /v1/check-ins/{id} | — |
| `addCheckinPhoto` | POST /v1/check-ins/{id}/photos | — |
| `toggleToast` | POST /v1/check-ins/{id}/toast | `feed_repository.dart:28 toggleToast()` |
| `getFeed` | GET /v1/feed | `feed_repository.dart:14 getFeed()` |
| `follow` | POST /v1/users/{username}/follow | `social_repository.dart:14 follow()` |
| `unfollow` | DELETE /v1/users/{username}/follow | `social_repository.dart:19 unfollow()` |
| `listFollowRequests` | GET /v1/follow-requests | `social_repository.dart:23 requests()` |
| `approveFollowRequest` | POST /v1/follow-requests/{id}/approve | `social_repository.dart:38 approve()` |
| `declineFollowRequest` | POST /v1/follow-requests/{id}/decline | `social_repository.dart:42 decline()` |
| `listCollections` | GET /v1/collections | `collection_repository.dart:14 list()` |
| `createCollection` | POST /v1/collections | `collection_repository.dart:22 create()` |
| `getCollection` | GET /v1/collections/{id} | `collection_repository.dart:37 detail()` |
| `renameCollection` | PATCH /v1/collections/{id} | `collection_repository.dart:27 rename()` |
| `deleteCollection` | DELETE /v1/collections/{id} | `collection_repository.dart:32 delete()` |
| `addCollectionEntry` | POST /v1/collections/{id}/entries | `collection_repository.dart:49 addEntry()` |
| `updateCollectionEntry` | PATCH /v1/collections/{id}/entries/{beverage_id} | — |
| `removeCollectionEntry` | DELETE /v1/collections/{id}/entries/{beverage_id} | `collection_repository.dart:60 removeEntry()` |
| `search` | GET /v1/search | `search_repository.dart:37 search()` |
| `getCategories` | GET /v1/categories | — (Flutter uses local `kCategoryStrings`) |
| `getFlavorTags` | GET /v1/flavor-tags | `checkin_repository.dart:43 tags()` |
| `submitBeverageRequest` | POST /v1/beverage-requests | — |

Total: 44 endpoints. Consumed: 33. Unused: 11 (all MINOR — see MIN-A). **Every Flutter repository call resolves to a real handler in `router.go`** (zero phantom calls).

### Response shape coherence spot-check

Each row: Go handler response struct ↔ Dart `fromJson` factory. Field-by-field match (case + nullability).

| Endpoint | Go struct | Dart factory | Verdict |
|---|---|---|---|
| `register` / `login` / `google` | `AuthResponse { user, access_token, token_type, expires_in }` (`types.go`, `handlers/auth.go`) | `auth.dart:18` matches keys; `tokenType` default `'Bearer'`, `expiresIn` `int` | OK |
| `getFeed` | `cursor.Page[FeedItem] { items, next_cursor, has_more }` | `page.dart:18` + `checkin.dart:108 FeedItem.fromJson` | OK |
| `getBeverage` | `BeverageDetail` (embedded `Beverage` flat + `aggregated_flavor` + `recent_check_ins`) | `beverage.dart:115 BeverageDetail.fromJson` reads `Beverage.fromJson(json)` (flat embed correct), then `aggregated_flavor`, `recent_check_ins` | OK |
| `createCheckin` | `domain.Checkin` | `checkin.dart:65 Checkin.fromJson` — all 13 wire fields present, nullables match | OK |
| `getUser` | `publicProfile { ...User, stats, follow_state, restricted }` | `user.dart:86 PublicProfile.fromJson` flattens `User.fromJson(json)` + `stats`, `follow_state`, `restricted` | OK |
| `listCollections` | `cursor.Page[Collection] { items, has_more: false }` | `collection_repository.dart:14 list() → Page.fromJson` | OK |
| `approveFollowRequest` | `domain.FollowResult { status }` | `social_repository.dart:38` returns Future<void> — discards body. Backend still returns 200 body per OpenAPI. Acceptable but the body is unused. | OK (minor: client throws away the body) |
| `getFlavorTags` | `[]domain.FlavorTag` | `checkin_repository.dart:43 tags()` returns `List<FlavorTag>` | OK |

---

## Stub inventory (consolidated punch list)

| Severity | File:line | Marker | Summary | Owner |
|---|---|---|---|---|
| MAJOR | `internal/handlers/auth.go:75,295,370` | TODO | Wire SMTP — currently logs verification link | `backend-engineer` |
| MAJOR | `internal/handlers/checkins.go:183` | CONFIGURE | Photo storage strategy (presigned URL or multipart) not implemented | `backend-engineer` |
| MAJOR | `internal/handlers/users.go:71-77` | (privacy hazard, not commented) | Public profile leaks target email — split into `PublicUser` | `backend-engineer` |
| MINOR | `internal/domain/types.go:271` | (drift) | `Brewery.BeverageCount` exists in Go but not OpenAPI; never populated | `backend-engineer` |
| MINOR | `internal/domain/types.go:265-294` etc. | (drift) | `omitempty` vs OpenAPI `nullable: true` — choose absent or null and apply consistently | `backend-engineer` |
| MINOR | `internal/repository/search.go:22-87` | (limitation) | Typeless `/v1/search` cursor is approximate past page 1; document or split endpoint | `backend-engineer` |
| MINOR | `internal/handlers/checkins.go:107-112` | (dead code) | `decodeJSON` strict-then-loose fallback no longer needed; ClearXxx fields exist | `backend-engineer` |
| MINOR | `internal/domain/types.go:660-666` | TODO(designer) | Localized default-collection names — ja/ko strings pending designer | `designer` then `backend-engineer` |
| MINOR | `internal/config/config.go:20,39` | (dead docs) | `GoogleClientSecret` loaded but never used; keep as documentation or remove | `backend-engineer` |
| MINOR | `internal/auth/jwt.go:98` | CONFIGURE | `GOOGLE_CLIENT_ID` env required for Google sign-in to work at runtime | deployment / ops |
| MINOR | `lib/app/router.dart:5` | (doc drift) | Comment lists `/auth/verify-email` route that isn't registered | `flutter-engineer` |
| MINOR | `lib/features/check_in/screens/check_in_screen.dart:14` | (incomplete wiring) | `image_picker` is imported and surfaces the picker UI, but no upload call exists in any repository — tied to backend M1 | `flutter-engineer` after M1 |
| MINOR | `lib/features/profile/screens/profile_screen.dart` | (unwired data) | Public profile screen shows stats but doesn't render the target user's check-ins via `profileRepository.userCheckins` | `flutter-engineer` |
| MINOR | `lib/l10n/intl_*.arb` (×14 keys ×3 locales) | (dead i18n) | See MIN-B for the list. Wire `errorUnauthorized`, `errorNetwork`, `collectionsBottleCount*`, `searchResultCount*`, etc., or prune | `flutter-engineer` |

No `// FIXME`, `// STUB`, or `// HACK` markers found in either layer.

---

## Build sanity

### Backend
```
$ cd _workspace/02_backend/api
$ go build ./...
(clean)
$ go vet ./...
(clean)
$ go test ./...
ok    github.com/kamos/api/internal/auth     (cached)
ok    github.com/kamos/api/internal/cursor   (cached)
ok    github.com/kamos/api/internal/domain   (cached)
?     [handlers, repository, server, middleware, config, apierror, cmd] no test files
```

### Frontend
```
$ cd _workspace/03_frontend
$ flutter analyze
No issues found! (1.5s)
$ flutter test
All tests passed! (18/18)
```

Tests covered: ARB key parity en/ja/ko (3 cases) + SPEC §6.5 fallback (5 cases) + SPEC §2.1 category strings byte-equal across 9 (slug × locale) pairs + the "no abbreviations slip in" guard.

No runtime DB tests were executed — QA operates on source. `backend-engineer` should still smoke-apply both migrations against a fresh PG instance before Phase 5 starts.

---

## Open questions / substitution flags (carried from `_workspace/01_design/HANDOFF.md`)

1. **Display font** — Shippori Mincho substitution awaits user confirmation. Flutter currently relies on system fonts via `theme.dart`; no font asset is bundled.
2. **Icon set** — Phosphor recommended; the kit ships inline SVG fallbacks. Flutter uses `Icons.*` Material icons, not Phosphor. Visual drift from the JSX kit; not blocking.
3. **Koh accent retention** — single-hue brand decision pending. Currently used only on the kanpai/toast button (`kanpai_button.dart`).
4. **Half-star glyph** — Flutter substitutes a custom-painted half-fill in `stars_input.dart:130-134` (no glyph dependency), resolving the open question.
5. **Localized default collection names** — designer still owes ja/ko strings for `Inventory` / `Wishlist`. Backend stub at `types.go:660-666` returns English for all locales until then.

---

## Routing of remaining work

| Owner | Items |
|---|---|
| `backend-engineer` | M1 (presigned URL endpoint), M2 (SMTP), M3 (PublicUser shape), MIN-D ×7 |
| `designer` | localized default-collection strings (MIN-D #6) |
| `flutter-engineer` | MIN-B (ARB dead keys), MIN-C (router doc), photo-upload wiring after backend M1, public-profile check-ins (MIN-A `userCheckins`) |
| ops / deployment (Phase 5) | `GOOGLE_CLIENT_ID` env, `GOOGLE_CLIENT_SECRET` env, SMTP config, `KAMOS_API_BASE_URL` dart-define |

None block the Phase 4 gate. Recommend proceeding to Phase 5 (DEPLOYMENT.md, docker-compose.yml, Makefile) and folding M1/M2/M3 into pre-public-beta hardening.
