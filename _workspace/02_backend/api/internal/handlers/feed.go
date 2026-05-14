package handlers

import (
	"net/http"

	"github.com/kamos/api/internal/apierror"
	"github.com/kamos/api/internal/cursor"
	"github.com/kamos/api/internal/domain"
)

// Feed — GET /v1/feed. 20 items per page, reverse-chronological, follows
// only, excludes own check-ins (SPEC §5.2).
func (h *Handler) Feed(w http.ResponseWriter, r *http.Request) {
	uid, ok := h.authedID(w, r)
	if !ok {
		return
	}
	limit := parseLimit(r, 20, 20) // SPEC §5.2 hard-pins 20 for the feed
	c, err := parseCursor(r)
	if err != nil {
		h.writeErr(w, "Feed cursor", err)
		return
	}
	ts, id := optTimestamp(c), optString(c.ID)
	rows, err := h.Repos.Feed.Page(r.Context(), uid, ts, id, limit)
	if err != nil {
		h.writeErr(w, "Feed", err)
		return
	}
	items, next, hasMore := cursor.SliceAndCursor(rows, limit, func(it domain.FeedItem) cursor.Cursor {
		return cursor.Cursor{CreatedAt: it.CreatedAt, ID: it.ID}
	})
	apierror.WriteJSON(w, http.StatusOK, cursor.Page[domain.FeedItem]{
		Items: items, NextCursor: next, HasMore: hasMore,
	})
}
