# QA — Phase 7a backend (cache layer, 4 of 5 commits)

Scope: `4b3a1f4` LRU layer · `df64f43` middleware (CC + ETag) · `e81d633` wire to read endpoints · `041bced` invalidation on writes. Commit 5 (Prometheus counter) is in-flight in a separate agent; the wiring lines that *call* the observers (`observability.RecordCacheHit/Miss`) are already in place (`cmd/server/main.go:160-161`, `internal/observability/prom.go`) and reviewed here as part of the wiring slice.

**Verdict: FAIL — 2 BLOCKER, 4 MAJOR, 4 MINOR**

Tests: `go vet ./...` clean (3 pre-existing test-only "using X before err check" notices in `cache_headers_test.go`, not introduced here). `go build ./...` clean. `go test ./internal/middleware/... ./internal/cache/...` pass.

ETag is mounted **GLOBALLY** at `internal/server/router.go:50` (`r.Use(middleware.ETag)`), not per-route. This is the deliberate design but it has correctness implications — see BLOCKER-2.

---

## BLOCKER

### BLOCKER-1 — `AdminModerateCheckin` does not invalidate `BeverageDetail` cache

`internal/repository/admin.go:308-318` soft-deletes a check-in via `UPDATE check_ins SET deleted_at = NOW()`. The `deleted_at` trigger recomputes `beverages.avg_rating` + `check_in_count` (Phase 1 design). But `internal/handlers/admin.go:225-255` (`AdminModerateCheckin`) never calls `h.invalidateBeverageDetail(...)`.

Consequence: a moderator soft-deletes a check-in → DB row reflects fresh aggregates → in-process `BeverageDetail` LRU keeps serving the stale `avg_rating` + `check_in_count` for up to **5 minutes** (TTL ceiling). For a moderation surface this is the wrong staleness model — moderation is precisely the case where stale-but-public reads must update immediately, because the moderation action is in response to a problem report and operators expect the public page to reflect the action.

The corresponding owner-side `DeleteCheckin` (`internal/handlers/checkins.go:228`) does invalidate — fetches the beverage_id from `Checkins.Get` *before* the soft-delete and busts the cache after. `AdminModerateCheckin` needs the same shape: `Repos.Checkins.Get(...)` before `Repos.Admin.ModerateCheckin(...)`, then `h.invalidateBeverageDetail(bevID)` after the transaction commits.

**Fix owner:** backend-engineer · file `internal/handlers/admin.go:225-255`.

### BLOCKER-2 — Global ETag mount widens the buffer-the-entire-response surface to every GET, including authed feed/list pages

`internal/server/router.go:50` mounts `middleware.ETag` globally. The comment ("Mounted globally rather than per-route so a new GET route gets ETag support by default") frames this as a feature, but it makes ETag compute a SHA-256 over the **entire JSON body** of every GET response — including:

- `GET /v1/feed` — page of up to 20 FeedItems, each with embedded user + beverage + brewery + tags + venue. The body is ~10–30 KB.
- `GET /v1/users/{username}/check-ins` — same shape.
- `GET /v1/users/me` — moderate.
- `GET /v1/check-ins/{id}/comments`, `/v1/beverages/{id}/check-ins`, `/v1/breweries`, etc.

This has two distinct problems:

1. **CPU cost — uncosted in any review.** SHA-256 on ~30 KB is ~30 µs on modern CPUs, plus the buffering allocation (one `bytes.Buffer` per request, the `body []byte` slice over it). For the feed at 60 rps per user × N users, this is the new CPU floor. Phase 1's "<4ms p95" reads were measured before this middleware existed — they will move. The brief explicitly asks for the order of magnitude; nothing in `etag.go` or the design doc bounds it.
2. **Effective semantics mismatch with `Cache-Control`.** The 5 documented cacheable routes have `Cache-Control` headers (`/v1/categories`, `/v1/flavor-tags`, `/v1/beverages/{id}`, `/v1/breweries/{id}`, `/v1/users/{username}`). Every other GET gets an ETag with *no* Cache-Control, which most HTTP intermediaries treat as a heuristic-cacheable response (Fielding §13.4 / RFC 7234 §4.2.2 — 200 OK without freshness info MAY use heuristic freshness). A scrape proxy or buggy CDN could cache `/v1/feed` responses keyed by ETag, then re-serve them to unrelated viewers — same authed feed page replayed to different users. The current Flutter app sends `Authorization` with the request and Dio does not heuristic-cache, so today this isn't exploitable from KAMOS clients, but the contract is now broken: per route the dev intent was "5 cacheable surfaces", per implementation it is "every GET, with no freshness info".

