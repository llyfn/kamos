# QA Report — Phase 7 Flutter (per-layer; backend still in-flight)

Date: 2026-05-17
Scope: Phase 7 Flutter HTTP-cache slice — two commits.
- `94ee071` — `dio_cache_interceptor: ^4.0.6` mounted on the authed `dioProvider`
  (`lib/core/api/api_client.dart`), with `_buildCacheOptions()` + interceptor
  ordering and an explicit doc-block covering the cache contract.
- `b55227b` — `cache_extras.dart` exposing `kBypassCache` as a per-request
  opt-out sentinel + `core_api_cache_test.dart` covering the fresh-cache-hit
  and stale-revalidation-via-If-None-Match paths.

Verdict: **PASS WITH MAJOR** (one MAJOR privacy concern + one MAJOR cache-
lifecycle concern; ship-able only if both are addressed before promoting to a
release branch).

`flutter analyze` → "No issues found! (ran in 2.0s)". `flutter test
test/core_api_cache_test.dart` → 2/2 PASS. The cache behaves as advertised in
the happy path; the concerns below are about what happens at the boundary
between sessions, users, and offline conditions.

---

## Key cache-key question, answered up front

**Does the cache key include `Authorization`? NO.**

`CacheOptions.defaultCacheKeyBuilder` at
`~/.pub-cache/hosted/pub.dev/http_cache_core-1.1.3/lib/src/model/cache/cache_options.dart:74-80`
is:

```dart
static String defaultCacheKeyBuilder({
  required Uri url,
  Map<String, String>? headers,
  Object? body,
}) {
  return _uuid.v5(Namespace.url.value, url.toString());
}
```

The signature accepts `headers` and `body`, but the implementation only
UUID-v5-hashes the URL string. `Authorization` is **never** part of the key.

The interceptor does pass flat headers to `keyBuilder` (see
`dio_cache_interceptor-4.0.6/lib/src/dio_cache_interceptor_cache_utils.dart:123-129`),
so a custom `keyBuilder` could fold the token in — but the production code
uses the default. Two users on the same device hitting the same URL share a
cache entry.

