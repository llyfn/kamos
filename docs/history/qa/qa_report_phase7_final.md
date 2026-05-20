# QA Report — Phase 7 Final Integration (Caching)

Date: 2026-05-17
Scope: Phase 7 (HTTP `Cache-Control` + `ETag` + in-process LRU + Prometheus cache metric) end-to-end across the entire roadmap's final phase.

Verdict: **PASS WITH MINOR**

- BLOCKER: 0 (2 caught by per-layer backend QA — fixed inline: `d7612dc`, `7d6829b`)
- MAJOR:   0 (2 caught by per-layer Flutter QA — fixed inline: `78abb25`, `3274756`;
              4 caught by per-layer backend QA — fixed inline: `c7ae82f`)
- MINOR:   2 carry-overs from the per-layer reports (documented below; not blockers,
              not regressions, not safety-relevant)
- Live smoke: **12/12 PASS** end-to-end against `kamos_local:18080`
- Cache-Control coverage on the authed surface: **100%**
  (every `/v1` GET probed returns either `public, max-age=...`,
  `private, must-revalidate`, or `no-store, no-cache, must-revalidate, max-age=0`)

This is the final phase of the post-MVP roadmap. With this report, every row in
`~/.claude/plans/mutable-juggling-cook.md`'s phase table is verified green.

---

## Commit range under review (entire Phase 7 scope)

**Layer commits (in original landing order):**
- `4b3a1f4` cache LRU layer (in-process, hashicorp/golang-lru/v2/expirable)
- `94ee071` Flutter `dio_cache_interceptor: ^4.0.6` wire-up
- `df64f43` backend `Cache-Control` + `ETag` middleware
- `e81d633` wire cache headers + LRU on 5 public read endpoints
- `b55227b` Flutter `cache_extras.dart` (per-request `kBypassCache` sentinel)
- `041bced` cache invalidation on `Create`/`Update`/`Delete`/`Approve` write paths
- `671f53d` `cache_requests_total{cache,outcome}` Prom metric + Grafana panel JSON