**Recommendation:** either (a) move ETag to per-route — chain `r.With(middleware.CacheControl(...), middleware.ETag)` on the same 5 routes the Cache-Control already covers — or (b) add explicit `Cache-Control: no-store` middleware on every route the team did **not** intend to cache (`/v1/feed`, `/v1/users/me`, `/v1/check-ins/{id}/comments`, the entire authed surface). Option (a) matches the documented surface; option (b) keeps the "ETag on every GET for free" property the comment values, at the cost of having to remember to put `no-store` on private routes.

Flutter's Phase 7 QA already flagged this concern about widened cache surface — confirmed here from the backend side.

**Fix owner:** backend-engineer · file `internal/server/router.go:46-50`. Decision needs designer + qa-inspector alignment on intended caching surface; flag to orchestrator.

---

## MAJOR

### MAJOR-1 — No singleflight / stampede protection on cache misses

Every cache target (`Categories`, `FlavorTags`, `BeverageDetail`, `BreweryDetail`) uses the pattern: `Get → miss → DB call → Set`. When a hot key expires (the 5-min TTL on `BeverageDetail` is the dangerous one), N concurrent requests all see the miss and each issues the full Detail + AggregatedFlavor + RecentCheckins query trio (`internal/handlers/beverages.go:84-98` — three DB calls). For a popular beverage during a campaign-driven spike this is a thundering-herd against Postgres.

`internal/foursquare/client.go:31,109` already uses `golang.org/x/sync/singleflight` for exactly this reason. The brief explicitly asks for the comparison.

**Recommendation:** add a `singleflight.Group` field to `LRU[K, V]` (or to `Caches`), and rewrite each handler's miss branch as `do := c.sf.Do(string(key), func() (any, error) { ... DB ... })`. Adds one mutex acquire per request — invisible compared to a DB round-trip and one to two orders of magnitude smaller than the SHA-256 cost from BLOCKER-2.

**Fix owner:** backend-engineer · files `internal/cache/cache.go` (add `sf singleflight.Group`), `internal/handlers/{taxonomy,beverages}.go` (rewrite miss branches).

### MAJOR-2 — ETag computation cost is uncosted; no upper bound on what gets buffered

`internal/middleware/etag.go:35-80` buffers the *entire* response body into `bytes.Buffer` regardless of size, then hashes it. There is no size cap. A handler that accidentally returns a 5 MB response (e.g., a future endpoint that includes a base64-encoded image, or a misconfigured pagination that returns 1000 items instead of 20) would buffer the whole thing and hash it. The comment says "the response is a few KB at most" but the middleware doesn't enforce that.

The brief asked for the order of magnitude. SHA-256 throughput on a modern x86 is ~500 MB/s, so 10 KB → ~20 µs, 100 KB → ~200 µs, 5 MB → ~10 ms. Buffer alloc is a separate concern: at p99 traffic of 1000 rps with mean 10 KB body, peak heap is ~10 MB of `bytes.Buffer` waste before GC reclaims. None of this kills us, but none of it is documented in any commit message or design note.

**Recommendation:** document the cost in `etag.go`'s package comment with a concrete order-of-magnitude estimate, and add a soft cap (`if buf.body.Len() > 256 * 1024 { skip ETag, flush as-is }`) so a future regression that returns a giant body doesn't quietly bloat memory.

**Fix owner:** backend-engineer · file `internal/middleware/etag.go`.

### MAJOR-3 — `etagBuffer.wroteHeader` flag is misaligned with default `status: http.StatusOK`

`internal/middleware/etag.go:43-47` initializes `status: http.StatusOK` and `wroteHeader: false` (default). The outer flush at line 54-77 reads `buf.status` unconditionally. If the inner handler returns without ever calling `Write` or `WriteHeader` (an empty 200), `buf.wroteHeader` is false and `buf.body.Len() == 0`, so we hit the `body.Len() == 0` branch at line 59-62 and call `w.WriteHeader(http.StatusOK)`. Correct.

But if the inner handler calls `WriteHeader(204)` and writes no body, `buf.wroteHeader = true`, `buf.status = 204`, `buf.body.Len() == 0`, we again hit line 59-62 and write `WriteHeader(204)`. Correct.

The case that's *almost* a bug: an inner handler that writes a body then calls `WriteHeader` later — `Write` calls `WriteHeader(200)` internally (line 102-104), so the explicit WriteHeader call is a no-op (line 92-94 short-circuits if `wroteHeader`). Standard `net/http` would log a "superfluous WriteHeader call"; here we silently drop it. Net behavior matches stdlib.

