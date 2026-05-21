# Runbook — secret rotation

Two secrets in the KAMOS API have user-visible consequences when rotated: `JWT_SECRET` and `CURSOR_SECRET`. Both are HMAC keys, both are validated for length (≥ 32 bytes) at startup, both must be set in production. This runbook covers both — and notes the gap that a future graceful-rotation upgrade would close.

## When to rotate

- **Scheduled** — once per year, or after every personnel change on the operator side.
- **Unscheduled** — immediately after any suspected leak (config commit, dumped backup, compromised host, contractor offboarding, etc.).
- **Never** — across a major API release without first stress-testing the post-rotation client behaviour in staging.

## JWT_SECRET rotation

**Blast radius:** every active access token and every refresh token is invalidated the moment the new secret loads on the first API replica. Mobile users will see a `401`, the Dio `AuthInterceptor` will fail the refresh attempt, and the app will route them back to the login screen. Admin users will be logged out on their next mutation (the CSRF middleware will reject; the cookie auth will fail).

**Sequence (~10 minutes of degraded auth):**

1. Generate the new secret: `openssl rand -base64 48`. Stash it in the secret store; do not commit it.
2. Announce maintenance window in the user-facing surface (mobile in-app banner, admin login page banner). One-line: "you may need to log in again around HH:MM UTC."
3. Set the new value on every replica's env (API + worker).
4. Restart all API replicas + the worker. Rolling restart is fine — there's no graceful-rotation path, so a mid-restart inconsistency window of seconds is fine; tokens issued in that window will fail-fast on the next request.
5. Verify: log in fresh from a clean device → `POST /v1/auth/login` returns 200 with a new token; old tokens captured before the cutover return `401 INVALID_TOKEN`.
6. Watch Sentry for an auth-error surge over the next 30 minutes. A short bump is expected; a sustained one means something downstream is caching the old secret.

**Post-rotation:** users re-login as a one-time cost. No data is lost. Refresh-token families are reset (the row in `refresh_tokens` is signature-validated, so the old families are dead).

## CURSOR_SECRET rotation

**Blast radius:** every outstanding paginated cursor is invalidated. A client mid-scroll on the feed (or any list) will get a `400 INVALID_CURSOR` on the next page request; the client's cache layer drops the page and re-paginates from cursor=nil. No login impact, no data loss.

**Sequence (~5 minutes, no user-visible auth disruption):**

1. Generate the new secret: `openssl rand -base64 48`.
2. Set the new value on every API replica's env. (Worker doesn't sign cursors.)
3. Rolling-restart API replicas.
4. Verify: hit a paged endpoint, capture the cursor, pause >10s, hit the next page → 200. Then submit a pre-rotation cursor stored from before step 2 → `400 INVALID_CURSOR`.

**Post-rotation:** clients re-paginate. The Flutter feed already handles `INVALID_CURSOR` by clearing state and re-fetching page 1; check the admin SPA's list pages do the same before the rotation (they currently use `openapi-fetch` + the typed error envelope, which surfaces the error code).

## Future work — graceful rotation (HS256 → RS256 + JWKS)

The current design assumes a single active key, which is why both rotations are disruptive. The roadmapped upgrade:

- Switch JWT from HS256 (symmetric) to RS256 (asymmetric, private key signs / public key verifies).
- Publish a JWK Set endpoint (`/.well-known/jwks.json`) holding two active public keys during overlap windows: the previous key (verify-only) and the next key (sign + verify).
- Rotate by: (a) add new key as verify-only, (b) deploy a release that signs with the new key, (c) wait the access-token TTL + a safety margin, (d) drop the old key from the JWK Set.

`CURSOR_SECRET` can adopt the same pattern with two simultaneous HMAC keys (verify both, sign with the newer). The cursor envelope would need a 1-byte `kid` prefix.

Both are tracked as post-Stage-9 follow-ups; not in scope for the current release.
