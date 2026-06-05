// admin_subcategories.go — admin CRUD over beverage_subcategories.
//
// Every mutation bundles a moderation_log row into the same pgx.Tx so the
// change + audit commit atomically. After commit the handler emits
// pg_notify('kamos_cache_invalidate', 'subcategories') so every replica
// drops the public list cache.

package handlers

import (
	"context"
	"errors"
	"net/http"
	"regexp"
	"strings"

	"github.com/go-chi/chi/v5"

	"github.com/kamos/api/internal/cache"
	"github.com/kamos/api/internal/domain"
	"github.com/kamos/api/internal/httperr"
	"github.com/kamos/api/internal/repository"
)

// adminSubcategorySlugRe enforces the same shape as the DB CHECK on
// beverage_subcategories.slug (lowercase alnum + underscore, 1..64 chars).
// Pre-validated in the handler so a bad payload returns 422 VALIDATION
// instead of hitting the CHECK and surfacing a 500.
var adminSubcategorySlugRe = regexp.MustCompile(`^[a-z0-9_]{1,64}$`)

// AdminSubcategoryCreate is the body for POST /v1/admin/subcategories.
type AdminSubcategoryCreate struct {
	CategoryID   *string         `json:"category_id,omitempty"`
	CategorySlug *string         `json:"category_slug,omitempty"`
	Slug         string          `json:"slug"`
	NameI18n     domain.I18nText `json:"name_i18n"`
	SortOrder    *int16          `json:"sort_order,omitempty"`
}

func (r *AdminSubcategoryCreate) Validate() error {
	r.Slug = strings.TrimSpace(r.Slug)
	if r.Slug == "" || !adminSubcategorySlugRe.MatchString(r.Slug) {
		return wrapV("slug must match [a-z0-9_]{1,64}")
	}
	hasID := r.CategoryID != nil && *r.CategoryID != ""
	hasSlug := r.CategorySlug != nil && *r.CategorySlug != ""
	if !hasID && !hasSlug {
		return wrapV("category_id or category_slug is required")
	}
	if r.NameI18n.EN == "" || r.NameI18n.JA == "" || r.NameI18n.KO == "" {
		return wrapV("name_i18n.en, name_i18n.ja, name_i18n.ko are all required")
	}
	if err := sanitizeI18n("name_i18n", &r.NameI18n, 200); err != nil {
		return err
	}
	return nil
}

// AdminSubcategoryUpdate is the body for PATCH /v1/admin/subcategories/{id}.
// Every field is optional.
type AdminSubcategoryUpdate struct {
	Slug      *string          `json:"slug,omitempty"`
	NameI18n  *domain.I18nText `json:"name_i18n,omitempty"`
	SortOrder *int16           `json:"sort_order,omitempty"`
}

func (r *AdminSubcategoryUpdate) Validate() error {
	if r.Slug != nil {
		s := strings.TrimSpace(*r.Slug)
		if !adminSubcategorySlugRe.MatchString(s) {
			return wrapV("slug must match [a-z0-9_]{1,64}")
		}
		*r.Slug = s
	}
	if r.NameI18n != nil {
		if r.NameI18n.EN == "" || r.NameI18n.JA == "" || r.NameI18n.KO == "" {
			return wrapV("name_i18n.en, name_i18n.ja, name_i18n.ko are all required when name_i18n is supplied")
		}
		if err := sanitizeI18n("name_i18n", r.NameI18n, 200); err != nil {
			return err
		}
	}
	return nil
}

// AdminListSubcategories — GET /v1/admin/subcategories[?category=…][&include_deleted=1]
func (h *Handler) AdminListSubcategories(w http.ResponseWriter, r *http.Request) {
	category := r.URL.Query().Get("category")
	var categoryPtr *string
	if category != "" {
		categoryPtr = &category
	}
	includeDeleted := r.URL.Query().Get("include_deleted") == "1"
	rows, err := h.Repos.Subcategories.AdminList(r.Context(), categoryPtr, includeDeleted)
	if err != nil {
		h.writeErr(w, "AdminListSubcategories", err)
		return
	}
	httperr.WriteJSON(w, http.StatusOK, rows)
}

