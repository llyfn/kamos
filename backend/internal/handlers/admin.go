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

// ============================================================================
// Stage 8 — admin catalog CRUD request bodies
// ============================================================================
//
// Both beverage + brewery use the same validation strategy: every text
// field flows through domain.SanitizeText so the bidi-override /
// control-char guards apply to admin-curated catalog data exactly the
// way they apply to user-submitted check-in reviews. Numeric ranges
// (abv 0–60, polishing_ratio 0–100, founded_year 800–2100) are tighter
// than the DB CHECK constraints — the schema accepts abv up to 70 but
// the admin tooling caps direct writes at 60 since anything above 60%
// is almost certainly bad data.

// AdminBeverageCreate is the body for POST /v1/admin/beverages.
type AdminBeverageCreate struct {
	BreweryID      string           `json:"brewery_id"`
	CategoryID     string           `json:"category_id"`
	NameI18n       domain.I18nText  `json:"name_i18n"`
	SubcategoryI18n *domain.I18nText `json:"subcategory_i18n,omitempty"`
	ABV             *float64        `json:"abv,omitempty"`
	PolishingRatio  *int            `json:"polishing_ratio,omitempty"`
	FlavorProfile   []string        `json:"flavor_profile,omitempty"`
	Prefecture      *string         `json:"prefecture,omitempty"`
	Region          *string         `json:"region,omitempty"`
	DescriptionI18n *domain.I18nText `json:"description_i18n,omitempty"`
	LabelImageURL   *string         `json:"label_image_url,omitempty"`
}

// Validate enforces SPEC §2.2 catalog field rules. See validateBeverageFields
// for the shared body — Update calls the same predicate against its partial
// inputs.
func (r *AdminBeverageCreate) Validate() error {
	if r.BreweryID == "" {
		return wrapV("brewery_id is required")
	}
	if r.CategoryID == "" {
		return wrapV("category_id is required")
	}
	if r.NameI18n.EN == "" || r.NameI18n.JA == "" {
		return wrapV("name_i18n.en and name_i18n.ja are required")
	}
	if err := sanitizeI18n("name_i18n", &r.NameI18n, 200); err != nil {
		return err
	}
	if r.SubcategoryI18n != nil {
		if err := sanitizeI18n("subcategory_i18n", r.SubcategoryI18n, 200); err != nil {
			return err
		}
	}
	if r.DescriptionI18n != nil {
		if err := sanitizeI18n("description_i18n", r.DescriptionI18n, 2000); err != nil {
			return err
		}
	}
	if r.ABV != nil && (*r.ABV < 0 || *r.ABV > 60) {
		return wrapV("abv must be between 0 and 60")
	}
	if r.PolishingRatio != nil && (*r.PolishingRatio < 0 || *r.PolishingRatio > 100) {
		return wrapV("polishing_ratio must be between 0 and 100")
	}
	if err := sanitizeOptional("prefecture", r.Prefecture, 100); err != nil {
		return err
	}
	if err := sanitizeOptional("region", r.Region, 100); err != nil {
		return err
	}
	if err := validateLabelImageURL(r.LabelImageURL); err != nil {
		return err
	}
	return nil
}

// AdminBeverageUpdate is the body for PATCH /v1/admin/beverages/{id}.
// Every field is a pointer; nil means "leave unchanged". A non-nil but
// all-empty I18nText on subcategory/description clears the column.
type AdminBeverageUpdate struct {
	BreweryID       *string          `json:"brewery_id,omitempty"`
	CategoryID      *string          `json:"category_id,omitempty"`
	NameI18n        *domain.I18nText `json:"name_i18n,omitempty"`
	SubcategoryI18n *domain.I18nText `json:"subcategory_i18n,omitempty"`
	ABV             *float64         `json:"abv,omitempty"`
	PolishingRatio  *int             `json:"polishing_ratio,omitempty"`
	FlavorProfile   *[]string        `json:"flavor_profile,omitempty"`
	Prefecture      *string          `json:"prefecture,omitempty"`
	Region          *string          `json:"region,omitempty"`
	DescriptionI18n *domain.I18nText `json:"description_i18n,omitempty"`
	LabelImageURL   *string          `json:"label_image_url,omitempty"`
}

func (r *AdminBeverageUpdate) Validate() error {
	if r.NameI18n != nil {
		if r.NameI18n.EN == "" || r.NameI18n.JA == "" {
			return wrapV("name_i18n.en and name_i18n.ja are required")
		}
		if err := sanitizeI18n("name_i18n", r.NameI18n, 200); err != nil {
			return err
		}
	}
	if r.SubcategoryI18n != nil {
		if err := sanitizeI18n("subcategory_i18n", r.SubcategoryI18n, 200); err != nil {
			return err
		}
	}
	if r.DescriptionI18n != nil {
		if err := sanitizeI18n("description_i18n", r.DescriptionI18n, 2000); err != nil {
			return err
		}
	}
	if r.ABV != nil && (*r.ABV < 0 || *r.ABV > 60) {
		return wrapV("abv must be between 0 and 60")
	}
	if r.PolishingRatio != nil && (*r.PolishingRatio < 0 || *r.PolishingRatio > 100) {
		return wrapV("polishing_ratio must be between 0 and 100")
	}
	if err := sanitizeOptional("prefecture", r.Prefecture, 100); err != nil {
		return err
	}
	if err := sanitizeOptional("region", r.Region, 100); err != nil {
		return err
	}
	if err := validateLabelImageURL(r.LabelImageURL); err != nil {
		return err
	}
	return nil
}

