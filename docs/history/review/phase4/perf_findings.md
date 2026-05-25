# Performance Review — Phase 4 (Venues + Foursquare)

Scope: commits `be82d83..2c72f0f`. Focus on Foursquare client, venue upsert hot path, feed query with the new `LEFT JOIN venues`, Flutter picker debounce/rebuild behavior, and wire-format cost of the new `venue` field.

Severity scale: HIGH (must fix this phase), MEDIUM (fix opportunistically / track), LOW (note for backlog).

---

### PERF-001 — Foursquare client uses zero-config HTTP transport (default MaxIdleConnsPerHost=2) [MEDIUM]
**File:** `_workspace/02_backend/api/internal/foursquare/client.go:107-113`
**Issue:** `New` constructs `&http.Client{Timeout: httpTimeout}` and never sets a `Transport`. Go's `DefaultTransport` is used by default, but the `Client` does not even share `DefaultTransport` explicitly — and `DefaultTransport`'s `MaxIdleConnsPerHost` is **2**. Foursquare search calls go to a single host (`api.foursquare.com`), so under concurrent load (e.g., a launch promo where 10 mobile clients type in the picker simultaneously and the cache is cold), only 2 keep-alive connections per host are reused; the rest open and close TCP+TLS for every request. TLS handshake to a remote API is the dominant latency component (~80–200ms).
**Impact:** Latency under modest concurrency. P95 on `/v1/venues/search` cold-cache requests will be noticeably higher (extra ~100ms per request that has to renegotiate TLS) when more than 2 in-flight calls exist.
**Recommendation:** Construct a dedicated `http.Transport` with `MaxIdleConns: 100`, `MaxIdleConnsPerHost: 32`, `MaxConnsPerHost: 64`, `IdleConnTimeout: 90 * time.Second`, `ForceAttemptHTTP2: true`. Reuse it across the client's lifetime. The expirable LRU cache mitigates this for popular `(q, ll, locale)` keys but does nothing for the long-tail of unique typed queries.

---

### PERF-002 — Foursquare LRU cache is unbounded by entry size — large response can pin ~MB per key [LOW]
**File:** `_workspace/02_backend/api/internal/foursquare/client.go:111`
**Issue:** `expirable.NewLRU[string, []Place](1000, nil, time.Hour)` caps at 1000 entries by *count*, not bytes. Each `Place` is ~150–300 bytes (8 string fields + 2 float64); with `Limit ≤ 50`, a single entry is up to ~15KB. At 1000 entries that's <20MB worst case, so the cap is fine. However, the package comment claims "≪ 1MB" which is wrong by ~10×. Not a real problem at this scale, but the comment will mislead a future operator sizing the heap.
**Impact:** Memory (small absolute; misleading documentation).
**Recommendation:** Either correct the comment to "~15MB worst-case at maxLimit=50" or switch to a byte-bounded cache (e.g., `ristretto`) if memory pressure becomes a concern. Defer until profiling shows real heap impact.

---

### PERF-003 — Cache stores in-flight failures' absence, not in-flight calls — thundering herd on cache miss [MEDIUM]
**File:** `_workspace/02_backend/api/internal/foursquare/client.go:120-142`
**Issue:** `Search` checks the LRU, and on miss calls `fetchWithRetry` directly. There is no singleflight / coalescing. If 50 concurrent callers issue the same (q, ll, locale) at the moment of cache miss (or cache TTL expiry), all 50 will fire upstream simultaneously, each costing 1 (or 2 with the 5xx retry) Foursquare API call. Foursquare's free tier is hard-rate-limited; a herd is the exact failure mode the LRU was supposed to prevent.
**Impact:** Throughput / upstream cost — burns the rate-limit budget right when the cache would have saved it. Realistic when a popular event drives many users to check-in at the same venue at the same minute.
**Recommendation:** Wrap the cache miss in `singleflight.Group.Do(key, ...)` (golang.org/x/sync/singleflight). One in-flight upstream call per (q, ll, locale) key; all concurrent callers share the result. Cheap (one extra dependency, ~10 LOC) and high-value at low traffic spikes.

---

