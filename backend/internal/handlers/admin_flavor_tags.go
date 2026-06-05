// admin_flavor_tags.go — admin CRUD over the flavor_tags taxonomy.
//
// Slice C (migration 006 added flavor_tags.deleted_at and the
// 'flavor_tag' moderation target). Five endpoints, admin-only:
//
//	GET    /v1/admin/flavor-tags
//	POST   /v1/admin/flavor-tags
//	PATCH  /v1/admin/flavor-tags/{id}
//	DELETE /v1/admin/flavor-tags/{id}
//	POST   /v1/admin/flavor-tags/{id}/restore
//
// Every mutation bundles a moderation_log row into the same pgx.Tx so the
// change + audit commit atomically. After commit the handler emits
// pg_notify('kamos_cache_invalidate', 'flavor-tags') so every replica
// drops the public taxonomy cache.

package handlers

import (
	"context"
	"net/http"
	"regexp"
	"strings"

	"github.com/go-chi/chi/v5"

	"github.com/kamos/api/internal/cache"
	"github.com/kamos/api/internal/domain"
	"github.com/kamos/api/internal/httperr"
	"github.com/kamos/api/internal/repository"
)

// adminFlavorTagSlugRe matches lowercase alnum + underscore, 1..64 chars.
// flavor_tags has no DB-level slug shape CHECK (only the unique index)
// — we enforce a sensible shape here so the admin can't paste
// freeform text that breaks the existing FK slug-to-id resolver
// (BeverageRepo.ResolveFlavorTagIDs).
var adminFlavorTagSlugRe = regexp.MustCompile(`^[a-z0-9_]{1,64}$`)

// allowedDimensions mirrors the DB CHECK on flavor_tags.dimension.
var allowedDimensions = map[string]bool{
	"sweetness": true,
	"body":      true,
	"acidity":   true,
	"character": true,
	"finish":    true,
}

// AdminFlavorTagCreate is the body for POST /v1/admin/flavor-tags.
type AdminFlavorTagCreate struct {
	Slug      string          `json:"slug"`
	Dimension string          `json:"dimension"`
	NameI18n  domain.I18nText `json:"name_i18n"`
	SortOrder *int16          `json:"sort_order,omitempty"`
}

func (r *AdminFlavorTagCreate) Validate() error {
	r.Slug = strings.TrimSpace(r.Slug)
	if !adminFlavorTagSlugRe.MatchString(r.Slug) {
		return wrapV("slug must match [a-z0-9_]{1,64}")
	}
	if !allowedDimensions[r.Dimension] {
		return wrapV("dimension must be one of: sweetness, body, acidity, character, finish")
	}
	if r.NameI18n.EN == "" {
		return wrapV("name_i18n.en is required")
	}
	if err := sanitizeI18n("name_i18n", &r.NameI18n, 200); err != nil {
		return err
	}
	return nil
}

// AdminFlavorTagUpdate is the body for PATCH /v1/admin/flavor-tags/{id}.
type AdminFlavorTagUpdate struct {
	Slug      *string          `json:"slug,omitempty"`
	Dimension *string          `json:"dimension,omitempty"`
	NameI18n  *domain.I18nText `json:"name_i18n,omitempty"`
	SortOrder *int16           `json:"sort_order,omitempty"`
}

func (r *AdminFlavorTagUpdate) Validate() error {
	if r.Slug != nil {
		s := strings.TrimSpace(*r.Slug)
		if !adminFlavorTagSlugRe.MatchString(s) {
			return wrapV("slug must match [a-z0-9_]{1,64}")
		}
		*r.Slug = s
	}
	if r.Dimension != nil && !allowedDimensions[*r.Dimension] {
		return wrapV("dimension must be one of: sweetness, body, acidity, character, finish")
	}
	if r.NameI18n != nil {
		if r.NameI18n.EN == "" {
			return wrapV("name_i18n.en is required when name_i18n is supplied")
		}
		if err := sanitizeI18n("name_i18n", r.NameI18n, 200); err != nil {
			return err
		}
	}
	return nil
}

