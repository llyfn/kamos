// admin request bodies + validators.
//
// Stage 3 split: the actual HTTP handlers now live in:
//   - admin_beverage_requests.go (list, approve, reject)
//   - admin_users.go             (list, role update, suspend)
//   - admin_comments.go          (list, moderate)
//   - admin_checkins.go          (moderate)
//
// This file keeps only the wire-body types + per-body Validate methods +
// the shared `wrapV` validation-error helper, all referenced from the four
// split files above. We keep them in the handlers package so they can share
// `*Handler` without a constructor explosion (the route-mounting in
// server/router.go decides which role each endpoint requires).
package handlers

import (
	"errors"
	"strings"

	"github.com/kamos/api/internal/domain"
)

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
// the domain.ErrValidation sentinel via errors.Is.
func wrapV(msg string) error {
	return errors.Join(domain.ErrValidation, errors.New(msg))
}