**The system is NOT entirely unsafe** — privacy on the wire-side is preserved
in the online path because the backend stamps `Cache-Control: private,
must-revalidate` on every viewer-varying endpoint (`/v1/users/{username}`) and
strong, body-derived ETags on every GET response (`router.go:49`'s global
ETag mount + `etag.go:65-67`'s `SHA-256(body)`). On revalidation the server
runs the handler with the *current* viewer's JWT, computes a fresh ETag, and
either echoes the cached body (304, ETags match → same viewer → same body) or
returns a fresh 200 (different viewer → different body → ETag mismatch).

**Where the safety net tears: `hitCacheOnNetworkFailure: true`.** If User A
fetches `/v1/users/me` (or `/v1/feed`, or any other authed GET), then logs
out, then User B logs in *offline*, the client serves User A's cached body
without revalidating, because the request fails with `connectionError` and
the interceptor's `onError` (`dio_cache_interceptor.dart:137-155`) resolves
with the cached `Response`. The cache key is URL-only, so the cache entry is
visible to User B. This is the MAJOR finding below.

---

## Lens 1 — Integration boundaries

- **Two Dio instances, two roles**: PASS. `dioProvider` (authed singleton,
  `api_client.dart:97`) is the only Dio with `DioCacheInterceptor` installed.
  `refreshDioProvider` (`api_client.dart:81`) is bare — no auth, no cache —
  and is the Dio that posts to `/v1/auth/refresh`, so a refresh-call 401 can
  never recurse into the refresh path. The R2 presigned-PUT path in
  `CheckInRepository._rawDio = Dio()` (`checkin_repository.dart:58`) is a
  third, fresh, interceptor-less Dio — no cache, no auth, as intended for
  the signed URL. **R2 traffic does not contaminate the cache** and the cache
  does not see the refresh exchange.
- **Interceptor order**: PASS. `DioCacheInterceptor` is added **first**
  (`api_client.dart:155`), then `AuthInterceptor` (`api_client.dart:156`).
  On `onRequest` Dio walks interceptors in registration order, so a cache hit
  short-circuits via `handler.resolve(...)` (`dio_cache_interceptor.dart:69-72`)
  **before** `AuthInterceptor.onRequest` attaches the bearer token or
  triggers any refresh logic. A cached 200 therefore never goes through the
  refresh dance. The doc-comment at `api_client.dart:149-154` describes this
  correctly.
- **Auth-failure flow on cache miss**: PASS. On a cache miss the request
  hits the network; on a 401, Dio walks interceptors in **reverse** for
  `onError`, so `AuthInterceptor` sees the 401 first. The cache interceptor's
  `onError` would only act if the response status is 304 or
  `hitCacheOnErrorCodes` includes the code — both are not 401, so the
  cache interceptor's `onError` falls through to `handler.next(err)` and the
  401 reaches `AuthInterceptor`, refresh fires, request retries. **The
  interceptor does NOT swallow auth failures.** The agent's claim is
  correct.
- **304 reconstruction**: PASS in test; verified by reading the package. On
  a stale entry the strategy attaches `If-None-Match: "<etag>"` to the
  outgoing request (`cache_strategy.dart` builds the conditional request
  from the stored ETag). The server returns 304; the cache interceptor's
  `onResponse` (`dio_cache_interceptor.dart:107-114`) loads the cached
  body, updates headers from the 304, and returns it as a synthetic 200.
  The test exercises this exactly. Note: the production Dio has
  `validateStatus: (s) => s >= 200 && s < 300` which would treat the on-wire
  304 as an error — but that's fine because the cache interceptor's `onError`
  handler (`dio_cache_interceptor.dart:125-158`) catches 304 explicitly via
  `isCacheCheckAllowed` (`http_cache_core/.../cache_utils.dart:5-18`,
  `if (statusCode == 304) return true`), loads the cached body, and resolves
  with it. The test uses `validateStatus: < 400` which lets the 304 flow
  through `onResponse` instead — a different code path. Both paths work, but
  **the production code path is exercised only via `onError`**, not the test.
  See MINOR #1.
- **`CachePolicy.request` semantics**: PASS. From
  `dio_cache_interceptor.dart:38-43`: with `policy=request`, the interceptor
  consults the cache on every request and uses `CacheStrategyFactory` to
  decide between serve-fresh vs. revalidate. Freshness comes from the
  server's `Cache-Control: max-age=N` (`cache_response.dart:155-159`); if
  there is no max-age, freshness is 0 and every request revalidates. This
  matches the documented contract.
- **`allowPostMethod: false`**: PASS. Default is already false
  (`cache_options.dart:69`); the explicit set keeps the contract loud, which
  is correct hygiene. `_shouldSkip` (`dio_cache_interceptor_cache_utils.dart:35-39`)
  skips any non-GET when `allowPostMethod` is false. POST/PATCH/DELETE
  never see the cache. Verified.
- **Backend Cache-Control mounted only where listed**: PASS, with one
  observation that drives MAJOR #1. The backend mounts `middleware.ETag`
  **globally** on every route (`router.go:49`), and per-route `CacheControl`
  on five endpoints (`/v1/categories`, `/v1/flavor-tags`,
  `/v1/beverages/{id}`, `/v1/breweries/{id}`, `/v1/users/{username}`). The
  doc-block in `api_client.dart:28-43` lists exactly those five as "cached
  on the client". **But** because ETag is global, every other GET response
  also carries an ETag. The cache strategy considers any response with an
  ETag cacheable (`cache_strategy.dart:166-173`: `result = response.headers
  [etagHeader] != null`), so in practice **every GET is cached on the
  client**, just with freshness=0 → forced revalidation. That includes
  `/v1/users/me`, `/v1/feed`, `/v1/check-ins/{id}`, `/v1/check-ins/{id}/
  comments`, `/v1/collections/{id}`, etc. The doc-block under-describes
  what is actually cached. See MAJOR #1.

## Lens 2 — Architecture

- **`kBypassCache` is `final`, not `const`** — and that's correct, not a
  bug. The task wording asks "is it actually `const`?" — the source at
  `cache_extras.dart:36` declares
  `final Map<String, dynamic> kBypassCache = const CacheOptions(...).toExtra();`.
  The `const` keyword binds to the `CacheOptions` constructor, not the
  returned `Map`. `toExtra()` (`cache_option_extension.dart:12-14`)
  constructs a new `Map<String, dynamic>` at call time, so the result
  *cannot* be `const`. `final` is the right call. The variable is
  effectively immutable from the caller's side because Dio copies
  `Options.extra` before merging (`options.dart:331-333`,
  `Map<String, dynamic>.from(baseOpt.extra)`), so no caller can mutate the
  shared map. Shared safely.
- **MemCacheStore lifetime crosses sessions (MAJOR)**. `dioProvider` is a
  plain `Provider<Dio>` (`api_client.dart:97`). Riverpod holds the same Dio
  instance — and therefore the same `MemCacheStore` — for the entire app
  process. Nothing invalidates `dioProvider` on logout:
  - `AuthStateNotifier.logout()` (`auth_state.dart:66-72`) calls
    `storage.clearAll()` and flips the state flag. It does **not**
    `ref.invalidate(dioProvider)`.
  - `AuthInterceptor` on a refresh failure clears tokens but does not
    invalidate the Dio.
  - A repo-wide search for `ref.invalidate(dioProvider)` returns zero hits.

  Consequence: User A signs in, fetches `/v1/users/me`, then logs out. The
  cached body for `/v1/users/me` is still in `MemCacheStore`, keyed by the
  URL only. User B signs in on the same device. On the next online fetch
  of `/v1/users/me`, the interceptor will revalidate (freshness=0) and the
  server will return 200 with User B's body (ETag mismatch) — privacy held.
  **But offline:** if User B's device is offline (or hits a connect/send/
  receive timeout) at that moment, `hitCacheOnNetworkFailure: true`
  resolves the cached User A response. **User B sees User A's
  `/v1/users/me`, `/v1/feed`, `/v1/check-ins/{id}`, and every other
  previously-cached GET.** This is the MAJOR privacy concern.

  Fix options (in increasing rigor):
  1. **Minimum:** call `ref.invalidate(dioProvider)` from
     `AuthStateNotifier.logout()` AND from `onUnauthorized()`. That destroys
     the old Dio (and its closure-held `MemCacheStore`), Riverpod rebuilds
     a fresh one on next read.
  2. **Better:** set `hitCacheOnNetworkFailure: false` for any authed
     endpoint. The four genuinely-public taxonomy/detail endpoints
     (categories, flavor-tags, beverages, breweries) can keep stale-on-
     network-failure because they don't vary by viewer; the rest should not.
     But the global Dio singleton means this is per-route via `Options(extra:
     ...)` per request, which is a big surface to retrofit.
  3. **Best:** a custom `keyBuilder` that folds the access-token's user-id
     claim (or a short device-bound user marker) into the cache key. Then
     User A's entries and User B's entries are in different namespaces from
     birth. This is also what defends against unforeseen offline edge cases
     long-term.

