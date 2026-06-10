# KAMOS — Flutter App

A Japanese alcoholic beverage discovery and tracking app — iOS + Android, Flutter stable.

## Stack

| Layer | Choice |
|---|---|
| Routing | `go_router` |
| State | `flutter_riverpod` |
| HTTP | `dio` with auth interceptor |
| Secure storage | `flutter_secure_storage` (JWT only) |
| Models | `freezed` (no JSON codegen — hand-rolled `fromJson` to keep parsing defensive) |
| i18n | ARB (`flutter_localizations` + generated `AppLocalizations`) |
| Icons | Material Symbols (Phosphor substitution noted in design HANDOFF; pending product call) |

Min platforms: iOS 13+, Android API 26+ (set in `ios/Runner/Info.plist` and `android/app/build.gradle.kts`).

## Setup

```bash
cd frontend
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # freezed
flutter gen-l10n                                            # ARB → AppLocalizations
```

## Run

```bash
# Local backend at http://localhost:8080 is the default.
flutter run --dart-define=KAMOS_API_BASE_URL=http://localhost:8080

# Against a deployed staging server:
flutter run --dart-define=KAMOS_API_BASE_URL=https://api.staging.kamos.example
```

### Optional dart-defines

| Flag | Default | Notes |
|---|---|---|
| `KAMOS_API_BASE_URL` | `http://localhost:8080` | Where the Dio client points. |
| `KAMOS_SENTRY_DSN` | _(empty)_ | Empty disables Sentry entirely; no SDK init, no network calls. |
| `KAMOS_ENV` | `dev` | Sentry `environment` tag. Use `staging` / `production` when deployed. |
| `KAMOS_VERSION` | `dev` | Sentry `release` tag. CI should pass the build version. |
| `KAMOS_GOOGLE_SIGN_IN_ENABLED` | `false` | When `true`, the Google button drives the platform SDK. Off by default so dev runs and `flutter test` need no native config. |
| `KAMOS_GOOGLE_CLIENT_ID` | _(empty)_ | Optional server/web OAuth client ID. Used as `serverClientId` for Android; ignored on iOS (which reads `GoogleService-Info.plist`). |

All Sentry flags are optional in dev — the app runs identically with or without them.

## Google sign-in setup

The Google button is gated behind `--dart-define=KAMOS_GOOGLE_SIGN_IN_ENABLED=true`. When the flag is absent the button renders disabled with a "Google sign-in not configured" tooltip — this is the default for new clones until Google Cloud Console setup is complete (cookbook §C1 in the post-MVP roadmap).

The backend exchange is `POST /v1/auth/google` with `{ id_token }`. The Flutter app only ever transmits the Google-issued ID token; the OAuth client secret stays server-side (SPEC §3.1 / brief §6.10).

To enable:

