package handlers

import (
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/kamos/api/internal/apierror"
	"github.com/kamos/api/internal/cursor"
	"github.com/kamos/api/internal/domain"
	"github.com/kamos/api/internal/repository"
)

// ListBeverages — GET /v1/beverages.
// Query params: q, category (slug), cursor, limit. Sorted by check_in_count.
func (h *Handler) ListBeverages(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query().Get("q")
	cat := r.URL.Query().Get("category")
	limit := parseLimit(r, 20, 50)
	c, err := parseCursor(r)
	if err != nil {
		h.writeErr(w, "ListBeverages cursor", err)
		return
	}
	var (
		qPtr   *string
		catPtr *string
		cnt    *int64
		idPtr  *string
	)
	if q != "" {
		qPtr = &q
	}
	if cat != "" {
		catPtr = &cat
	}
	if c.Score != nil {
		cnt = c.Score
		if c.ID != "" {
			cid := c.ID
			idPtr = &cid
		}
	}
	rows, err := h.Repos.Beverages.List(r.Context(), repository.BeverageListParams{
		Q:            qPtr,
		CategorySlug: catPtr,
		CursorCount:  cnt,
		CursorID:     idPtr,
		Limit:        limit,
	})
	if err != nil {
		h.writeErr(w, "ListBeverages", err)
		return
	}
	items, next, hasMore := cursor.SliceAndCursor(rows, limit, func(b domain.Beverage) cursor.Cursor {
		score := int64(b.CheckInCount)
		return cursor.Cursor{Score: &score, ID: b.ID}
	})
	apierror.WriteJSON(w, http.StatusOK, cursor.Page[domain.Beverage]{
		Items: items, NextCursor: next, HasMore: hasMore,
	})
}

// GetBeverage — GET /v1/beverages/{id}. Includes aggregated flavor + recent.
//
// Phase 7: in-process LRU cache keyed on <id>:<locale>. The cached value
// is *domain.BeverageDetail — see cache.NewCaches for size/TTL. The
// response varies per viewer ONLY in scaffolded fields that aren't on
// BeverageDetail today (no you_toasted on this endpoint), so we serve
// the cached pointer directly. If a future commit adds a viewer-relative
// field to BeverageDetail, that handler MUST deep-copy before mutating —
// the cache hands out the same pointer to every concurrent request.
//
// Write-path invalidation (commit 4) busts <id>:* on every check-in
// create/update/delete so avg_rating + check_in_count stay fresh.
func (h *Handler) GetBeverage(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	cacheKey := id + ":" + localeKey(r)
	if h.Caches != nil {
		if cached, ok := h.Caches.BeverageDetail.Get(cacheKey); ok {
			apierror.WriteJSON(w, http.StatusOK, cached)
			return
		}
	}
	bv, err := h.Repos.Beverages.Detail(r.Context(), id)
	if err != nil {
		h.writeErr(w, "GetBeverage detail", err)
		return
	}
	flavor, err := h.Repos.Beverages.AggregatedFlavor(r.Context(), id)
	if err != nil {
		h.writeErr(w, "GetBeverage flavor", err)
		return
	}
	recent, err := h.Repos.Beverages.RecentCheckins(r.Context(), id, nil, nil, 10)
	if err != nil {
		h.writeErr(w, "GetBeverage recent", err)
		return
	}
	out := domain.BeverageDetail{
		Beverage:         *bv,
		AggregatedFlavor: flavor,
		RecentCheckins:   recent,
	}
	if len(recent) > 10 {
		out.RecentCheckins = recent[:10]
	}
	if h.Caches != nil {
		h.Caches.BeverageDetail.Set(cacheKey, &out)
	}
	apierror.WriteJSON(w, http.StatusOK, out)
}

