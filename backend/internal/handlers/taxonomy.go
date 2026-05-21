package handlers

import (
	"encoding/json"
	"net/http"

	"github.com/kamos/api/internal/domain"
	"github.com/kamos/api/internal/httperr"
)

// Categories — GET /v1/categories.
//
// in-process LRU cache keyed on Accept-Language. The repository
// returns all locales in the i18n JSON column, so the locale axis of the
// key is currently a forward-compat hedge — keeping it lets a future
// "locale-narrowed taxonomy" pivot drop in without a wire change. TTL +
// size live in cache.NewCaches.
//
// misses are coalesced via singleflight (GetOrLoad).
//
// Status: scaffold-for-Phase5 (admin needs server-validated taxonomy to
// populate dropdowns). Endpoint is intentionally pre-wired; Flutter uses
// the local `kCategoryStrings` constant in MVP.
func (h *Handler) Categories(w http.ResponseWriter, r *http.Request) {
	key := localeKey(r)
	loader := func() ([]domain.CategoryLabel, error) {
		return h.Repos.Taxonomy.Categories(r.Context())
	}
	if h.Caches == nil {
		rows, err := loader()
		if err != nil {
			h.writeErr(w, "Categories", err)
			return
		}
		httperr.WriteJSON(w, http.StatusOK, rows)
		return
	}
	rows, err := h.Caches.Categories.GetOrLoad(key, loader)
	if err != nil {
		h.writeErr(w, "Categories", err)
		return
	}
	httperr.WriteJSON(w, http.StatusOK, rows)
}

// FlavorTags — GET /v1/flavor-tags. See Categories for the cache key
// rationale; same shape, same TTL bucket.
func (h *Handler) FlavorTags(w http.ResponseWriter, r *http.Request) {
	key := localeKey(r)
	loader := func() ([]domain.FlavorTag, error) {
		return h.Repos.Taxonomy.FlavorTags(r.Context())
	}
	if h.Caches == nil {
		rows, err := loader()
		if err != nil {
			h.writeErr(w, "FlavorTags", err)
			return
		}
		httperr.WriteJSON(w, http.StatusOK, rows)
		return
	}
	rows, err := h.Caches.FlavorTags.GetOrLoad(key, loader)
	if err != nil {
		h.writeErr(w, "FlavorTags", err)
		return
	}
	httperr.WriteJSON(w, http.StatusOK, rows)
}

// SubmitBeverageRequest — POST /v1/beverage-requests.
//
// Status: scaffold-for-Phase5 (user-submitted beverages will wire the
// user-side form on top of this endpoint). Endpoint is intentionally
// pre-wired; no Flutter caller in MVP.
func (h *Handler) SubmitBeverageRequest(w http.ResponseWriter, r *http.Request) {
	uid, ok := h.authedID(w, r)
	if !ok {
		return
	}
	var req domain.BeverageRequest
	if err := decodeJSON(r, &req); err != nil {
		h.writeErr(w, "SubmitBeverageRequest decode", err)
		return
	}
	if err := req.Validate(); err != nil {
		h.writeErr(w, "SubmitBeverageRequest validate", err)
		return
	}
	payload, _ := json.Marshal(req.Payload)
	id, err := h.Repos.Beverages.SubmitAdditionRequest(r.Context(), &uid, payload)
	if err != nil {
		h.writeErr(w, "SubmitBeverageRequest", err)
		return
	}
	httperr.WriteJSON(w, http.StatusAccepted, map[string]string{"id": id})
}
