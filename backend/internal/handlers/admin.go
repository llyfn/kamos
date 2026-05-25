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
//
// Field set mirrors AdminBeverageCreate so the admin can drive both
// endpoints from the same form. Exactly one of `category_id` /
// `category_slug` is required; the handler resolves slug → UUID before
// the INSERT runs.
//
// Migration 016 dropped beverages.prefecture / beverages.region — the
// row's locality is now derived through the producer's prefecture_id, so
// per-beverage geo fields are no longer accepted. Re-curate the producer
// via PATCH /v1/admin/producers/{id} if needed before approving.
type AdminApproveBeverageRequest struct {
	ProducerID      string           `json:"producer_id"`
	CategoryID      *string          `json:"category_id,omitempty"`
	CategorySlug    *string          `json:"category_slug,omitempty"`
	NameI18n        domain.I18nText  `json:"name_i18n"`
	Subcategory     *domain.I18nText `json:"subcategory_i18n,omitempty"`
	ABV             *float64         `json:"abv,omitempty"`
	PolishingRatio  *int             `json:"polishing_ratio,omitempty"`
	LabelImageURL   *string          `json:"label_image_url,omitempty"`
	FlavorProfile   []string         `json:"flavor_profile,omitempty"`
	DescriptionI18n *domain.I18nText `json:"description_i18n,omitempty"`
	Notes           *string          `json:"notes,omitempty"`
}