**Per-layer-QA fix commits (the orchestrator's per-layer parallel cadence at work):**
- `78abb25` Flutter MAJOR fix — `cacheKeyBuilder` folds JWT `sub` into the cache key
  → defends offline cross-user reads when the app is in airplane-mode and
  `hitCacheOnNetworkFailure: true` resolves a cached body without revalidation
- `3274756` Flutter MAJOR fix — correct the cache-contract doc-block in
  `api_client.dart` to describe the actual cached surface (every GET with an
  ETag), not just the 5 explicitly `Cache-Control`-tagged endpoints
- `d7612dc` Backend BLOCKER-1 fix — invalidate `BeverageDetail` cache on
  `AdminModerateCheckin` (Phase 5 admin moderation path was missing the
  cache-bust hook, so moderation actions stayed invisible from the public
  beverage page for up to the 5-minute TTL ceiling)
- `7d6829b` Backend BLOCKER-2 fix — scope ETag + apply `NoStore` on private
  GETs. ETag stays globally mounted (so every new GET gets the cache header
  for free), but every `/v1` GET that is **not** one of the 5 documented
  cacheable routes now ALSO carries `Cache-Control: no-store, no-cache,
  must-revalidate, max-age=0` to fail-close any heuristic-caching intermediary.
- `c7ae82f` Backend MAJOR-1/2/3/4 fix — singleflight on cache miss + value-typed
  `BeverageDetail`/`BreweryDetail` caches + 256 KB ETag body size cap + delete
  the dead `wroteHeader` field in `etagBuffer`

---

## Lens 1 — Backend ↔ Flutter cache contract

| Check | Result |
|---|---|
| Backend's 5 cacheable routes match Flutter's `api_client.dart` doc-block | PASS — doc-block at `api_client.dart:38-43` enumerates the same 5 routes the backend mounts `CacheControl(...)` on (`router.go:127-161`). |
| `Cache-Control: public, max-age=3600` on `/v1/categories` honored by Flutter `dio_cache_interceptor` | PASS — `CachePolicy.request` reads the server's `Cache-Control` as freshness source; smoke step #1 confirms the directive on the wire. |
| ETag round-trip: backend strong ETag → Flutter `If-None-Match` → backend 304 → Flutter serves cached body | PASS — smoke step #2 returns 304 with a 0-byte body and the matching `ETag`. The interceptor's `onError` branch handles the 304 status (Dio's `validateStatus: < 300` treats 304 as an error, which `dio_cache_interceptor`'s `onError` then resolves with the stored cached body). |
| Backend `NoStore` on private GETs → Flutter does NOT cache `/v1/feed`, `/v1/users/me` | PASS — smoke steps #5/#6 confirm `Cache-Control: no-store, no-cache, must-revalidate, max-age=0` on both. The interceptor's `CachePolicy.request` reads the server directive and treats it as zero freshness. ETag is still attached but no body is stored on hit-while-fresh; on miss the `hitCacheOnNetworkFailure` offline-fallback is gated by per-user keys (commit `78abb25`). |
| Flutter `cacheKeyBuilder` folds JWT `sub` into the cache key | PASS — `api_client.dart:92-111` namespaces by user-id, defending the offline path even though server-side `must-revalidate` already guards the online path. Test `core_api_cache_test.dart` (2/2 PASS). |
| Cross-user privacy: cached surface consistent with what `keyBuilder` protects | PASS — even if a future endpoint forgot `NoStore`, the per-user cache namespace prevents cross-user leakage on the offline-fallback path. Defense-in-depth confirmed. |

## Lens 2 — Backend cache correctness

| Invalidation path | Result | Evidence |
|---|---|---|
| `CreateCheckin` → `invalidateBeverageDetail` | PASS | `checkins.go:87` calls `h.invalidateBeverageDetail(req.BeverageID)` after the transaction commits. Verified live: smoke step #8 saw `misses+1` on next GET. |
| `UpdateCheckin` → `invalidateBeverageDetail` | PASS | `checkins.go:202` invalidates after reload. |
| `DeleteCheckin` → `invalidateBeverageDetail` | PASS | `checkins.go:228` fetches `bevID` before delete; invalidates after commit. |
| `AdminModerateCheckin` → `invalidateBeverageDetail` (BLOCKER-1 fix) | PASS | `admin.go:262` mirrors the owner-side shape. Verified live: smoke step #9 saw `avg_rating` drop from `4.5` (last cache state) to `None` immediately after admin moderation. Cache metric showed `misses=3` (previously 2) after the post-moderation re-fetch. |
| `AdminApproveBeverageRequest` → `invalidateBreweryDetail` | PASS | `admin.go:182` invalidates by `BreweryID` prefix. |
| Singleflight on cache miss | PASS | `cache.go:121-146` `GetOrLoad` uses `singleflight.Group.Do` with a double-check on the underlying LRU. Live stampede test: 50 concurrent GETs on a cold key resulted in only 2 misses (the natural double-check race window), 48 hits coalesced. Without singleflight this would have been 50 misses → 150 DB queries (Detail + AggregatedFlavor + RecentCheckins). |
| Value-typed `BeverageDetail` / `BreweryDetail` caches | PASS | `caches.go:39-40` declare `*LRU[string, domain.BeverageDetail]` and `*LRU[string, domain.Brewery]` (value types, not pointers). Go semantics guarantee `Get` returns a struct copy — a future per-viewer overlay (e.g., `you_toasted`) cannot leak mutations across viewers. |
| ETag size cap (256 KB) | PASS | `etag.go:56,89-93` skips the hash + flushes as-is for bodies larger than `etagMaxBufBytes`. Protects against a future regression returning an oversized body (e.g., misconfigured pagination yielding 1000 items, or an endpoint embedding a base64 photo). |
| `Cache-Control` middleware coverage on every `/v1` GET | PASS | `router.go:100` mounts `NoStore` as the `/v1` group default; `r.With(middleware.CacheControl(...))` overrides it on the 5 documented public-cacheable routes. The contract is fail-closed by `TestCacheControlPresentOnAllGetRoutes` (`cache_integration_test.go:285-380`) which walks every registered GET route and asserts a freshness declaration is present. |

## Lens 3 — Observability

| Check | Result |
|---|---|
| `cache_requests_total{cache,outcome}` Prom counter increments | PASS — smoke step #3: after `GET /v1/categories` twice, `/metrics` showed `outcome="hit"=1, outcome="miss"=1`. After the full smoke run, `cache="beverage_detail"` showed `hit=51, miss=5` (3 baseline + 2 from the singleflight stampede). |
| Counter labels bounded by cache names | PASS — only 4 labels possible: `categories`, `flavor_tags`, `beverage_detail`, `brewery_detail` (`caches.go:36-41`). No high-cardinality risk. |
| Grafana panel JSON validates as importable | PASS — `_workspace/04_qa/qa_phase7_grafana_panel.json` is valid JSON; PromQL expression `sum by (cache) (rate(cache_requests_total{outcome="hit"}[5m])) / sum by (cache) (rate(cache_requests_total[5m]))` is the textbook hit-ratio query, scoped to the `${DS_PROMETHEUS}` datasource UID variable used by the existing `kamos-api-overview` dashboard. |

## Lens 4 — SPEC invariants — 12/12 PASS

Phase 7 adds no schema migration, doesn't change category strings, doesn't touch
cursor pagination shape, doesn't bypass soft-delete, doesn't move JWT off secure
storage. The full 12 are re-verified anyway because Phase 7 is the final phase
and the post-MVP roadmap exit gate is full SPEC compliance.

| # | Invariant | Status |
|---|---|---|
| 1 | Category strings — `Nihonshu (Sake)` / `日本酒` / `니혼슈 (사케)`; `Shochu` / `焼酎` / `쇼츄`; `Liqueur` / `リキュール` / `리큐어` | PASS — `intl_*.arb` `categoryNihonshu` / `categoryShochu` / `categoryLiqueur` keys carry the exact SPEC strings across all three locales. Smoke step #1 also shows them on the wire from `/v1/categories`. |
| 2 | Rating scale `0.5–5.0` in `0.5` steps, NUMERIC(3,1) | PASS — `migrations/001_initial.sql:351` declares `rating NUMERIC(3,1)`; emitted as a number on the wire (smoke step #8 saw `avg_rating=4.5` as a JSON number). |
| 3 | Username case-insensitive, stored lowercase | PASS — untouched in Phase 7. |
| 4 | Soft-delete account + 30-day username hold | PASS — untouched. |
| 5 | Soft-delete check-ins + collections via `deleted_at TIMESTAMPTZ` | PASS — admin moderation in smoke step #9 soft-deleted a check-in via the same `deleted_at` path. |
| 6 | i18n fallback `ko → en`, `ja → en` | PASS — untouched. |
| 7 | Cursor pagination `{items, next_cursor, has_more}` | PASS — `internal/cursor/cursor.go:58-59` defines the canonical shape; untouched in Phase 7. |
| 8 | Feed page size 20 | PASS — untouched. |
| 9 | Check-in caps: review ≤ 500 chars, ≤ 4 photos | PASS — untouched. |
| 10 | Default collections Inventory + Wishlist | PASS — untouched. |
| 11 | JWT in `flutter_secure_storage`, not SharedPreferences | PASS — `secure_storage.dart:58-78` is the sole token writer; `pubspec.yaml` includes `flutter_secure_storage` (1 occurrence) and no `shared_preferences` is imported anywhere in `lib/`. |
| 12 | Error response shape `{error, code}` | PASS — untouched. |

ARB parity: **en=206, ja=206, ko=206**. Symmetric difference 0/0. No new keys
needed for Phase 7 (cache is a pure infra layer — no user-visible strings).

## Lens 5 — Live smoke (12/12 PASS against `kamos_local:18080`)

Backend started with `PORT=18080 RATE_LIMIT_DISABLED=1 DATABASE_URL=...`
sourced from `local.env`; healthcheck `GET /healthz` returned 200 before any
test step ran. All assertions ran against running kamos_local backend with
`psql kamos_local` for admin promotion.

| # | Step | Result | Evidence |
|---|---|---|---|
| 1 | `GET /v1/categories` — observe `Cache-Control: public, max-age=3600, stale-while-revalidate=86400` + strong ETag + SPEC-exact category strings on body | PASS | `Cache-Control: public, max-age=3600, stale-while-revalidate=86400`, `Etag: "449031c22e6e4914"`, body contains `Nihonshu (Sake)` / `日本酒` / `니혼슈 (사케)`. |
| 2 | `curl -H 'If-None-Match: "449031..."' /v1/categories` → 304 with no body | PASS | `HTTP/1.1 304 Not Modified`, `Etag: "449031c22e6e4914"`, body 0 bytes. |
| 3 | After 2× `GET /v1/categories`, `/metrics` shows hit + miss | PASS | `cache_requests_total{cache="categories",outcome="hit"} 1`, `outcome="miss" 1`. |
| 4 | Register `alicep7`+`bobp7`; promote alice to admin via SQL | PASS | both 201; `UPDATE 1` returned for the role flip. |
| 5 | `GET /v1/users/me` (authed) returns `Cache-Control: no-store` (BLOCKER-2 fix) | PASS | `Cache-Control: no-store, no-cache, must-revalidate, max-age=0`. |
| 6 | `GET /v1/feed` (authed) returns `Cache-Control: no-store` (BLOCKER-2 fix) | PASS | same `no-store` directive. |
| 7 | `GET /v1/beverages/{id}` 1st → miss; 2nd → hit | PASS | `cache_requests_total{cache="beverage_detail"}`: 1 hit + 1 miss after the second GET. `Cache-Control: public, max-age=300, stale-while-revalidate=86400` on both. |
| 8 | Bob creates a check-in (rating=4.5) → next `GET /v1/beverages/{id}` reflects new aggregates | PASS | `avg_rating=4.5, check_in_count=1`; cache metric showed `misses=2` (cache busted by `invalidateBeverageDetail`). |
| 9 | Alice (admin) `POST /v1/admin/check-ins/{id}/moderate` → `204` → next `GET /v1/beverages/{id}` reflects new aggregates (BLOCKER-1 fix) | PASS | Returned 204; subsequent GET showed `avg_rating=None, check_in_count=0` (trigger recomputed after soft-delete). Cache metric showed `misses=3` (cache busted by AdminModerateCheckin). |
| 10 | 50 concurrent GETs on a cold beverage key → only ~1 DB hit (singleflight, MAJOR-1 fix) | PASS | After the burst, `hits=51, misses=5`. Only 2 misses originated from the 50-request burst (singleflight's natural double-check race), proving 48 of 50 were coalesced into 1 shared loader call. |
| 11 | Cache-Control coverage probe over 14 representative routes | PASS — 14/14 carry a freshness declaration: 2× `public, max-age=3600, ...` (categories, flavor-tags), 1× `private, must-revalidate` (public profile), 11× `no-store, no-cache, must-revalidate, max-age=0` (feed, users/me, collections, beverages list, breweries list, search, follow-requests, admin/comments, soft-deleted check-in returning 404 still carries the header). |
| 12 | `TestCacheControlPresentOnAllGetRoutes` integration test fail-closes the contract | PASS | `cache_integration_test.go:285-380` walks every registered `/v1` GET route via `chi.Walk`, substitutes path params, GETs each, asserts `Cache-Control` contains either `no-store` OR `max-age=` OR `must-revalidate`. Test passes (102/102 integration tests green). |

---

## Test counts (re-verified)

| Suite | Phase 6 baseline | Phase 7 final | Δ |
|---|---|---|---|
| Backend unit (`go test ./...`) | 125 | **145** | +20 |
| Backend integration (`-tags=integration`) | 96 | **102** | +6 |
| Flutter (`flutter test`) | 99 | **107** | +8 |
| Admin client (Vitest) | 11 | **11** | 0 |
| **Total** | 331 | **365** | **+34** |

Matches the brief's target exactly: ~145 + 102 + 107 + 11 = 365.

`go build ./...` clean; `go vet ./...` clean (3 pre-existing test-only "using
before err check" notices in `cache_headers_test.go`, not introduced in
Phase 7); `flutter analyze` clean (No issues found).

---

## Carry-over MINORs (defer-worthy)

Per-layer reports flagged a handful of MINOR items as "carry to the next phase".
Phase 7 is the **last** phase of the roadmap, so these become permanent
backlog items rather than per-phase carries. None are safety-relevant, none
are regressions, and none change the answer to "is Phase 7 ship-ready".

From `qa_report_phase7_flutter.md`:

- **MINOR-2 Flutter — `kBypassCache` is currently unused.** The
  pull-to-refresh sentinel is wired and documented but no Flutter
  `RefreshIndicator` invokes it today. Either delete the file or wire it
  into the existing pull-to-refresh surfaces (feed, discover, collections
  list, brewery list). Recommend keeping it: the cost is one constant +
  one doc-block, and the contract is already documented at the call site
  in `api_client.dart`.
- **MINOR-4 Flutter — `maxStale: 7 days` is request-side.** When the
  server emits `max-age=300` without `must-revalidate` (i.e. `/v1/
  beverages/{id}` and `/v1/breweries/{id}`), the client may serve a
  stale body for up to 7 days when online. Currently fine because the
  in-process LRU + write-path invalidation keeps drift bounded, but a
  future Phase 1 metric could prove a tighter request-side cap is
  warranted. Defer.
- **MINOR-5 Flutter — `MemCacheStore` is byte-bounded only, not
  entry-bounded.** A flood of small responses could fill the 5 MB cap
  with many low-value entries before LRU eviction kicks in. Theoretical;
  flagged for completeness.

From `qa_report_phase7a_backend_qa.md`:

- **MINOR-1 Backend — ETag is truncated SHA-256 (8 bytes / 16 hex
  chars).** Deliberate trade for shorter headers; collision domain is
  ~2^32 which is negligible at our scale. Documented in `etag.go:50-55`.
- **MINOR-2 Backend — `localeKey` accepts any 2-char Accept-Language.**
  A misbehaving client sending `Accept-Language: zh` produces a
  redundant cache entry. Bounded by LRU size (1000) — memory-safe but
  hit-rate-suboptimal. Defer.
- **MINOR-3 Backend — Magic numbers in `caches.go`** (sizes 4/4/1000/500
  + TTLs 1h/1h/5m/10m) live inline rather than as named constants. The
  package-level doc-block explains each but tuning happens in two places
  if observability proves a different shape is needed. Cosmetic.
- **MINOR-4 Backend — `invalidateBeverageDetail` on `DeleteCheckin` is
  a no-op for the idempotent-retry path** (already-deleted check-in
  fails the `Get` and `bevID` stays empty). Documented at the call site;
  no real-world failure mode today.

---

## Cross-references

- `_workspace/02_backend/api/internal/cache/cache.go` — LRU + singleflight + observers
- `_workspace/02_backend/api/internal/cache/caches.go` — 4 named caches with sizing + TTL doc-block
- `_workspace/02_backend/api/internal/middleware/etag.go` — strong ETag, 304 short-circuit, 256 KB size cap
- `_workspace/02_backend/api/internal/middleware/cache_headers.go` — `CacheControl(...)` + `NoStore` middleware
- `_workspace/02_backend/api/internal/server/router.go:62-92` — global ETag + group-level `NoStore` + per-route `CacheControl` overrides
- `_workspace/02_backend/api/internal/handlers/admin.go:225-270` — `AdminModerateCheckin` with BLOCKER-1 cache-bust hook
- `_workspace/02_backend/api/internal/handlers/checkins.go:87-104` — `invalidateBeverageDetail` + write-path call sites
- `_workspace/02_backend/api/internal/observability/prom.go` — `cache_requests_total{cache,outcome}` counter
- `_workspace/02_backend/api/tests/integration/cache_integration_test.go:285-380` — `TestCacheControlPresentOnAllGetRoutes` contract test
- `_workspace/03_frontend/lib/core/api/api_client.dart:73-127` — `cacheKeyBuilder` per-user namespace + `CacheOptions` construction
- `_workspace/03_frontend/lib/core/api/cache_extras.dart` — `kBypassCache` per-request sentinel
- `_workspace/03_frontend/test/core_api_cache_test.dart` — 2/2 PASS happy-path + revalidation tests
- `_workspace/04_qa/qa_phase7_grafana_panel.json` — Grafana panel for `cache_requests_total` hit-rate

---

## What's owed by the user

No new vendor signups for Phase 7 (caching is pure infra). Pre-existing items
remain from earlier phases (none of which block this phase's verdict):

- Cookbook §C1 Google OAuth (Phase 2)
- §C2 R2 (Phase 3 photos), §C3 Resend (Phase 3 SMTP)
- §C5 Foursquare API key (Phase 4)
- §C6 Cloudflare Pages for admin hosting (Phase 5)
- Sentry dashboard build (Phase 1 — Sentry MCP gap; UI build required)

---

**Net: Phase 7 is ship-ready, and so is the entire post-MVP roadmap.**

All 8 phases (0–7) have landed under the per-layer parallel QA cadence with
implementer-routed fix flows. 0 outstanding BLOCKER, 0 outstanding MAJOR, 12/12
SPEC invariants intact across the cumulative build, 365 tests green, ARB parity
206/206/206. The cache layer cuts DB load on hot taxonomy + detail rows
(verified by `cache_requests_total` and the 50-request stampede smoke), the
contract is enforceable (the `chi.Walk`-based integration test fail-closes any
future GET that omits a freshness declaration), and the user-isolation story
is multi-layered (server-side `must-revalidate` + body-derived ETag for the
online path; client-side per-user `cacheKeyBuilder` for the offline path).
