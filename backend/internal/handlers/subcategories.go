// subcategories.go — public read endpoint for the beverage_subcategories
// taxonomy table. Slice C (migration 005).
//
// The endpoint is cached per (category, locale) tuple via the existing
// in-process LRU bundle. Admin mutations on /v1/admin/subcategories emit
// pg_notify('kamos_cache_invalidate', 'subcategories') so every replica
// drops the slot on the next NOTIFY tick.

package handlers

import (
	"net/http"

	"github.com/kamos/api/internal/domain"
	"github.com/kamos/api/internal/httperr"
)

// ListSubcategories — GET /v1/subcategories[?category=<slug>]
//
// Returns the live (deleted_at IS NULL) subcategories ordered by
// (category_slug, sort_order, slug). When `category` is supplied (one of
// the SPEC §2.1 slugs) the list is filtered to that category. The shape
// mirrors the slim Subcategory ref carried inline on Beverage responses.
func (h *Handler) ListSubcategories(w http.ResponseWriter, r *http.Request) {
	categoryQuery := r.URL.Query().Get("category")
	var categoryPtr *string
	keyCat := "all"
	if categoryQuery != "" {
		categoryPtr = &categoryQuery
		keyCat = categoryQuery
	}
	key := keyCat + ":" + localeKey(r)
	//nolint:contextcheck // loader runs synchronously inside the request; captures r.Context() (GetOrLoad takes no ctx).
	loader := func() ([]domain.Subcategory, error) {
		return h.Repos.Subcategories.List(r.Context(), categoryPtr)
	}
	if h.Caches == nil {
		rows, err := loader()
		if err != nil {
			h.writeErr(w, "ListSubcategories", err)
			return
		}
		httperr.WriteJSON(w, http.StatusOK, rows)
		return
	}
	rows, err := h.Caches.Subcategories.GetOrLoad(key, loader)
	if err != nil {
		h.writeErr(w, "ListSubcategories", err)
		return
	}
	httperr.WriteJSON(w, http.StatusOK, rows)
}
