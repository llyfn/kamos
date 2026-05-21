// Phase 6a — flat comments on check-ins.
//
// Routes (router.go does the mounting):
//
//	GET    /v1/check-ins/{id}/comments  — OptionalAuth, cursor-paginated
//	POST   /v1/check-ins/{id}/comments  — authed; tight per-user rate limit
//	DELETE /v1/comments/{id}            — authed; own-comment OR admin/moderator
package handlers

import (
	"errors"
	"net/http"

	"github.com/go-chi/chi/v5"

	"github.com/kamos/api/internal/cursor"
	"github.com/kamos/api/internal/domain"
	"github.com/kamos/api/internal/httperr"
	"github.com/kamos/api/internal/middleware"
)

// ListComments — GET /v1/check-ins/{id}/comments.
//
// OptionalAuth. Cursor pagination on (created_at, id) DESC.
//
// Phase 6a fix: this endpoint NOW enforces the SPEC §3 private-account
// rule on the parent check-in. The check-in detail endpoint
// (`GET /v1/check-ins/{id}`) returns 404 to a non-follower of a private
// owner; the comment thread that hangs off the same check-in must do
// the same. Without this gate, a non-follower with the check-in UUID
// could enumerate the comment text — which often quotes the parent's
// review — defeating the privacy invariant on the parent.
func (h *Handler) ListComments(w http.ResponseWriter, r *http.Request) {
	checkInID := chi.URLParam(r, "id")

	// Privacy gate. viewerID is "" for anonymous requests.
	viewerID := commentsViewerID(r)
	if err := h.Repos.Checkins.AssertViewerCanSeeCheckin(r.Context(), checkInID, viewerID); err != nil {
		h.writeErr(w, "ListComments visibility", err)
		return
	}

	limit := parseLimit(r, 20, 50)
	c, err := parseCursor(r)
	if err != nil {
		h.writeErr(w, "ListComments cursor", err)
		return
	}
	items, err := h.Repos.Comments.List(r.Context(), checkInID,
		optTimestamp(c), optString(c.ID), limit)
	if err != nil {
		h.writeErr(w, "ListComments", err)
		return
	}
	page, next, hasMore := cursor.SliceAndCursor(items, limit, func(row domain.Comment) cursor.Cursor {
		return cursor.Cursor{CreatedAt: row.CreatedAt, ID: row.ID}
	})
	httperr.WriteJSON(w, http.StatusOK, cursor.Page[domain.Comment]{
		Items: page, NextCursor: next, HasMore: hasMore,
	})
}

// CreateComment — POST /v1/check-ins/{id}/comments. Returns 201 with the
// newly-created comment so the Flutter client can optimistic-insert without
// a follow-up GET.
func (h *Handler) CreateComment(w http.ResponseWriter, r *http.Request) {
	uid, ok := h.authedID(w, r)
	if !ok {
		return
	}
	checkInID := chi.URLParam(r, "id")
	var req domain.CreateCommentRequest
	if err := decodeJSON(r, &req); err != nil {
		h.writeErr(w, "CreateComment decode", err)
		return
	}
	if err := req.Validate(); err != nil {
		h.writeErr(w, "CreateComment validate", err)
		return
	}
	out, err := h.Repos.Comments.Create(r.Context(), checkInID, uid, req.Body)
	if err != nil {
		h.writeErr(w, "CreateComment", err)
		return
	}
	httperr.WriteJSON(w, http.StatusCreated, out)
}

// DeleteComment — DELETE /v1/comments/{id}.
//
// Allow if viewer owns the comment OR holds moderator+ role. Admin paths
// additionally write a moderation_log row.
func (h *Handler) DeleteComment(w http.ResponseWriter, r *http.Request) {
	uid, ok := h.authedID(w, r)
	if !ok {
		return
	}
	commentID := chi.URLParam(r, "id")

	c, err := h.Repos.Comments.Get(r.Context(), commentID)
	if err != nil {
		h.writeErr(w, "DeleteComment lookup", err)
		return
	}

	// Stage 7 (M-12.2): User may be nil for orphaned comments (author
	// hard-purged by the username-hold sweep). No owner means moderator+
	// is the only path that can authorize the delete.
	isOwner := c.User != nil && c.User.ID == uid
	isAdminPath := false
	if !isOwner {
		// Check role. NOT a hot path — we only run this branch when the
		// caller is trying to delete someone else's comment.
		role, err := h.Repos.Users.GetUserRole(r.Context(), uid)
		if err != nil {
			h.writeErr(w, "DeleteComment role", err)
			return
		}
		if role != domain.RoleAdmin && role != domain.RoleModerator {
			httperr.WriteError(w, http.StatusForbidden, "FORBIDDEN", "forbidden")
			return
		}
		isAdminPath = true
	}

	// Optional body for the moderation path: notes are recorded in
	// moderation_log. Owners can also send a body; we ignore it.
	var body struct {
		Notes string `json:"notes,omitempty"`
	}
	_ = decodeJSON(r, &body)
	var notesPtr *string
	if isAdminPath && body.Notes != "" {
		n := body.Notes
		notesPtr = &n
	}

	if err := h.Repos.Comments.SoftDelete(r.Context(), commentID, uid, isAdminPath, notesPtr); err != nil {
		// Soft-deletes might race with a second admin click — treat ErrNotFound
		// as success (idempotent), matching the toast / collection patterns.
		if errors.Is(err, domain.ErrNotFound) {
			httperr.WriteError(w, http.StatusNotFound, "NOT_FOUND", "not found")
			return
		}
		h.writeErr(w, "DeleteComment", err)
		return
	}

	if isAdminPath {
		h.Log.Info("admin moderation",
			"action", "comment_delete",
			"comment_id", commentID,
			"moderator_id", uid,
			"notes", body.Notes,
		)
	}
	w.WriteHeader(http.StatusNoContent)
}

// commentsViewerID extracts the viewer's user id from an OptionalAuth
// request, returning "" for anonymous callers. Used by the parent-privacy
// gate on the comment list endpoint.
func commentsViewerID(r *http.Request) string {
	if u := middleware.UserFromContext(r.Context()); u != nil {
		return u.ID
	}
	return ""
}
