# QA Verification — Phase 5a Backend (independent review of the agent's own QA pass)

Date: 2026-05-16
Scope: 6 commits `bf9d38b`..`5284c86` (the Flutter commit `ceedf8b` is out of scope).
The agent's own QA report (`qa_report_phase5a_backend.md`) is verified, not trusted.

Verdict: **PASS WITH MINOR** — 0 BLOCKER, 1 MAJOR, 5 MINOR.

Test counts (re-run independently):

| Suite | Re-counted | Agent claimed | Notes |
|---|---|---|---|
| Unit (`go test ./...`) | 12 packages green, `--- PASS:` lines = 121 (top-level) | 214 | Discrepancy is counting-method (subtests vs top-level). All green either way. |
| Integration (`go test -tags=integration ./tests/integration/...`) | 69 (`--- PASS:` lines) | 69 | Match. |
| `go build ./...` | clean | clean | Match. |
| `go test -race ./internal/auth ./internal/middleware` | green | green | Concurrent path of SoftDeleteCache verified. |

Migration 007 verified on both DBs:
- `kamos_local`: `role | user_role | not null | 'user'::user_role`; `idx_users_deleted_at_recent` present.
- `kamos_test`: same.

SEC-006 status: **GENUINELY VERIFIED** (access-token side). See Lens 4.

---

## Lens 1 — Integration boundaries

PASS overall.

- Migration 007 applied to BOTH `kamos_local` and `kamos_test`. `\d users` confirms `role user_role NOT NULL DEFAULT 'user'`. Partial index `idx_users_deleted_at_recent` confirmed on both (PostgreSQL `pg_indexes` query).
- OpenAPI ↔ handler shape per endpoint:
  - `GET /v1/admin/beverage-requests` (`openapi.yaml:1115-1150`) ↔ `AdminListBeverageRequests` (`handlers/admin.go:105`). Page wrapper `{items, next_cursor, has_more}` matches `cursor.Page` shape. Item schema `AdminBeverageRequest` (`openapi.yaml:2059-2085`) fields (`id`, `user_id`, `username`, `payload`, `status`, `reviewed_by`, `reviewed_at`, `notes`, `created_at`) match `BeverageRequestRow` JSON tags (`repository/admin.go:33-44`). One catch: the JSON tag on `Username` is `"username,omitempty"` — when no submitter (`user_id` is NULL for a hard-purged user), the field is omitted entirely. The OpenAPI `username: nullable: true` allows both null and missing, so the shape is compatible. Minor cosmetic noted.
  - `POST /admin/beverage-requests/{id}/approve` ↔ `AdminApproveBeverageRequest`. Request body schema `AdminBeverageRequestApproval` (`openapi.yaml:2087-2113`) matches Go body struct (`handlers/admin.go:29-40`). 200 response `{request_id, beverage_id}` matches handler at line 176-179.
  - `POST /admin/beverage-requests/{id}/reject` ↔ `AdminRejectBeverageRequest`. Request body `{notes string 1..500}` matches. 200 response `{request_id, status, notes}` matches handler line 206-210.
  - `POST /admin/check-ins/{id}/moderate` ↔ `AdminModerateCheckin`. 204 with optional `{notes}` body. Matches.
  - `GET /admin/users` ↔ `AdminListUsers`. `AdminUser` schema (`openapi.yaml:2115-2129`) ↔ `AdminUserRow` (`repository/admin.go:252-261`) — all 8 fields align. `include_deleted` schema declares `enum: ["0","1"]` (string); handler reads `== "1"`. Matches.
  - `POST /admin/users/{id}/role` ↔ `AdminUpdateUserRole`. Body `{role enum}` matches.
  - `POST /admin/users/{id}/suspend` ↔ `AdminSuspendUser`. 204. Matches.
- Global `security: - bearerAuth: []` at the root of `openapi.yaml:42-43` is inherited by every admin op. Tag `admin` defined at line 40. Each operation has 401 + 403 response refs. PASS.
- `/v1/users/me` schema (`openapi.yaml:1443-1462`):
  - `required: [stats, role]` and optional `deleted_at` (nullable date-time).
  - Handler returns `domain.Me { User, Stats, Role, DeletedAt }` (`users.go:36-41`). `domain.Me` (`types.go` around 122) has matching JSON tags.
  - Flutter `Me.fromJson` (`_workspace/03_frontend/lib/core/models/user.dart:69-74`) ignores unknown fields. Backward-compatible — Flutter passes.
- Smoke script `qa_phase5a_smoke.sh` re-read: every assertion is reasonable; idempotency hack (line 110 — soft-delete the admin at the end) is correct since the live-username index would otherwise collide on re-run.

## Lens 2 — Architecture

