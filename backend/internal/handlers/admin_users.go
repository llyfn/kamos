// admin_users.go — admin user management (list, role updates, suspend).
package handlers

import (
	"net/http"

	"github.com/go-chi/chi/v5"

	"github.com/kamos/api/internal/cursor"
	"github.com/kamos/api/internal/domain"
	"github.com/kamos/api/internal/httperr"
	"github.com/kamos/api/internal/repository"
	"github.com/kamos/api/internal/spec"
)

// AdminListUsers — GET /v1/admin/users
//
// Query params:
// - role: user|moderator|admin (optional)
// - include_deleted: 1 to include soft-deleted (default false)
// - username: exact-match lookup (case-insensitive via LOWER)
// - email:    exact-match lookup (case-insensitive via LOWER)
// - id:       exact-match lookup by UUID
// - cursor: opaque cursor token
// - limit: 1..50, default 20
//
// When any of `username`, `email`, `id` is set, the query collapses to a
// single indexed lookup and the cursor is ignored (has_more = false).
// Only one exact-match field may be set at a time; if multiple are
// supplied, the precedence is id > username > email (matches the repo's
// fast-path order).
func (h *Handler) AdminListUsers(w http.ResponseWriter, r *http.Request) {
	limit := parseLimit(r, spec.PageSizeDefault, spec.PageSizeMax)
	c, err := parseCursor(r)
	if err != nil {
		h.writeErr(w, "AdminListUsers cursor", err)
		return
	}
	roleFilter := r.URL.Query().Get("role")
	if roleFilter != "" && !domain.UserRole(roleFilter).Valid() {
		httperr.WriteError(w, http.StatusUnprocessableEntity, "VALIDATION",
			"role must be one of: user, moderator, admin")
		return
	}
	includeDeleted := r.URL.Query().Get("include_deleted") == "1"
	usernameExact := optString(r.URL.Query().Get("username"))
	emailExact := optString(r.URL.Query().Get("email"))
	idExact := optString(r.URL.Query().Get("id"))
	items, err := h.Repos.Admin.ListUsers(r.Context(), repository.ListUsersParams{
		RoleFilter:     roleFilter,
		IncludeDeleted: includeDeleted,
		UsernameExact:  usernameExact,
		EmailExact:     emailExact,
		IDExact:        idExact,
		CursorTs:       optTimestamp(c),
		CursorID:       optString(c.ID),
		Limit:          limit,
	})
	if err != nil {
		h.writeErr(w, "AdminListUsers", err)
		return
	}
	page, next, hasMore := cursor.SliceAndCursor(items, limit, func(u repository.AdminUserRow) cursor.Cursor {
		return cursor.Cursor{CreatedAt: u.CreatedAt, ID: u.ID}
	})
	httperr.WriteJSON(w, http.StatusOK, cursor.Page[repository.AdminUserRow]{
		Items: page, NextCursor: next, HasMore: hasMore,
	})
}

// AdminUpdateUserRole — POST /v1/admin/users/{id}/role
func (h *Handler) AdminUpdateUserRole(w http.ResponseWriter, r *http.Request) {
	uid, ok := h.authedID(w, r)
	if !ok {
		return
	}
	userID := chi.URLParam(r, "id")
	if userID == "" {
		httperr.WriteError(w, http.StatusBadRequest, "BAD_REQUEST", "missing user id")
		return
	}
	if userID == uid {
		// Prevent self-demotion lockout in production. An admin can be
		// demoted only by another admin.
		httperr.WriteError(w, http.StatusForbidden, "FORBIDDEN",
			"cannot change your own role")
		return
	}
	var body AdminUpdateRoleRequest
	if err := decodeJSON(r, &body); err != nil {
		h.writeErr(w, "AdminUpdateUserRole decode", err)
		return
	}
	if err := body.Validate(); err != nil {
		h.writeErr(w, "AdminUpdateUserRole validate", err)
		return
	}
	if h.Services != nil && h.Services.Admin != nil {
		if err := h.Services.Admin.UpdateUserRole(r.Context(), userID, uid, domain.UserRole(body.Role)); err != nil {
			h.writeErr(w, "AdminUpdateUserRole", err)
			return
		}
	} else if err := h.Repos.Admin.UpdateUserRole(r.Context(), userID, uid, domain.UserRole(body.Role)); err != nil {
		h.writeErr(w, "AdminUpdateUserRole", err)
		return
	}
	h.Log.Info("admin role update",
		"action", "role_update",
		"user_id", userID,
		"moderator_id", uid,
		"new_role", body.Role,
	)
	httperr.WriteJSON(w, http.StatusOK, map[string]string{
		"user_id": userID,
		"role":    body.Role,
	})
}

// AdminSuspendUser — POST /v1/admin/users/{id}/suspend
//
// Admin-initiated soft-delete. The user's existing JWTs are revoked by the
// SoftDeleteCache exactly the same way as a self-initiated DELETE /v1/users/me.
func (h *Handler) AdminSuspendUser(w http.ResponseWriter, r *http.Request) {
	uid, ok := h.authedID(w, r)
	if !ok {
		return
	}
	userID := chi.URLParam(r, "id")
	if userID == "" {
		httperr.WriteError(w, http.StatusBadRequest, "BAD_REQUEST", "missing user id")
		return
	}
	if userID == uid {
		httperr.WriteError(w, http.StatusForbidden, "FORBIDDEN",
			"cannot suspend yourself")
		return
	}
	if h.Services != nil && h.Services.Admin != nil {
		if err := h.Services.Admin.SuspendUser(r.Context(), userID, uid); err != nil {
			h.writeErr(w, "AdminSuspendUser", err)
			return
		}
	} else {
		if err := h.Repos.Admin.SuspendUser(r.Context(), userID, uid); err != nil {
			h.writeErr(w, "AdminSuspendUser", err)
			return
		}
		if _, err := h.Repos.RefreshTokens.RevokeAllForUser(r.Context(), userID); err != nil {
			h.writeErr(w, "AdminSuspendUser revoke refresh", err)
			return
		}
	}
	if h.SoftDelete != nil {
		h.SoftDelete.Add(userID)
	}
	h.Log.Info("admin suspend",
		"action", "user_suspend",
		"user_id", userID,
		"moderator_id", uid,
	)
	w.WriteHeader(http.StatusNoContent)
}
