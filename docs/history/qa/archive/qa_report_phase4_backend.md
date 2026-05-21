# QA Report — Phase 4 Backend (in-flight, before Flutter QA)

Date: 2026-05-14
Scope: Phase 4 backend changes — `internal/foursquare/`, `repository/venues.go`, `handlers/venues.go`, `migrations/005_venues.sql`, `domain.Venue/VenueRef/CheckinVenue`, `handlers/checkins.go::resolveCheckinVenue`, `apierror` venue sentinels, `config.FoursquareAPIKey`, `openapi.yaml` venues additions, `cmd/server/main.go` wiring, env / docs.
Verdict: **PASS WITH MINOR**

Test suite green: `go build ./...` clean; `go test ./internal/foursquare/...` PASS (5/5); integration suite (`-tags=integration`) **53 PASS** with `INTEGRATION_DATABASE_URL` pointed at local `kamos_test` (matches expected count).

---

## Lens 1 — Integration boundaries

- **OpenAPI `GET /v1/venues/search` vs Go handler return type**: PASS. `VenueSearchResponse { items: [FoursquarePlace] }` (`openapi.yaml:1620-1626`) matches `venueSearchResponse{Items []foursquare.Place}` (`handlers/venues.go:22-24`). `foursquare.Place` JSON tags (`foursquare_id`, `name`, `address`, `lat`, `lng`, `country`, `prefecture`, `locality`) at `internal/foursquare/client.go:77-86` match the `FoursquarePlace` schema at `openapi.yaml:1606-1618`.
- **`CreateCheckinRequest.venue` shape vs `CheckinVenueInput`**: PASS. Nine fields (`id`, `foursquare_id`, `name`, `address`, `lat`, `lng`, `country`, `prefecture`, `locality`) — all optional, JSON tags match. `domain/types.go:402-413` vs `openapi.yaml:1554-1571`.
- **`Checkin.venue` returns only `id|name|locality|country`**: PASS. `domain.VenueRef` at `types.go:432-437` has exactly those four; `VenueRef` schema at `openapi.yaml:1502-1512` matches; SQL projection at `repository/checkins.go:112,533` selects only those four.
- **Migration column types vs wire**: PASS. `lat`/`lng` are `DOUBLE PRECISION` (`005_venues.sql:16-17`) and the Go field is `*float64` (`domain/types.go:421-422`). All text columns nullable except `name`, matching `Venue` schema's `required: [id, name, created_at, updated_at]`.
- **SPEC invariants intact**: PASS. No change to rating, review cap, photo cap, username regex, cursor pagination, soft-delete filters, JWT-in-secure-storage. The new `LEFT JOIN venues v ON v.id = ci.venue_id` in `repository/checkins.go:117,540` does not bypass `WHERE ci.deleted_at IS NULL` — venue rows have no `deleted_at` column by design (kept as orphans on check-in delete, FK `ON DELETE SET NULL` at `005_venues.sql:33`).
- **New error codes follow conventions**: PASS. `VENUE_SEARCH_DISABLED` → 503 (no `Retry-After`, intentional — config gate), `VENUE_RATE_LIMITED` → 503 + `Retry-After: 1` header (`handlers/venues.go:80-89`). Both sentinels in `apierror.go:43-49`, also routable through `apierror.WriteFrom` at `apierror.go:106-111` though the handler bypasses `WriteFrom` to set the header. **MINOR**: status code is 503 for rate-limit; the documented HTTP convention for upstream rate-limit is 429, but the team has chosen 503 + Retry-After deliberately (matches `STORAGE_DISABLED` family). OpenAPI documents this clearly at `openapi.yaml:1462-1473`.

## Lens 2 — Architecture

- **Dependency direction**: PASS. `grep -rn github.com/kamos internal/foursquare/` returns nothing — the package only imports stdlib + `hashicorp/golang-lru/v2/expirable` (`client.go:18-30`). No imports of `handlers`, `repository`, or `domain`.
- **Layer separation**: PASS. `repository/venues.go` imports only `pgx`, `apierror`, `domain` — no `foursquare`. `handlers/checkins.go::resolveCheckinVenue` (`checkins.go:298-329`) is the seam, translating `*domain.CheckinVenue` into `repository.UpsertVenueInput`. `handlers/venues.go` imports `foursquare` and translates `[]foursquare.Place` → JSON, never reaching into Foursquare-specific response structs (those are unexported in `client.go:218-236`).
- **No premature abstraction**: PASS. No `VenueProvider` interface in `internal/foursquare/` or `handlers/venues.go`. `handler.Foursquare` is the concrete `*foursquare.Client` (`handlers/handlers.go:30`).
- **Test client uses real http path**: PASS. `client_test.go:163-189` injects a `rewriteTransport` so the actual `net/http` code path is exercised against `httptest`. No struct-field mocking. **MINOR/cosmetic**: `clone.URL = &(*req.URL)` at `client_test.go:182` is unusual Go idiom — `c := *req.URL; clone.URL = &c` reads better; functionally fine.