PASS overall, with one MAJOR cross-cutting concern flagged below.

- `internal/auth/softdelete_cache.go`:
  - `sync.RWMutex` used correctly: `Contains` takes RLock, `Add`/Refresh take WLock. `Refresh` does the slow DB query OUTSIDE the lock and only swaps the map pointer under WLock (line 113-115). No goroutine leaks: `Run` honors `ctx.Done()` (line 130-131) and `defer t.Stop()` (line 128).
  - Initial refresh on `Run` is best-effort (line 124-126) — startup is not blocked, which matches the comment.
- `internal/middleware/rbac.go`:
  - Correct order: nil-check → `UserIDFromContext` (set by `Auth` upstream) → role lookup → allow/deny. The middleware MUST be downstream of Auth, which it is (`router.go:175-192` Auth runs before per-route `r.With(modOrAdmin/adminOnly)`).
  - Missing user (uid == "") returns 401, not 403 — correct because the rest of the auth stack uses 401 UNAUTHORIZED for "no identity".
  - Nil receiver / nil pool fails closed with 500 (lines 75-79) — explicitly documented. Defensive.
  - `pgx.ErrNoRows` (user soft-deleted between Auth and role lookup) → 401 ACCOUNT_DELETED. Reasonable race resolution.
- `/v1/admin/*` handlers all use the correct RBAC binding (`router.go:182-192`):
  - `modOrAdmin`: list bev-requests, reject, moderate check-in, list users.
  - `adminOnly`: approve, suspend, role-update.
  - This matches the design intent: privilege-altering ops (approve creates a new catalog row; suspend kills tokens; role-update changes RBAC) require admin.
- Admin group is `r.Route("/admin", ...)` — sibling of the regular authed `r.Group { ... }`. So non-admin authed routes do NOT pay the role-lookup cost (the RBAC middleware is per-route on the admin tree only). Architecturally clean.
- Approval transaction (`repository/admin.go:115-191`):
  - `tx, _ := r.db.Begin(ctx)` → defer rollback (line 116-120).
  - `SELECT ... FOR UPDATE` locks the request row (line 124-130).
  - Category lookup inside tx (line 137-144).
  - INSERT beverages, UPDATE request, COMMIT. One transaction end-to-end. PASS.
- `GET /v1/users/me`: authed (via `Auth(signer, softDelete)` from `router.go:115`). Unauthed → 401 from middleware. PASS.

## Lens 3 — Coding conventions

PASS with cosmetic minors.

- Naming: file is `softdelete_cache.go`; the rest of the repo prefers `_`-separated multi-word names like `admin_helpers.go`, `email_verification_cleanup.go`, `photo_orphan_cleanup.go`. `soft_delete_cache.go` would match better. Cosmetic.
- Error handling: typed sentinels used consistently — `apierror.ErrNotFound`, `apierror.ErrConflict`, `apierror.ErrValidation`, `auth.ErrAuth`. Approval uses `errors.Join(apierror.ErrValidation, ...)` so handler's `writeErr` → `apierror.WriteFrom` can produce 422.
- Magic values: `softDeleteWindow = 30m floor; max(30m, JWT_TTL)` documented at `main.go:99-105`; `refreshInterval = 1m`. Documented. Test helper sets `(30s, jwtTTL+1h)` — also documented.
- Dead code: none observed in the new files.
- Test naming: `TestAdmin_*`, `TestSoftDeleteCache*`, `TestSoftDeleteCacheRefreshRebuildsFromDB`. Matches existing `TestRefresh_*` style for the refresh-token suite.
- One real test name discrepancy: the agent's report (section 2 of `qa_report_phase5a_backend.md`) cites `TestUpdateAndDeleteSelf` (integration, updated) — that name is fine, no issue.

## Lens 4 — Security / Performance

PASS with 1 MAJOR.

- **SEC-006 access-token revocation: GENUINELY verified, NOT test-tautology.** The relevant test (`TestSoftDeleteCacheRevokesActiveToken`, `softdelete_cache_integration_test.go:25`) is built on the production server (`newServer(t) → buildServerWithTTL(t, true, time.Hour, 30*24*time.Hour, nil)`, `helpers_test.go:127-129`). JWT TTL = 1 hour. The test sequence is:
  1. Register → get token.
  2. Verify `/me` → 200.
  3. Call `DELETE /v1/users/me` → 204.
  4. Re-call `/me` with the SAME token → 401 ACCOUNT_DELETED.
  5. Re-call `/feed` with the same token → 401.

  Step 4-5 occur within milliseconds. The JWT is valid for 60 minutes. If SoftDeleteCache were absent, step 4 would 200. Revocation is provably the cache, not expiry. **NOT a tautology** — sub-second test on a 1-hour-TTL token.