- **Singleton interceptor + injection**: PASS (mechanism). The
  `interceptor.retryDio = dio` self-reference on `api_client.dart:148` is a
  known late-init dance and is documented at `auth_interceptor.dart:60-65`.
  Adding `DioCacheInterceptor` did not change this.
- **No per-feature cache leakage into the data layer**: PASS. Repositories
  call `dio.get(...)` and get a `Response<dynamic>` back. They have no
  knowledge of caching. The only feature-layer touch-point would be the
  `kBypassCache` opt-out — which is currently NOT invoked anywhere in the
  codebase (grep confirms zero call sites in `lib/`). See MINOR #2.

## Lens 3 — Coding conventions

- **Naming**: PASS. `kBypassCache` matches the existing constant style
  (e.g. `kIsGoogleConfigured` in the same surface area). Lowercase-prefix
  `k` for top-level immutables is the Flutter idiom.
- **Documentation**: PASS in shape, **under-describes scope** in content.
  `api_client.dart:28-62` is a well-organised cache contract — explains the
  policy choice, the `hitCacheOnNetworkFailure` tradeoff, why
  `hitCacheOnErrorCodes` is empty, why `allowPostMethod` is loud, and how
  to opt out per request. `cache_extras.dart:1-23` documents the sentinel
  rationale clearly. **But:** the contract claims only five endpoints are
  cached, when in practice every GET response with an ETag is cached
  (which, given the global ETag mount, is every GET). The "Never cached"
  bullet list is wrong on that point — `/v1/feed`, `/v1/users/me`,
  `/v1/check-ins/{id}` etc. ARE cached, they just have freshness=0 and
  always revalidate online. See MINOR #3.
