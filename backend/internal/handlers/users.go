package handlers

import (
	"errors"
	"net/http"
	"strings"
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

// SearchUsers — GET /v1/users/search?q=...&cursor=...&limit=...
//
// OptionalAuth. Returns a page of PublicUser rows matching `q`:
//   - username prefix > display_name prefix > contains-either (ranked at
//     the SQL level so cursor pagination stays stable).
//   - Soft-deleted users excluded.
//   - No follower counts or private fields leak — the username is
//     inherently public (it's the canonical key for the profile route).
//
// `q` is sanitized via SanitizeText (control + bidi-override rejected),
// trimmed, and must be ≥ 2 chars; shorter queries return
// 400 INVALID_QUERY. Empty `q` returns the same.
//
// The opaque cursor carries (rank, created_at, id). Rank lives in the
// Cursor.Score slot — keyset pagination must order by rank first to
// keep results stable across the (rank ASC, created_at DESC, id DESC)
// outer sort. A 2-tuple of (created_at, id) would re-emit rows from
// earlier rank tiers on page 2+ and skip newer rows in later tiers.
func (h *Handler) SearchUsers(w http.ResponseWriter, r *http.Request) {
	raw := strings.TrimSpace(r.URL.Query().Get("q"))
	q, err := domain.SanitizeText("q", raw, false, 100)
	if err != nil {
		h.writeErr(w, "SearchUsers sanitize", err)
		return
	}
	if len([]rune(q)) < 2 {
		httperr.WriteError(w, http.StatusBadRequest, "INVALID_QUERY",
			"q must be at least 2 characters")
		return
	}
	limit := parseLimit(r, 20, 50)
	c, err := parseCursor(r)
	if err != nil {
		h.writeErr(w, "SearchUsers cursor", err)
		return
	}
	var sc *repository.SearchCursor
	if c.Score != nil && !c.CreatedAt.IsZero() && c.ID != "" {
		sc = &repository.SearchCursor{
			Rank:      int(*c.Score),
			CreatedAt: c.CreatedAt,
			ID:        c.ID,
		}
	}
	rows, err := h.Repos.Users.SearchUsers(r.Context(), q, sc, limit)
	if err != nil {
		h.writeErr(w, "SearchUsers", err)
		return
	}
	items, next, hasMore := cursor.SliceAndCursor(rows, limit, func(row repository.SearchRow) cursor.Cursor {
		score := int64(row.Rank)
		return cursor.Cursor{
			Score:     &score,
			CreatedAt: row.User.CreatedAt,
			ID:        row.User.ID,
		}
	})
	users := make([]domain.PublicUser, 0, len(items))
	for _, row := range items {
		users = append(users, row.User)
	}
	httperr.WriteJSON(w, http.StatusOK, cursor.Page[domain.PublicUser]{
		Items: users, NextCursor: next, HasMore: hasMore,
	})
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

// GetUserCollections — GET /v1/users/{username}/collections.
//
// OptionalAuth. Returns the page of collections belonging to the named
// user, visibility-gated by the viewer:
//   - viewer == owner: every live collection (public + private).
//   - otherwise: only `visibility = 'public'` rows.
//
// 404 USER_NOT_FOUND when the username does not resolve to a live user.
// Cursor on (created_at, id) DESC, default page 20 / max 50. The
// response shape matches GET /v1/collections (PageOfCollection).
func (h *Handler) GetUserCollections(w http.ResponseWriter, r *http.Request) {
	username := chi.URLParam(r, "username")
	owner, err := h.Repos.Users.FindByUsername(r.Context(), username)
	if err != nil {
		h.writeErr(w, "GetUserCollections find", err)
		return
	}
	viewerID := ""
	if v := middleware.UserFromContext(r.Context()); v != nil {
		viewerID = v.ID
	}
	limit := parseLimit(r, 20, 50)
	c, err := parseCursor(r)
	if err != nil {
		h.writeErr(w, "GetUserCollections cursor", err)
		return
	}
	rows, err := h.Repos.Collections.ListByUser(r.Context(),
		owner.ID, viewerID, optTimestamp(c), optString(c.ID), limit)
	if err != nil {
		h.writeErr(w, "GetUserCollections", err)
		return
	}
	items, next, hasMore := cursor.SliceAndCursor(rows, limit, func(row domain.Collection) cursor.Cursor {
		return cursor.Cursor{CreatedAt: row.CreatedAt, ID: row.ID}
	})
	httperr.WriteJSON(w, http.StatusOK, cursor.Page[domain.Collection]{
		Items: items, NextCursor: next, HasMore: hasMore,
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
	// Slice D: optional `?q=` prefix search across (username,
	// display_name). Empty / whitespace-only `q` is treated as
	// "no filter" — no error, the full list returns. Length cap
	// matches SPEC §3.2 username + display-name caps.
	var qPrefix *string
	if raw := strings.TrimSpace(r.URL.Query().Get("q")); raw != "" {
		clean, err := domain.SanitizeText("q", raw, false, 50)
		if err != nil {
			h.writeErr(w, "listSocial sanitize", err)
			return
		}
		if len([]rune(clean)) > 30 {
			httperr.WriteError(w, http.StatusBadRequest, "INVALID_QUERY",
				"q must be 30 characters or fewer")
			return
		}
		qPrefix = &clean
	}
	ts := optTimestamp(c)
	cid := optString(c.ID)
	var rows []repository.SocialUser
	if followers {
		rows, err = h.Repos.Social.Followers(r.Context(), user.ID, qPrefix, ts, cid, limit)
	} else {
		rows, err = h.Repos.Social.Following(r.Context(), user.ID, qPrefix, ts, cid, limit)
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
