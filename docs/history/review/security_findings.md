# Security Findings — Phase 4 (Venues + Foursquare)

Reviewer: security-reviewer
Date: 2026-05-16
Scope: diff `be82d83..2c72f0f`. Focus on `/v1/venues/search` authz + rate limit, Foursquare client, venue upsert TOCTOU, CheckinVenue input validation, JWT/auth path, Flutter token handling, OpenAPI auth declaration.

Severity legend: CRITICAL ship-blocker / HIGH must-fix / MEDIUM fix this pass / LOW backlog.

---

### SEC-001 — Unbounded venue name + address persistence enables stored-XSS payload + DB bloat [HIGH]
**File:** `_workspace/02_backend/api/internal/handlers/checkins.go:299-329`, `_workspace/02_backend/api/internal/repository/venues.go:38-67`, `_workspace/02_backend/api/migrations/005_venues.sql:9-25`
**Issue:** When a client supplies `venue.foursquare_id + name + address + …` on POST /v1/check-ins, the handler passes the strings straight into `Venues.UpsertByFoursquareID` with no length cap, no charset filter, and no rejection of control characters. The migration declares `name TEXT NOT NULL` / `address TEXT` without `CHECK (char_length(...))`. The handler's only validation is "FoursquareID is required and Name is non-empty" (`UpsertByFoursquareID` body). A malicious client can submit a `name` of arbitrary size (MB-scale) and arbitrary content including `<script>`-shaped payloads, NUL bytes, or zero-width Unicode. These strings then surface verbatim through `FeedItem.venue.name` (`feed.go:113`), `Checkin.venue.name` (`checkins.go:162-169`), and any future profile/feed render path. The Flutter rendering uses `Text(place.name)` which is safe for the mobile app today, but the same column is consumed by the future admin web client per the post-MVP roadmap — that's an XSS sink the data layer is feeding.
**Risk:**
- Stored data poisoning: a single attacker fixes `name = "<a long string>"` on a popular `foursquare_id` and every other user picking that venue sees it on every check-in card. UNIQUE on `foursquare_id` + the upsert `ON CONFLICT … DO UPDATE SET name = EXCLUDED.name` means the LAST writer wins, including malicious ones (see SEC-002).
- DB row bloat: 1 row with a 10MB name still respects no UNIQUE constraint; multiplied across the venue rows referenced by every check-in feed query, the GIN tsvector index (`idx_venues_name_tsv`) blows up.
- Future XSS: when the admin web client (post-MVP) renders `venue.name` without escaping it, the payload fires.
**Recommendation:**
1. Add `Validate()` to `domain.CheckinVenue`: `len([]rune(name)) ∈ [1, 200]`, `len([]rune(address)) ≤ 500`, reject any rune < 0x20 except spaces, reject explicit NULs. Same for `country`, `prefecture`, `locality` with smaller caps (e.g. 100).
2. Add `CHECK (char_length(name) ≤ 200)` etc. to the migration as a backstop (new migration, not edit-in-place since 005 has shipped).
3. Call this validator from `handlers/checkins.go:resolveCheckinVenue` before invoking the upsert.

---

### SEC-002 — Venue upsert lets ANY authenticated user overwrite a venue's mutable columns (TOCTOU + last-writer-wins) [HIGH]
**File:** `_workspace/02_backend/api/internal/repository/venues.go:38-67`
**Issue:** `UpsertByFoursquareID` runs `INSERT … ON CONFLICT (foursquare_id) DO UPDATE SET name = EXCLUDED.name, address = …, lat = …, lng = …, country = …, prefecture = …, locality = …, updated_at = now()`. There is no check that the inbound `(name, lat, lng, country, …)` matches what Foursquare actually reports for that `foursquare_id`. Once a venue row exists, every subsequent check-in that re-supplies the same `foursquare_id` completely overwrites every mutable column with whatever the client claims. The user-controlled keys are never validated against the Foursquare API — the only place that contract is enforced is the `/v1/venues/search` proxy, but the check-in upsert path uses an entirely separate, key-trusting flow.
**Risk:** A malicious authed user can:
- Rename "Daikoku, Tokyo" to anything by POSTing one check-in with `{foursquare_id: "<known>", name: "<garbage>"}`. The next legitimate user picking Daikoku from a search hit overwrites it back, but for the window between the two writes (and for any feed card already rendered) the bad name is canonical.
- Move a venue geographically by overwriting `lat`/`lng`. The CHECK constraints on the migration only bound the range to [-90/90, -180/180], not "near where Foursquare says".
- Confuse a different `foursquare_id` by reusing an obviously-fake one (e.g. `"fsq-abc-123"` literal from the integration test) and then poisoning it with claims of being a different real place. Foursquare IDs are opaque strings; the server has no way to detect "this isn't a real FSQ id" without round-tripping the proxy.
**TOCTOU note:** the race itself (two clients upserting the same fsq id concurrently) is handled correctly by Postgres — `ON CONFLICT` is atomic and the UNIQUE constraint serializes the writers. The issue is not the race; it's that EITHER winner's data is trusted.
**Recommendation:** Two options, in order of strength:
- (Strong) Have the search endpoint cache the place server-side and require the check-in upsert path to look up its `(name, lat, lng, country, …)` from that cache by `foursquare_id`, rejecting any client-supplied fields that disagree. The cache already exists in `foursquare.Client` (1h TTL, 1000 entries) — reuse it.
- (Weak) On `ON CONFLICT`, do NOT overwrite the existing columns. Change the upsert to `ON CONFLICT (foursquare_id) DO UPDATE SET updated_at = now()` with `RETURNING id;` (first-writer-wins). Stale Foursquare data is then a separate refresh problem, but at least no one user can rewrite a shared venue.