### PERF-004 — Cache key omits Lat/Lng when only one side is set; two distinct callers with mismatched coords share a result [LOW]
**File:** `_workspace/02_backend/api/internal/foursquare/client.go:263-275`
**Issue:** `cacheKey` only writes the `ll` segment when `Lat != nil && Lng != nil`. The handler enforces both-or-neither (`venues.go:55-58`), so this is theoretically unreachable. But if validation regresses, two callers — one with `(Lat=35, Lng=nil)` and one with `(Lat=nil, Lng=nil)` — would collide on the same cache key but send different upstream URLs. Defensive concern, not a current bug.
**Impact:** Correctness (cache poisoning) if upstream validation is ever loosened.
**Recommendation:** In `cacheKey`, render a stable marker when only one of lat/lng is non-nil (e.g., `?,?` or skip writing entirely with a distinguishing token). Or `panic("invariant: lat/lng both-or-neither")` since the handler is the only caller. Low priority.

---

### PERF-005 — `fetchOnce` decodes through `json.NewDecoder(resp.Body)` without sizing the underlying buffer; allocations not pooled [LOW]
**File:** `_workspace/02_backend/api/internal/foursquare/client.go:237-258`
**Issue:** The decode path allocates a fresh anonymous `payload` struct each call, including nested slices. For a 50-result page, the `Results` slice + nested `Geocodes`/`Location` structs produce ~150 allocations per call. Combined with the `places = make([]Place, 0, len(payload.Results))` final copy, total per-call allocs are ~250–350 for a max page. At sustained 50 rps this is hot enough to show in pprof.
**Impact:** Memory pressure / GC time at sustained load. Not a current bottleneck; flagged for the "scale impact" file.
**Recommendation:** Defer. If Foursquare traffic ever rises to 100+ rps sustained, switch to `jsoniter` or a `sync.Pool` of the response struct. Not worth pre-optimizing at MVP/Phase 4 volumes.

---

