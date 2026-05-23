// admin_beverages.go — admin direct CRUD over beverages.
//
// Stage 8 (admin catalog CRUD). Six endpoints, all admin-only:
//
//   GET    /v1/admin/beverages
//   GET    /v1/admin/beverages/{id}
//   POST   /v1/admin/beverages
//   PATCH  /v1/admin/beverages/{id}
//   DELETE /v1/admin/beverages/{id}
//   POST   /v1/admin/beverages/{id}/restore
//
// Direct admin write access supplements the existing user-submission
// queue (/v1/admin/beverage-requests). Every mutation bundles its
// moderation_log audit row into the same pgx.Tx so the change + audit
// commit atomically. category_slug is derived by the database trigger
// from category_id — handlers do not set it explicitly.
package handlers

import (
	"context"
	"net/http"

	"github.com/go-chi/chi/v5"

	"github.com/kamos/api/internal/cache"
	"github.com/kamos/api/internal/cursor"
	"github.com/kamos/api/internal/httperr"
	"github.com/kamos/api/internal/repository"
)

// AdminListBeverages — GET /v1/admin/beverages
//
// Query params:
//   - q: optional websearch query (FTS via idx_beverages_name_tsv)
//   - brewery_id, category_id, category_slug: optional filters
//   - id: optional UUID exact-match (short-circuits cursor)
//   - include_deleted=1: include soft-deleted rows
//   - cursor: opaque cursor
//   - limit: 1..50, default 20
func (h *Handler) AdminListBeverages(w http.ResponseWriter, r *http.Request) {
	limit := parseLimit(r, 20, 50)
	c, err := parseCursor(r)
	if err != nil {
		h.writeErr(w, "AdminListBeverages cursor", err)
		return
	}
	q := optString(r.URL.Query().Get("q"))
	breweryID := optString(r.URL.Query().Get("brewery_id"))
	categoryID := optString(r.URL.Query().Get("category_id"))
	categorySlug := optString(r.URL.Query().Get("category_slug"))
	id := optString(r.URL.Query().Get("id"))
	includeDeleted := r.URL.Query().Get("include_deleted") == "1"

	items, err := h.Repos.Beverages.AdminList(r.Context(), repository.AdminBeverageListParams{
		Q:              q,
		BreweryID:      breweryID,
		CategoryID:     categoryID,
		CategorySlug:   categorySlug,
		IDExact:        id,
		IncludeDeleted: includeDeleted,
		CursorTs:       optTimestamp(c),
		CursorID:       optString(c.ID),
		Limit:          limit,
	})
	if err != nil {
		h.writeErr(w, "AdminListBeverages", err)
		return
	}
	page, next, hasMore := cursor.SliceAndCursor(items, limit, func(b repository.AdminBeverageRow) cursor.Cursor {
		return cursor.Cursor{CreatedAt: b.CreatedAt, ID: b.ID}
	})
	httperr.WriteJSON(w, http.StatusOK, cursor.Page[repository.AdminBeverageRow]{
		Items: page, NextCursor: next, HasMore: hasMore,
	})
}

// AdminGetBeverage — GET /v1/admin/beverages/{id}
// Returns the row including soft-deleted (admin needs the tombstone to
// surface a Restore button).
func (h *Handler) AdminGetBeverage(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	if id == "" {
		httperr.WriteError(w, http.StatusBadRequest, "BAD_REQUEST", "missing beverage id")
		return
	}
	row, err := h.Repos.Beverages.AdminDetail(r.Context(), id)
	if err != nil {
		h.writeErr(w, "AdminGetBeverage", err)
		return
	}
	httperr.WriteJSON(w, http.StatusOK, row)
}