// AdminListFlavorTags — GET /v1/admin/flavor-tags[?dimension=…][&include_deleted=1]
func (h *Handler) AdminListFlavorTags(w http.ResponseWriter, r *http.Request) {
	dim := r.URL.Query().Get("dimension")
	var dimPtr *string
	if dim != "" {
		dimPtr = &dim
	}
	includeDeleted := r.URL.Query().Get("include_deleted") == "1"
	rows, err := h.Repos.FlavorTags.AdminList(r.Context(), dimPtr, includeDeleted)
	if err != nil {
		h.writeErr(w, "AdminListFlavorTags", err)
		return
	}
	httperr.WriteJSON(w, http.StatusOK, rows)
}

// AdminCreateFlavorTag — POST /v1/admin/flavor-tags
func (h *Handler) AdminCreateFlavorTag(w http.ResponseWriter, r *http.Request) {
	uid, ok := h.authedID(w, r)
	if !ok {
		return
	}
	var body AdminFlavorTagCreate
	if err := decodeJSON(r, &body); err != nil {
		h.writeErr(w, "AdminCreateFlavorTag decode", err)
		return
	}
	if err := body.Validate(); err != nil {
		h.writeErr(w, "AdminCreateFlavorTag validate", err)
		return
	}
	var sortOrder int16
	if body.SortOrder != nil {
		sortOrder = *body.SortOrder
	}
	out, err := h.createFlavorTagTx(r.Context(), uid, repository.FlavorTagCreateInput{
		Slug:      body.Slug,
		Dimension: body.Dimension,
		Name:      body.NameI18n,
		SortOrder: sortOrder,
	})
	if err != nil {
		h.writeErr(w, "AdminCreateFlavorTag", err)
		return
	}
	h.invalidateFlavorTags(r.Context())
	httperr.WriteJSON(w, http.StatusCreated, out)
}

// AdminUpdateFlavorTag — PATCH /v1/admin/flavor-tags/{id}
func (h *Handler) AdminUpdateFlavorTag(w http.ResponseWriter, r *http.Request) {
	uid, ok := h.authedID(w, r)
	if !ok {
		return
	}
	id := chi.URLParam(r, "id")
	if id == "" {
		httperr.WriteError(w, http.StatusBadRequest, "BAD_REQUEST", "missing flavor tag id")
		return
	}
	var body AdminFlavorTagUpdate
	if err := decodeJSON(r, &body); err != nil {
		h.writeErr(w, "AdminUpdateFlavorTag decode", err)
		return
	}
	if err := body.Validate(); err != nil {
		h.writeErr(w, "AdminUpdateFlavorTag validate", err)
		return
	}
	out, err := h.updateFlavorTagTx(r.Context(), uid, id, repository.FlavorTagUpdateInput{
		Slug:      body.Slug,
		Dimension: body.Dimension,
		Name:      body.NameI18n,
		SortOrder: body.SortOrder,
	})
	if err != nil {
		h.writeErr(w, "AdminUpdateFlavorTag", err)
		return
	}
	h.invalidateFlavorTags(r.Context())
	httperr.WriteJSON(w, http.StatusOK, out)
}

// AdminSoftDeleteFlavorTag — DELETE /v1/admin/flavor-tags/{id}
func (h *Handler) AdminSoftDeleteFlavorTag(w http.ResponseWriter, r *http.Request) {
	uid, ok := h.authedID(w, r)
	if !ok {
		return
	}
	id := chi.URLParam(r, "id")
	if id == "" {
		httperr.WriteError(w, http.StatusBadRequest, "BAD_REQUEST", "missing flavor tag id")
		return
	}
	if err := h.softDeleteFlavorTagTx(r.Context(), uid, id); err != nil {
		h.writeErr(w, "AdminSoftDeleteFlavorTag", err)
		return
	}
	h.invalidateFlavorTags(r.Context())
	w.WriteHeader(http.StatusNoContent)
}