// GetBeverageCheckins — GET /v1/beverages/{id}/check-ins. Cursor-paginated.
//
// Status: scaffold-for-Phase6 (discovery surfaces) and Phase5 (admin
// moderation by beverage). Endpoint is intentionally pre-wired; no Flutter
// caller in MVP (BeverageDetailScreen uses `recent_check_ins` inlined in
// `getBeverage`).
func (h *Handler) GetBeverageCheckins(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	limit := parseLimit(r, 20, 50)
	c, err := parseCursor(r)
	if err != nil {
		h.writeErr(w, "GetBeverageCheckins cursor", err)
		return
	}
	ts, cid := optTimestamp(c), optString(c.ID)
	rows, err := h.Repos.Beverages.RecentCheckins(r.Context(), id, ts, cid, limit)
	if err != nil {
		h.writeErr(w, "GetBeverageCheckins", err)
		return
	}
	items, next, hasMore := cursor.SliceAndCursor(rows, limit, func(c domain.CheckinSummary) cursor.Cursor {
		return cursor.Cursor{CreatedAt: c.CreatedAt, ID: c.ID}
	})
	apierror.WriteJSON(w, http.StatusOK, cursor.Page[domain.CheckinSummary]{
		Items: items, NextCursor: next, HasMore: hasMore,
	})
}

// ListBreweries — GET /v1/breweries.
func (h *Handler) ListBreweries(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query().Get("q")
	limit := parseLimit(r, 20, 50)
	c, err := parseCursor(r)
	if err != nil {
		h.writeErr(w, "ListBreweries cursor", err)
		return
	}
	var qPtr *string
	if q != "" {
		qPtr = &q
	}
	cid := optString(c.ID)
	rows, err := h.Repos.Breweries.List(r.Context(), qPtr, cid, limit)
	if err != nil {
		h.writeErr(w, "ListBreweries", err)
		return
	}
	items, next, hasMore := cursor.SliceAndCursor(rows, limit, func(b domain.Brewery) cursor.Cursor {
		return cursor.Cursor{ID: b.ID}
	})
	apierror.WriteJSON(w, http.StatusOK, cursor.Page[domain.Brewery]{
		Items: items, NextCursor: next, HasMore: hasMore,
	})
}

// GetBrewery — GET /v1/breweries/{id}. Includes beverage list (first page).
//
// Phase 7: only the brewery row itself is cached (LRU keyed on
// <id>:<locale>). The inline beverages page is intentionally NOT cached
// here — it's cursor-paginated and adding the cursor to the cache key
// would balloon the entry count. The beverage list query is already fast
// (<2ms p95 per Phase 1 metrics) and the brewery row is the expensive
// part (it carries the i18n description + beverage_count aggregate).
//
// ETag still hashes the combined response, so byte-identical repeat
// requests still short-circuit at the middleware layer.
func (h *Handler) GetBrewery(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	cacheKey := id + ":" + localeKey(r)
	var br *domain.Brewery
	if h.Caches != nil {
		if cached, ok := h.Caches.BreweryDetail.Get(cacheKey); ok {
			br = cached
		}
	}
	if br == nil {
		fetched, err := h.Repos.Breweries.Detail(r.Context(), id)
		if err != nil {
			h.writeErr(w, "GetBrewery", err)
			return
		}
		br = fetched
		if h.Caches != nil {
			h.Caches.BreweryDetail.Set(cacheKey, br)
		}
	}
	limit := parseLimit(r, 20, 50)
	c, err := parseCursor(r)
	if err != nil {
		h.writeErr(w, "GetBrewery cursor", err)
		return
	}
	cid := optString(c.ID)
	bevs, err := h.Repos.Breweries.Beverages(r.Context(), id, cid, limit)
	if err != nil {
		h.writeErr(w, "GetBrewery beverages", err)
		return
	}
	items, next, hasMore := cursor.SliceAndCursor(bevs, limit, func(b domain.Beverage) cursor.Cursor {
		return cursor.Cursor{ID: b.ID}
	})
	type out struct {
		domain.Brewery
		Beverages cursor.Page[domain.Beverage] `json:"beverages"`
	}
	apierror.WriteJSON(w, http.StatusOK, out{
		Brewery:   *br,
		Beverages: cursor.Page[domain.Beverage]{Items: items, NextCursor: next, HasMore: hasMore},
	})
}