func (r *AdminApproveBeverageRequest) Validate() error {
	if r.ProducerID == "" {
		return wrapV("producer_id is required")
	}
	hasID := r.CategoryID != nil && *r.CategoryID != ""
	hasSlug := r.CategorySlug != nil && *r.CategorySlug != ""
	if !hasID && !hasSlug {
		return wrapV("category_id or category_slug is required")
	}
	if r.NameI18n.EN == "" || r.NameI18n.JA == "" {
		return wrapV("name_i18n.en and name_i18n.ja are required")
	}
	return validateBeverageFields(
		&r.NameI18n, r.Subcategory, r.DescriptionI18n,
		r.ABV, r.PolishingRatio, r.LabelImageURL,
	)
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
// Both beverage + producer use the same validation strategy: every text
// field flows through domain.SanitizeText so the bidi-override /
// control-char guards apply to admin-curated catalog data exactly the
// way they apply to user-submitted check-in reviews. Numeric ranges
// (abv 0–60, polishing_ratio 0–100, founded_year 800–2100) are tighter
// than the DB CHECK constraints — the schema accepts abv up to 70 but
// the admin tooling caps direct writes at 60 since anything above 60%
// is almost certainly bad data.

// AdminBeverageCreate is the body for POST /v1/admin/beverages.
//
// Exactly one of `category_id` (UUID) or `category_slug` (one of
// `nihonshu` / `shochu` / `liqueur`) must be supplied. The admin SPA
// has no way to surface category UUIDs cleanly — `/v1/taxonomy/categories`
// only returns slug + label — so `category_slug` is the ergonomic path;
// `category_id` stays for any direct DB-aware caller. If both are sent
// `category_id` wins and `category_slug` is ignored.
type AdminBeverageCreate struct {
	ProducerID      string           `json:"producer_id"`
	CategoryID      *string          `json:"category_id,omitempty"`
	CategorySlug    *string          `json:"category_slug,omitempty"`
	NameI18n        domain.I18nText  `json:"name_i18n"`
	SubcategoryI18n *domain.I18nText `json:"subcategory_i18n,omitempty"`
	ABV             *float64         `json:"abv,omitempty"`
	PolishingRatio  *int             `json:"polishing_ratio,omitempty"`
	FlavorProfile   []string         `json:"flavor_profile,omitempty"`
	DescriptionI18n *domain.I18nText `json:"description_i18n,omitempty"`
	LabelImageURL   *string          `json:"label_image_url,omitempty"`
}

// Validate enforces SPEC §2.2 catalog field rules. The field-level
// sanitization + range checks are shared with Update via
// validateBeverageFields.
func (r *AdminBeverageCreate) Validate() error {
	if r.ProducerID == "" {
		return wrapV("producer_id is required")
	}
	hasID := r.CategoryID != nil && *r.CategoryID != ""
	hasSlug := r.CategorySlug != nil && *r.CategorySlug != ""
	if !hasID && !hasSlug {
		return wrapV("category_id or category_slug is required")
	}
	if r.NameI18n.EN == "" || r.NameI18n.JA == "" {
		return wrapV("name_i18n.en and name_i18n.ja are required")
	}
	return validateBeverageFields(
		&r.NameI18n, r.SubcategoryI18n, r.DescriptionI18n,
		r.ABV, r.PolishingRatio, r.LabelImageURL,
	)
}

// AdminBeverageUpdate is the body for PATCH /v1/admin/beverages/{id}.
// Every field is a pointer; nil means "leave unchanged". A non-nil but
// all-empty I18nText on subcategory/description clears the column.
//
// At most one of `category_id` / `category_slug` may be supplied. If both
// are sent, `category_id` wins. If only `category_slug` is supplied the
// handler resolves it to a UUID before the UPDATE runs.
type AdminBeverageUpdate struct {
	ProducerID      *string          `json:"producer_id,omitempty"`
	CategoryID      *string          `json:"category_id,omitempty"`
	CategorySlug    *string          `json:"category_slug,omitempty"`
	NameI18n        *domain.I18nText `json:"name_i18n,omitempty"`
	SubcategoryI18n *domain.I18nText `json:"subcategory_i18n,omitempty"`
	ABV             *float64         `json:"abv,omitempty"`
	PolishingRatio  *int             `json:"polishing_ratio,omitempty"`
	FlavorProfile   *[]string        `json:"flavor_profile,omitempty"`
	DescriptionI18n *domain.I18nText `json:"description_i18n,omitempty"`
	LabelImageURL   *string          `json:"label_image_url,omitempty"`
}

func (r *AdminBeverageUpdate) Validate() error {
	if r.NameI18n != nil && (r.NameI18n.EN == "" || r.NameI18n.JA == "") {
		return wrapV("name_i18n.en and name_i18n.ja are required")
	}
	return validateBeverageFields(
		r.NameI18n, r.SubcategoryI18n, r.DescriptionI18n,
		r.ABV, r.PolishingRatio, r.LabelImageURL,
	)
}

// validateBeverageFields runs the field-level sanitization + range
// checks that are common to AdminBeverageCreate.Validate and
// AdminBeverageUpdate.Validate. Nil arguments are skipped; non-nil
// arguments may be mutated in place by sanitization helpers.
func validateBeverageFields(
	name *domain.I18nText,
	subcategory *domain.I18nText,
	description *domain.I18nText,
	abv *float64,
	polishingRatio *int,
	labelImageURL *string,
) error {
	if name != nil {
		if err := sanitizeI18n("name_i18n", name, 200); err != nil {
			return err
		}
	}
	if subcategory != nil {
		if err := sanitizeI18n("subcategory_i18n", subcategory, 200); err != nil {
			return err
		}
	}
	if description != nil {
		if err := sanitizeI18n("description_i18n", description, 2000); err != nil {
			return err
		}
	}
	if abv != nil && (*abv < 0 || *abv > 70) {
		return wrapV("abv must be between 0 and 70")
	}
	if polishingRatio != nil && (*polishingRatio < 0 || *polishingRatio > 100) {
		return wrapV("polishing_ratio must be between 0 and 100")
	}
	return validateLabelImageURL(labelImageURL)
}

// AdminProducerCreate is the body for POST /v1/admin/producers.
//
// Migration 016 replaced the free-text `prefecture` / `region` columns
// with `prefecture_id`. The admin SPA works in slugs (GET
// /v1/reference/regions returns slug + i18n labels), so we mirror the
// `category_slug` pattern: clients send `prefecture_slug` and the handler
// resolves it to a UUID before the INSERT. Region is derived from the
// prefecture (no separate input). Unknown slug → 422
// INVALID_PREFECTURE_SLUG.
type AdminProducerCreate struct {
	NameI18n        domain.I18nText  `json:"name_i18n"`
	PrefectureSlug  *string          `json:"prefecture_slug,omitempty"`
	FoundedYear     *int             `json:"founded_year,omitempty"`
	Website         *string          `json:"website,omitempty"`
	DescriptionI18n *domain.I18nText `json:"description_i18n,omitempty"`
}

func (r *AdminProducerCreate) Validate() error {
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
	if err := validatePrefectureSlugFormat(r.PrefectureSlug); err != nil {
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

// AdminProducerUpdate is the body for PATCH /v1/admin/producers/{id}.
//
// `prefecture_slug` semantics (mirrors how category_slug works on
// AdminBeverageUpdate, plus the "explicit clear" use-case):
//   - omitted (JSON key absent / nil pointer) → leave column unchanged.
//   - non-nil with a valid slug → resolve and set prefecture_id.
//   - non-nil with empty string ("") → clear prefecture_id to NULL.
//
// Unknown slug → 422 INVALID_PREFECTURE_SLUG.
type AdminProducerUpdate struct {
	NameI18n        *domain.I18nText `json:"name_i18n,omitempty"`
	PrefectureSlug  *string          `json:"prefecture_slug,omitempty"`
	FoundedYear     *int             `json:"founded_year,omitempty"`
	Website         *string          `json:"website,omitempty"`
	DescriptionI18n *domain.I18nText `json:"description_i18n,omitempty"`
}

func (r *AdminProducerUpdate) Validate() error {
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
	if err := validatePrefectureSlugFormat(r.PrefectureSlug); err != nil {
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

// validatePrefectureSlugFormat enforces the lightweight shape check on
// `prefecture_slug` so an obviously-malformed value (e.g. a 200-char
// payload) gets a 422 VALIDATION before the resolver round-trips to the
// DB. Existence + canonical-list membership is enforced by
// ProducerRepo.PrefectureIDForSlug at resolve time (422
// INVALID_PREFECTURE_SLUG). Empty string is allowed at the format
// layer — the resolver (resolveOptionalPrefectureID) is the one that
// decides whether an explicit empty is legal: it's the "clear" signal on
// Update (allowClear=true), and a 422 INVALID_PREFECTURE_SLUG on Create
// (allowClear=false). Nil pointer is a no-op.
func validatePrefectureSlugFormat(p *string) error {
	if p == nil || *p == "" {
		return nil
	}
	if len(*p) > 64 {
		return wrapV("prefecture_slug must be ≤ 64 characters")
	}
	for _, c := range *p {
		switch {
		case c >= 'a' && c <= 'z':
		case c >= '0' && c <= '9':
		case c == '_':
		default:
			return wrapV("prefecture_slug must match [a-z0-9_]")
		}
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