- **`pubspec.yaml` pin**: PASS. `dio_cache_interceptor: ^4.0.6` (`pubspec.yaml:25`),
  `pubspec.lock` resolves to exactly `4.0.6` (`pubspec.lock:212-219`).
  Transitive `http_cache_core: 1.1.3`, `uuid` for the key builder — all
  vendored in the lockfile.
- **Magic numbers / constants**: PASS. The `5 * 1024 * 1024` MemCacheStore
  cap (`api_client.dart:68`) and `Duration(days: 7)` maxStale
  (`api_client.dart:72`) appear once each, near their doc-comments. The
  arithmetic comment "5 MB cap" makes the byte literal scannable. The
  7-day maxStale is documented as "respect what the server says"
  (`api_client.dart:46-50`), but the actual semantic is "request-side cap
  on how stale a server entry can be before we refuse it" — not "force
  refresh after 7 days". See MINOR #4.

## Lens 4 — Performance / security spot-checks

- **Cache key includes Authorization? NO.** Already discussed at the top.
  This is the load-bearing finding for the user-isolation question.
  Authorization is passed to `keyBuilder` but the default builder ignores
  it. Two users on the same device share a cache namespace.
- **5 MB MemCacheStore cap**: PASS. Per-instance, in-memory, LRU. Plenty
  for KB-sized JSON responses; not so big that it pressures small Android
  devices.
- **`maxStale: 7 days`**: NUANCED. This is the **request-side** maxStale
  fed to `CacheOptions` (`api_client.dart:72`). Per the package's
  `cache_response.dart:86-89`, a response carrying `must-revalidate`
  **ignores** the request's maxStale entirely:
  ```dart
  final maxStaleMillis = (!cacheControl.mustRevalidate &&
      rqCacheCtrl.maxStale > -1) ? rqCacheCtrl.maxStale * 1000 : 0;
  ```
  So for `/v1/users/{username}` (`private, must-revalidate`) and any other
  server-marked-must-revalidate response, the 7-day maxStale is moot —
  every request revalidates. For the four public taxonomy/detail
  endpoints (`max-age=300/600/3600` with no `must-revalidate`), the
  request-side maxStale extends the freshness window by up to 7 days when
  online with a working cache. But the `policy=request` path computes
  `isExpired(rqCacheCtrl)` (`cache_response.dart:77-98`) and only serves
  stale if `ageMillis + minFresh < freshMillis + maxStaleMillis`. The
  net effect: when online and the server-side max-age has elapsed but is
  within 7 days of stored maxStale, the cache will serve stale immediately
  rather than revalidate. That's a deliberate offline-friendly tradeoff,
  but it means **a public beverage detail can be served stale for up to
  7 days** without round-tripping, even online. For categories/flavor-tags
  this is fine; for `/v1/beverages/{id}` whose `avg_rating` /
  `check_in_count` drift on each new check-in, this means a user could see
  numbers up to a week behind on a cache hit. See MINOR #5.
