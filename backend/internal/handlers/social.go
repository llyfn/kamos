package handlers

import (
	"net/http"

	"github.com/go-chi/chi/v5"

	"github.com/kamos/api/internal/cursor"
	"github.com/kamos/api/internal/domain"
	"github.com/kamos/api/internal/httperr"
)

// Follow — POST /v1/users/{username}/follow.
func (h *Handler) Follow(w http.ResponseWriter, r *http.Request) {
	uid, ok := h.authedID(w, r)
	if !ok {
		return
	}
	username := chi.URLParam(r, "username")
	target, err := h.Repos.Users.FindByUsername(r.Context(), username)
	if err != nil {
		h.writeErr(w, "Follow find", err)
		return
	}
	status, err := h.Services.Social.Follow(r.Context(), uid, target.ID)
	if err != nil {
		h.writeErr(w, "Follow", err)
		return
	}
	httperr.WriteJSON(w, http.StatusOK, domain.FollowResult{Status: status})
}

// Unfollow — DELETE /v1/users/{username}/follow.
func (h *Handler) Unfollow(w http.ResponseWriter, r *http.Request) {
	uid, ok := h.authedID(w, r)
	if !ok {
		return
	}
	username := chi.URLParam(r, "username")
	target, err := h.Repos.Users.FindByUsername(r.Context(), username)
	if err != nil {
		h.writeErr(w, "Unfollow find", err)
		return
	}
	if err := h.Services.Social.Unfollow(r.Context(), uid, target.ID); err != nil {
		h.writeErr(w, "Unfollow", err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// FollowRequests — GET /v1/follow-requests.
func (h *Handler) FollowRequests(w http.ResponseWriter, r *http.Request) {
	uid, ok := h.authedID(w, r)
	if !ok {
		return
	}
	limit := parseLimit(r, 20, 50)
	c, err := parseCursor(r)
	if err != nil {
		h.writeErr(w, "FollowRequests cursor", err)
		return
	}
	ts := optTimestamp(c)
	cid := optString(c.ID)
	rows, err := h.Repos.Social.Inbox(r.Context(), uid, ts, cid, limit)
	if err != nil {
		h.writeErr(w, "FollowRequests", err)
		return
	}
	items, next, hasMore := cursor.SliceAndCursor(rows, limit, func(f domain.FollowRequest) cursor.Cursor {
		return cursor.Cursor{CreatedAt: f.CreatedAt, ID: f.UserID}
	})
	httperr.WriteJSON(w, http.StatusOK, cursor.Page[domain.FollowRequest]{
		Items: items, NextCursor: next, HasMore: hasMore,
	})
}

// ApproveFollowRequest — POST /v1/follow-requests/{id}/approve. The `id`
// path param is the follower's user id (matches HANDOFF: requests are keyed
// by follower).
func (h *Handler) ApproveFollowRequest(w http.ResponseWriter, r *http.Request) {
	uid, ok := h.authedID(w, r)
	if !ok {
		return
	}
	followerID := chi.URLParam(r, "id")
	if err := h.Services.Social.Approve(r.Context(), uid, followerID); err != nil {
		h.writeErr(w, "ApproveFollowRequest", err)
		return
	}
	httperr.WriteJSON(w, http.StatusOK, domain.FollowResult{Status: "accepted"})
}

// DeclineFollowRequest — POST /v1/follow-requests/{id}/decline.
func (h *Handler) DeclineFollowRequest(w http.ResponseWriter, r *http.Request) {
	uid, ok := h.authedID(w, r)
	if !ok {
		return
	}
	followerID := chi.URLParam(r, "id")
	if err := h.Services.Social.Decline(r.Context(), uid, followerID); err != nil {
		h.writeErr(w, "DeclineFollowRequest", err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
