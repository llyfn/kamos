package handlers

import (
	"errors"
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"

	"github.com/kamos/api/internal/cursor"
	"github.com/kamos/api/internal/domain"
	"github.com/kamos/api/internal/httperr"
	"github.com/kamos/api/internal/middleware"
	"github.com/kamos/api/internal/repository"
)

// GetMe — GET /v1/users/me.
//
// response includes `role` (RBAC) and `deleted_at` so the admin
// client can branch on privileges + the Flutter app can surface
// suspension state.
func (h *Handler) GetMe(w http.ResponseWriter, r *http.Request) {
	uid, ok := h.authedID(w, r)
	if !ok {
		return
	}
	me, err := h.Repos.Users.FindMe(r.Context(), uid)
	if err != nil {
		h.writeErr(w, "GetMe find", err)
		return
	}
	stats, err := h.Repos.Users.Stats(r.Context(), uid)
	if err != nil {
		h.writeErr(w, "GetMe stats", err)
		return
	}
	httperr.WriteJSON(w, http.StatusOK, domain.Me{
		User:      me.User,
		Stats:     stats,
		Role:      me.Role,
		DeletedAt: me.DeletedAt,
	})
}

// UpdateMe — PATCH /v1/users/me.
func (h *Handler) UpdateMe(w http.ResponseWriter, r *http.Request) {
	uid, ok := h.authedID(w, r)
	if !ok {
		return
	}
	var req domain.UpdateMeRequest
	if err := decodeJSON(r, &req); err != nil {
		h.writeErr(w, "UpdateMe decode", err)
		return
	}
	if err := req.Validate(); err != nil {
		h.writeErr(w, "UpdateMe validate", err)
		return
	}
	user, err := h.Repos.Users.UpdateMe(r.Context(), uid, req)
	if err != nil {
		h.writeErr(w, "UpdateMe update", err)
		return
	}
	httperr.WriteJSON(w, http.StatusOK, user)
}

// DeleteMe — DELETE /v1/users/me. Soft-delete + 30-day username hold.
//
// After the DB UPDATE commits we Add(uid) to the in-memory soft-delete
// cache (SEC-006). This revokes the user's outstanding JWTs immediately —
// the next request with the now-doomed token gets 401 ACCOUNT_DELETED
// instead of waiting for the access-token TTL to expire.
func (h *Handler) DeleteMe(w http.ResponseWriter, r *http.Request) {
	uid, ok := h.authedID(w, r)
	if !ok {
		return
	}
	if err := h.Repos.Users.SoftDelete(r.Context(), uid); err != nil {
		h.writeErr(w, "DeleteMe", err)
		return
	}
	if _, err := h.Repos.RefreshTokens.RevokeAllForUser(r.Context(), uid); err != nil {
		h.writeErr(w, "DeleteMe revoke refresh", err)
		return
	}
	if h.SoftDelete != nil {
		h.SoftDelete.Add(uid)
	}
	w.WriteHeader(http.StatusNoContent)
}

// publicProfile is the response shape for GET /v1/users/{username}.
// Embeds PublicUser (not User) so email + email_verified never reach the wire.
type publicProfile struct {
	domain.PublicUser
	Stats       domain.UserStats `json:"stats"`
	FollowState string           `json:"follow_state,omitempty"` // 'accepted' | 'pending' | ''
	Restricted  bool             `json:"restricted"`             // private + caller not approved
}

// GetUser — GET /v1/users/{username}. Public profile, optional auth for
// follow-state hints. Private profiles return only basic fields to non-
// followers and set `restricted: true` so the client hides check-ins.
func (h *Handler) GetUser(w http.ResponseWriter, r *http.Request) {
	username := chi.URLParam(r, "username")
	user, err := h.Repos.Users.FindByUsername(r.Context(), username)
	if err != nil {
		h.writeErr(w, "GetUser find", err)
		return
	}
	viewer := middleware.UserFromContext(r.Context())
	stats, err := h.Repos.Users.Stats(r.Context(), user.ID)
	if err != nil {
		h.writeErr(w, "GetUser stats", err)
		return
	}
	out := publicProfile{PublicUser: user.ToPublic(), Stats: stats}
	if viewer != nil && viewer.ID != user.ID {
		s, err := h.Repos.Social.FollowState(r.Context(), viewer.ID, user.ID)
		if err != nil {
			h.writeErr(w, "GetUser follow state", err)
			return
		}
		out.FollowState = s
	}
	if user.PrivacyMode == "private" {
		if viewer == nil || (viewer.ID != user.ID && out.FollowState != "accepted") {
			out.Restricted = true
		}
	}
	httperr.WriteJSON(w, http.StatusOK, out)
}