- **`hitCacheOnNetworkFailure: true`** drives MAJOR #2 (privacy across
  sessions when offline) and also has a benign offline-friendly effect for
  public taxonomy data (categories on a flaky network → serve the cached
  list). Both effects live on the same flag; the privacy concern is the
  important one.
- **No-cache on POST/PATCH/DELETE**: PASS. Confirmed in
  `dio_cache_interceptor_cache_utils.dart:35-39`. The agent's claim that
  `allowPostMethod: false` enforces this is correct (and that default
  alone would have already enforced it — the explicit set is just hygiene).
- **`kBypassCache` is dead code today**: a grep across `lib/` shows zero
  call sites. No pull-to-refresh handler uses it. Defensible as belt-and-
  suspenders, but the doc-comment claim that it's used for "pull to
  refresh" is aspirational — no such call site exists. See MINOR #2.
- **Cache leak across log-out / log-in (same user)**: PASS in the online
  case. After User A logs out and logs back in, their cached entries are
  still valid for them (same identity, same JWT claims, same ETags). The
  cache is genuinely useful here.
- **Cache leak across log-out / log-in (different user, ONLINE)**: PASS,
  via the server's body-derived ETag. Different viewer → different body →
  different ETag → server returns 200 with the right body. The cached
  entry is overwritten with the new body. Note this requires the server
  to actually emit `must-revalidate` (or `max-age=0`) on every viewer-
  varying endpoint. If a future endpoint emits `private, max-age=60`
  without `must-revalidate`, the cache could serve cross-user data for up
  to 60 seconds. This is a forward-looking constraint, not a current bug.
- **Cache leak across log-out / log-in (different user, OFFLINE)**:
  MAJOR #2. Cached entry served via `hitCacheOnNetworkFailure: true`,
  no revalidation possible, User B sees User A's data.
- **No JWT / secret in cache key**: PASS. The default `keyBuilder` is
  URL-only; even if it folded headers in, the test setup doesn't write
  `Authorization` because the test runs against a stub adapter without
  the auth interceptor. But this is also the failure mode — see MAJOR #2.
- **`pubspec.lock` integrity**: PASS. `dio_cache_interceptor` is a
  `direct main` dependency, sha256 pinned, transitives resolved cleanly.
- **No new platform-specific code paths**: PASS. `MemCacheStore` is pure
  Dart; no iOS/Android channels, no Hive, no SQLite. The package's
  optional `DbCacheStore` / `FileCacheStore` are not imported.
- **Tests cover happy paths only**: NUANCED. Both test scenarios fire
  through `onResponse` (because the test's Dio uses `validateStatus: < 400`).
  The production Dio (`< 300`) hits `onError` for 304s. A redundant test
  with `validateStatus: < 300` would lock in the production code path.
  See MINOR #1.

---

## BLOCKERs

None.

## MAJORs

1. **Cache contract under-describes what's cached.** The doc-block at
   `api_client.dart:28-43` names five endpoints as "Cached on the client",
   and lists everything else (auth, mutations, `/v1/feed`, etc.) under
   "Never cached". In practice, the backend's global `middleware.ETag`
   mount (`router.go:49`) means **every GET response carries an ETag**, and
   the cache strategy treats every ETagged response as cacheable
   (`cache_strategy.dart:166-173`). So `/v1/users/me`, `/v1/feed`,
   `/v1/check-ins/{id}`, `/v1/check-ins/{id}/comments`, `/v1/collections
   /{id}`, `/v1/discover/public-collections`, `/v1/search`, etc. all get
   cached on the client, with freshness=0 → forced revalidation each
   request. That's actually fine *online* (the server's ETag check is the
   privacy boundary), but the contract should say so, because the cached
   surface is much larger than the five-endpoint list suggests — and that
   larger surface is exactly what makes MAJOR #2 worse.

   Fix: rewrite the doc-block to reflect actual behavior. Two-tier:
   (a) "explicitly freshness-windowed by the server" (the five listed
   endpoints; cache hit short-circuits the network), and (b) "ETag-only,
   forced revalidation each call" (every other GET; revalidation costs ~0
   on a 304 but the cached body is still on disk/in memory for the
   `hitCacheOnNetworkFailure` path). Tying the doc to the actual cache
   surface makes MAJOR #2 visible and forces a decision on it.