// AdminCreateSubcategory — POST /v1/admin/subcategories
func (h *Handler) AdminCreateSubcategory(w http.ResponseWriter, r *http.Request) {
	uid, ok := h.authedID(w, r)
	if !ok {
		return
	}
	var body AdminSubcategoryCreate
	if err := decodeJSON(r, &body); err != nil {
		h.writeErr(w, "AdminCreateSubcategory decode", err)
		return
	}
	if err := body.Validate(); err != nil {
		h.writeErr(w, "AdminCreateSubcategory validate", err)
		return
	}

	categoryID, err := h.resolveCategoryID(r.Context(), body.CategoryID, body.CategorySlug)
	if err != nil {
		h.writeCategoryErr(w, "AdminCreateSubcategory", err)
		return
	}
	var sortOrder int16
	if body.SortOrder != nil {
		sortOrder = *body.SortOrder
	}
	out, err := h.createSubcategoryTx(r.Context(), uid, repository.SubcategoryCreateInput{
		CategoryID: categoryID,
		Slug:       body.Slug,
		Name:       body.NameI18n,
		SortOrder:  sortOrder,
	})
	if err != nil {
		h.writeErr(w, "AdminCreateSubcategory", err)
		return
	}
	h.invalidateSubcategories(r.Context())
	httperr.WriteJSON(w, http.StatusCreated, out)
}

// AdminUpdateSubcategory — PATCH /v1/admin/subcategories/{id}
func (h *Handler) AdminUpdateSubcategory(w http.ResponseWriter, r *http.Request) {
	uid, ok := h.authedID(w, r)
	if !ok {
		return
	}
	id := chi.URLParam(r, "id")
	if id == "" {
		httperr.WriteError(w, http.StatusBadRequest, "BAD_REQUEST", "missing subcategory id")
		return
	}
	var body AdminSubcategoryUpdate
	if err := decodeJSON(r, &body); err != nil {
		h.writeErr(w, "AdminUpdateSubcategory decode", err)
		return
	}
	if err := body.Validate(); err != nil {
		h.writeErr(w, "AdminUpdateSubcategory validate", err)
		return
	}
	out, err := h.updateSubcategoryTx(r.Context(), uid, id, repository.SubcategoryUpdateInput{
		Slug:      body.Slug,
		Name:      body.NameI18n,
		SortOrder: body.SortOrder,
	})
	if err != nil {
		h.writeErr(w, "AdminUpdateSubcategory", err)
		return
	}
	h.invalidateSubcategories(r.Context())
	httperr.WriteJSON(w, http.StatusOK, out)
}

// AdminSoftDeleteSubcategory — DELETE /v1/admin/subcategories/{id}
func (h *Handler) AdminSoftDeleteSubcategory(w http.ResponseWriter, r *http.Request) {
	uid, ok := h.authedID(w, r)
	if !ok {
		return
	}
	id := chi.URLParam(r, "id")
	if id == "" {
		httperr.WriteError(w, http.StatusBadRequest, "BAD_REQUEST", "missing subcategory id")
		return
	}
	if err := h.softDeleteSubcategoryTx(r.Context(), uid, id); err != nil {
		h.writeErr(w, "AdminSoftDeleteSubcategory", err)
		return
	}
	h.invalidateSubcategories(r.Context())
	w.WriteHeader(http.StatusNoContent)
}

// AdminRestoreSubcategory — POST /v1/admin/subcategories/{id}/restore
func (h *Handler) AdminRestoreSubcategory(w http.ResponseWriter, r *http.Request) {
	uid, ok := h.authedID(w, r)
	if !ok {
		return
	}
	id := chi.URLParam(r, "id")
	if id == "" {
		httperr.WriteError(w, http.StatusBadRequest, "BAD_REQUEST", "missing subcategory id")
		return
	}
	if err := h.restoreSubcategoryTx(r.Context(), uid, id); err != nil {
		h.writeErr(w, "AdminRestoreSubcategory", err)
		return
	}
	h.invalidateSubcategories(r.Context())
	out, err := h.Repos.Subcategories.Get(r.Context(), id)
	if err != nil {
		h.writeErr(w, "AdminRestoreSubcategory refetch", err)
		return
	}
	httperr.WriteJSON(w, http.StatusOK, out)
}