What's actually wrong: when `buf.status >= 300` (the 4xx/5xx pass-through at line 54-58), we always call `w.WriteHeader(buf.status)`. But if the inner handler intentionally sent a 204 *without* any body, `buf.status` is 204, which falls into the 2xx-but-empty branch and would never go through 4xx/5xx. That works. The combination that breaks: a handler that sets a status code via `WriteHeader(307)` and writes no body — we go to 54-58, call `w.WriteHeader(307)`, write the empty body. Correct. So no actual bug — but the code is fragile and the `wroteHeader` field is **never read after assignment** (it's set in `WriteHeader` and `Write`, but the outer flush logic only reads `buf.status` and `buf.body.Len()`). This dead state is misleading.

**Recommendation:** delete `wroteHeader` entirely — the `status` field with default `http.StatusOK` already captures the necessary state. Or, if kept, document explicitly that it gates only the idempotency of WriteHeader. Cosmetic but the kind of thing that grows into a real bug as the middleware accretes branches.

**Fix owner:** backend-engineer · file `internal/middleware/etag.go:84-99`.

### MAJOR-4 — `BeverageDetail` cache stores a `*pointer`; future per-viewer field on this endpoint will silently leak across viewers

`internal/cache/caches.go:33` declares `BeverageDetail *LRU[string, *domain.BeverageDetail]`. `handlers/beverages.go:108` does `h.Caches.BeverageDetail.Set(cacheKey, &out)` — the cache holds the same pointer the handler built. Line 79 reads `cached, ok := ... .Get(cacheKey)` and writes the *same pointer* via `apierror.WriteJSON`.

Today `BeverageDetail` has no viewer-relative fields (`CheckinSummary` has no `you_toasted` — verified `internal/domain/types.go:695-701`). The handler comment on line 67-72 acknowledges the footgun but does not enforce it: a future commit that adds `YouToasted bool` to `CheckinSummary` and mutates it after the cache fetch would mutate the cached pointer for every viewer.

The cache package comment (`internal/cache/cache.go:16-20`) explicitly says "deep-copy at the call site before mutation." Right now there is no call site that does this, but there's also no guard. The `*LRU[string, *T]` shape makes mutation cheap and silent.

**Recommendation:** change `BeverageDetail` and `BreweryDetail` to value caches (`*LRU[string, domain.BeverageDetail]`, `*LRU[string, domain.Brewery]`). The cost is one extra struct copy per Get/Set — at ~1 KB per BeverageDetail × 500 rps × 1 µs/KB ≈ 0.5 ms of CPU per second, well below the singleflight win above. Worth the safety.

**Fix owner:** backend-engineer · files `internal/cache/caches.go`, `internal/handlers/beverages.go`.

---

## MINOR

### MINOR-1 — ETag is truncated SHA-256 (8 bytes / 16 hex chars)

`internal/middleware/etag.go:65-67` does `hex.EncodeToString(sum[:8])`. 64 bits gives ~2^32 collision domain (birthday). At our scale this is fine — collisions across different routes are inert because the ETag is scoped to one URI's response, and within one route the collision probability over the cache's lifetime is negligible. Worth documenting as a deliberate trade for shorter headers, not a bug.

**Fix owner:** backend-engineer (doc only) · file `internal/middleware/etag.go:65`.

### MINOR-2 — `localeKey` accepts any 2-char Accept-Language, allowing unbounded cache-key axes from misbehaving clients

`internal/handlers/handlers.go:173-191` collapses Accept-Language to its first 2 lowercase chars. KAMOS only ships `en/ja/ko`, but a client that sends `Accept-Language: zh` produces cache key `<id>:zh` — the `I18nText.Resolve` fallback returns EN, but the cache fills with redundant keys. Bounded by LRU size (1000) so memory is fine, but cache hit rate drops if many such clients exist.

**Recommendation:** whitelist to `en/ja/ko/any` in `localeKey`:

```go
switch primary {
case "en", "ja", "ko":
    return primary
default:
    return "en" // map unsupported locales to the EN fallback bucket
}
```

**Fix owner:** backend-engineer · file `internal/handlers/handlers.go:173-191`.

### MINOR-3 — Magic numbers in `caches.go` are commented but inconsistent in shape

`internal/cache/caches.go:30-44` — Categories size 4, FlavorTags size 4, BeverageDetail size 1000, BreweryDetail size 500; TTLs 1h / 1h / 5m / 10m. The package comment explains each but they are not bound to constants. If observability shows the BeverageDetail working set exceeds 1000, the tuning happens in two places (this file plus any test that asserts the cap). Small footgun.

**Recommendation:** lift the four sizing tuples to named constants at the top of the file.

**Fix owner:** backend-engineer (cosmetic) · file `internal/cache/caches.go`.

### MINOR-4 — `invalidateBeverageDetail` on `DeleteCheckin` reads the row via `Checkins.Get` before delete, but `Get` filters `deleted_at IS NULL`

