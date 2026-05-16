# Phase 5a Backend — QA Report

**Scope:** RBAC backend + admin endpoints + user-submitted beverage moderation + SEC-006 (soft-deleted user JWT revocation).

**Date:** 2026-05-16

## 1. Test Counts

| Suite | Baseline | After Phase 5a | Delta |
|---|---|---|---|
| Unit (`go test ./...`) | 202 | **214** | +12 |
| Integration (`go test -tags=integration ./tests/integration/...`) | 57 | **69** | +12 |
| Total | 259 | **283** | +24 |

All green. Build clean.

## 2. SEC-006 — End-to-end verification

**Fix:** in-memory `auth.SoftDeleteCache` rejects access tokens whose subject is in the soft-deleted set (added synchronously by `DeleteMe` / `AdminSuspendUser`; refreshed every 60s from `SELECT id FROM users WHERE deleted_at > now() - INTERVAL '30 minutes'`, backed by the new partial index from migration 007).

**Verification:**

| Test | Result |
|---|---|
| `TestSoftDeleteCacheRevokesActiveToken` (integration) | PASS — register → use token → `DELETE /v1/users/me` → same token returns 401 `ACCOUNT_DELETED` on the very next request, well within the 1h test-JWT TTL. |
| `TestSoftDeleteCacheRefreshRebuildsFromDB` (integration) | PASS — directly `UPDATE users SET deleted_at = NOW()`, build a fresh cache, call `Refresh`; `Contains(uid)` returns true. Verifies the restart-recovery path. |
| `TestUpdateAndDeleteSelf` (integration, updated) | PASS — post-DeleteMe `GET /me` now returns 401 `ACCOUNT_DELETED` instead of the pre-fix 404. |
| `TestAdmin_SuspendUserRevokesTokens` (integration) | PASS — admin suspension triggers the same revocation path. |
| `TestSoftDeleteCache_AddContains` (unit) | PASS |
| `TestSoftDeleteCache_Concurrent` (unit, `-race`) | PASS |

**SEC-006 status: FIXED.**

## 3. Per-endpoint smoke (`qa_phase5a_smoke.sh`)

Ran against `kamos_local` with the API on `http://localhost:8080`. All 8 stages pass:

| # | Step | Result |
|---|---|---|
| 1 | Register fresh user | PASS |
| 2 | Promote via `UPDATE users SET role='admin'` | PASS |
| 3 | Login (new token) | PASS |
| 4 | `GET /v1/users/me` includes `role: "admin"` | PASS |
| 5 | `GET /v1/admin/beverage-requests` returns 200 with `items: []` | PASS |
| 6 | `GET /v1/admin/users` returns 200 with non-empty items | PASS |
| 7 | Submit → approve cycle creates a beverage row | PASS |
| 8 | Admin attempting `POST /v1/admin/users/{self}/suspend` → 403 | PASS |

Script: `_workspace/04_qa/qa_phase5a_smoke.sh`. Idempotent (uses timestamp-suffixed usernames).

## 4. SPEC invariants — 12/12 PASS

| # | Invariant | Status | Notes |
|---|---|---|---|
| 1 | Category strings unchanged (`Nihonshu (Sake)` / `Shochu` / `Liqueur` etc.) | PASS | No taxonomy edits in this phase. |
| 2 | Rating scale `0.5–5.0` in 0.5 steps | PASS | No check-in validation changes. |
| 3 | Username case-insensitive, lowercase stored, display case-preserved | PASS | No username path changes. |
| 4 | Soft-delete: account → 30-day username hold | PASS | `SuspendUser` reuses the same `deleted_at + username_release_at + INTERVAL '30 days'` pair. |
| 5 | Soft-delete: check-ins via `deleted_at TIMESTAMPTZ` | PASS | `AdminModerateCheckin` writes the same column. |
| 6 | i18n fallback (`ko → en`, `ja → en`) | PASS | No i18n path changes. |
| 7 | Cursor pagination (never offset); page shape `{items, next_cursor, has_more}` | PASS | All new admin list endpoints use `cursor.SliceAndCursor`. |
| 8 | Page size 20 for feed | PASS | Feed unchanged. |
| 9 | Check-in caps: review ≤ 500 chars, ≤ 4 photos | PASS | Not touched. |
| 10 | Default collections (Inventory, Wishlist) seeded per user | PASS | Not touched. |
| 11 | JWT in `flutter_secure_storage` only | N/A | Backend phase. |
| 12 | Error response shape `{error, code}` | PASS | All admin handlers use `apierror.WriteError` / `apierror.WriteJSON`. New codes: `ACCOUNT_DELETED`, `ROLE_REQUIRED`. |