// ---- transaction helpers ----

func (h *Handler) createSubcategoryTx(ctx context.Context, adminID string, in repository.SubcategoryCreateInput) (repository.AdminSubcategoryRow, error) {
	tx, err := h.Repos.DB.Begin(ctx)
	if err != nil {
		return repository.AdminSubcategoryRow{}, err
	}
	defer func() { _ = tx.Rollback(ctx) }()

	row, err := h.Repos.Subcategories.Create(ctx, tx, in)
	if err != nil {
		return repository.AdminSubcategoryRow{}, err
	}
	if err := h.Repos.Admin.LogAction(ctx, tx, adminID, "subcategory", row.ID, "create", nil,
		map[string]any{"slug": row.Slug, "category_slug": row.CategorySlug}); err != nil {
		return repository.AdminSubcategoryRow{}, err
	}
	if err := tx.Commit(ctx); err != nil {
		return repository.AdminSubcategoryRow{}, err
	}
	return row, nil
}

func (h *Handler) updateSubcategoryTx(ctx context.Context, adminID, id string, in repository.SubcategoryUpdateInput) (repository.AdminSubcategoryRow, error) {
	tx, err := h.Repos.DB.Begin(ctx)
	if err != nil {
		return repository.AdminSubcategoryRow{}, err
	}
	defer func() { _ = tx.Rollback(ctx) }()

	row, err := h.Repos.Subcategories.Update(ctx, tx, id, in)
	if err != nil {
		return repository.AdminSubcategoryRow{}, err
	}
	if err := h.Repos.Admin.LogAction(ctx, tx, adminID, "subcategory", id, "update", nil, nil); err != nil {
		return repository.AdminSubcategoryRow{}, err
	}
	if err := tx.Commit(ctx); err != nil {
		return repository.AdminSubcategoryRow{}, err
	}
	return row, nil
}

func (h *Handler) softDeleteSubcategoryTx(ctx context.Context, adminID, id string) error {
	tx, err := h.Repos.DB.Begin(ctx)
	if err != nil {
		return err
	}
	defer func() { _ = tx.Rollback(ctx) }()

	if err := h.Repos.Subcategories.SoftDelete(ctx, tx, id); err != nil {
		return err
	}
	if err := h.Repos.Admin.LogAction(ctx, tx, adminID, "subcategory", id, "soft_delete", nil, nil); err != nil {
		return err
	}
	return tx.Commit(ctx)
}

func (h *Handler) restoreSubcategoryTx(ctx context.Context, adminID, id string) error {
	tx, err := h.Repos.DB.Begin(ctx)
	if err != nil {
		return err
	}
	defer func() { _ = tx.Rollback(ctx) }()

	if err := h.Repos.Subcategories.Restore(ctx, tx, id); err != nil {
		return err
	}
	if err := h.Repos.Admin.LogAction(ctx, tx, adminID, "subcategory", id, "restore", nil, nil); err != nil {
		return err
	}
	return tx.Commit(ctx)
}

// invalidateSubcategories busts the local cache slot AND emits the
// cross-replica NOTIFY so every server replica drops its slot. The
// beverage detail cache is also flushed (subcategory rename + delete
// changes embedded subcategory.name on every linked beverage).
func (h *Handler) invalidateSubcategories(ctx context.Context) {
	if h.Caches != nil {
		h.Caches.Subcategories.InvalidatePrefix("")
		h.Caches.BeverageDetail.InvalidatePrefix("")
	}
	cache.NotifyInvalidation(context.WithoutCancel(ctx), h.DB, h.Log, "subcategories")
}

// ensure errors.Is is used (keeps gofmt-aware import linter happy).
var _ = errors.Is