### PERF-006 — Foursquare HTTP timeout (5s) larger than retry-after-Foursquare-429 wait — burns wall-clock during outages [LOW]
**File:** `_workspace/02_backend/api/internal/foursquare/client.go:45-49`
**Issue:** With `httpTimeout=5s` + `retryBackoff=200ms` + one retry, a single Foursquare outage can hold a caller goroutine for ~10.2 seconds (5s timeout, 200ms backoff, 5s timeout again). The handler `r.Context()` is the caller's HTTP request context, so the mobile client typically aborts first, but the goroutine still does the full upstream wait when there is no client-side timeout. Combined with `RateLimitByUser(60, 120)`, a single user could hold 60 goroutines × ~10s = up to 600 stuck goroutines if Foursquare hangs.
**Impact:** Throughput / goroutine count during upstream outages. Not a steady-state issue.
**Recommendation:** Either drop `httpTimeout` to ~2s (mobile clients aren't waiting 5s anyway) or guard the whole `Search` call with a `context.WithTimeout(ctx, 4*time.Second)` at the handler so the second retry can't blow past the request's overall budget. Defer; current settings are tolerable.

---

### PERF-007 — `cacheKey` allocates `strings.Builder` + 8 writes per call; cheaper alternatives exist but unnecessary [LOW]
**File:** `_workspace/02_backend/api/internal/foursquare/client.go:263-275`
**Issue:** Each cache lookup builds a key string from scratch (no key reuse). At ~30 rps cached hits, that's 30 string allocations/sec for the key alone. Trivial.
**Impact:** Memory (negligible).
**Recommendation:** Ignore. Mentioned only because the file comment emphasizes "tiny cache cuts upstream load substantially" — the lookup itself is not free, but the cost is in the noise.

---

### PERF-008 — Feed query: `LEFT JOIN venues` is well-indexed but `LEFT JOIN` on a nullable FK adds a hashed-build pass for every page [LOW]
**File:** `_workspace/02_backend/api/internal/repository/feed.go:35,45`
**Issue:** The feed query already had 4 inner joins + 3 correlated subqueries per row; the new `LEFT JOIN venues v ON v.id = ci.venue_id` adds a single equality lookup on `venues.id` (primary key, hash join trivially cheap). At 20 rows per page this is ~20 hash probes — measurable only on a tiny query plan. Cursor index `idx_check_ins_user_created` still serves the keyset scan; the new join does not break that.
**Impact:** Latency (estimated <1ms additional per page).
**Recommendation:** Accept as-is. No action needed unless EXPLAIN shows a planner regression — it should not, since `venues.id` is the PK.

---

### PERF-009 — `idx_check_ins_venue` is a partial index but the venue field is not used in any current query's WHERE clause [LOW]
**File:** `_workspace/02_backend/api/migrations/005_venues.sql:35`
**Issue:** `CREATE INDEX idx_check_ins_venue ON check_ins(venue_id) WHERE venue_id IS NOT NULL` was created but no Phase 4 query filters or joins on `check_ins.venue_id` (the feed and user-checkins queries go the other direction: from check_ins to venues via the venue_id FK, which uses the PK on `venues`, not this index). The index pays a write cost on every check-in INSERT/UPDATE/soft-delete for zero current read benefit. The partial predicate keeps it small (~5–20% of rows likely have a venue), which is good.
**Impact:** Write throughput (very small — one extra index entry on check-ins with venue_id set). Cost: ~1µs per insert. Benefit currently: 0. The index *will* be useful when Phase 6 / venue-detail screens land ("show check-ins at this venue").
**Recommendation:** Keep — the cost is negligible and the read use case is one phase away. Note in `indexes.md` that this index has no current reader so an operator doesn't drop it during cleanup.

---

### PERF-010 — `UpsertByFoursquareID` is a single round-trip but is not in the same transaction as the check-in create [MEDIUM]
**File:** `_workspace/02_backend/api/internal/handlers/checkins.go:43-47,68` and `_workspace/02_backend/api/internal/repository/venues.go:38-67`
**Issue:** When creating a check-in with `{foursquare_id, name, ...}`, the handler calls `h.resolveCheckinVenue` (which runs `UpsertByFoursquareID` in its own implicit pgx connection) *before* `h.Repos.Checkins.Create`. That's two distinct DB round-trips on the hot write path: upsert venue, then begin tx, insert check-in, insert photos, insert tags, commit. The upsert is a single statement (good) but it's a full network round-trip outside the tx. If the check-in tx subsequently fails (e.g., beverage_id soft-deleted between Exists check and Create), the venue row is already committed — a small amount of "venue orphan" garbage accumulates. Not a correctness problem (venues live until referenced; orphans are cheap per the migration comment) but two RTTs is two RTTs.
**Impact:** Latency (one extra DB RTT ~1–3ms per venue-tagged check-in) and minor orphan accumulation.
**Recommendation:** Two options:
- Pass a `pgx.Tx` (or use a transactional helper) into `UpsertByFoursquareID` so the upsert + check-in insert share one tx. Cleaner.
- Or accept the orphan cost (the migration comment already does) and call it good; the latency delta is one query and ~1–3ms on a write that already takes 5–20ms.
Defer to the architect (cross-message in arch-reviewer) for whether the repository layer should expose a tx-aware variant.

---

### PERF-011 — `idx_venues_country` and `idx_venues_prefecture` have no current reader [LOW]
**File:** `_workspace/02_backend/api/migrations/005_venues.sql:27-28`
**Issue:** Both indexes were created but no repository query filters venues by country or prefecture. They will be useful for "browse check-ins by venue locality" (Phase 6+) but pay an insert/update cost now. Each new venue triggers two extra index inserts. At Phase 4 venue write volume (rare — only on first sighting of a fsq_id), this is invisible.
**Impact:** Write throughput (negligible).
**Recommendation:** Accept — keep for future locality browse, document in `indexes.md` next to `idx_check_ins_venue`. Same disposition as PERF-009.

---

### PERF-012 — `idx_venues_name_tsv` (GIN tsvector on `name`) has no current reader and is moderately write-expensive [MEDIUM]
**File:** `_workspace/02_backend/api/migrations/005_venues.sql:29-30`
**Issue:** Unlike the country/prefecture btrees, GIN updates are non-trivial — each tsvector insert/update touches multiple posting lists. There is no current query that uses this index (venue search goes to Foursquare, not the local DB). At Phase 4 venue write volume this is still tiny, but the cost-vs-benefit balance is the worst of the three "future-readers" indexes.
**Impact:** Write throughput (small; each venue insert adds ~5–20µs for GIN maintenance).
**Recommendation:** Consider dropping this index until a "search local venues" query actually exists (Phase 6+ when free-form venue entry is allowed per the migration comment). Re-add in the migration that introduces the reader. Flag for `db-architect` via the orchestrator: there's a useful tsvector for FUTURE work, but creating it now without a reader is premature.

---

### PERF-013 — Flutter `VenueSearchNotifier.setQuery` creates a fresh `VenueSearchQuery` per keystroke; equality check is O(n) on text [LOW]
**File:** `_workspace/03_frontend/lib/features/venues/providers/venue_providers.dart:33-42` and `_workspace/03_frontend/lib/features/venues/widgets/venue_picker_sheet.dart:55-59`
**Issue:** `_onChanged` builds a new `VenueSearchQuery(text: text, locale: _locale)` on every character. Equality compares text via String `==` (O(n)) plus a few scalar fields — fine. But the notifier stores `_query = q` unconditionally even when the value hasn't changed (e.g., IME composition events that re-fire onChanged with the same string). Each set restarts the 300ms debounce timer, which is the correct behavior on rapid typing but wastes work on no-op IME re-emissions. Memory: per keystroke at 10 char/s = 10 VenueSearchQuery objects/s = negligible.
**Impact:** Memory / CPU (negligible). Worth noting for the rebuild-storm review.
**Recommendation:** Cheap guard: `if (q == _query) return;` at the top of `setQuery`. ~3 LOC, no behavior change.

---

### PERF-014 — Flutter picker sheet: full sheet rebuilds on every notifier state transition; the TextField is inside the rebuilt subtree [MEDIUM]
**File:** `_workspace/03_frontend/lib/features/venues/widgets/venue_picker_sheet.dart:62-106`
**Issue:** `build()` calls `ref.watch(venueSearchProvider)` at the top of the State's `build`, so every `AsyncValue` transition (idle → loading → data) rebuilds the entire sheet, including the `TextField`. Under rapid typing (e.g., 10 char/s), the sequence is: keystroke → setState in TextField → setQuery → state = AsyncValue.loading → notifier emits → ref.watch rebuilds → TextField widget rebuilt with same controller. The TextField keeps its `_controller` so no text is lost, but Flutter rebuilds the entire input decoration, hint, suffix icon, etc. on every keystroke.
**Impact:** Frame jank under fast typing — the rebuild cost is small (~0.5ms per keystroke on a mid-range Android), but it's measurable and unnecessary.
**Recommendation:** Move the `ref.watch(venueSearchProvider)` into the `_Results` subtree (it already exists — pass results into it via a Consumer, not as a constructor argument). Then the `TextField` parent doesn't rebuild when only the results change. Concretely: wrap `_Results` in a `Consumer(builder: (_, ref, __) => _Results(results: ref.watch(venueSearchProvider), ...))` and remove the `ref.watch` from the outer `build()`.

---

### PERF-015 — `_Results` reads `_controller.text` indirectly via `query` prop passed from outer build; query empty-check happens on every parent rebuild [LOW]
**File:** `_workspace/03_frontend/lib/features/venues/widgets/venue_picker_sheet.dart:97,127`
**Issue:** The parent's `build()` passes `query: _controller.text` to `_Results`. This couples the results widget's rebuild to the parent's. The check `if (query.trim().isEmpty)` re-runs per parent rebuild. Cosmetic — the cost is one string trim + one comparison. Coupled with PERF-014's fix, this becomes a non-issue.
**Impact:** Trivial.
**Recommendation:** Fix as part of the PERF-014 restructure.

---

### PERF-016 — `ListView.separated` re-creates `ListTile`s on every results-list update; no `itemExtent` and no key reuse [LOW]
**File:** `_workspace/03_frontend/lib/features/venues/widgets/venue_picker_sheet.dart:196-210`
**Issue:** With up to 30 items, `ListView.separated`'s default lazy build is fine. Scroll perf is not a concern at 30 items. However, each results refresh (new query → new list) replaces the entire item list. Without keys, Flutter recycles tiles by index, which is correct. No real issue here.
**Impact:** None measurable.
**Recommendation:** Accept as-is. Flagged for completeness.

---

### PERF-017 — Wire size: `FeedItem.venue` adds 4 nullable fields per row; ~80 bytes worst case × 20 rows × N pages [LOW]
**File:** `_workspace/02_backend/api/internal/domain/types.go` (Venue/VenueRef) and the feed JSON shape
**Issue:** Each `VenueRef` is `{id: uuid, name: string, locality?: string, country?: string}` ~80–150 bytes JSON-serialized when present, ~10 bytes (`"venue":null`) when absent. At 20 rows per feed page with ~30% venue-tagged check-ins, the per-page wire delta is ~600 bytes. On 4G this adds <5ms; on slow 3G ~20–50ms.
**Impact:** Wire bandwidth on slow networks. Trivial.
**Recommendation:** Accept. Below any reasonable optimization threshold. Omit-empty would save ~200 bytes/page when no row has a venue; check if Go's `json.Marshal` already drops `venue: null` via `omitempty` tag — if not, add it.

---

### PERF-018 — `VenueRepo.GetByID` selects 11 columns when the check-in resolver only needs `id` [LOW]
**File:** `_workspace/02_backend/api/internal/repository/venues.go:71-89` and `_workspace/02_backend/api/internal/handlers/checkins.go:303-309`
**Issue:** `resolveCheckinVenue` with `v.ID != nil` calls `GetByID` purely to verify existence and pick up the `id` field (which equals `*v.ID`). The full row hydrate is wasted — `name`, `address`, lat/lng, country, prefecture, locality, created_at, updated_at all read for no use. Postgres still returns the full row.
**Impact:** Latency (negligible — one row, one trip) and minor allocation waste.
**Recommendation:** Add a `VenueRepo.Exists(ctx, id) (bool, error)` method that runs `SELECT 1 FROM venues WHERE id = $1`. Saves ~200 bytes per check-in create call that picks an existing venue. Or simpler: keep `GetByID` for the path that actually needs the venue (post-Phase-5 venue-detail GET) and use the cheaper Exists in `resolveCheckinVenue`.

---

### PERF-019 — Foursquare 5xx retry uses a fixed 200ms backoff with no jitter — concurrent retry storms align [MEDIUM]
**File:** `_workspace/02_backend/api/internal/foursquare/client.go:49,156-160`
**Issue:** When Foursquare returns 5xx, every concurrent caller waits exactly 200ms and retries simultaneously. If the upstream issue is sustained, 100 concurrent callers hammer the API in lock-step — exactly the pattern that prevents the upstream from recovering. Combined with the absence of singleflight (PERF-003), one Foursquare outage produces aligned retry storms.
**Impact:** Throughput / upstream cost during outages. Suspected — needs profiling under simulated upstream degradation, but the pattern is well-documented.
**Recommendation:** Add jitter: `time.Sleep(retryBackoff + time.Duration(rand.Int63n(int64(retryBackoff))))` (uniform in `[backoff, 2*backoff]`). 2 LOC fix. The singleflight in PERF-003 is the bigger lever — fix both.

---

### Cross-domain messages

- To `arch-reviewer`: PERF-010 (venue upsert outside the check-in tx) has both a layering and a perf dimension. The repository layer doesn't currently expose tx-aware methods, so the handler can't trivially co-locate the upsert into the check-in's tx. Architectural decision needed.
- To `security-reviewer`: PERF-003 (thundering herd on cache miss) + PERF-019 (no jitter) together amplify DoS amplification — one attacker keyword that misses cache produces N concurrent upstream calls, each costing rate-limit budget. Worth pairing with their look at `/v1/venues/search` rate limiting.
- To orchestrator → `db-architect`: PERF-012 — `idx_venues_name_tsv` has no current reader and is the most write-expensive of the three no-reader venue indexes; consider dropping until the reader is introduced.

### Summary

- **0 HIGH** (no regressions that would block Phase 5 from a perf standpoint).
- **6 MEDIUM**: PERF-001 (HTTP transport config), PERF-003 (singleflight), PERF-010 (upsert + check-in tx separation), PERF-012 (premature GIN index), PERF-014 (sheet rebuild scope), PERF-019 (retry jitter).
- **13 LOW**: documentation/minor allocation/future-reader indexes.

The Phase 4 perf surface is clean for MVP-scale traffic. The MEDIUMs become real bottlenecks at >50 req/s sustained on `/v1/venues/search` or during Foursquare upstream incidents.