1. **Cloud Console** — finish setup of OAuth client IDs for iOS, Android, and the backend ("Web application" type for the server verifier).
2. **iOS** — drop `GoogleService-Info.plist` into `ios/Runner/`. Add the reversed-client-ID URL scheme to `ios/Runner/Info.plist` under `CFBundleURLTypes`. See the [google_sign_in iOS guide](https://pub.dev/packages/google_sign_in_ios#integration).
3. **Android** — reference the OAuth client ID in `android/app/build.gradle.kts` per the [google_sign_in_android guide](https://pub.dev/packages/google_sign_in_android#integration). `google-services.json` is NOT required for the ID-token flow.
4. **Run** with the dart-define:

   ```bash
   flutter run \
     --dart-define=KAMOS_API_BASE_URL=https://api.staging.kamos.example \
     --dart-define=KAMOS_GOOGLE_SIGN_IN_ENABLED=true \
     --dart-define=KAMOS_GOOGLE_CLIENT_ID=YOUR-SERVER-CLIENT-ID.apps.googleusercontent.com
   ```

Until step 1–3 are complete, leaving the dart-define off (the default) keeps the button visibly disabled and never touches the SDK.

## Build

```bash
# iOS (TestFlight build, requires a configured signing identity):
flutter build ipa --release --dart-define=KAMOS_API_BASE_URL=https://api.kamos.example

# Android (Play Store internal track):
flutter build appbundle --release --dart-define=KAMOS_API_BASE_URL=https://api.kamos.example
```

## Verification commands

```bash
flutter analyze                                # should pass clean
flutter test                                   # 23+ tests; ARB parity, category strings, refresh interceptor
grep -rn 'SharedPreferences' lib/ | grep -i token   # must be empty (SPEC §6.9 — JWT is in flutter_secure_storage)
```

## Project structure

Feature-first layout under `lib/features/`. Shared widgets in `lib/shared/widgets/`. Core API + storage + i18n in `lib/core/`. The router is `lib/app/router.dart`; theme tokens are `lib/app/theme.dart` (mirroring `design/colors_and_type.css`).

## Design substitutions (per `design/HANDOFF.md`)

- **Display font** — Shippori Mincho is the design recommendation. The app declares `fontFamily: 'ShipporiMincho'` but does not bundle the typeface; the OS falls back through Hiragino → Yu Mincho → Songti SC → Noto Serif JP. Drop the TTF files into `assets/fonts/` and register them in `pubspec.yaml` to lock the look.
- **Icon set** — design recommended Phosphor; the Flutter app uses Material Symbols (`Icons.*`) until product confirms. Switch to `phosphor_flutter` by importing the package and replacing icon glyphs site-by-site.
- **Half-star glyph** — the `U+2BE8` codepoint renders inconsistently across platforms. KAMOS uses a custom `CustomPainter` in `lib/shared/widgets/stars_display.dart` and `stars_input.dart` instead.

## Photos

Check-in photos use a 3-step presigned upload (`lib/features/check_in/repository/checkin_repository.dart#uploadPhotoAndAttach`):

1. `POST /v1/uploads/photo-presign` — authed; returns `upload_id`, signed `upload_url`, and `headers` to apply on the PUT.
2. `PUT <upload_url>` — through a separate Dio with **no** interceptors (the presigned URL signs the request itself; an `Authorization` header would invalidate the signature).
3. `POST /v1/check-ins/{id}/photos { upload_id }` — authed; returns the `PhotoRef` (`id`, `url`) attached to the check-in.

Uploads run **sequentially** per check-in (one PUT in flight at a time) — friendlier to the rate limiter and avoids same-`blob_key` races. Per-photo progress + retry are tracked in `_photoStates` on the check-in screen.

**Backend must have R2 configured** (cookbook §C2 in the post-MVP roadmap) for uploads to succeed. When it is not, the presign endpoint returns `503 { code: STORAGE_DISABLED }`; the Flutter app surfaces this as a `StorageDisabledException`, drops the photos, completes the check-in without them, and shows the `photoUploadDisabled` SnackBar.

**Photo cap of 4** is enforced both client-side (UI cap in `lib/features/check_in/screens/check_in_screen.dart`, `checkInPhotoLimitReached` ARB key) and server-side. A failed PUT is recoverable per-tile via the `actionRetry` button overlay; the check-in itself is already saved before any upload begins.

## Venues (Phase 4)

Check-ins may optionally attach a venue (bar / restaurant / shop). Two paths:

1. **Picker → Foursquare-backed attach.** The check-in screen exposes a "Where?" row that opens the bottom-sheet picker (`lib/features/venues/widgets/venue_picker_sheet.dart`). The sheet talks to `GET /v1/venues/search` via `VenueRepository`, which proxies Foursquare Places server-side. Tapping a result attaches it to the check-in by `foursquare_id`; the backend upserts the row on `POST /v1/check-ins`.
2. **Already-known venue.** When the client already has a `venue.id` (e.g., picked from a recent-venues list), it can post `venue: { id }` directly without going through Foursquare.

**Search requires `FOURSQUARE_API_KEY` on the backend** (cookbook §C5). When unset, `GET /v1/venues/search` returns `503 { code: VENUE_SEARCH_DISABLED }`; the picker surfaces `venuePickerDisabled` and offers a Close button. **Check-in venue attachment works without the API key** — the upsert path is DB-only, so the user can still pick a place from a saved venue list, or omit a venue entirely.

Upstream 429s from Foursquare bubble out as `503 { code: VENUE_RATE_LIMITED }`; the picker shows `venuePickerRateLimited` and lets the user retry.

## SPEC invariants the code enforces

- **Category strings** — `lib/core/i18n/category_labels.dart` hardcodes the SPEC §2.1 strings character-for-character; `test/category_strings_test.dart` enforces parity.
- **Rating** — 0.25–5.0 in 0.25 steps (20 levels). Compose uses the custom `lib/features/check_in/widgets/rating_slider.dart` (continuous drag, snaps to 0.25); read surfaces render `lib/shared/widgets/stars_display.dart` (continuous fractional fill). Both produce nullable `double?` values; null is a valid rating ("I tried this").
- **Review ≤ 500 chars** — `TextField.maxLength: 500` with `MaxLengthEnforcement.enforced` in the check-in screen.
- **Photos ≤ 1 on submission** — UI cap in `lib/features/check_in/screens/check_in_screen.dart`; server is the backstop. Existing multi-photo rows remain readable end-to-end.
- **Cursor pagination** — every list provider holds `(items, nextCursor, hasMore)` and never sends an offset. Page size 20 on the feed.
- **JWT storage** — both the access token and the rotating refresh token live in `flutter_secure_storage` only, via `lib/core/storage/secure_storage.dart`. No `SharedPreferences` token usage anywhere in the tree (see verification command above). The Dio interceptor (`lib/core/api/auth_interceptor.dart`) auto-exchanges the refresh token on 401 with single-flight semantics.
- **i18n fallback** — `lib/core/i18n/beverage_name.dart` falls back to `en` for missing `ja` / `ko` beverage names per SPEC §6.5.
- **No emoji in UI** — the toast button uses the brand kanpai mark (`assets/images/logo_white.png` overlay).