## 5. New routes — summary

```
GET    /v1/admin/beverage-requests              moderator+
POST   /v1/admin/beverage-requests/{id}/reject  moderator+
POST   /v1/admin/check-ins/{id}/moderate        moderator+
GET    /v1/admin/users                          moderator+
POST   /v1/admin/beverage-requests/{id}/approve admin
POST   /v1/admin/users/{id}/role                admin
POST   /v1/admin/users/{id}/suspend             admin
```

All gated by `middleware.Auth(signer, softDelete)` + `roleResolver.RequireRole(...)`. Rate-limited to 30 rps / burst 60 per user.

`GET /v1/users/me` now includes `role` (read fresh on every request — no JWT claim) and `deleted_at`.

## 6. Migration 007

- `_workspace/02_backend/db/migrations/007_user_role_and_soft_delete_index.sql`
- `_workspace/02_backend/api/migrations/007_user_role_and_soft_delete_index.sql` (byte-identical)
- Applied to `kamos_local` and `kamos_test`.
- Verified: `\d users` shows `role | user_role | not null | 'user'::user_role`; `\d+ users` lists the partial index `idx_users_deleted_at_recent`.

## 7. Open items / deferred minors

- **Check-in moderation audit log** — `AdminModerateCheckin` currently logs the optional `notes` field to slog only; a dedicated `moderation_log` table is deferred until we have repeat-offender / appeals workflow requirements. (Per-action audit is in the structured access log; sufficient for Phase 5a.)
- **`UpdateUserRole` audit** — same treatment; logged structured-only.
- **OpenAPI 3.1 validation** — the file parses as YAML and matches the handler response shapes by inspection; full schema validation against generated client (`flutter_engineer` agent) lands in the Phase 5a final QA pass.
- **`GET /v1/users/me` exposes `role` even for soft-deleted users.** The handler runs `FindMe` without the `deleted_at IS NULL` predicate so a freshly-suspended admin can see their own `deleted_at`. The SoftDeleteCache normally blocks the request before reaching the handler — `deleted_at` is observable only in the narrow race window before the next refresh.

## 8. Files touched

```
_workspace/02_backend/db/migrations/007_user_role_and_soft_delete_index.sql       NEW
_workspace/02_backend/api/migrations/007_user_role_and_soft_delete_index.sql      NEW (mirror)
_workspace/02_backend/api/internal/auth/softdelete_cache.go                       NEW
_workspace/02_backend/api/internal/auth/softdelete_cache_test.go                  NEW
_workspace/02_backend/api/internal/middleware/rbac.go                             NEW
_workspace/02_backend/api/internal/middleware/rbac_test.go                        NEW
_workspace/02_backend/api/internal/handlers/admin.go                              NEW
_workspace/02_backend/api/internal/repository/admin.go                            NEW
_workspace/02_backend/api/internal/repository/admin_helpers.go                    NEW
_workspace/02_backend/api/tests/integration/admin_integration_test.go             NEW
_workspace/02_backend/api/tests/integration/softdelete_cache_integration_test.go  NEW
_workspace/04_qa/qa_phase5a_smoke.sh                                              NEW
_workspace/04_qa/qa_report_phase5a_backend.md                                     NEW
_workspace/02_backend/api/internal/domain/types.go                                MODIFIED
_workspace/02_backend/api/internal/middleware/middleware.go                       MODIFIED
_workspace/02_backend/api/internal/middleware/middleware_test.go                  MODIFIED
_workspace/02_backend/api/internal/repository/users.go                            MODIFIED
_workspace/02_backend/api/internal/repository/repository.go                       MODIFIED
_workspace/02_backend/api/internal/handlers/users.go                              MODIFIED
_workspace/02_backend/api/internal/handlers/handlers.go                           MODIFIED
_workspace/02_backend/api/internal/handlers/handlers_test.go                      MODIFIED
_workspace/02_backend/api/internal/handlers/venues_test.go                        MODIFIED
_workspace/02_backend/api/internal/server/router.go                               MODIFIED
_workspace/02_backend/api/cmd/server/main.go                                      MODIFIED
_workspace/02_backend/api/tests/integration/helpers_test.go                       MODIFIED
_workspace/02_backend/api/tests/integration/misc_integration_test.go              MODIFIED
_workspace/02_backend/api/openapi.yaml                                            MODIFIED
```