2. **`MemCacheStore` outlives the auth session and `hitCacheOnNetwork
   Failure: true` leaks cross-user data offline.** The Dio singleton is
   created once at app start; `MemCacheStore` lives in its closure;
   `dioProvider` is never invalidated on logout
   (`auth_state.dart:66-72` + `auth_interceptor.dart:138-143`); the cache
   key is URL-only with no `Authorization` ingredient
   (`http_cache_core/.../cache_options.dart:74-80`). Consequence:
   - **Online:** safe, because the server's body-derived ETag + the
     `must-revalidate` directive on viewer-varying routes forces a fresh
     200 when the viewer differs.
   - **Offline (or any connect/send/receive timeout):** the interceptor's
     `onError` returns the cached body without revalidation
     (`dio_cache_interceptor.dart:137-155` + `cache_utils.dart:9-10` —
     `statusCode == null && hitCacheOnNetworkFailure → return true`).
     User B sees User A's `/v1/users/me`, `/v1/feed`,
     `/v1/check-ins/{id}`, and any other authed GET that User A fetched
     before logging out.

   This is a real privacy bug, not theoretical: an airplane-mode
   handoff between two users on a shared device leaks personal feed
   contents and account info.

   Fix (minimum, surgical): invalidate `dioProvider` on logout AND on
   unauthorized. Two lines:
   ```dart
   // In AuthStateNotifier.logout(), after storage.clearAll():
   ref.invalidate(dioProvider);
   // In AuthStateNotifier.onUnauthorized():
   ref.invalidate(dioProvider);
   ```
   That destroys the closure-held `MemCacheStore`. Riverpod rebuilds a
   fresh Dio (and fresh cache) on next read. Costs: every repository
   provider that read the old `Dio` instance will need to re-read the
   provider — which they do already, since they read via `ref.read(dio
   Provider)` at construction. There may be a few repos that hold the Dio
   handle in a long-lived field; those need a re-read on auth change.

   Fix (better, defense-in-depth): add a custom `keyBuilder` that folds the
   current access token's user-id claim into the URL hash, so the cache is
   physically namespaced per user. Even if the provider invalidation
   misses, cross-user reads can't collide.

## MINORs

1. **Test code path diverges from production code path**. The test's
   Dio uses `validateStatus: (s) => s >= 200 && s < 400`
   (`core_api_cache_test.dart:88`), so the 304 flows through Dio's
   `onResponse` chain. The production Dio
   (`api_client.dart:105`) uses `(s) => s >= 200 && s < 300`, so the 304
   flows through `onError`. Both paths exist in the cache interceptor
   and both work; but a second test fixture with `validateStatus: < 300`
   would lock in the **production** code path against future package
   changes. Cheap to add — copy the existing test and tighten the validator.

2. **`kBypassCache` is unused.** `grep -rn "kBypassCache" lib/` finds
   only the declaration in `cache_extras.dart:36`. No pull-to-refresh
   handler invokes it. The doc-comment claims it's used "e.g. a
   'pull to refresh' gesture" (`cache_extras.dart:10-12`), but no such
   call site exists. Either wire it into the existing pull-to-refresh
   surfaces (feed, discover, collections list, brewery list — most of
   those are pre-existing `RefreshIndicator` widgets) or downgrade the
   doc-comment from "in use for" to "available for future use by".

3. **Doc-block at `api_client.dart:28-43` misrepresents the cached
   surface.** Says five endpoints are "cached"; in fact every GET with an
   ETag is. Update text — see MAJOR #1 fix.