## Lens 3 — Coding conventions

- **Naming**: PASS. `New`, `Err*` sentinels (`ErrDisabled`, `ErrRateLimited`) at package level. Snake_case JSON tags, camelCase Go fields, exported names match capitalization rules.
- **Error handling**: PASS. Every error path in `client.go` either wraps with `%w` (`fetchOnce` lines 176/189/200/238) or returns a typed sentinel (`ErrRateLimited`, `ErrDisabled`, `*upstreamServerError`). Never both wrap-and-log. `UpsertByFoursquareID` and `GetByID` wrap with `%w` consistently. **MINOR**: `client.go:209` returns `fmt.Errorf("fetchOnce: auth failed (%d)", status)` — string-formatted instead of a typed `ErrAuth` sentinel; callers can only match it by substring (the test does this at `client_test.go:100`). If callers ever need to distinguish auth failures from "unexpected status", upgrading this to a sentinel would help. Currently no caller distinguishes — defer.
- **Magic values**: PASS. `apiBase`, `httpTimeout`, `retryBackoff`, `cacheTTL`, `cacheSize`, `defaultLimit`, `maxLimit`, `fsqCategories` — all `const` at `client.go:39-72`, each with a 1-line WHY. `venueSearchLimit` (handler-side cap, `handlers/venues.go:16`) is a separate const with WHY comment.
- **Dead code**: PASS. No commented-out blocks, no unused params. `Country/Prefecture/Locality` flow end-to-end.
- **Comments**: PASS overall, but the codebase uses generous explanatory headers — consistent with the established Phase 1–3 style ("WHY" comments around design decisions). No comments narrate WHAT in the trivial-restatement sense. **MINOR**: `handlers/venues.go:32-34` lists error responses inside a block-comment header (`// Errors:`). Useful, kept.
- **Test-coverage gaps**: PASS. Every error path is exercised: disabled (`TestDisabled`), happy path + cache (`TestSearchDecodesAndCaches`), auth-fail not cached (`TestAuthFailureNotCached`), 5xx retry (`TestRetryOn5xx`), 429 typed (`TestRateLimitedSurfacesTypedError`), cache-key normalization (`TestCacheKey`). Integration: 503-when-disabled, fsq-upsert + idempotent upsert, attach-existing-id, empty-object silent-drop. **MINOR**: no test for `lat-without-lng` or `lng-without-lat` 422 branch in `handlers/venues.go:55-58`. Coverage gap; not a correctness gap.

## Lens 4 — Security / Performance

- **Parameterized SQL**: PASS. `UpsertByFoursquareID` uses `$1..$8` (`venues.go:46-57`). `GetByID` uses `$1` (`venues.go:72-76`). No `fmt.Sprintf` query construction. The `LEFT JOIN venues v ON v.id = ci.venue_id` patches into existing parameterized queries.
- **SSRF surface**: PASS. `apiBase` is a hardcoded const (`client.go:41`); URL construction uses `url.Parse(apiBase)` + `q.Set(...)` with all values either constants (`fsqCategories`, `limit`) or formatted from validated numbers (`%.6f,%.6f` for lat/lng, range-checked at `handlers/venues.go:62,68`). User-supplied `q` and `locale` go into query params and `Accept-Language` header — both URL-encoded by `url.Values.Encode()` / `req.Header.Set` respectively. No way for a caller to redirect the upstream URL.
- **Secrets in logs**: PASS. `cmd/server/main.go:123-130` logs only `foursquare enabled`/`foursquare disabled (FOURSQUARE_API_KEY unset)` — no key value. `Authorization` header is set programmatically (`client.go:192`) and never logged. `Disabled()` checks compare against `""` without exposing the value.
- **Rate limit on `/v1/venues/search`**: PASS. Route registered inside the authed `r.Group` at `server/router.go:124-126`, which applies `middleware.RateLimitByUser(log, 60, 120)` at `router.go:104`. Per-user limit applies as expected.
- **Cache poisoning by locale**: PASS. `cacheKey` at `client.go:263-275` includes locale + lat/lng (rounded to 3 decimals ~100m) + query + limit. A `ja` call and an `en` call produce distinct keys. **MINOR**: cache key omits the auth key, but the client is single-tenant so this is fine.
- **N+1 in CreateCheckin venue resolution**: PASS. `resolveCheckinVenue` performs at most ONE extra query per check-in (`GetByID` for the `id` branch, or `UpsertByFoursquareID` for the fsq branch). No loops. The subsequent `Get` after insert uses a single LEFT JOIN, not a separate venue fetch.
- **Index coverage**: PASS. `foursquare_id TEXT UNIQUE` (`005_venues.sql:13`) gives the upsert lookup a unique B-tree index for free. `idx_check_ins_venue` (partial, `venue_id IS NOT NULL`) covers the FK-join direction. `idx_venues_country`, `idx_venues_prefecture`, `idx_venues_name_tsv` (GIN FTS) provide filtering. **MINOR**: no index on `(country, prefecture)` composite, but no query uses both yet — defer.
- **Blocking I/O / context propagation**: PASS. `fetchOnce` uses `http.NewRequestWithContext(ctx, …)` (`client.go:187`); retry honors `ctx.Done()` (`client.go:156-160`); `httpTimeout = 5s` on the `http.Client` bounds the upstream call.