// GetUserCheckins — GET /v1/users/{username}/check-ins.
// Private accounts return an empty page to non-followers (the repository
// already gates rows by privacy).
func (h *Handler) GetUserCheckins(w http.ResponseWriter, r *http.Request) {
	username := chi.URLParam(r, "username")
	user, err := h.Repos.Users.FindByUsername(r.Context(), username)
	if err != nil {
		h.writeErr(w, "GetUserCheckins find", err)
		return
	}
	viewerID := ""
	if v := middleware.UserFromContext(r.Context()); v != nil {
		viewerID = v.ID
	}
	limit := parseLimit(r, 20, 50)
	c, err := parseCursor(r)
	if err != nil {
		h.writeErr(w, "GetUserCheckins cursor", err)
		return
	}
	ts, id := optTimestamp(c), optString(c.ID)
	items, err := h.Repos.Checkins.UserCheckins(r.Context(), viewerID, user.ID, ts, id, limit)
	if err != nil {
		if errors.Is(err, domain.ErrNotFound) {
			httperr.WriteError(w, http.StatusNotFound, "NOT_FOUND", "not found")
			return
		}
		h.writeErr(w, "GetUserCheckins", err)
		return
	}
	rows, next, hasMore := cursor.SliceAndCursor(items, limit, func(c domain.Checkin) cursor.Cursor {
		return cursor.Cursor{CreatedAt: c.CreatedAt, ID: c.ID}
	})
	httperr.WriteJSON(w, http.StatusOK, cursor.Page[domain.Checkin]{
		Items: rows, NextCursor: next, HasMore: hasMore,
	})
}

// GetUserFollowers — GET /v1/users/{username}/followers.
//
// Status: scaffold-for-Phase6 (future profile screen iteration: followers
// list). Endpoint is intentionally pre-wired; no Flutter caller in MVP.
func (h *Handler) GetUserFollowers(w http.ResponseWriter, r *http.Request) {
	h.listSocial(w, r, true)
}

// GetUserFollowing — GET /v1/users/{username}/following.
//
// Status: scaffold-for-Phase6 (future profile screen iteration: following
// list). Endpoint is intentionally pre-wired; no Flutter caller in MVP.
func (h *Handler) GetUserFollowing(w http.ResponseWriter, r *http.Request) {
	h.listSocial(w, r, false)
}

func (h *Handler) listSocial(w http.ResponseWriter, r *http.Request, followers bool) {
	username := chi.URLParam(r, "username")
	user, err := h.Repos.Users.FindByUsername(r.Context(), username)
	if err != nil {
		h.writeErr(w, "listSocial find", err)
		return
	}
	limit := parseLimit(r, 20, 50)
	c, err := parseCursor(r)
	if err != nil {
		h.writeErr(w, "listSocial cursor", err)
		return
	}
	ts := optTimestamp(c)
	cid := optString(c.ID)
	var rows []repository.SocialUser
	if followers {
		rows, err = h.Repos.Social.Followers(r.Context(), user.ID, ts, cid, limit)
	} else {
		rows, err = h.Repos.Social.Following(r.Context(), user.ID, ts, cid, limit)
	}
	if err != nil {
		h.writeErr(w, "listSocial query", err)
		return
	}
	page, next, hasMore := cursor.SliceAndCursor(rows, limit, func(s repository.SocialUser) cursor.Cursor {
		return cursor.Cursor{CreatedAt: s.FollowedAt, ID: s.ID}
	})
	httperr.WriteJSON(w, http.StatusOK, cursor.Page[repository.SocialUser]{
		Items: page, NextCursor: next, HasMore: hasMore,
	})
}

// optTimestamp returns a *time.Time when the cursor was non-empty; otherwise
// nil. The repository SQL uses NULL to mean "first page".
func optTimestamp(c cursor.Cursor) *time.Time {
	if c.CreatedAt.IsZero() {
		return nil
	}
	t := c.CreatedAt
	return &t
}

// optString returns a *string only when non-empty.
func optString(s string) *string {
	if s == "" {
		return nil
	}
	return &s
}