4. **`maxStale: 7 days` is request-side, not response-side.** The
   doc-comment at `api_client.dart:71-72` says "lets the client serve a
   stale body when the network is unreachable" — true, but the same flag
   *also* allows the client to serve stale data online for up to 7 days
   when the server emits `max-age=N` without `must-revalidate`. That
   applies to `/v1/beverages/{id}` (max-age=300) and `/v1/breweries/{id}`
   (max-age=600), neither of which sets `must-revalidate`. So an
   authoritative read of a beverage with rapidly-changing aggregates
   (`avg_rating`, `check_in_count`) could be 7 days behind on a cache
   hit. Probably fine for MVP (the aggregates are mostly stable on a
   minute-by-minute basis), but the contract should be honest about the
   "online stale serve" window. Either tighten `maxStale` to e.g. 24h on
   the global config, or pass per-request `maxStale` via `Options(extra:
   ...)` on the few endpoints where freshness matters.

5. **Cache MemStore not bounded by entry count.** `MemCacheStore(maxSize:
   5 * 1024 * 1024)` is byte-bounded only. A flood of small responses
   (e.g., 1000 distinct `/v1/beverages/{id}` lookups during a search
   session, each ~5 KB) is well under the cap, but the LRU eviction logic
   is whole-entry only. Probably never a real-world bottleneck; flagging
   for completeness.

6. **`pubspec.yaml:25` comment says "swap to a Hive-backed store later if
   offline reads become a requirement"** — but `hitCacheOnNetworkFailure:
   true` is already in place, which makes offline reads a partial reality
   today (in-memory only, lost on app restart). Either tighten the
   comment to "swap to a persistent store" or set the flag to false until
   the persistent store lands and the privacy gating is solved
   (MAJOR #2). The flag and the comment disagree.

## Backlog (cosmetic, defer)

- `api_client.dart:74` — passing `keyBuilder: CacheOptions.default
  CacheKeyBuilder` explicitly is redundant (it's the default, same
  argument as for `allowPostMethod: false`). Keeping it explicit for
  loudness is fine — note in passing.
- `core_api_cache_test.dart:48` — manually reading two header casings
  (`'if-none-match'` and `'If-None-Match'`) is defensive but the
  package canonicalises header keys lowercase before sending; the
  uppercase branch is dead.
- `api_client.dart:67-68` — the comment "Phase 7 sticks to in-memory to
  avoid the platform-specific filesystem code path" is accurate but
  `dio_cache_interceptor` ships pure-Dart `FileCacheStore` as well; the
  platform-specific note is overstated. The real reason is simpler:
  in-memory is enough for Phase 7's read-heavy taxonomy endpoints.

---

## Test counts

- New: 2 tests in 1 file (`core_api_cache_test.dart`).
- `flutter analyze`: clean (No issues found).
- `flutter test test/core_api_cache_test.dart`: 2/2 PASS.
- Full suite not re-run in this slice; if backend QA hasn't already
  triggered one, recommend `flutter test` before promoting.

---

**Net:** the Phase 7 wiring is mechanically correct — interceptor order is
right, the auth + refresh + cache interaction is sound, R2 upload is
isolated, the test set captures the happy path. **The cache key does NOT
isolate users; user isolation depends entirely on (a) the server's
must-revalidate + body-ETag combo and (b) the device being online.** The
backend invariant holds today on every viewer-varying endpoint, so the
online path is safe. The offline path is **not** safe — `hitCacheOnNetwork
Failure: true` plus a never-invalidated `dioProvider` plus a URL-only cache
key means User B can read User A's last-cached responses from local memory
after a device handoff. That's the MAJOR. The fix is two `ref.invalidate
(dioProvider)` lines in `AuthStateNotifier.logout()` and
`onUnauthorized()`, plus an honest rewrite of the cache-contract doc-block.
Recommend resolving both MAJORs before promoting Phase 7 to a release
branch.