---

## BLOCKERs

None.

## MAJORs

- **OpenAPI / domain drift: `FeedItem.venue`** — `VenueRef` schema documentation states "Lightweight projection of a venue embedded on Checkin / FeedItem. Feed cards render 'at <name>, <locality>'" (`openapi.yaml:1504-1507`), and the same intent appears in `domain/types.go:432-434`. But:
  - `domain.FeedItem` (`types.go:617-628`) has **no** `Venue` field;
  - The `FeedItem` OpenAPI schema (`openapi.yaml:~1486` area) does not include a `venue` property;
  - `repository/feed.go` does not project venue columns (verified by `grep -n venue feed.go` → zero matches).

  Either the documentation overstates the contract (FeedItem deliberately omits venue at this phase) or the feed projection is missing. The Flutter agent is currently building a venue picker and may reasonably expect `FeedItem.venue` per the doc. **Routing**: needs `backend-engineer` to either (a) add `Venue *VenueRef` to `domain.FeedItem` + project it in `repository/feed.go::FeedHome` + update `openapi.yaml` FeedItem schema, OR (b) tighten the `VenueRef` doc to "embedded on Checkin only (FeedItem venue is deferred)". Flag to orchestrator: SPEC is silent so either resolution is reasonable — but the docs must match the wire.

## MINORs

- `handlers/venues.go::resolveLocale` quietly drops invalid locales (e.g., `?locale=xx`) and returns `"en"` rather than 422. SPEC §8 allows en/ja/ko only — silently substituting `en` is friendly to clients but hides typos. Defer.
- `client.go:209` auth failure returns a `fmt.Errorf` string-formatted error instead of a typed sentinel; test depends on `strings.Contains(err.Error(), "auth failed")` (`client_test.go:100`). Promote to `ErrAuth` if any caller ever needs to branch on it.
- No handler test for the `lat-without-lng` 422 branch (`handlers/venues.go:55-58`).
- `client_test.go:182` uses `clone.URL = &(*req.URL)` — non-idiomatic Go pointer-dance. Cosmetic.
- `cacheSize = 1000` (`client.go:58`) — fine for a single-pod deployment; if multi-pod is added, each pod will warm independently. Document if/when relevant.
- `apierror.WriteFrom` venue branch (`apierror.go:106-111`) is dead code for the rate-limit case — handler always handles `ErrRateLimited` directly to set the `Retry-After` header. Defer; harmless safety net.

## Backlog (cosmetic, can defer)

- `idx_venues_name_tsv` is a `to_tsvector('simple', name)` index — works for ASCII / Latin names but `'simple'` doesn't lemmatize Japanese / Korean names. Will likely need a different strategy once free-text venue search is exposed. No endpoint uses it yet (Phase 4 only queries by `foursquare_id` / `id`), so deferring is correct.
- `005_venues.sql:23-24` lat/lng range CHECKs are good defensive constraints; matching `minimum/maximum` on the OpenAPI `Venue` schema lines 1517-1518 is consistent. The `CheckinVenueInput` lat/lng also have `minimum/maximum` (lines 1564-1565). Good.
- Consider documenting the deliberate "503 not 429 for upstream rate-limit" choice in `apierror.go` near the sentinel.

---

**Net**: ship-ready pending the `FeedItem.venue` doc/wire reconciliation. None of the minor items block the Flutter slice (they only affect Flutter's venue picker if it tries to read `FeedItem.venue`, which it shouldn't be doing in Phase 4 — venue is a check-in attribute, the feed card render decision is post-MVP at best).
