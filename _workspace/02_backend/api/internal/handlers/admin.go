// Phase 5a — admin handlers. Mounted under /v1/admin/*, gated by
// middleware.RequireRole(...) per-route in server/router.go.
//
// We keep these in the same package as the other handlers so they can
// share *Handler (repos / logger / signer / etc) without a constructor
// explosion. The route-mounting is the single place that decides which
// role is required for each endpoint.
package handlers

import (
	"errors"
	"net/http"
	"strings"

	"github.com/go-chi/chi/v5"
	"github.com/kamos/api/internal/apierror"
	"github.com/kamos/api/internal/cursor"
	"github.com/kamos/api/internal/domain"
	"github.com/kamos/api/internal/repository"
)

// ----------------------------------------------------------------------------
// Request bodies
// ----------------------------------------------------------------------------

// AdminApproveBeverageRequest is the body for POST /v1/admin/beverage-requests/{id}/approve.
// The admin uses this to fill in canonical fields based on the user-
// submitted payload (which is free-form JSONB).
type AdminApproveBeverageRequest struct {
	BreweryID     string           `json:"brewery_id"`
	CategoryID    string           `json:"category_id"`
	NameI18n      domain.I18nText  `json:"name_i18n"`
	Subcategory   *domain.I18nText `json:"subcategory_i18n,omitempty"`
	ABV           *float64         `json:"abv,omitempty"`
	Prefecture    *string          `json:"prefecture,omitempty"`
	Region        *string          `json:"region,omitempty"`
	LabelImageURL *string          `json:"label_image_url,omitempty"`
	FlavorProfile []string         `json:"flavor_profile,omitempty"`
	Notes         *string          `json:"notes,omitempty"`
}

func (r *AdminApproveBeverageRequest) Validate() error {
	if r.BreweryID == "" {
		return wrapV("brewery_id is required")
	}
	if r.CategoryID == "" {
		return wrapV("category_id is required")
	}
	if r.NameI18n.EN == "" || r.NameI18n.JA == "" {
		return wrapV("name_i18n.en and name_i18n.ja are required")
	}
	if r.ABV != nil && (*r.ABV < 0 || *r.ABV > 70) {
		return wrapV("abv must be between 0 and 70")
	}
	return nil
}

// AdminRejectRequest is the body for POST /v1/admin/beverage-requests/{id}/reject.
type AdminRejectRequest struct {
	Notes string `json:"notes"`
}

func (r *AdminRejectRequest) Validate() error {
	r.Notes = strings.TrimSpace(r.Notes)
	if r.Notes == "" {
		return wrapV("notes is required")
	}
	if len([]rune(r.Notes)) > 500 {
		return wrapV("notes must be ≤ 500 characters")
	}
	return nil
}

// AdminUpdateRoleRequest is the body for POST /v1/admin/users/{id}/role.
type AdminUpdateRoleRequest struct {
	Role string `json:"role"`
}

func (r *AdminUpdateRoleRequest) Validate() error {
	role := domain.UserRole(r.Role)
	if !role.Valid() {
		return wrapV("role must be one of: user, moderator, admin")
	}
	r.Role = string(role)
	return nil
}

// wrapV mirrors domain.wrapValidation, kept local so admin.go can validate
// without exporting the domain helper. The handler.writeErr path picks up
// the apierror.ErrValidation sentinel via errors.Is.
func wrapV(msg string) error {
	return errors.Join(apierror.ErrValidation, errors.New(msg))
}

// ----------------------------------------------------------------------------
// Handlers
// ----------------------------------------------------------------------------

// AdminListBeverageRequests — GET /v1/admin/beverage-requests
//
// Query params:
//   - status: pending|approved|rejected (optional; default: all)
//   - cursor: opaque cursor token
//   - limit:  1..50, default 20
func (h *Handler) AdminListBeverageRequests(w http.ResponseWriter, r *http.Request) {
	limit := parseLimit(r, 20, 50)
	c, err := parseCursor(r)
	if err != nil {
		h.writeErr(w, "AdminListBeverageRequests cursor", err)
		return
	}
	statusFilter := r.URL.Query().Get("status")
	switch statusFilter {
	case "", "pending", "approved", "rejected":
	default:
		apierror.WriteError(w, http.StatusUnprocessableEntity, "VALIDATION",
			"status must be one of: pending, approved, rejected")
		return
	}
	items, err := h.Repos.Admin.ListBeverageRequests(r.Context(), repository.ListBeverageRequestsParams{
		StatusFilter: statusFilter,
		CursorTs:     optTimestamp(c),
		CursorID:     optString(c.ID),
		Limit:        limit,
	})
	if err != nil {
		h.writeErr(w, "AdminListBeverageRequests", err)
		return
	}
	page, next, hasMore := cursor.SliceAndCursor(items, limit, func(b repository.BeverageRequestRow) cursor.Cursor {
		return cursor.Cursor{CreatedAt: b.CreatedAt, ID: b.ID}
	})
	apierror.WriteJSON(w, http.StatusOK, cursor.Page[repository.BeverageRequestRow]{
		Items: page, NextCursor: next, HasMore: hasMore,
	})
}

