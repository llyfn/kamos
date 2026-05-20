// admin_comments.go — Phase 6a admin comment moderation surface. Split out
// of admin.go in Stage 3.
package handlers

import (
	"net/http"

	"github.com/go-chi/chi/v5"

	"github.com/kamos/api/internal/cursor"
	"github.com/kamos/api/internal/httperr"
	"github.com/kamos/api/internal/repository"
)

// AdminListComments — GET /v1/admin/comments
//
// Moderator-or-admin queue surface. `status=visible|deleted` filters; both
// cases include the most recent moderation_log row joined in, so the UI
// can show "deleted by @username, 3 days ago, notes: ..." inline.
func (h *Handler) AdminListComments(w http.ResponseWriter, r *http.Request) {
	limit := parseLimit(r, 20, 50)
	c, err := parseCursor(r)
	if err != nil {
		h.writeErr(w, "AdminListComments cursor", err)
		return
	}
	status := r.URL.Query().Get("status")
	var onlyDeleted bool
	switch status {
	case "", "visible":
		onlyDeleted = false
	case "deleted":
		onlyDeleted = true
	default:
		httperr.WriteError(w, http.StatusUnprocessableEntity, "VALIDATION",
			"status must be one of: visible, deleted")
		return
	}
	items, err := h.Repos.Comments.ListForAdmin(r.Context(),
		onlyDeleted, optTimestamp(c), optString(c.ID), limit)
	if err != nil {
		h.writeErr(w, "AdminListComments", err)
		return
	}
	page, next, hasMore := cursor.SliceAndCursor(items, limit, func(row repository.AdminCommentRow) cursor.Cursor {
		return cursor.Cursor{CreatedAt: row.CreatedAt, ID: row.ID}
	})
	httperr.WriteJSON(w, http.StatusOK, cursor.Page[repository.AdminCommentRow]{
		Items: page, NextCursor: next, HasMore: hasMore,
	})
}

// AdminModerateComment — POST /v1/admin/comments/{id}/moderate.
//
// Phase 6a admin-only path for explicit comment moderation with notes. The
// caller can equivalently DELETE /v1/comments/{id} (which we already gate
// by RBAC) — this endpoint exists so the admin client has a stable
// admin-specific endpoint for the moderation queue UI, with a notes
// requirement to match AdminRejectBeverageRequest's UX.
func (h *Handler) AdminModerateComment(w http.ResponseWriter, r *http.Request) {
	uid, ok := h.authedID(w, r)
	if !ok {
		return
	}
	commentID := chi.URLParam(r, "id")
	if commentID == "" {
		httperr.WriteError(w, http.StatusBadRequest, "BAD_REQUEST", "missing comment id")
		return
	}
	var body struct {
		Notes string `json:"notes,omitempty"`
	}
	_ = decodeJSON(r, &body)
	var notesPtr *string
	if body.Notes != "" {
		notesPtr = &body.Notes
	}
	// isAdmin=true so the repo writes the moderation_log row.
	if err := h.Repos.Comments.SoftDelete(r.Context(), commentID, uid, true, notesPtr); err != nil {
		h.writeErr(w, "AdminModerateComment", err)
		return
	}
	h.Log.Info("admin moderation",
		"action", "comment_delete",
		"comment_id", commentID,
		"moderator_id", uid,
		"notes", body.Notes,
	)
	w.WriteHeader(http.StatusNoContent)
}
