// In-app notifications inbox (SPEC §5.4).
//
// Routes (mounted in internal/server/router.go):
//
//	GET  /v1/notifications              — cursor-paginated inbox
//	GET  /v1/notifications/unread-count — single-int badge endpoint
//	POST /v1/notifications/read         — { ids:[…] } | { all:true }
//
// Read paths only — the write paths are emitted from the source-event
// services (toast / comment / follow) so the inbox row lands in the same
// transaction as the underlying mutation.
package handlers

import (
	"net/http"

	"github.com/google/uuid"

	"github.com/kamos/api/internal/cursor"
	"github.com/kamos/api/internal/domain"
	"github.com/kamos/api/internal/httperr"
)

// ListNotifications — GET /v1/notifications.
func (h *Handler) ListNotifications(w http.ResponseWriter, r *http.Request) {
	uid, ok := h.authedID(w, r)
	if !ok {
		return
	}
	limit := parseLimit(r, 20, 50)
	c, err := parseCursor(r)
	if err != nil {
		h.writeErr(w, "ListNotifications cursor", err)
		return
	}
	items, err := h.Services.Notification.List(r.Context(), uid,
		optTimestamp(c), optString(c.ID), limit)
	if err != nil {
		h.writeErr(w, "ListNotifications", err)
		return
	}
	page, next, hasMore := cursor.SliceAndCursor(items, limit, func(n domain.Notification) cursor.Cursor {
		return cursor.Cursor{CreatedAt: n.CreatedAt, ID: n.ID}
	})
	httperr.WriteJSON(w, http.StatusOK, cursor.Page[domain.Notification]{
		Items: page, NextCursor: next, HasMore: hasMore,
	})
}

// UnreadNotificationCount — GET /v1/notifications/unread-count.
func (h *Handler) UnreadNotificationCount(w http.ResponseWriter, r *http.Request) {
	uid, ok := h.authedID(w, r)
	if !ok {
		return
	}
	n, err := h.Services.Notification.CountUnread(r.Context(), uid)
	if err != nil {
		h.writeErr(w, "UnreadNotificationCount", err)
		return
	}
	httperr.WriteJSON(w, http.StatusOK, domain.UnreadCountResponse{Count: n})
}

// MarkNotificationsRead — POST /v1/notifications/read.
//
// Body is one of:
//
//	{ "ids": ["uuid", ...] }   -- mark the listed ids read (own only)
//	{ "all": true }            -- mark every unread row read
//
// Returns 200 with `{ "marked": N }`.
//
// IDOR note: when `ids` contains a UUID that does NOT belong to the
// caller, the unmatched rows are silently skipped (the SQL WHERE clause
// scopes the UPDATE to recipient_user_id = $caller). We respond 200 with
// the actual rowcount rather than 404, so this endpoint cannot be used as
// a probing oracle for "does notification X exist on any user".
func (h *Handler) MarkNotificationsRead(w http.ResponseWriter, r *http.Request) {
	uid, ok := h.authedID(w, r)
	if !ok {
		return
	}
	var req domain.MarkReadRequest
	if err := decodeJSON(r, &req); err != nil {
		h.writeErr(w, "MarkNotificationsRead decode", err)
		return
	}
	hasIDs := len(req.IDs) > 0
	if hasIDs == req.All {
		httperr.WriteValidation(w, "exactly one of `ids` or `all` is required")
		return
	}

	// SEC-003: cap the batch size before the UUID parse loop. 100 is
	// comfortably above the SPEC page-size of 20 (a scroll-driven batch
	// of "mark-read on view" rarely exceeds one page) and small enough
	// that a malicious caller cannot push pgx into building a giant
	// $2::uuid[] array.
	if hasIDs && len(req.IDs) > 100 {
		httperr.WriteValidation(w, "ids cannot exceed 100 entries")
		return
	}

	// Pre-validate UUIDs at the edge so a malformed string surfaces as
	// 422 instead of a generic 500 from pgx's text→uuid cast failure.
	if hasIDs {
		for _, id := range req.IDs {
			if _, err := uuid.Parse(id); err != nil {
				httperr.WriteValidation(w, "ids contains a non-UUID value")
				return
			}
		}
	}

	var (
		marked int
		err    error
	)
	if req.All {
		marked, err = h.Services.Notification.MarkAllRead(r.Context(), uid)
	} else {
		marked, err = h.Services.Notification.MarkRead(r.Context(), uid, req.IDs)
	}
	if err != nil {
		h.writeErr(w, "MarkNotificationsRead", err)
		return
	}
	httperr.WriteJSON(w, http.StatusOK, domain.MarkReadResponse{Marked: marked})
}