`internal/handlers/checkins.go:221-228` — if the check-in is already soft-deleted (idempotent delete), `Get` returns ErrNotFound, `bevID` stays empty, `invalidateBeverageDetail("")` is a no-op (guarded at line 99). The DB `SoftDelete` then either succeeds again or no-ops. This is functionally fine but the cache is *not* busted on the idempotent-retry path. A real-world second-DELETE with a different actor is extremely unlikely, but if the trigger does any second-time work the cache will miss it. Tiny, acceptable as documented.

**Recommendation:** none unless the trigger is changed to be non-idempotent. Document the assumption.

---

## Per-lens summary

### Lens 1 — Integration boundaries

- ETag mounted **globally** at router.go:50. See BLOCKER-2 for the cache-surface widening and Lens-4 cache-poisoning angle.
- LRU response + per-viewer overlay: today no overlay on cached `BeverageDetail` endpoints — see MAJOR-4 for future-proofing.
- `Cache-Control` per route is per-spec: `public, max-age=3600, stale-while-revalidate=86400` for `/v1/categories` and `/v1/flavor-tags`; `public, max-age=300, stale-while-revalidate=86400` for `/v1/beverages/{id}`; `public, max-age=600, stale-while-revalidate=86400` for `/v1/breweries/{id}`; `private, must-revalidate` for `/v1/users/{username}`. Correct. (`router.go:104-139`)

### Lens 2 — Architecture

- ETag is strong (no `W/` prefix) per `etag.go:35-67`. Correct for our deterministic JSON shape.
- Status codes: 4xx/5xx pass through without ETag (`etag.go:54-58`); 304 returns no body + matching ETag header (`etag.go:69-75`). Confirmed by `cache_headers_test.go:141-157,49-84`.
- 304 short-circuit: empty body, no Content-Length forced to body size. The standard library will not set Content-Length on a 304 in `http.ResponseWriter`. Correct.
- Cache invalidation is called **after** the repository write but **after the transaction commits implicitly** (repository functions handle their own tx + commit). Order is correct: cache reflects committed state.

### Lens 3 — Conventions

- LRU package naming: `expirable.LRU` matches foursquare's import path (`golang-lru/v2/expirable`).
- Magic numbers: present but commented inline. MINOR-3.
- Test names: follow existing `TestXxx` pattern; concurrency test exists (`cache_test.go:71-97`).

### Lens 4 — Spot checks (security/perf)

- **Cache poisoning via shared key:** today `BeverageDetail` has no per-viewer field, so the shared cache is safe. But the pointer-cached shape (MAJOR-4) plus a future per-viewer overlay would leak. The handler comment warns of this but does not enforce.
- **ETag computation cost:** MAJOR-2 — uncosted, no size cap.
- **Cache stampede on miss:** MAJOR-1 — no singleflight.
- **Invalidation thoroughness on `CreateCheckin`:** `invalidateBeverageDetail` calls `InvalidatePrefix(beverageID + ":")` (`checkins.go:102`), which evicts every locale-suffixed entry — correct. But `AdminModerateCheckin` doesn't invalidate at all — BLOCKER-1.

---

## Cross-references

- `internal/cache/cache.go` — LRU + observers; clean wiring with `expirable.LRU`.
- `internal/cache/caches.go` — four named caches with documented sizes + TTLs.
- `internal/middleware/etag.go` — strong ETag, 304 short-circuit, 4xx/5xx pass-through. Mounted globally at `internal/server/router.go:50` (BLOCKER-2).
- `internal/middleware/cache_headers.go` — `Cache-Control` per-route wrapper, pre-handler header set.
- `internal/handlers/beverages.go:75-111` — cache-aware `GetBeverage`.
- `internal/handlers/beverages.go:179-222` — cache-aware `GetBrewery` (brewery row only, beverages inline are not cached).
- `internal/handlers/taxonomy.go:22-60` — cache-aware `Categories` + `FlavorTags`.
- `internal/handlers/checkins.go:14-104` — `CreateCheckin` invalidates; `DeleteCheckin:210-230` invalidates; `UpdateCheckin:128-204` invalidates (uses reloaded `out.Beverage.ID` — correct).
- `internal/handlers/admin.go:175-188` — `AdminApproveBeverageRequest` invalidates BreweryDetail; `AdminModerateCheckin:225-255` does **not** invalidate BeverageDetail (BLOCKER-1).
- `cmd/server/main.go:156-168` — boot wires `cache.NewCaches()` + `SetObservers(observability.RecordCacheHit, ...)`.
- `internal/observability/prom.go` — `cache_requests_total{cache,outcome}` Prometheus counter, `/metrics` mount at `router.go:76`.
- Integration tests: `tests/integration/cache_integration_test.go` covers Categories hit/miss, BeverageDetail invalidation on create + on delete, ETag short-circuit on Categories. Does **not** cover `AdminModerateCheckin` invalidation (BLOCKER-1 has no integration regression test).
