// flat comments on check-ins.
//
// Routes (router.go does the mounting):
//
//	GET    /v1/check-ins/{id}/comments  — OptionalAuth, cursor-paginated
//	POST   /v1/check-ins/{id}/comments  — authed; tight per-user rate limit
//	PATCH  /v1/comments/{id}            — authed; author-only edit (slice 01)
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
	"github.com/kamos/api/internal/spec"
)

// ListComments — GET /v1/check-ins/{id}/comments.
//
// OptionalAuth. Cursor pagination on (created_at, id) DESC.
//
// fix: this endpoint NOW enforces the SPEC §3 private-account
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

	limit := parseLimit(r, spec.PageSizeDefault, spec.PageSizeMax)
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
	out, err := h.Services.Comment.Create(r.Context(), checkInID, uid, req.Body)
	if err != nil {
		h.writeErr(w, "CreateComment", err)
		return
	}
	httperr.WriteJSON(w, http.StatusCreated, out)
}

// UpdateComment — PATCH /v1/comments/{id}.
//
// Author-only edit (slice 01 / SPEC §5.4). Body is the only mutable field;
// `edited_at` is touched by the repo only when the body actually changes
// (docs/db/query_patterns.md §19). A non-author attempt hits an empty
// RETURNING and surfaces as 404 — we don't leak comment existence to
// non-authors. Soft-deleted comments are also 404 (the WHERE clause
// filters them out).
func (h *Handler) UpdateComment(w http.ResponseWriter, r *http.Request) {
	uid, ok := h.authedID(w, r)
	if !ok {
		return
	}
	commentID := chi.URLParam(r, "id")
	var req domain.UpdateCommentRequest
	if err := decodeJSON(r, &req); err != nil {
		h.writeErr(w, "UpdateComment decode", err)
		return
	}
	if err := req.Validate(); err != nil {
		h.writeErr(w, "UpdateComment validate", err)
		return
	}
	if h.Services != nil && h.Services.Comment != nil {
		out, err := h.Services.Comment.Update(r.Context(), commentID, uid, req.Body)
		if err != nil {
			h.writeErr(w, "UpdateComment", err)
			return
		}
		httperr.WriteJSON(w, http.StatusOK, out)
		return
	}
	// Legacy fallback (tests that skip the service bundle).
	out, err := h.Repos.Comments.Update(r.Context(), commentID, uid, req.Body)
	if err != nil {
		h.writeErr(w, "UpdateComment", err)
		return
	}
	httperr.WriteJSON(w, http.StatusOK, out)
}

// DeleteComment — DELETE /v1/comments/{id}.
//
// Allow if viewer owns the comment OR holds moderator+ role. Admin paths
// additionally write a moderation_log row. All policy lives in
// CommentService.Delete — the handler is decode → call → respond.
func (h *Handler) DeleteComment(w http.ResponseWriter, r *http.Request) {
	uid, ok := h.authedID(w, r)
	if !ok {
		return
	}
	commentID := chi.URLParam(r, "id")

	// Optional body for the moderation path: notes are recorded in
	// moderation_log. The service ignores notes from owner callers.
	var body struct {
		Notes string `json:"notes,omitempty"`
	}
	_ = decodeJSON(r, &body)
	var notesPtr *string
	if body.Notes != "" {
		n := body.Notes
		notesPtr = &n
	}

	isAdminPath, err := h.Services.Comment.Delete(r.Context(), commentID, uid, notesPtr)
	if err != nil {
		// Soft-deletes might race with a second admin click — treat
		// ErrNotFound as 404 (idempotent), matching the toast / collection
		// patterns.
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
