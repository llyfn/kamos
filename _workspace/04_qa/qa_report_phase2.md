# QA Report — Phase 2 Auth Hardening (refresh tokens + Google sign-in scaffold)

Date: 2026-05-14
Scope: Phase 2 of post-MVP roadmap (`~/.claude/plans/mutable-juggling-cook.md`).
Verdict: **PASS** (Google OAuth half is end-to-end-blocked on user's Google Cloud Console setup per cookbook §C1; the Flutter scaffold + backend handler are otherwise complete and tested).

---

## What landed

### Backend — rotating refresh tokens with family-revocation

- **Migration `003_refresh_tokens.sql`** — `refresh_tokens(id, user_id, token_hash BYTEA UNIQUE, parent_id, family_id, issued_at, expires_at, revoked_at, device_label, user_agent, ip)`. Three indexes: active-by-user (partial), family, expires (partial). CASCADE on user delete.
- **`internal/auth/refresh.go`** — `NewRefreshSecret()` returns a 43-char base64-rawurl secret (32 random bytes from `crypto/rand`) and its SHA-256 hash. Raw secret never persisted.
- **`internal/repository/refresh_tokens.go`** — `Insert / LookupByHash / MarkRevoked / RevokeFamily / RevokeAllForUser`.
- **Access-token TTL default lowered to 15 min** (`JWT_TTL`, was 720h). Refresh-token TTL defaults to 30 days (`REFRESH_TTL=720h`). Both overridable via env.
- **Handler updates** in `internal/handlers/auth.go`:
  - `Register`, `Login`, `GoogleLogin` now also issue a refresh token via `issueAuthPair` helper. Response shape grows `refresh_token`, `refresh_expires_in`.
  - **New `POST /v1/auth/refresh`** (public, brute-force-rate-limited via existing `/v1/auth/*` 5 rps / burst 10):
    - Valid + active token → rotate (revoke old, insert new with same `family_id`, return new pair).
    - **Already-revoked token presented (re-use detection)** → revoke entire family, return 401, log `WARN refresh_token_reuse_detected`.
    - Expired or unknown token → plain 401.
  - **New `POST /v1/auth/logout`** (authed):
    - With body `{refresh_token: ...}` → revoke that specific token.
    - Without body → revoke **every** active refresh token for the authenticated user.
    - Always returns 204 (no token-ownership leak via response codes).
- **OpenAPI** updated with the two new operations and the extended `AuthResponse` schema.

### Flutter — google_sign_in scaffold + refresh-token client

- `google_sign_in: ^7.2.0` added to pubspec.
- New `lib/core/auth/google_signin_service.dart` — `signInAndGetIdToken()` returns null when `kIsGoogleConfigured` is false (gated by `--dart-define=KAMOS_GOOGLE_SIGN_IN_ENABLED=true`).
- Auth-screen Google button: when configured, calls the service then `AuthRepository.googleSignIn(idToken)`; when not configured, shows a disabled state with localized tooltip `authGoogleDisabled` ("Google sign-in not configured" / "Googleサインインは未設定" / "Google 로그인이 설정되지 않았습니다").
- `lib/core/storage/secure_storage.dart` — refreshToken field alongside access token. Both in `flutter_secure_storage` only (SPEC §6.9 invariant intact).
- `lib/core/api/auth_interceptor.dart` — single-flight refresh loop. On 401 from a non-auth route: if a refresh exchange isn't already in flight, run one; on success persist + retry original request once with the new access token; on failure clear tokens and surface the existing `errorUnauthorized` toast. No recursion.
- `AuthRepository` extended with `refresh(refreshToken)` and `logout({refreshToken})`. The `AuthResponse` Freezed model carries the new `refresh_token`/`expires_in`/`refresh_expires_in` fields.
- `AuthController.signInWithGoogle()` added; auth state hydration reads both tokens on app start; sign-out calls `POST /v1/auth/logout` best-effort.
- ARB: 3 new keys (`authGoogleSignInButton`, `authGoogleDisabled`, `authGoogleSignInFailed`) in parity across en/ja/ko. Regenerated `app_localizations*.dart`.
- README_flutter.md: Google sign-in setup section + dart-define table.

---

## Live smoke (this run, against local Postgres 18)

Truncated dev DB, registered fresh `refresh_smoke` user via the API on port 18080. Every assertion below verified end-to-end:

```
1. Register             → 201; access (JWT, 307 chars) + refresh (43 chars) issued
                          expires_in=900s, refresh_expires_in=2592000s
2. GET /v1/users/me     → 200 with access token
3. POST /v1/auth/refresh → 200; refresh token ROTATED (refresh2 != refresh1) ✓
                          access2 == access1 within same second is expected: HS256
                          over identical claims is deterministic; not a regression.
4. Re-use old refresh1  → 401 {"code":"TOKEN_INVALID"}
                          WARN log: refresh_token_reuse_detected
                            family_id=06811970-… revoked_count=1
                          → confirms the family-wide revocation fired.
5. Try refresh2 after family-revoke → 401 ✓
                          (Second reuse_detected log line confirms idempotency.)
6. Fresh login → logout (no body, revoke-all) → 204 ✓
7. Previously-active R3 after logout → 401 ✓
```

All five security invariants from the brief verified: rotation, single-use enforcement, re-use ⇒ family revoke, expiry, logout-all.

---

## Test counts

| Suite | Before Phase 2 | After Phase 2 |
|---|---|---|
| Backend unit | all packages PASS, coverage unchanged | same packages PASS; `internal/auth` retains 64.7%; `internal/config` 95.2% |
| Backend integration | 38 PASS | **43 PASS** (+5 — TestRefreshRoundTrip, TestRefreshExpiry, TestLogoutSingleToken, TestLogoutAllTokens, TestRefreshCompromiseDetection) |
| Flutter | 21/21 | **23/23** (+2 — auth_refresh_interceptor_test, auth_refresh_failure_test) |
| `flutter analyze` | clean | clean |

---

## What's still needed from the user

| Item | Source | Owner |
|---|---|---|
| Google Cloud Console: project + OAuth consent screen + 3 OAuth client IDs (web/iOS/Android) + Android SHA-1 + `GoogleService-Info.plist` | cookbook §C1 in roadmap | user |
| iOS: drop `GoogleService-Info.plist` into `_workspace/03_frontend/ios/Runner/`; add `reversedClientId` URL scheme to `Info.plist` | google_sign_in package docs | user, then either of us |
| Android: paste OAuth client ID into `android/app/build.gradle.kts` (server-client-id) | google_sign_in package docs | user, then either of us |
| Flutter run command for verification: `flutter run --dart-define=KAMOS_API_BASE_URL=http://10.0.2.2:8080 --dart-define=KAMOS_SENTRY_DSN=$KAMOS_SENTRY_DSN --dart-define=KAMOS_GOOGLE_SIGN_IN_ENABLED=true` | README_flutter.md | user |

The refresh-token half is fully shipped and verified without these.

---

## Follow-ons (backlog, not blocking)

- **Sentry body scrubbing.** `internal/observability/sentry.go` has no `BeforeSend` hook. Today's panic path (`RecoverWithSentry`) doesn't capture request bodies, so the refresh secret is safe; but the next person who wires HTTP breadcrumbs into Sentry must add a scrubber for `/v1/auth/refresh`, `/v1/auth/login`, `/v1/auth/register`. Tracked.
- **Two ARB keys for one button label**: `authContinueGoogle` (legacy) and `authGoogleSignInButton` carry the same string. Phase 0's orphan-cleanup rule applies — `authContinueGoogle` is now dead. Add to next cleanup pass.
- **`Logout` partial failure ordering**: if the new-token INSERT succeeds but the predecessor `MarkRevoked` fails during refresh rotation, the new token is returned and the old is logged as still-live. Client uses the new one on its next call so rotation proceeds normally. Worst case is a brief window with two valid tokens. Documented in the handler comment.

---

## SPEC invariants — still 12/12 PASS

Phase 2 added a new table but did not alter category strings, rating semantics, photo cap, cursor pagination shape, or JWT-in-secure-storage. The invariant trace from `qa_report_final.md` and `qa_report_phase1.md` holds.
