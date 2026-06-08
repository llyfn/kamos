---
id: invariant:admin-auth
spec: SPEC.md §6.9; ARCHITECTURE.md §5
severity_on_violation: BLOCKER
layers: [admin, api, infra]
owners: [backend-engineer, security-reviewer, qa-inspector]
---

# Admin auth: HttpOnly cookie + double-submit CSRF

## Rule

Admin auth uses `HttpOnly` + `Secure` + `SameSite=Strict` cookies for access + refresh. Never Bearer for admin.

- **CSRF** — double-submit token. `X-CSRF-Token` request header is compared **constant-time** against the `kamos_admin_csrf` cookie. Required on every mutating admin request. Mismatch → `403 CSRF_MISMATCH`.
- **Identity** — `GET /v1/admin/me` is the cookie-authable identity endpoint. `/v1/users/me` is Bearer-only and must reject cookies.
- **Cross-site path** — Pages ↔ Fly is cross-site; same-site is restored by the Pages Function proxy at `admin/functions/v1/[[path]].ts` (and `vite.config.ts` locally). Do **not** flip cookies to `SameSite=None`.

## Check

```bash
# CSRF header path
grep -rn "X-CSRF-Token\|kamos_admin_csrf\|CSRF_MISMATCH" backend/internal/ admin/src/

# /v1/admin/me cookie-auth
grep -rn "/v1/admin/me\|AdminMe" backend/internal/handlers/ admin/src/

# Cookies set with HttpOnly + Secure + SameSite=Strict
grep -rn "kamos_admin" backend/internal/handlers/auth*.go backend/internal/handlers/admin*.go \
  | grep -iE "httponly|samesite|secure"

# No Bearer used by admin
grep -rn "Authorization.*Bearer" admin/src/
# (admin/src/ should not authenticate via Bearer — proxy + cookie only)
```

## Where each layer enforces it

- **Backend middleware** — `backend/internal/middleware/admin_cookie.go` (or similar) issues + validates the CSRF pair.
- **Admin SPA** — `admin/src/lib/api.ts` (or fetch wrapper) reads the CSRF cookie and copies the value into `X-CSRF-Token` on every mutating request.
- **Pages Function** — `admin/functions/v1/[[path]].ts` proxies to Fly; same-origin preserves SameSite=Strict.
- **Local dev** — `admin/vite.config.ts` mirrors the proxy locally.

## Related

- [[invariant:jwt-storage]] — mobile uses Bearer + secure storage; do not cross-pollinate the two auth surfaces
- [[invariant:sanitize-text]] — admin write paths still sanitize free-text input
