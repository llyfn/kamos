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
cd _workspace/03_frontend
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

All three Sentry flags are optional in dev — the app runs identically with or without them.

Google Sign-In is wired through `/v1/auth/google`. The Flutter app only transmits the Google ID token; the client secret stays server-side (SPEC §3.1 / brief §6.10). To enable the button you must:

1. Add `google_sign_in` to `pubspec.yaml`.
2. Drop `google-services.json` into `android/app/` and `GoogleService-Info.plist` into `ios/Runner/`.
3. Wire the `onGoogleHandoff` callback in `auth_screen.dart` to `GoogleSignIn.signIn` and pass the resulting `id_token` to `authRepositoryProvider.google(idToken: ...)`.

For MVP/test runs the button is stubbed; tap to see a snackbar pointing at this README.

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
flutter test                                   # 18+ tests; category/ARB parity + i18n fallback
grep -rn 'SharedPreferences' lib/ | grep -i token   # must be empty (SPEC §6.9 — JWT is in flutter_secure_storage)
```

## Project structure

Feature-first layout under `lib/features/`. Shared widgets in `lib/shared/widgets/`. Core API + storage + i18n in `lib/core/`. The router is `lib/app/router.dart`; theme tokens are `lib/app/theme.dart` (mirroring `_workspace/01_design/colors_and_type.css`).

## Design substitutions (per `_workspace/01_design/HANDOFF.md`)

- **Display font** — Shippori Mincho is the design recommendation. The app declares `fontFamily: 'ShipporiMincho'` but does not bundle the typeface; the OS falls back through Hiragino → Yu Mincho → Songti SC → Noto Serif JP. Drop the TTF files into `assets/fonts/` and register them in `pubspec.yaml` to lock the look.
- **Icon set** — design recommended Phosphor; the Flutter app uses Material Symbols (`Icons.*`) until product confirms. Switch to `phosphor_flutter` by importing the package and replacing icon glyphs site-by-site.
- **Half-star glyph** — the `U+2BE8` codepoint renders inconsistently across platforms. KAMOS uses a custom `CustomPainter` in `lib/shared/widgets/stars_display.dart` and `stars_input.dart` instead.

## SPEC invariants the code enforces

- **Category strings** — `lib/core/i18n/category_labels.dart` hardcodes the SPEC §2.1 strings character-for-character; `test/category_strings_test.dart` enforces parity.
- **Rating** — 0.5–5.0 in 0.5 steps. `lib/shared/widgets/stars_input.dart` produces nullable `double?` values; null is a valid rating ("I tried this").
- **Review ≤ 500 chars** — `TextField.maxLength: 500` with `MaxLengthEnforcement.enforced` in the check-in screen.
- **Photos ≤ 4** — UI cap in `lib/features/check_in/screens/check_in_screen.dart`; server is the backstop.
- **Cursor pagination** — every list provider holds `(items, nextCursor, hasMore)` and never sends an offset. Page size 20 on the feed.
- **JWT storage** — `flutter_secure_storage` only, via `lib/core/storage/secure_storage.dart`. No `SharedPreferences` token usage anywhere in the tree (see verification command above).
- **i18n fallback** — `lib/core/i18n/beverage_name.dart` falls back to `en` for missing `ja` / `ko` beverage names per SPEC §6.5.
- **No emoji in UI** — the toast button uses the brand kanpai mark (`assets/images/logo_white.png` overlay).
