# Architecture Findings — Phase 4 (Venues + Foursquare)

Date: 2026-05-16
Reviewer: arch-reviewer
Verdict: 0 CRITICAL / 0 HIGH / 2 MEDIUM / 5 LOW

---

### ARCH-001 — Vendor package struct is the API wire DTO [MEDIUM]
**File:** `_workspace/02_backend/api/internal/handlers/venues.go:22-24`
**Issue:** `venueSearchResponse.Items` is typed as `[]foursquare.Place`, so the JSON wire shape of `GET /v1/venues/search` is dictated by the vendor-integration package (`internal/foursquare/Place` at `client.go:77-86`). The handler layer does not own a venue-search DTO; it transparently re-exports a vendor type's JSON tags. The openapi schema name `FoursquarePlace` reinforces this — the public API names the vendor at the wire. The intent stated in `foursquare/client.go:74-76` ("We translate the Foursquare payload at the package boundary so neither the repository nor handler imports a foursquare-specific response struct") is only half-realized: the handler does import a foursquare-specific struct, just not the raw upstream one. Consequences: (a) a future non-Foursquare venue source would require either a second response shape or a shim type; (b) JSON-key renames for API versioning would touch the integration package, not the handler layer; (c) the handler cannot add transport-layer fields (e.g., a `confidence` score derived independently) without polluting the foursquare-package struct.
**Recommendation:** Introduce a thin `handlers.venueSearchItem` (or `domain.VenueSearchResult`) that the handler maps to inside `VenueSearch` — three lines of mapping. Keep `foursquare.Place` strictly as the vendor-DTO at the package boundary.

### ARCH-002 — `VenueRef` projection duplicated across three repository queries [LOW]
**File:** `_workspace/02_backend/api/internal/repository/feed.go:35`, `_workspace/02_backend/api/internal/repository/checkins.go:112`, `_workspace/02_backend/api/internal/repository/checkins.go:534`
**Issue:** Three queries each carry the same `LEFT JOIN venues v ON v.id = ci.venue_id` and the same `v.id, v.name, v.locality, v.country` projection, followed by the same 4-pointer scan + nil-check hydration block. Any future addition to `VenueRef` requires three edits in lockstep.
**Recommendation:** Add `domain.ScanVenueRef(...)` helper to consolidate nil-check + struct build. Leave SQL projection inline. Defer to next call site.

### ARCH-003 — Widget→repository import for typed exceptions crosses layer boundary [MEDIUM]
**File:** `_workspace/03_frontend/lib/features/venues/widgets/venue_picker_sheet.dart:17`
**Issue:** The widget imports `repository/venue_repository.dart` exclusively to reference `VenueSearchDisabledException` and `VenueRateLimitedException` in the `error:` branch (lines 146, 165). The file's own header at line 7-8 documents the boundary: "this widget only talks to `venueSearchProvider`. The provider talks to `VenueRepository`. Dio is invisible from here." The implementation then violates the documented boundary. Leaving it sets a precedent that any feature-package widget can reach into its sibling repository for "just the exception types".
**Recommendation:** Move `VenueSearchDisabledException` and `VenueRateLimitedException` to `lib/features/venues/exceptions.dart`. Repository imports it (concrete `throw`), widget imports it (type-check in `error:` branch), provider passes through. Five-line refactor.

### ARCH-004 — `Foursquare` client mutability on `Handler` singleton [LOW]
**File:** `_workspace/02_backend/api/internal/handlers/handlers.go:36, 52, 65-70`
**Issue:** The `Handler` struct holds `Foursquare *foursquare.Client` as a mutable, exported field that `WithFoursquare` swaps in after construction. Consistent with the pre-existing `WithStorage` / `WithMailer` pattern but architecturally weaker than a constructor that takes the wired client as a required argument.
**Recommendation:** Defer. If constructor surface ever grows past 5 dependencies, fold into a single `Options` struct.

### ARCH-005 — `foursquare.Client` cache is per-pod state, not abstracted [LOW]
**File:** `_workspace/02_backend/api/internal/foursquare/client.go:101, 111`
**Issue:** `expirable.LRU` is local to the process. Multi-pod deployments each warm independently. No `Cache` interface today. Per "no premature abstraction" rule, in-memory is correct for current scale.
**Recommendation:** Defer. Add a one-line comment on `cacheSize` documenting the multi-pod consequence.

### ARCH-006 — `resolveCheckinVenue` mixes parsing + repository dispatch in handler [LOW]
**File:** `_workspace/02_backend/api/internal/handlers/checkins.go:299-329`
**Issue:** Function does parsing, repository dispatch, and silently drops incomplete payloads. The silent-drop policy at line 327-328 is a business rule next to a routing decision. Today the placement is fine; if Phase 5 admin moderation needs stricter validation, this policy will have to move.
**Recommendation:** Defer. Hoist to `(*domain.CheckinVenue).Resolve()` returning a typed `Decision` if validation strictness becomes adjustable.

### ARCH-007 — `FoursquarePlace` is openapi-named but has no `domain` type [LOW]
**File:** `_workspace/02_backend/api/openapi.yaml:1606-1621`, `_workspace/02_backend/api/internal/foursquare/client.go:77-86`, `_workspace/02_backend/api/internal/domain/types.go`
**Issue:** `FoursquarePlace` is the lone openapi schema whose Go peer lives in an integration package, not `internal/domain/`. Manifestation of ARCH-001 at the wire layer.
**Recommendation:** If ARCH-001 fixed, name it `domain.FoursquarePlace`. If deferred, add a one-line comment in `domain/types.go` pointing to `foursquare.Place`.

---

## Items NOT re-flagged (covered by QA)

- `_maxResultsOnScreen = 30` no WHY — QA Flutter MINOR #1
- `feedCardAtVenue` ignores `country` — QA Flutter MINOR #3
- `cacheSize = 1000` multi-pod — QA Backend MINOR #5 (escalated angle as ARCH-005)
- `client.go:209` auth `fmt.Errorf` sentinel — QA Backend MINOR #2
- `resolveLocale` silent → en — QA Backend MINOR #1
- `apierror.WriteFrom` venue rate-limit unreachable — QA Backend MINOR #6
- `client_test.go:182` pointer-dance — QA Backend MINOR #4
