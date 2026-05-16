# QA Report — Phase 5 Final Integration

Date: 2026-05-16
Scope: Phase 5 (Admin web client + RBAC + user-submitted beverage moderation) end-to-end.
Verdict: **PASS WITH MINOR**

- BLOCKER: 0
- MAJOR: 0 (the per-layer SEC-006 MAJOR is fixed in `208f106` and double-locked by tests)
- MINOR: 4 (3 carry-overs + 1 new admin-client UX gap)
- Live smoke: 12/12 PASS end-to-end against `kamos_local`

---

## Commit range under review

- `bf9d38b` migration 007 (users.role enum + idx_users_deleted_at_recent)
- `6831dd0` SoftDeleteCache + Auth middleware integration (SEC-006 access-token side)
- `256c4c0` RBAC middleware (RequireRole)
- `ceedf8b` Flutter beverage-request submit form
- `9bf6ced` /v1/admin/* endpoints
- `3d14c68` /v1/users/me exposes role + deleted_at
- `5284c86` Phase 5a backend smoke + report
- `67ca219` admin client scaffold
- `1bccd34` admin client OpenAPI codegen + typed fetch
- `ad6f3b4` admin beverage-requests queue
- `75f4f3e` admin user management + check-in moderation
- `208f106` SEC-006 MAJOR fix (revoke refresh tokens on suspend + self-delete)

## Lens 1 — Backend ↔ Flutter integration

| Check | Result |
|---|---|
| Flutter `BeverageRequest.toJson` → server `{payload: {...}}` shape | PASS (smoke #7 returned `{"id":"e53895c9-…"}`; admin-side payload listing #8 showed the four flat fields wrapped exactly as encoded) |
| `/v1/users/me` returns `role` + `deleted_at`, Flutter `Me.fromJson` ignores unknowns | PASS (smoke #4: `role: "admin"`, `deleted_at: null`; `lib/core/models/user.dart:69-74` only reads known keys) |
| ARB parity en/ja/ko | PASS — 184/184/184; zero asymmetry. 11 new keys × 3 locales. |
| SPEC category strings | PASS (smoke #10: `category.label_i18n = {"en":"Nihonshu (Sake)","ja":"日本酒","ko":"니혼슈 (사케)"}`) |

## Lens 2 — Backend ↔ Admin web client

| Check | Result |
|---|---|
| `src/types/api.d.ts` covers all 7 admin paths | PASS (paths at `api.d.ts:769-893`) |
| Admin schemas typed (`UserRole`, `AdminBeverageRequest`, `AdminBeverageRequestApproval`, `AdminUser`, `AdminUserRoleUpdate`) | PASS — all 5 present; `UserRole = "user" \| "moderator" \| "admin"` matches Go `domain.UserRole` |
| `useAuth().isAdmin` / `.isModerator` derived from `me.role` | PASS (`auth.ts:26-27`) |
| Token storage: localStorage only (no sessionStorage/cookies) | PASS (`tokens.ts:7-25`); web platform on HTTPS — SPEC §6.9 secure-storage requirement applies only to Flutter |
| 401 retry → `/v1/auth/refresh` attaches refresh in body + single-flight | PASS (`api.ts:30-62`) |
| Admin client build | PASS (`tsc --noEmit` clean; `vite build` → 354 kB JS / 11 kB CSS) |
| Admin tests | PASS — 5/5 |

## Lens 3 — Schema invariants

Migration 007 verified on both `kamos_local` and `kamos_test`:
- `users.role user_role NOT NULL DEFAULT 'user'` — present
- `user_role` enum = `{user, moderator, admin}` (ordered)
- Partial index `idx_users_deleted_at_recent` — present
- Existing rows backfilled to `role='user'`
- 001-006 unchanged; 007 is purely additive

## Lens 4 — SPEC invariants — 12/12 PASS

| # | Invariant | Status |
|---|---|---|
| 1 | Category strings (SPEC §2.1) | PASS |
| 2 | Rating scale 0.5–5.0 NUMERIC(3,1) | PASS (untouched) |
| 3 | Username case-insensitive lowercase | PASS (untouched) |
| 4 | Soft-delete account + 30-day username hold | PASS (`Admin.SuspendUser` writes same `deleted_at + username_release_at` pair as `DeleteMe`) |
| 5 | Soft-delete check-ins via `deleted_at TIMESTAMPTZ` | PASS (`AdminModerateCheckin` writes the column) |
| 6 | i18n fallback `ko → en`, `ja → en` | PASS (untouched) |
| 7 | Cursor pagination shape `{items, next_cursor, has_more}` | PASS (admin list endpoints use `cursor.SliceAndCursor`) |
| 8 | Feed page size 20 | PASS (untouched) |
| 9 | Check-in caps: review ≤ 500, ≤ 4 photos | PASS (untouched) |
| 10 | Default collections Inventory + Wishlist | PASS (untouched) |
| 11 | JWT in `flutter_secure_storage` only on Flutter | PASS (Flutter untouched; admin is a separate web platform) |
| 12 | Error response shape `{error, code}` | PASS (smoke #5: `ROLE_REQUIRED`; #11b: `ACCOUNT_DELETED`; #12: `TOKEN_INVALID`) |

## Lens 5 — Live smoke (12/12 PASS against `kamos_local:8080`)

| # | Step | Result |
|---|---|---|
| 1-2 | Register alice + bob | PASS |
| 3 | `UPDATE users SET role='admin' WHERE username='alice'` | PASS — `UPDATE 1` |
| 4 | alice `GET /v1/users/me` → `role: "admin"`, `deleted_at: null` | PASS |
| 5 | bob `GET /v1/admin/users` → `403 ROLE_REQUIRED` | PASS |
| 6 | alice `GET /v1/admin/users?role=user` → 200 + bob in items | PASS |
| 7 | bob `POST /v1/beverage-requests` `{payload:{...4 fields...}}` → 202 + id | PASS |
| 8 | alice `GET /v1/admin/beverage-requests?status=pending` → item with bob's username and the 4-field payload | PASS |
| 9 | alice `POST /v1/admin/beverage-requests/{id}/approve` → 200 + `{beverage_id, request_id}` | PASS |
| 10 | `GET /v1/beverages` → new beverage with SPEC category strings | PASS |
| 11a | alice `POST /v1/admin/users/{bob}/suspend` → 204 | PASS |
| 11b | bob's previous access token → 401 ACCOUNT_DELETED (sub-second after suspension; well within 30d TTL → revocation is genuinely from cache, not expiry) | PASS |
| 12 | bob's refresh token → 401 TOKEN_INVALID | PASS |
| 12b | DB check on `refresh_tokens` for bob: `total=1, revoked=1` → SEC-006 fix verified end-to-end | PASS |

## Test counts (re-verified, not trusted)

| Suite | Phase 4 baseline | Phase 5a per-layer | Phase 5 final | Δ vs Phase 4 |
|---|---|---|---|---|
| Backend unit | 116 | 121 | **121** | +5 |
| Backend integration | 57 | 69 | **71** | +14 |
| Flutter | 35 | 45 | **45** | +10 |
| Admin client (Vitest) | n/a | 5 | **5** | +5 |
| **Total** | 208 | 240 | **242** | **+34** |

`go build ./...` clean. `flutter analyze` clean. `tsc --noEmit` clean. `vite build` clean.

## Outstanding minors

1. **`SubmitBeverageRequestNotifier.reset()` dead** (Flutter QA carry-over). Owner: `flutter-engineer`. Defer.
2. **Settings menu reuses `submitBeverageRequestTitle` for both menu label and screen title** (Flutter QA carry-over). Owner: `flutter-engineer`. Defer.
3. **Search empty-state CTA shows on cold-start when feed has zero beverages** (Flutter QA carry-over). Owner: `flutter-engineer`. Defer.
4. **Admin client `RoleGuard` defined but never wired** (NEW). `_workspace/05_admin/src/components/guard.tsx` exports `RoleGuard`, but no route uses it. Server enforces RBAC (smoke #5 + `TestAdmin_RoleGate` confirm) — this is a UX gap, not a security gap: `role=user` deep-link to `/queue` sees "Failed to load queue" instead of "Insufficient privileges". 5-minute fix; defer to next admin-client touch.

Also documented but non-actionable:
- `/v1/users/me` returns `role + deleted_at` for soft-deleted users in the narrow race window before `SoftDeleteCache` refresh — acceptable (documented in OpenAPI description).
- Approve vs Reject response shape inconsistency — cosmetic.
- `include_deleted` enum strings `"0"/"1"` — cosmetic.

## What's owed by the user (cookbook §C6)

**Cloudflare Pages — admin hosting**. Admin client builds and runs locally; production deployment requires:
1. Cloudflare account (same as R2) → Pages → create project
2. Connect GitHub repo, build command `npm run build`, output `_workspace/05_admin/dist/`
3. Env vars: `VITE_API_BASE_URL`, `VITE_SENTRY_DSN` (Sentry not yet wired; small follow-on)

**Sentry for the admin client is NOT wired in this phase.** Observability parity with Phase 1 backend + Flutter is incomplete. Not a Phase 5 blocker.

---

**Net: Phase 5 is ship-ready.**
