package handlers

import (
	"net/http"

	"github.com/go-chi/chi/v5"

	"github.com/kamos/api/internal/cursor"
	"github.com/kamos/api/internal/domain"
	"github.com/kamos/api/internal/httperr"
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
	)
	if q != "" {
		qPtr = &q
	}
	if cat != "" {
		catPtr = &cat
	}
	// Popularity cursor uses the (CheckInCount, CreatedAt, ID) triple.
	// Legacy cursors that only carry Score+ID are still honored — the
	// missing timestamp keeps the keyset at a 2-tuple, which simply walks
	// a slightly larger page boundary on the upgrade transition.
	cnt := c.Score
	ts := optTimestamp(c)
	idPtr := optString(c.ID)
	rows, err := h.Repos.Beverages.List(r.Context(), repository.BeverageListParams{
		Q:            qPtr,
		CategorySlug: catPtr,
		CursorCount:  cnt,
		CursorTs:     ts,
		CursorID:     idPtr,
		Limit:        limit,
	})
	if err != nil {
		h.writeErr(w, "ListBeverages", err)
		return
	}
	items, next, hasMore := cursor.SliceAndCursor(rows, limit, func(b domain.Beverage) cursor.Cursor {
		score := int64(b.CheckInCount)
		return cursor.Cursor{Score: &score, CreatedAt: b.CreatedAt, ID: b.ID}
	})
	httperr.WriteJSON(w, http.StatusOK, cursor.Page[domain.Beverage]{
		Items: items, NextCursor: next, HasMore: hasMore,
	})
}

// GetBeverage — GET /v1/beverages/{id}. Includes aggregated flavor + recent.
//
// in-process LRU cache keyed on <id>:<locale>. // fix: the cached value is now `domain.BeverageDetail` (a value, not a
// pointer), so Get returns a struct copy and a future per-viewer overlay
// can mutate the result without leaking across requests. The copy cost
// is ~1 KB per call — invisible compared to the saved DB trio (Detail
// + AggregatedFlavor + RecentCheckins).
//
// misses are coalesced via singleflight (see
// LRU.GetOrLoad). On a hot key during a campaign spike, only one
// loader runs while concurrent callers share its result.
//
// Write-path invalidation busts <id>:* on every check-in
// create/update/delete so avg_rating + check_in_count stay fresh.
func (h *Handler) GetBeverage(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	cacheKey := id + ":" + localeKey(r)

	//nolint:contextcheck // loader runs synchronously inside the request; it captures r.Context() (GetOrLoad's signature takes no ctx).
	loader := func() (domain.BeverageDetail, error) {
		bv, err := h.Repos.Beverages.Detail(r.Context(), id)
		if err != nil {
			return domain.BeverageDetail{}, err
		}
		flavor, err := h.Repos.Beverages.AggregatedFlavor(r.Context(), id)
		if err != nil {
			return domain.BeverageDetail{}, err
		}
		recent, err := h.Repos.Beverages.RecentCheckins(r.Context(), id, nil, nil, 10)
		if err != nil {
			return domain.BeverageDetail{}, err
		}
		out := domain.BeverageDetail{
			Beverage:         *bv,
			AggregatedFlavor: flavor,
			RecentCheckins:   recent,
		}
		if len(recent) > 10 {
			out.RecentCheckins = recent[:10]
		}
		return out, nil
	}

	if h.Caches == nil {
		// Test / no-cache wiring — fall through to the loader directly.
		out, err := loader()
		if err != nil {
			h.writeErr(w, "GetBeverage", err)
			return
		}
		httperr.WriteJSON(w, http.StatusOK, out)
		return
	}
	out, err := h.Caches.BeverageDetail.GetOrLoad(cacheKey, loader)
	if err != nil {
		h.writeErr(w, "GetBeverage", err)
		return
	}
	httperr.WriteJSON(w, http.StatusOK, out)
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
	httperr.WriteJSON(w, http.StatusOK, cursor.Page[domain.CheckinSummary]{
		Items: items, NextCursor: next, HasMore: hasMore,
	})
}

// ListProducers — GET /v1/producers.
func (h *Handler) ListProducers(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query().Get("q")
	limit := parseLimit(r, 20, 50)
	c, err := parseCursor(r)
	if err != nil {
		h.writeErr(w, "ListProducers cursor", err)
		return
	}
	var qPtr *string
	if q != "" {
		qPtr = &q
	}
	ts := optTimestamp(c)
	cid := optString(c.ID)
	rows, err := h.Repos.Producers.List(r.Context(), qPtr, ts, cid, limit)
	if err != nil {
		h.writeErr(w, "ListProducers", err)
		return
	}
	items, next, hasMore := cursor.SliceAndCursor(rows, limit, func(b domain.Producer) cursor.Cursor {
		return cursor.Cursor{CreatedAt: b.CreatedAt, ID: b.ID}
	})
	httperr.WriteJSON(w, http.StatusOK, cursor.Page[domain.Producer]{
		Items: items, NextCursor: next, HasMore: hasMore,
	})
}

// GetProducer — GET /v1/producers/{id}. Includes beverage list (first page).
//
// only the producer row itself is cached (LRU keyed on
// <id>:<locale>). The inline beverages page is intentionally NOT cached
// here — it's cursor-paginated and adding the cursor to the cache key
// would balloon the entry count. The beverage list query is already fast
// (<2ms p95 per metrics) and the producer row is the expensive
// part (it carries the i18n description + beverage_count aggregate).
//
// ProducerDetail is now a value cache; Get returns a
// struct copy. misses are coalesced via singleflight.
//
// ETag still hashes the combined response, so byte-identical repeat
// requests still short-circuit at the middleware layer.
func (h *Handler) GetProducer(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	cacheKey := id + ":" + localeKey(r)

	//nolint:contextcheck // loader runs synchronously inside the request; it captures r.Context() (GetOrLoad's signature takes no ctx).
	loader := func() (domain.Producer, error) {
		fetched, err := h.Repos.Producers.Detail(r.Context(), id)
		if err != nil {
			return domain.Producer{}, err
		}
		return *fetched, nil
	}

	var br domain.Producer
	if h.Caches == nil {
		got, err := loader()
		if err != nil {
			h.writeErr(w, "GetProducer", err)
			return
		}
		br = got
	} else {
		got, err := h.Caches.ProducerDetail.GetOrLoad(cacheKey, loader)
		if err != nil {
			h.writeErr(w, "GetProducer", err)
			return
		}
		br = got
	}

	limit := parseLimit(r, 20, 50)
	c, err := parseCursor(r)
	if err != nil {
		h.writeErr(w, "GetProducer cursor", err)
		return
	}
	ts := optTimestamp(c)
	cid := optString(c.ID)
	bevs, err := h.Repos.Producers.Beverages(r.Context(), id, ts, cid, limit)
	if err != nil {
		h.writeErr(w, "GetProducer beverages", err)
		return
	}
	items, next, hasMore := cursor.SliceAndCursor(bevs, limit, func(b domain.Beverage) cursor.Cursor {
		return cursor.Cursor{CreatedAt: b.CreatedAt, ID: b.ID}
	})
	type out struct {
		domain.Producer
		Beverages cursor.Page[domain.Beverage] `json:"beverages"`
	}
	httperr.WriteJSON(w, http.StatusOK, out{
		Producer:  br,
		Beverages: cursor.Page[domain.Beverage]{Items: items, NextCursor: next, HasMore: hasMore},
	})
}