- **IDOR on admin endpoints: PASS.** `TestAdmin_RoleGate` (admin_integration_test.go:63) covers regular `user` → 403 ROLE_REQUIRED on `/admin/beverage-requests` and `/admin/users`. `TestAdmin_AdminOnlyVsModerator` (line 90) covers moderator → 403 on the admin-only `suspend` endpoint. `TestAdmin_RequiresAuth` (line 44) covers no-bearer → 401 on all four sample routes.
- **Self-protection on `/admin/users/{id}/role` and `/admin/users/{id}/suspend`**: handler 403s if `userID == uid` (`admin.go:296-301, 342-345`). Tested at `TestAdmin_UpdateUserRole` line 364-369 and `TestAdmin_SuspendUserRevokesTokens` line 451-455.
- **SQL injection on cursor + filters:** PASS. `ListBeverageRequests` uses `$1..$4`; `ListUsers` uses `$1..$5`. `parseCursor` decodes via the signed `cursor.Decode` helper (`handlers/handlers.go:127-129`). `roleFilter` is checked against `domain.UserRole.Valid()` *before* binding (`admin.go:260-264`). No fmt.Sprintf in SQL. No vector.
- **Soft-delete cache pruning:** `Refresh` rebuilds the entire map from `SELECT id FROM users WHERE deleted_at > now() - $1::interval`. Entries older than `window` (default `max(30m, JWT_TTL)`) naturally fall out on the next refresh. With 720h test/dev TTL, the cache holds up to 30 days of soft-deletes — bounded by the username-release horizon. PASS.
- **Refresh-loop cost:** at 1m refresh interval with 30-day window, the worst-case map size is bounded by soft-delete rate × 30d. For a small/medium app this is trivial; the partial index `idx_users_deleted_at_recent` (migration 007) ensures the query plan is index-only. PASS for MVP scale.
- **Role lookup per request:** one `SELECT role::text FROM users WHERE id=$1 AND deleted_at IS NULL` per admin request. Indexed PK lookup, sub-ms. Confined to the `/admin` route group only — non-admin authed routes do NOT pay this cost. PASS.
- **N+1 in admin lists:** none. `ListBeverageRequests` is one SQL with a `LEFT JOIN users` for the username. `ListUsers` is one SQL with no joins. Both use cursor pagination on `(created_at, id)` tuples (lexicographic `<` comparison) — correct. PASS.
- **MAJOR — `AdminSuspendUser` does not revoke refresh tokens.** `AdminSuspendUser` calls `Admin.SuspendUser` (which only UPDATEs `users` — sets `deleted_at`, `username_release_at`, demotes role to `user`) and `h.SoftDelete.Add(userID)`. It does NOT call `RefreshTokens.RevokeAllForUser(ctx, userID)`. `RevokeAllForUser` exists (`repository/refresh_tokens.go:144-150`) and is used by the existing logout-everywhere path (`handlers/auth.go:608`).

  Net effect: the suspended user's access token is revoked (SoftDeleteCache), but their refresh token's `revoked_at` is NOT set. The refresh flow at `handlers/auth.go:459-540` re-checks `Users.FindByID` which filters `WHERE id=$1 AND deleted_at IS NULL` (`repository/users.go:189`), so a POST to `/v1/auth/refresh` for the suspended user does 401 TOKEN_INVALID via the user-lookup miss — the suspended user genuinely cannot mint a new access token via refresh. So **the practical security risk is contained** (defense in depth via the `deleted_at IS NULL` filter in FindByID).

  Still, this is sloppy compared to the existing convention. Reasons it should be fixed:
  1. **Defense in depth.** If a future code path looks up refresh tokens directly (e.g., a "list my devices" endpoint) without joining to `users.deleted_at`, the suspended user's tokens would still appear active.
  2. **Audit log honesty.** The `refresh_tokens.revoked_at` column is the canonical record of "this token was killed". Suspension should leave a clear audit trail there.
  3. **Symmetric with self-DELETE.** `DeleteMe` ALSO does not call `RevokeAllForUser` — same issue, same containment. Both flows should call it.
  4. **The agent's own report § 7 explicitly defers this as "open items"**, but I'd promote it to MAJOR because the dependency on `FindByID`'s `deleted_at IS NULL` filter is a load-bearing invariant that is not asserted by any test.

  Routing: **`backend-engineer`**. Fix is two lines added to `AdminSuspendUser` (and likely also `DeleteMe`):
  ```go
  if _, err := h.Repos.RefreshTokens.RevokeAllForUser(r.Context(), userID); err != nil {
      h.Log.Error("AdminSuspendUser revoke refresh tokens", "err", err, "user_id", userID)
      // Continue — the soft-delete already took effect; refresh-rotation will 401 anyway.
  }
  ```
  Plus an integration test: register → get refresh token → suspend → POST `/v1/auth/refresh` → expect 401. Add a similar test for `DELETE /v1/users/me`.