A SendMessage was sent to `arch-reviewer` because this is fundamentally a layering issue (the upsert path bypasses the Foursquare-truth boundary the search path established).

---

### SEC-003 — `Authorization` header value is forwarded raw to Foursquare without bearer-style normalization, and the `apiKey` is the literal credential [MEDIUM]
**File:** `_workspace/02_backend/api/internal/foursquare/client.go:192`
**Issue:** `req.Header.Set("Authorization", c.apiKey)` — Foursquare's v3 API does expect the raw key in `Authorization` without a `Bearer ` prefix, so this is correct per the upstream docs. However:
- If an operator misconfigures `FOURSQUARE_API_KEY` with a leading/trailing whitespace, newline, or any header-poisoning sequence (`X-Foo: bar\r\n`), the value goes straight into the request header. Go's `http.Header.Set` does not validate per RFC 7230; `net/http` will reject CR/LF on write (causing the request to fail), but spaces and tabs pass through silently.
- The full API key appears in any error message from `c.http.Do` that includes the request URL/header bag (it doesn't by default, but a debugging wrapper or a future change might log `req.Header`).
**Risk:**
- Header injection is mitigated by Go's stdlib, but a quietly-broken key (whitespace) gives Foursquare 401s that map to `auth failed (401)` — surfaced as `INTERNAL` to the client, not as a configuration error. Operators won't know it's their fault.
- Future-proofing: if a developer later adds `h.Log.Error("fetchOnce", "headers", req.Header)`, the key lands in structured logs and Sentry breadcrumbs.
**Recommendation:**
1. In `foursquare.New`, `strings.TrimSpace` the apiKey before storing.
2. Add a small comment-anchored test asserting that the stored key matches `^[A-Za-z0-9_-]+$` (or whatever Foursquare's key alphabet is).
3. Make `Client.apiKey` unexported (it already is) and add a doc note "MUST NOT be logged; treat as a secret".

---

### SEC-004 — `/v1/venues/search` per-user rate limit is shared with the rest of the authed surface (60 rps / burst 120) and is bypassable when `RATE_LIMIT_DISABLED=1` is leaked into production [MEDIUM]
**File:** `_workspace/02_backend/api/internal/server/router.go:101-127`, `_workspace/02_backend/api/internal/config/config.go:85,127`
**Issue:**
- The route is correctly behind `middleware.Auth(signer)` and the global `RateLimitByIP` (30 rps / burst 60) + per-user `RateLimitByUser` (60 rps / burst 120). However, both limits are GENERIC — they cover every authed endpoint together. A single user has a 60 rps / burst 120 budget across the whole API; spending all 120 against `/v1/venues/search` exhausts the upstream Foursquare free-tier rate-limit very quickly (the foursquare client's LRU cache mitigates this for repeated `q`, but a varying `q` defeats the cache).
- There is no dedicated stricter cap on `/v1/venues/search`. Per the SPEC the route should be treated more carefully because it is a paid upstream egress.
- `RateLimitDisabled` is read from env at startup and silently flips off ALL middleware caps when set, including the auth-group 5 rps / burst 10 that protects login from credential stuffing. If `RATE_LIMIT_DISABLED=1` ever leaks into production (operator typo, container env-template error), the whole API becomes brute-force vulnerable. Production should refuse to boot if both `APP_ENV=production` and `RATE_LIMIT_DISABLED=1`.
**Risk:**
- Upstream Foursquare key burn: a single authed user with a varying `q` can hit 120 unique requests per second, blowing the Foursquare free-tier quota. The cache doesn't help when `q` varies. Once Foursquare 429s us, EVERY user gets `VENUE_RATE_LIMITED` until the upstream window resets.
- Production rate-limit kill switch: this is a foot-gun. A leaked `RATE_LIMIT_DISABLED=1` removes the brute-force backstop on `/v1/auth/login` (5 rps cap), and the only thing left between an attacker and credential stuffing is bcrypt cost.
**Recommendation:**
1. Add a dedicated, tighter limiter for `/v1/venues/search` — e.g. 5 rps / burst 10 per user — applied via `r.With(middleware.RateLimitByUser(log, 5, 10))` on JUST that route, AFTER the global authed limiter. This double-limits the route (60+5) which is the desired behaviour.
2. In `config.Load`, refuse to start if `APP_ENV=production && RateLimitDisabled`:
   ```go
   if c.Env == "production" && c.RateLimitDisabled {
       return nil, fmt.Errorf("Load: RATE_LIMIT_DISABLED must be unset in production")
   }
   ```
3. (Optional but cheap) Cap `?limit=` for venue search at a lower value than 50 — even Foursquare's own free tier rarely needs 50 hits.

A SendMessage was sent to `perf-reviewer` because the dedicated limiter has both a security and a perf payoff (less upstream pressure).

---

### SEC-005 — Foursquare client base URL is a `const` but parsed at every call; cache key omits the `limit`-dependent cache poisoning vector [LOW]
**File:** `_workspace/02_backend/api/internal/foursquare/client.go:41,173-185,263-275`
**Issue:** SSRF safety: `apiBase = "https://api.foursquare.com/v3/places/search"` is a const, the value is `url.Parse`d, and only known query keys are `.Set` onto the parsed `u.Query()`. There is NO path where a user-controlled value reaches the URL host or path. This is correct. Two minor concerns:
- The cache key DOES include `limit` (line 273), so the LRU cannot serve a higher-limit response from a lower-limit cache entry. Good. But: `q` is `strings.ToLower(strings.TrimSpace(opts.Query))` and `locale` is the raw string from `resolveLocale` (validated to en/ja/ko). If an attacker can poison a cache entry with a malformed `locale` (currently impossible because the handler validates it, but defense-in-depth) they could pin a result.
- The `Accept-Language` header is set from `opts.Locale` (line 195) which is en/ja/ko-validated. Good.
**Risk:** Currently no exploit. Documented for defence-in-depth.
**Recommendation:** Add an explicit comment in `cacheKey` that `opts.Locale` must already be validated by the caller, and a test that asserts a non-en/ja/ko locale never reaches `cacheKey`. This makes the contract explicit so a future refactor that loosens `resolveLocale` doesn't accidentally enable cache poisoning.

---

### SEC-006 — `Auth` middleware does NOT verify `users.deleted_at IS NULL` — soft-deleted users can still hit /v1/venues/search (and every other authed route) until their JWT expires [HIGH]
**File:** `_workspace/02_backend/api/internal/middleware/middleware.go:25-30, 144-163`
**Issue:** The middleware comments are explicit: "We never re-fetch the DB user on every request — the JWT claims are authoritative until expiry." Per SPEC and the `DeleteMe` flow (soft-delete + 30d username hold), once a user soft-deletes their account, their existing access tokens REMAIN VALID until the JWT TTL elapses (default 15m per `config.Load:141`). During that window the deleted user can:
- Call `/v1/venues/search` (Foursquare egress on the deleted user's behalf, costing quota).
- Call `/v1/check-ins` (create a check-in attributed to a soft-deleted `user_id`, which then surfaces — or doesn't — depending on the feed query's `u.deleted_at IS NULL` filter).
- Call every other authed endpoint listed in `router.go:101-148`.
This is NOT introduced by Phase 4 — it's a pre-existing gap. But Phase 4 makes it materially worse because (a) it adds a paid egress (Foursquare), and (b) it adds a new write surface (venue upsert) that a soft-deleted user can still poison.
**Risk:**
- Burn Foursquare credit on behalf of an account that "doesn't exist" anymore.
- Soft-deleted user creates a check-in that links a venue row that then survives forever (venue `ON DELETE SET NULL` on the FK, but the venue itself lives on regardless).
- Audit trail confusion: a check-in attributed to a deleted account inserted AFTER the delete timestamp.
**Recommendation:** Two paths, pick one:
- (Cheap) Reduce access-token TTL to ≤5 min for the soft-delete window. Already at 15m; reasonable but doesn't fully close the gap.
- (Correct) Add a DB check to the Auth middleware OR (better, since per-request DB hit is too expensive — see the SendMessage to perf-reviewer) a token-revocation cache. Revoke all refresh tokens on `DeleteMe` (already done per Phase 2?) and add an in-memory bloom filter of soft-deleted user IDs that the Auth middleware consults. The filter is populated at startup from `SELECT id FROM users WHERE deleted_at > now() - JWT_TTL` and updated on `DeleteMe`. This is the same pattern as JWT-revocation lists.

This is "Needs verification" because the Phase 2 refresh-rotation flow MIGHT already revoke all refresh tokens on DeleteMe, but the access token window remains regardless.

A SendMessage was sent to `arch-reviewer` (architectural: the JWT-is-authoritative decision is global) and to `perf-reviewer` (a naive per-request DB check would be a real cost).

---

### SEC-007 — `q` query param has no length/charset cap and reaches the Foursquare URL via `url.Values.Set` (correctly escaped) but with no upper bound [LOW]
**File:** `_workspace/02_backend/api/internal/handlers/venues.go:40-45`, `_workspace/02_backend/api/internal/foursquare/client.go:179`
**Issue:** `q` is `strings.TrimSpace`d and required-non-empty, but unbounded. A 100KB `q` reaches `url.Values.Set("query", opts.Query)` and `u.RawQuery = q.Encode()`. Go encodes the value safely (URL-escape applied; no injection), and the upstream Foursquare server rejects oversized URLs with 414. But:
- The cache key (line 265) includes the entire 100KB `q`, blowing up the LRU's memory budget. The cache has `cacheSize = 1000`; a 100KB string per key gives 100MB resident.
- A burst of varying long `q`s defeats the cache (each is a unique key) and shifts pressure to the upstream key.
**Risk:** Tier-1 DoS amplification: an attacker can submit large unique `q`s, burning both the LRU memory budget and Foursquare quota. The route's per-user rate limit (60 rps from the authed group) caps this, but see SEC-004.
**Recommendation:** In `VenueSearch`, reject `q` over a sensible length: `if len([]rune(q)) > 100 { 422 VALIDATION "q too long" }`. Foursquare itself only meaningfully indexes ~3-30-char queries.

---

### SEC-008 — `resolveLocale` falls back to `Accept-Language` header (user-controlled) but DOES validate the en/ja/ko enum; minor observation [LOW]
**File:** `_workspace/02_backend/api/internal/handlers/venues.go:101-126`
**Issue:** The header parsing accepts the primary tag (everything before `,` or `;` or `-`) and validates against the en/ja/ko allowlist before forwarding to Foursquare as `Accept-Language`. This is safe — the upstream header value is one of three known constants. No injection vector here.
**Risk:** None today.
**Recommendation:** Add a test for an obviously hostile header like `Accept-Language: en\r\nX-Injected: yes` to lock the contract in. Go's stdlib already strips CR/LF on header WRITE, but the test makes the safety explicit.

---

### SEC-009 — Flutter venue search request attaches Authorization correctly through Dio interceptor; no token leak in error path [INFO]
**File:** `_workspace/03_frontend/lib/features/venues/repository/venue_repository.dart:38-86`, `_workspace/03_frontend/lib/core/api/auth_interceptor.dart:100-110`
**Issue (verification):**
- `VenueRepository` calls `_dio.get('/v1/venues/search', …)`. The Dio instance is the singleton from `dioProvider` (`api_client.dart`), which installs `AuthInterceptor`. The interceptor's `onRequest` reads the token from `SecureStorageService.readToken()` (which uses `flutter_secure_storage` per SPEC §6.9) and sets `Authorization: Bearer <token>` on every outbound request including this one.
- On 401, the interceptor performs the refresh-token exchange and retries — same as every other authed route.
- The error path (`DioException` catch) inspects `e.response?.statusCode` and `body['code']` to map to `VenueSearchDisabledException` / `VenueRateLimitedException`. No token is logged anywhere. The exception's `toString()` returns a hardcoded "Venue search disabled" / "Venue search rate-limited" message — no PII or secret.
- The `rethrow` on line 83 propagates the original DioException; the surrounding provider handles it as `AsyncValue.error`. The `_normalise` in the interceptor builds an `ApiException(statusCode, code, message)` from the body — no token, no header.
**Risk:** None observed.
**Recommendation:** Confirmed safe. No action needed.

---

### SEC-010 — OpenAPI declares `security: bearerAuth` globally (line 41-42) and does NOT override it on `/v1/venues/search` — auth is correctly documented [INFO]
**File:** `_workspace/02_backend/api/openapi.yaml:41-42, 714-770`
**Issue (verification):** Global `security: [{bearerAuth: []}]` is set at the document level. Public endpoints opt out explicitly with `security: []` (e.g. `/health` at line 49). The `/v1/venues/search` definition has NO `security: []` override → inherits the global bearerAuth requirement. The route in `router.go:126` is also nested inside the `r.Group { r.Use(middleware.Auth(signer)) … }` block. OpenAPI and the actual middleware chain agree.
**Risk:** None — this is verifiably correct.
**Recommendation:** No action. Note for the synthesized report.

---

### SEC-011 — Foursquare client 5xx retry has no max-retries-per-request beyond the single retry, but the cache TTL means repeated same-query requests will not retry — defensible [INFO]
**File:** `_workspace/02_backend/api/internal/foursquare/client.go:147-162`
**Issue (verification):** `fetchWithRetry` retries exactly once on `upstreamServerError` (5xx). 401/403/429/4xx variants do not retry. The retry waits `retryBackoff = 200 * time.Millisecond` and respects `ctx.Done()`. Worst-case caller wait: `2 * httpTimeout (5s) + retryBackoff = 10.2s`. The route is behind a 30s WriteTimeout (`main.go:157`) so the request will not exceed the server's own timeout. The retry is bounded and reasonable.
**Risk:** None.
**Recommendation:** No action.

---

### SEC-012 — Integration test does not exercise auth-required behavior on /v1/venues/search [LOW]
**File:** `_workspace/02_backend/api/tests/integration/venues_integration_test.go:27-45`
**Issue:** `TestVenueSearchReturns503WhenDisabled` calls `/v1/venues/search?q=daikoku` WITH a valid bearer token (`tok` from `mustRegister`), confirming the disabled-mode 503. There is NO test that calls the endpoint WITHOUT a token to confirm it 401s — i.e., no regression guard against a future refactor accidentally moving the route out of the authed group.
**Risk:** A future commit moves `r.Get("/venues/search", h.VenueSearch)` outside the `middleware.Auth(signer)` group (e.g. while reorganizing routes); the test suite passes because it doesn't check the unauthenticated case.
**Recommendation:** Add a one-liner test:
```go
func TestVenueSearchRequiresAuth(t *testing.T) {
    srv := newServer(t); defer srv.Close()
    code, _ := doReq(t, srv, http.MethodGet, "/v1/venues/search?q=x", "", nil)
    if code != http.StatusUnauthorized { t.Fatalf("want 401, got %d", code) }
}
```

---

## Summary

| Severity | Count |
|---|---|
| CRITICAL | 0 |
| HIGH | 3 (SEC-001, SEC-002, SEC-006) |
| MEDIUM | 2 (SEC-003, SEC-004) |
| LOW | 4 (SEC-005, SEC-007, SEC-008, SEC-012) |
| INFO | 3 (SEC-009, SEC-010, SEC-011) |

**Cross-reviewer messages sent:**
- → `arch-reviewer`: SEC-002 (venue upsert bypasses the Foursquare-truth boundary); SEC-006 (JWT-is-authoritative decision is global)
- → `perf-reviewer`: SEC-004 (dedicated /v1/venues/search limiter has perf upside); SEC-006 (per-request DB check for deleted_at would be expensive — token-revocation cache pattern proposed)

**Top fix order (by ROI):**
1. SEC-001 + SEC-002 together — both touch the same `domain.CheckinVenue` + venue upsert path. One-PR fix: add a `Validate()` method to `CheckinVenue`, change the upsert to first-writer-wins (or cache-truth-wins), add a backstop CHECK migration. ~50 LOC.
2. SEC-004 — add a dedicated 5 rps / burst 10 limiter on `/v1/venues/search`, and refuse to boot with `APP_ENV=production && RATE_LIMIT_DISABLED=1`. ~10 LOC.
3. SEC-006 — confirm refresh-token revocation on DeleteMe (Phase 2 verification) + reduce access-token TTL OR introduce a token-revocation cache. Larger; not a Phase 4 regression but exacerbated by it.