// AdminApproveBeverageRequest — POST /v1/admin/beverage-requests/{id}/approve
func (h *Handler) AdminApproveBeverageRequest(w http.ResponseWriter, r *http.Request) {
	uid, ok := h.authedID(w, r)
	if !ok {
		return
	}
	requestID := chi.URLParam(r, "id")
	if requestID == "" {
		apierror.WriteError(w, http.StatusBadRequest, "BAD_REQUEST", "missing request id")
		return
	}
	var body AdminApproveBeverageRequest
	if err := decodeJSON(r, &body); err != nil {
		h.writeErr(w, "AdminApproveBeverageRequest decode", err)
		return
	}
	if err := body.Validate(); err != nil {
		h.writeErr(w, "AdminApproveBeverageRequest validate", err)
		return
	}
	bevID, err := h.Repos.Admin.ApproveBeverageRequest(r.Context(), repository.ApproveBeverageRequestParams{
		RequestID:     requestID,
		BreweryID:     body.BreweryID,
		CategoryID:    body.CategoryID,
		NameI18n:      body.NameI18n,
		Subcategory:   body.Subcategory,
		ABV:           body.ABV,
		Prefecture:    body.Prefecture,
		Region:        body.Region,
		LabelImageURL: body.LabelImageURL,
		FlavorProfile: body.FlavorProfile,
		ReviewerID:    uid,
		Notes:         body.Notes,
	})
	if err != nil {
		h.writeErr(w, "AdminApproveBeverageRequest", err)
		return
	}
	apierror.WriteJSON(w, http.StatusOK, map[string]string{
		"request_id":  requestID,
		"beverage_id": bevID,
	})
}

// AdminRejectBeverageRequest — POST /v1/admin/beverage-requests/{id}/reject
func (h *Handler) AdminRejectBeverageRequest(w http.ResponseWriter, r *http.Request) {
	uid, ok := h.authedID(w, r)
	if !ok {
		return
	}
	requestID := chi.URLParam(r, "id")
	if requestID == "" {
		apierror.WriteError(w, http.StatusBadRequest, "BAD_REQUEST", "missing request id")
		return
	}
	var body AdminRejectRequest
	if err := decodeJSON(r, &body); err != nil {
		h.writeErr(w, "AdminRejectBeverageRequest decode", err)
		return
	}
	if err := body.Validate(); err != nil {
		h.writeErr(w, "AdminRejectBeverageRequest validate", err)
		return
	}
	if err := h.Repos.Admin.RejectBeverageRequest(r.Context(), requestID, uid, body.Notes); err != nil {
		h.writeErr(w, "AdminRejectBeverageRequest", err)
		return
	}
	apierror.WriteJSON(w, http.StatusOK, map[string]string{
		"request_id": requestID,
		"status":     "rejected",
		"notes":      body.Notes,
	})
}

// AdminModerateCheckin — POST /v1/admin/check-ins/{id}/moderate
//
// Soft-deletes the check-in. The optional `notes` body field is not yet
// persisted (no audit table in Phase 5a) — it's logged for now.
func (h *Handler) AdminModerateCheckin(w http.ResponseWriter, r *http.Request) {
	uid, ok := h.authedID(w, r)
	if !ok {
		return
	}
	checkinID := chi.URLParam(r, "id")
	if checkinID == "" {
		apierror.WriteError(w, http.StatusBadRequest, "BAD_REQUEST", "missing check-in id")
		return
	}
	// Body is optional; we accept and log it but don't fail on parse error.
	var body struct {
		Notes string `json:"notes,omitempty"`
	}
	_ = decodeJSON(r, &body) // tolerate empty / missing
	if err := h.Repos.Admin.ModerateCheckin(r.Context(), checkinID); err != nil {
		h.writeErr(w, "AdminModerateCheckin", err)
		return
	}
	h.Log.Info("admin moderation",
		"action", "checkin_delete",
		"check_in_id", checkinID,
		"moderator_id", uid,
		"notes", body.Notes,
	)
	w.WriteHeader(http.StatusNoContent)
}

// AdminListUsers — GET /v1/admin/users
//
// Query params:
//   - role: user|moderator|admin (optional)
//   - include_deleted: 1 to include soft-deleted (default false)
//   - cursor: opaque cursor token
//   - limit:  1..50, default 20
func (h *Handler) AdminListUsers(w http.ResponseWriter, r *http.Request) {
	limit := parseLimit(r, 20, 50)
	c, err := parseCursor(r)
	if err != nil {
		h.writeErr(w, "AdminListUsers cursor", err)
		return
	}
	roleFilter := r.URL.Query().Get("role")
	if roleFilter != "" && !domain.UserRole(roleFilter).Valid() {
		apierror.WriteError(w, http.StatusUnprocessableEntity, "VALIDATION",
			"role must be one of: user, moderator, admin")
		return
	}
	includeDeleted := r.URL.Query().Get("include_deleted") == "1"
	items, err := h.Repos.Admin.ListUsers(r.Context(), repository.ListUsersParams{
		RoleFilter:     roleFilter,
		IncludeDeleted: includeDeleted,
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
	apierror.WriteJSON(w, http.StatusOK, cursor.Page[repository.AdminUserRow]{
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
		apierror.WriteError(w, http.StatusBadRequest, "BAD_REQUEST", "missing user id")
		return
	}
	if userID == uid {
		// Prevent self-demotion lockout in production. An admin can be
		// demoted only by another admin.
		apierror.WriteError(w, http.StatusForbidden, "FORBIDDEN",
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
	if err := h.Repos.Admin.UpdateUserRole(r.Context(), userID, domain.UserRole(body.Role)); err != nil {
		h.writeErr(w, "AdminUpdateUserRole", err)
		return
	}
	h.Log.Info("admin role update",
		"action", "role_update",
		"user_id", userID,
		"moderator_id", uid,
		"new_role", body.Role,
	)
	apierror.WriteJSON(w, http.StatusOK, map[string]string{
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
		apierror.WriteError(w, http.StatusBadRequest, "BAD_REQUEST", "missing user id")
		return
	}
	if userID == uid {
		apierror.WriteError(w, http.StatusForbidden, "FORBIDDEN",
			"cannot suspend yourself")
		return
	}
	if err := h.Repos.Admin.SuspendUser(r.Context(), userID); err != nil {
		h.writeErr(w, "AdminSuspendUser", err)
		return
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