- **Notes on test count discrepancy:** the agent's report claims +12 unit / +12 integration. I see +12 integration genuinely (the admin and softdelete_cache test files together add 12 cases). Unit test delta is a counting artifact and is not load-bearing.

---

## BLOCKERS

None.

## MAJOR

1. **`AdminSuspendUser` (and `DeleteMe`) do not revoke refresh tokens.** Refresh-token `revoked_at` is never set on suspension/self-delete. Defense-in-depth via `FindByID`'s `deleted_at IS NULL` filter contains the practical risk, but a single regression in that filter would re-open the hole. Fix is two lines + one test per flow. Owner: `backend-engineer`. Detail above.

## MINOR

1. **No integration test for refresh-token revocation under SEC-006.** The access-token revocation test is excellent. There is no counterpart that exercises `POST /v1/auth/refresh` post-suspend. Even with the current state (where it would 401 via the `FindByID` `deleted_at` filter), the assertion would be cheap and would lock the contract. Owner: `backend-engineer`.
2. **Filename `softdelete_cache.go` doesn't match repo's snake_case convention.** Existing precedent: `admin_helpers.go`, `email_verification_cleanup.go`, `photo_orphan_cleanup.go`. `soft_delete_cache.go` would be canonical. Cosmetic. Defer.
3. **`/v1/users/me` returns `role` and `deleted_at` for soft-deleted users.** `FindMe` (`repository/users.go:217-242`) deliberately omits the `deleted_at IS NULL` filter. The agent's own report § 7 acknowledges this and notes the narrow window between `Add()` and the next refresh. Acceptable as-is; surface a test for the `deleted_at IS NOT NULL` race path if you want to lock it down.
4. **Approval handler doesn't echo back the approved `notes`.** `AdminApproveBeverageRequest` returns `{request_id, beverage_id}` while `AdminRejectBeverageRequest` returns `{request_id, status, notes}`. Inconsistent shape, no functional bug. Defer.
5. **`AdminListUsers` query parameter `include_deleted` is `enum: ["0", "1"]` (strings) in OpenAPI** but the handler tolerates anything (just checks `== "1"`). Aligns, but a more idiomatic API would accept `true`/`false`. Cosmetic.

## Backlog (non-blocking observations)

- The `AdminSuspendUser` flow demotes role to `'user'` before soft-deleting (`repository/admin.go:325-330`). Sensible — if the user is ever un-suspended in the future, they shouldn't auto-recover admin rights. Worth a comment in the SQL.
- The `AdminModerateCheckin` notes are only logged structurally; the agent's own report § 7 flags a `moderation_log` table as deferred. Fine for Phase 5a but should land before Phase 6 (comments / public collections).
- The `Me.role` field is `required` in OpenAPI but the Flutter `Me.fromJson` ignores it — once an admin Flutter client is built, that client should READ this field. No issue today; flag for the admin-client work that lands later.

---

## SEC-006 verification — final word

The agent's claim of "SEC-006 FIXED" for the access-token side is **honest and verified**:

- `TestSoftDeleteCacheRevokesActiveToken` runs against a real JWT with 1-hour TTL, executes in 0.26s, and asserts 401 ACCOUNT_DELETED on a follow-up `/me` and `/feed` request after `DELETE /me`. The token is not even close to expiry — the test cannot pass without the cache doing its job. Re-verified by independently running the test.
- The Auth middleware (`middleware/middleware.go:153-176`) consults `softDelete.Contains(claims.UserID)` on every request and 401s with `ACCOUNT_DELETED`.
- `DeleteMe` (`handlers/users.go:73-86`) synchronously calls `h.SoftDelete.Add(uid)` after the DB UPDATE.
- `AdminSuspendUser` (`handlers/admin.go:347-353`) does the same.
- The 60s periodic `Refresh` provides cache rebuild after API restart, covered by `TestSoftDeleteCacheRefreshRebuildsFromDB`.

The agent's claim of "SEC-006 FIXED" for the **refresh-token side** is **implicit and under-tested** — see the MAJOR above. The refresh path 401s for suspended users *only because* `FindByID` filters by `deleted_at IS NULL`. A direct test of `POST /v1/auth/refresh` post-suspend is missing, and `revoked_at` is never set on the refresh row. This is not a runtime bug today but is the kind of latent issue that becomes a real bug if someone refactors `FindByID` or adds a new code path that looks up refresh tokens without joining `users`.

Net: **Ship-ready** modulo the MAJOR. The fix is small and the risk today is theoretical, but should not be left for Phase 5b.