// AdminCreateBeverage — POST /v1/admin/beverages
func (h *Handler) AdminCreateBeverage(w http.ResponseWriter, r *http.Request) {
	uid, ok := h.authedID(w, r)
	if !ok {
		return
	}
	var body AdminBeverageCreate
	if err := decodeJSON(r, &body); err != nil {
		h.writeErr(w, "AdminCreateBeverage decode", err)
		return
	}
	if err := body.Validate(); err != nil {
		h.writeErr(w, "AdminCreateBeverage validate", err)
		return
	}

	bevID, err := h.createBeverageTx(r.Context(), uid, body)
	if err != nil {
		h.writeErr(w, "AdminCreateBeverage", err)
		return
	}
	// Re-fetch via the admin projection so the response carries the
	// canonical row (id + category_slug from the trigger).
	out, err := h.Repos.Beverages.AdminDetail(r.Context(), bevID)
	if err != nil {
		h.writeErr(w, "AdminCreateBeverage refetch", err)
		return
	}
	// The new beverage's brewery cache no longer reflects the freshly-
	// added child; bust it so the brewery detail page reflects the new
	// count on next read.
	if body.BreweryID != "" && h.Caches != nil {
		h.Caches.BreweryDetail.InvalidatePrefix(body.BreweryID + ":")
	}
	cache.NotifyInvalidation(context.WithoutCancel(r.Context()), h.DB, h.Log, "brewery:"+body.BreweryID)
	httperr.WriteJSON(w, http.StatusCreated, out)
}

// AdminUpdateBeverage — PATCH /v1/admin/beverages/{id}
func (h *Handler) AdminUpdateBeverage(w http.ResponseWriter, r *http.Request) {
	uid, ok := h.authedID(w, r)
	if !ok {
		return
	}
	id := chi.URLParam(r, "id")
	if id == "" {
		httperr.WriteError(w, http.StatusBadRequest, "BAD_REQUEST", "missing beverage id")
		return
	}
	var body AdminBeverageUpdate
	if err := decodeJSON(r, &body); err != nil {
		h.writeErr(w, "AdminUpdateBeverage decode", err)
		return
	}
	if err := body.Validate(); err != nil {
		h.writeErr(w, "AdminUpdateBeverage validate", err)
		return
	}

	if err := h.updateBeverageTx(r.Context(), uid, id, body); err != nil {
		h.writeErr(w, "AdminUpdateBeverage", err)
		return
	}
	if h.Caches != nil {
		h.Caches.BeverageDetail.InvalidatePrefix(id + ":")
	}
	cache.NotifyInvalidation(context.WithoutCancel(r.Context()), h.DB, h.Log, "beverage:"+id)

	out, err := h.Repos.Beverages.AdminDetail(r.Context(), id)
	if err != nil {
		h.writeErr(w, "AdminUpdateBeverage refetch", err)
		return
	}
	httperr.WriteJSON(w, http.StatusOK, out)
}

// AdminSoftDeleteBeverage — DELETE /v1/admin/beverages/{id}
func (h *Handler) AdminSoftDeleteBeverage(w http.ResponseWriter, r *http.Request) {
	uid, ok := h.authedID(w, r)
	if !ok {
		return
	}
	id := chi.URLParam(r, "id")
	if id == "" {
		httperr.WriteError(w, http.StatusBadRequest, "BAD_REQUEST", "missing beverage id")
		return
	}
	if err := h.softDeleteBeverageTx(r.Context(), uid, id); err != nil {
		h.writeErr(w, "AdminSoftDeleteBeverage", err)
		return
	}
	if h.Caches != nil {
		h.Caches.BeverageDetail.InvalidatePrefix(id + ":")
	}
	cache.NotifyInvalidation(context.WithoutCancel(r.Context()), h.DB, h.Log, "beverage:"+id)
	w.WriteHeader(http.StatusNoContent)
}

// AdminRestoreBeverage — POST /v1/admin/beverages/{id}/restore
func (h *Handler) AdminRestoreBeverage(w http.ResponseWriter, r *http.Request) {
	uid, ok := h.authedID(w, r)
	if !ok {
		return
	}
	id := chi.URLParam(r, "id")
	if id == "" {
		httperr.WriteError(w, http.StatusBadRequest, "BAD_REQUEST", "missing beverage id")
		return
	}
	if err := h.restoreBeverageTx(r.Context(), uid, id); err != nil {
		h.writeErr(w, "AdminRestoreBeverage", err)
		return
	}
	if h.Caches != nil {
		h.Caches.BeverageDetail.InvalidatePrefix(id + ":")
	}
	cache.NotifyInvalidation(context.WithoutCancel(r.Context()), h.DB, h.Log, "beverage:"+id)

	out, err := h.Repos.Beverages.AdminDetail(r.Context(), id)
	if err != nil {
		h.writeErr(w, "AdminRestoreBeverage refetch", err)
		return
	}
	httperr.WriteJSON(w, http.StatusOK, out)
}

