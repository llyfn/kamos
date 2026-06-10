package handlers

import (
	"net/http"

	"github.com/kamos/api/internal/cursor"
	"github.com/kamos/api/internal/httperr"
	"github.com/kamos/api/internal/repository"
	"github.com/kamos/api/internal/spec"
)

// Search — GET /v1/search?q=&type=&cursor=&limit=.
//
// Typeless ordering: beverages first (drained in popularity-then-id order),
// then producers (id DESC). The cursor's `t` discriminator records which
// sub-stream the next page should continue in:
//   - empty / no cursor → start at beverages
//   - `t=beverage`      → continue beverages with id < cursor.ID
//   - `t=producer`      → continue producers with id < cursor.ID
//
// When the beverage sub-stream is exhausted on a typeless query, the page
// rolls over to producers and the next cursor carries `t=producer`.
func (h *Handler) Search(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query().Get("q")
	if q == "" {
		httperr.WriteError(w, http.StatusUnprocessableEntity, "VALIDATION", "q is required")
		return
	}
	typ := r.URL.Query().Get("type")
	limit := parseLimit(r, spec.PageSizeDefault, spec.PageSizeMax)
	c, err := parseCursor(r)
	if err != nil {
		h.writeErr(w, "Search cursor", err)
		return
	}

	// Effective sub-stream this page is in. Caller-pinned `type` always wins
	// over the cursor's `t`. For typeless queries the cursor's `t` decides.
	stream := typ
	if stream == "" {
		stream = c.Type
		if stream == "" {
			stream = "beverage"
		}
	}

	cid := optString(c.ID)

	if stream == "beverage" {
		results, err := h.Repos.Search.SearchBeverages(r.Context(), q, cid, limit)
		if err != nil {
			h.writeErr(w, "Search beverages", err)
			return
		}
		items, next, hasMore := cursor.SliceAndCursor(results, limit, func(s repository.SearchResult) cursor.Cursor {
			return cursor.Cursor{ID: s.Beverage.ID, Type: "beverage"}
		})
		// Typeless query rollover. Two cases when the beverage sub-stream
		// is exhausted (`!hasMore`):
		//   1. items < limit → fill the rest of this page with producers.
		//   2. items == limit → page is full but next call must continue
		//      into producers, so synthesize a "start of producer" cursor.
		if !hasMore && typ == "" {
			if len(items) < limit {
				brw, err := h.Repos.Search.SearchProducers(r.Context(), q, nil, limit-len(items))
				if err != nil {
					h.writeErr(w, "Search beverages rollover", err)
					return
				}
				brwItems, brwNext, brwMore := cursor.SliceAndCursor(brw, limit-len(items), func(s repository.SearchResult) cursor.Cursor {
					return cursor.Cursor{ID: s.Producer.ID, Type: "producer"}
				})
				items = append(items, brwItems...)
				next, hasMore = brwNext, brwMore
			} else {
				// Probe producer stream for at least one row so we know
				// whether to advertise has_more.
				probe, err := h.Repos.Search.SearchProducers(r.Context(), q, nil, 1)
				if err != nil {
					h.writeErr(w, "Search beverages probe", err)
					return
				}
				if len(probe) > 0 {
					next = cursor.Encode(cursor.Cursor{Type: "producer"})
					hasMore = true
				}
			}
		}
		httperr.WriteJSON(w, http.StatusOK, cursor.Page[repository.SearchResult]{
			Items: items, NextCursor: next, HasMore: hasMore,
		})
		return
	}

	// stream == "producer"
	results, err := h.Repos.Search.SearchProducers(r.Context(), q, cid, limit)
	if err != nil {
		h.writeErr(w, "Search producers", err)
		return
	}
	items, next, hasMore := cursor.SliceAndCursor(results, limit, func(s repository.SearchResult) cursor.Cursor {
		return cursor.Cursor{ID: s.Producer.ID, Type: "producer"}
	})
	httperr.WriteJSON(w, http.StatusOK, cursor.Page[repository.SearchResult]{
		Items: items, NextCursor: next, HasMore: hasMore,
	})
}