// AdminRestoreFlavorTag — POST /v1/admin/flavor-tags/{id}/restore
func (h *Handler) AdminRestoreFlavorTag(w http.ResponseWriter, r *http.Request) {
	uid, ok := h.authedID(w, r)
	if !ok {
		return
	}
	id := chi.URLParam(r, "id")
	if id == "" {
		httperr.WriteError(w, http.StatusBadRequest, "BAD_REQUEST", "missing flavor tag id")
		return
	}
	if err := h.restoreFlavorTagTx(r.Context(), uid, id); err != nil {
		h.writeErr(w, "AdminRestoreFlavorTag", err)
		return
	}
	h.invalidateFlavorTags(r.Context())
	out, err := h.Repos.FlavorTags.Get(r.Context(), id)
	if err != nil {
		h.writeErr(w, "AdminRestoreFlavorTag refetch", err)
		return
	}
	httperr.WriteJSON(w, http.StatusOK, out)
}

// ---- transaction helpers ----

func (h *Handler) createFlavorTagTx(ctx context.Context, adminID string, in repository.FlavorTagCreateInput) (repository.AdminFlavorTagRow, error) {
	tx, err := h.Repos.DB.Begin(ctx)
	if err != nil {
		return repository.AdminFlavorTagRow{}, err
	}
	defer func() { _ = tx.Rollback(ctx) }()

	row, err := h.Repos.FlavorTags.Create(ctx, tx, in)
	if err != nil {
		return repository.AdminFlavorTagRow{}, err
	}
	if err := h.Repos.Admin.LogAction(ctx, tx, adminID, "flavor_tag", row.ID, "create", nil,
		map[string]any{"slug": row.Slug, "dimension": row.Dimension}); err != nil {
		return repository.AdminFlavorTagRow{}, err
	}
	if err := tx.Commit(ctx); err != nil {
		return repository.AdminFlavorTagRow{}, err
	}
	return row, nil
}

func (h *Handler) updateFlavorTagTx(ctx context.Context, adminID, id string, in repository.FlavorTagUpdateInput) (repository.AdminFlavorTagRow, error) {
	tx, err := h.Repos.DB.Begin(ctx)
	if err != nil {
		return repository.AdminFlavorTagRow{}, err
	}
	defer func() { _ = tx.Rollback(ctx) }()

	row, err := h.Repos.FlavorTags.Update(ctx, tx, id, in)
	if err != nil {
		return repository.AdminFlavorTagRow{}, err
	}
	if err := h.Repos.Admin.LogAction(ctx, tx, adminID, "flavor_tag", id, "update", nil, nil); err != nil {
		return repository.AdminFlavorTagRow{}, err
	}
	if err := tx.Commit(ctx); err != nil {
		return repository.AdminFlavorTagRow{}, err
	}
	return row, nil
}

func (h *Handler) softDeleteFlavorTagTx(ctx context.Context, adminID, id string) error {
	tx, err := h.Repos.DB.Begin(ctx)
	if err != nil {
		return err
	}
	defer func() { _ = tx.Rollback(ctx) }()

	if err := h.Repos.FlavorTags.SoftDelete(ctx, tx, id); err != nil {
		return err
	}
	if err := h.Repos.Admin.LogAction(ctx, tx, adminID, "flavor_tag", id, "soft_delete", nil, nil); err != nil {
		return err
	}
	return tx.Commit(ctx)
}

func (h *Handler) restoreFlavorTagTx(ctx context.Context, adminID, id string) error {
	tx, err := h.Repos.DB.Begin(ctx)
	if err != nil {
		return err
	}
	defer func() { _ = tx.Rollback(ctx) }()

	if err := h.Repos.FlavorTags.Restore(ctx, tx, id); err != nil {
		return err
	}
	if err := h.Repos.Admin.LogAction(ctx, tx, adminID, "flavor_tag", id, "restore", nil, nil); err != nil {
		return err
	}
	return tx.Commit(ctx)
}

func (h *Handler) invalidateFlavorTags(ctx context.Context) {
	if h.Caches != nil {
		h.Caches.FlavorTags.InvalidatePrefix("")
		h.Caches.BeverageDetail.InvalidatePrefix("")
	}
	cache.NotifyInvalidation(context.WithoutCancel(ctx), h.DB, h.Log, "flavor-tags")
}