// ---- transaction helpers ----

func (h *Handler) createBeverageTx(ctx context.Context, adminID string, body AdminBeverageCreate) (string, error) {
	tx, err := h.Repos.DB.Begin(ctx)
	if err != nil {
		return "", err
	}
	defer func() { _ = tx.Rollback(ctx) }()

	bevID, err := h.Repos.Beverages.Create(ctx, tx, repository.BeverageCreateInput{
		BreweryID:      body.BreweryID,
		CategoryID:     body.CategoryID,
		Name:           body.NameI18n,
		Subcategory:    body.SubcategoryI18n,
		ABV:            body.ABV,
		PolishingRatio: body.PolishingRatio,
		FlavorProfile:  body.FlavorProfile,
		Prefecture:     body.Prefecture,
		Region:         body.Region,
		Description:    body.DescriptionI18n,
		LabelImageURL:  body.LabelImageURL,
	})
	if err != nil {
		return "", err
	}
	if err := h.Repos.Admin.LogAction(ctx, tx, adminID, "beverage", bevID, "create",
		nil,
		map[string]any{
			"name_en":    body.NameI18n.EN,
			"brewery_id": body.BreweryID,
		}); err != nil {
		return "", err
	}
	if err := tx.Commit(ctx); err != nil {
		return "", err
	}
	return bevID, nil
}

func (h *Handler) updateBeverageTx(ctx context.Context, adminID, id string, body AdminBeverageUpdate) error {
	tx, err := h.Repos.DB.Begin(ctx)
	if err != nil {
		return err
	}
	defer func() { _ = tx.Rollback(ctx) }()

	if err := h.Repos.Beverages.Update(ctx, tx, id, repository.BeverageUpdateInput{
		BreweryID:      body.BreweryID,
		CategoryID:     body.CategoryID,
		Name:           body.NameI18n,
		Subcategory:    body.SubcategoryI18n,
		ABV:            body.ABV,
		PolishingRatio: body.PolishingRatio,
		FlavorProfile:  body.FlavorProfile,
		Prefecture:     body.Prefecture,
		Region:         body.Region,
		Description:    body.DescriptionI18n,
		LabelImageURL:  body.LabelImageURL,
	}); err != nil {
		return err
	}
	if err := h.Repos.Admin.LogAction(ctx, tx, adminID, "beverage", id, "update", nil, nil); err != nil {
		return err
	}
	return tx.Commit(ctx)
}

func (h *Handler) softDeleteBeverageTx(ctx context.Context, adminID, id string) error {
	tx, err := h.Repos.DB.Begin(ctx)
	if err != nil {
		return err
	}
	defer func() { _ = tx.Rollback(ctx) }()

	if err := h.Repos.Beverages.SoftDelete(ctx, tx, id); err != nil {
		return err
	}
	if err := h.Repos.Admin.LogAction(ctx, tx, adminID, "beverage", id, "soft_delete", nil, nil); err != nil {
		return err
	}
	return tx.Commit(ctx)
}

func (h *Handler) restoreBeverageTx(ctx context.Context, adminID, id string) error {
	tx, err := h.Repos.DB.Begin(ctx)
	if err != nil {
		return err
	}
	defer func() { _ = tx.Rollback(ctx) }()

	if err := h.Repos.Beverages.Restore(ctx, tx, id); err != nil {
		return err
	}
	if err := h.Repos.Admin.LogAction(ctx, tx, adminID, "beverage", id, "restore", nil, nil); err != nil {
		return err
	}
	return tx.Commit(ctx)
}