// AdminBreweryCreate is the body for POST /v1/admin/breweries.
type AdminBreweryCreate struct {
	NameI18n        domain.I18nText  `json:"name_i18n"`
	Prefecture      *string          `json:"prefecture,omitempty"`
	Region          *string          `json:"region,omitempty"`
	FoundedYear     *int             `json:"founded_year,omitempty"`
	Website         *string          `json:"website,omitempty"`
	DescriptionI18n *domain.I18nText `json:"description_i18n,omitempty"`
}

func (r *AdminBreweryCreate) Validate() error {
	if r.NameI18n.EN == "" || r.NameI18n.JA == "" {
		return wrapV("name_i18n.en and name_i18n.ja are required")
	}
	if err := sanitizeI18n("name_i18n", &r.NameI18n, 200); err != nil {
		return err
	}
	if r.DescriptionI18n != nil {
		if err := sanitizeI18n("description_i18n", r.DescriptionI18n, 2000); err != nil {
			return err
		}
	}
	if err := sanitizeOptional("prefecture", r.Prefecture, 100); err != nil {
		return err
	}
	if err := sanitizeOptional("region", r.Region, 100); err != nil {
		return err
	}
	if r.FoundedYear != nil && (*r.FoundedYear < 800 || *r.FoundedYear > 2100) {
		return wrapV("founded_year must be between 800 and 2100")
	}
	if err := validateWebsite(r.Website); err != nil {
		return err
	}
	return nil
}

// AdminBreweryUpdate is the body for PATCH /v1/admin/breweries/{id}.
type AdminBreweryUpdate struct {
	NameI18n        *domain.I18nText `json:"name_i18n,omitempty"`
	Prefecture      *string          `json:"prefecture,omitempty"`
	Region          *string          `json:"region,omitempty"`
	FoundedYear     *int             `json:"founded_year,omitempty"`
	Website         *string          `json:"website,omitempty"`
	DescriptionI18n *domain.I18nText `json:"description_i18n,omitempty"`
}

func (r *AdminBreweryUpdate) Validate() error {
	if r.NameI18n != nil {
		if r.NameI18n.EN == "" || r.NameI18n.JA == "" {
			return wrapV("name_i18n.en and name_i18n.ja are required")
		}
		if err := sanitizeI18n("name_i18n", r.NameI18n, 200); err != nil {
			return err
		}
	}
	if r.DescriptionI18n != nil {
		if err := sanitizeI18n("description_i18n", r.DescriptionI18n, 2000); err != nil {
			return err
		}
	}
	if err := sanitizeOptional("prefecture", r.Prefecture, 100); err != nil {
		return err
	}
	if err := sanitizeOptional("region", r.Region, 100); err != nil {
		return err
	}
	if r.FoundedYear != nil && (*r.FoundedYear < 800 || *r.FoundedYear > 2100) {
		return wrapV("founded_year must be between 800 and 2100")
	}
	if err := validateWebsite(r.Website); err != nil {
		return err
	}
	return nil
}

// sanitizeI18n runs each non-empty locale through SanitizeText. The struct
// pointer is mutated in place so the handler sees the normalized (DEL-
// stripped) text. allowEmpty=true on each locale because en/ja required
// checks already ran on the caller side.
func sanitizeI18n(field string, t *domain.I18nText, maxLen int) error {
	en, err := domain.SanitizeText(field+".en", t.EN, true, maxLen)
	if err != nil {
		return err
	}
	ja, err := domain.SanitizeText(field+".ja", t.JA, true, maxLen)
	if err != nil {
		return err
	}
	ko, err := domain.SanitizeText(field+".ko", t.KO, true, maxLen)
	if err != nil {
		return err
	}
	t.EN = en
	t.JA = ja
	t.KO = ko
	return nil
}

// sanitizeOptional runs an optional single-line string through SanitizeText.
// Nil pointer is a no-op (the field is being left unchanged); non-nil is
// always sanitized — empty string is allowed as a "clear" signal where the
// caller permits it.
func sanitizeOptional(field string, p *string, maxLen int) error {
	if p == nil {
		return nil
	}
	v, err := domain.SanitizeText(field, *p, false, maxLen)
	if err != nil {
		return err
	}
	*p = v
	return nil
}

// validateLabelImageURL enforces https + length cap. Nil = no change /
// no value. Empty pointer (= empty string) clears the column.
func validateLabelImageURL(p *string) error {
	if p == nil {
		return nil
	}
	if *p == "" {
		return nil
	}
	if len(*p) > 512 {
		return wrapV("label_image_url must be ≤ 512 characters")
	}
	if !strings.HasPrefix(*p, "https://") {
		return wrapV("label_image_url must start with https://")
	}
	return nil
}

// validateWebsite mirrors validateLabelImageURL.
func validateWebsite(p *string) error {
	if p == nil {
		return nil
	}
	if *p == "" {
		return nil
	}
	if len(*p) > 512 {
		return wrapV("website must be ≤ 512 characters")
	}
	if !strings.HasPrefix(*p, "https://") && !strings.HasPrefix(*p, "http://") {
		return wrapV("website must be a URL")
	}
	return nil
}

// wrapV mirrors domain.wrapValidation, kept local so admin.go can validate
// without exporting the domain helper. The handler.writeErr path picks up
// the domain.ErrValidation sentinel via errors.Is.
func wrapV(msg string) error {
	return errors.Join(domain.ErrValidation, errors.New(msg))
}
