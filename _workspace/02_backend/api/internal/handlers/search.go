package handlers

import (
	"net/http"

	"github.com/kamos/api/internal/apierror"
	"github.com/kamos/api/internal/cursor"
	"github.com/kamos/api/internal/repository"
)

// Search — GET /v1/search?q=&type=&cursor=&limit=.
func (h *Handler) Search(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query().Get("q")
	if q == "" {
		apierror.WriteError(w, http.StatusUnprocessableEntity, "VALIDATION", "q is required")
		return
	}
	typ := r.URL.Query().Get("type")
	var typPtr *string
	if typ != "" {
		typPtr = &typ
	}
	limit := parseLimit(r, 20, 50)
	c, err := parseCursor(r)
	if err != nil {
		h.writeErr(w, "Search cursor", err)
		return
	}
	cid := optString(c.ID)
	results, err := h.Repos.Search.Search(r.Context(), q, typPtr, cid, limit)
	if err != nil {
		h.writeErr(w, "Search", err)
		return
	}
	items, next, hasMore := cursor.SliceAndCursor(results, limit, func(s repository.SearchResult) cursor.Cursor {
		id := ""
		if s.Beverage != nil {
			id = s.Beverage.ID
		} else if s.Brewery != nil {
			id = s.Brewery.ID
		}
		return cursor.Cursor{ID: id}
	})
	apierror.WriteJSON(w, http.StatusOK, cursor.Page[repository.SearchResult]{
		Items: items, NextCursor: next, HasMore: hasMore,
	})
}
