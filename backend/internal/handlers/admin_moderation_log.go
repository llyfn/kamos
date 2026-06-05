// admin_moderation_log.go — read endpoint for the moderator audit trail.
// The write path is co-located with each admin action (approve / reject /
// moderate / suspend / role-change); this handler is the read counterpart
// so the React admin UI can render history without dropping into psql.
package handlers

import (
	"net/http"

	"github.com/kamos/api/internal/cursor"
	"github.com/kamos/api/internal/domain"
	"github.com/kamos/api/internal/httperr"
	"github.com/kamos/api/internal/repository"
)

// AdminListModerationLog — GET /v1/admin/moderation-log
//
// Query params (all optional):
//   - target_type:  one of {check_in, comment, user, beverage_request}
//   - target_id:    uuid; only meaningful with target_type
//   - moderator_id: uuid
//   - cursor:       opaque keyset cursor (signed)
//   - limit:        1..50, default 20
//
// Role gate (modOrAdmin) lives on the router. The repo trusts the gate.
func (h *Handler) AdminListModerationLog(w http.ResponseWriter, r *http.Request) {
	limit := parseLimit(r, 20, 50)
	c, err := parseCursor(r)
	if err != nil {
		h.writeErr(w, "AdminListModerationLog cursor", err)
		return
	}

	q := r.URL.Query()
	targetType := q.Get("target_type")
	switch targetType {
	case "", "check_in", "comment", "user", "beverage_request":
	default:
		httperr.WriteError(w, http.StatusUnprocessableEntity, "VALIDATION",
			"target_type must be one of: check_in, comment, user, beverage_request")
		return
	}

	items, err := h.Repos.ModerationLog.ListModerationLog(r.Context(),
		repository.ModerationLogFilter{
			TargetType:  targetType,
			TargetID:    q.Get("target_id"),
			ModeratorID: q.Get("moderator_id"),
		},
		optTimestamp(c), optString(c.ID), limit)
	if err != nil {
		h.writeErr(w, "AdminListModerationLog", err)
		return
	}

	page, next, hasMore := cursor.SliceAndCursor(items, limit,
		func(e domain.ModerationLogEntry) cursor.Cursor {
			return cursor.Cursor{CreatedAt: e.CreatedAt, ID: e.ID}
		})
	httperr.WriteJSON(w, http.StatusOK, cursor.Page[domain.ModerationLogEntry]{
		Items: page, NextCursor: next, HasMore: hasMore,
	})
}
