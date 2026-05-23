// admin_breweries.go — admin direct CRUD over breweries.
//
// Stage 8 (admin catalog CRUD). Six endpoints, all admin-only:
//
//	GET    /v1/admin/breweries
//	GET    /v1/admin/breweries/{id}
//	POST   /v1/admin/breweries
//	PATCH  /v1/admin/breweries/{id}
//	DELETE /v1/admin/breweries/{id}
//	POST   /v1/admin/breweries/{id}/restore
//
// Every mutation runs inside a single pgx.Tx that bundles the moderation
// _log audit row, so the change + audit commit atomically. DELETE returns
// 409 BREWERY_HAS_LIVE_BEVERAGES when at least one beverage still
// references the brewery with deleted_at IS NULL.
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

// AdminListBreweries — GET /v1/admin/breweries
//
// Query params:
//   - q: optional websearch query (FTS via idx_breweries_name_tsv)
//   - id: optional UUID exact-match (short-circuits cursor)
//   - include_deleted=1: include soft-deleted rows (admin "trash" view)
//   - cursor: opaque cursor
//   - limit: 1..50, default 20
func (h *Handler) AdminListBreweries(w http.ResponseWriter, r *http.Request) {
	limit := parseLimit(r, 20, 50)
	c, err := parseCursor(r)
	if err != nil {
		h.writeErr(w, "AdminListBreweries cursor", err)
		return
	}
	q := optString(r.URL.Query().Get("q"))
	id := optString(r.URL.Query().Get("id"))
	includeDeleted := r.URL.Query().Get("include_deleted") == "1"

	items, err := h.Repos.Breweries.AdminList(r.Context(), repository.AdminBreweryListParams{
		Q:              q,
		IDExact:        id,
		IncludeDeleted: includeDeleted,
		CursorTs:       optTimestamp(c),
		CursorID:       optString(c.ID),
		Limit:          limit,
	})
	if err != nil {
		h.writeErr(w, "AdminListBreweries", err)
		return
	}
	page, next, hasMore := cursor.SliceAndCursor(items, limit, func(b repository.AdminBreweryRow) cursor.Cursor {
		return cursor.Cursor{CreatedAt: b.CreatedAt, ID: b.ID}
	})
	httperr.WriteJSON(w, http.StatusOK, cursor.Page[repository.AdminBreweryRow]{
		Items: page, NextCursor: next, HasMore: hasMore,
	})
}

// AdminGetBrewery — GET /v1/admin/breweries/{id}
// Returns the row including soft-deleted (admin needs to see the
// tombstone to restore it).
func (h *Handler) AdminGetBrewery(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	if id == "" {
		httperr.WriteError(w, http.StatusBadRequest, "BAD_REQUEST", "missing brewery id")
		return
	}
	row, err := h.Repos.Breweries.AdminDetail(r.Context(), id)
	if err != nil {
		h.writeErr(w, "AdminGetBrewery", err)
		return
	}
	httperr.WriteJSON(w, http.StatusOK, row)
}

// AdminCreateBrewery — POST /v1/admin/breweries
func (h *Handler) AdminCreateBrewery(w http.ResponseWriter, r *http.Request) {
	uid, ok := h.authedID(w, r)
	if !ok {
		return
	}
	var body AdminBreweryCreate
	if err := decodeJSON(r, &body); err != nil {
		h.writeErr(w, "AdminCreateBrewery decode", err)
		return
	}
	if err := body.Validate(); err != nil {
		h.writeErr(w, "AdminCreateBrewery validate", err)
		return
	}

	out, err := h.createBreweryTx(r.Context(), uid, body)
	if err != nil {
		h.writeErr(w, "AdminCreateBrewery", err)
		return
	}
	httperr.WriteJSON(w, http.StatusCreated, out)
}

// AdminUpdateBrewery — PATCH /v1/admin/breweries/{id}
func (h *Handler) AdminUpdateBrewery(w http.ResponseWriter, r *http.Request) {
	uid, ok := h.authedID(w, r)
	if !ok {
		return
	}
	id := chi.URLParam(r, "id")
	if id == "" {
		httperr.WriteError(w, http.StatusBadRequest, "BAD_REQUEST", "missing brewery id")
		return
	}
	var body AdminBreweryUpdate
	if err := decodeJSON(r, &body); err != nil {
		h.writeErr(w, "AdminUpdateBrewery decode", err)
		return
	}
	if err := body.Validate(); err != nil {
		h.writeErr(w, "AdminUpdateBrewery validate", err)
		return
	}

	out, err := h.updateBreweryTx(r.Context(), uid, id, body)
	if err != nil {
		h.writeErr(w, "AdminUpdateBrewery", err)
		return
	}
	// Invalidate the brewery LRU + notify peer replicas so a stale row
	// doesn't linger after the rename / description change.
	if h.Caches != nil {
		h.Caches.BreweryDetail.InvalidatePrefix(id + ":")
	}
	cache.NotifyInvalidation(context.WithoutCancel(r.Context()), h.DB, h.Log, "brewery:"+id)
	httperr.WriteJSON(w, http.StatusOK, out)
}

// AdminSoftDeleteBrewery — DELETE /v1/admin/breweries/{id}
// Returns 409 BREWERY_HAS_LIVE_BEVERAGES if any live beverage still
// references the brewery.
func (h *Handler) AdminSoftDeleteBrewery(w http.ResponseWriter, r *http.Request) {
	uid, ok := h.authedID(w, r)
	if !ok {
		return
	}
	id := chi.URLParam(r, "id")
	if id == "" {
		httperr.WriteError(w, http.StatusBadRequest, "BAD_REQUEST", "missing brewery id")
		return
	}
	if err := h.softDeleteBreweryTx(r.Context(), uid, id); err != nil {
		h.writeErr(w, "AdminSoftDeleteBrewery", err)
		return
	}
	if h.Caches != nil {
		h.Caches.BreweryDetail.InvalidatePrefix(id + ":")
	}
	cache.NotifyInvalidation(context.WithoutCancel(r.Context()), h.DB, h.Log, "brewery:"+id)
	w.WriteHeader(http.StatusNoContent)
}

// AdminRestoreBrewery — POST /v1/admin/breweries/{id}/restore
func (h *Handler) AdminRestoreBrewery(w http.ResponseWriter, r *http.Request) {
	uid, ok := h.authedID(w, r)
	if !ok {
		return
	}
	id := chi.URLParam(r, "id")
	if id == "" {
		httperr.WriteError(w, http.StatusBadRequest, "BAD_REQUEST", "missing brewery id")
		return
	}
	if err := h.restoreBreweryTx(r.Context(), uid, id); err != nil {
		h.writeErr(w, "AdminRestoreBrewery", err)
		return
	}
	if h.Caches != nil {
		h.Caches.BreweryDetail.InvalidatePrefix(id + ":")
	}
	cache.NotifyInvalidation(context.WithoutCancel(r.Context()), h.DB, h.Log, "brewery:"+id)
	// Return the freshly-restored row.
	out, err := h.Repos.Breweries.AdminDetail(r.Context(), id)
	if err != nil {
		h.writeErr(w, "AdminRestoreBrewery refetch", err)
		return
	}
	httperr.WriteJSON(w, http.StatusOK, out)
}

// ---- transaction helpers ----
//
// Each helper opens a tx, executes the repo mutation, writes the
// moderation_log row via AdminRepo.LogAction, and commits. They live
// here (handler layer) rather than in the repo because the moderation
// _log coupling is an admin concept, not a domain concept of breweries.

func (h *Handler) createBreweryTx(ctx context.Context, adminID string, body AdminBreweryCreate) (*repository.AdminBreweryRow, error) {
	tx, err := h.Repos.DB.Begin(ctx)
	if err != nil {
		return nil, err
	}
	defer func() { _ = tx.Rollback(ctx) }()

	out, err := h.Repos.Breweries.Create(ctx, tx, repository.BreweryCreateInput{
		Name:        body.NameI18n,
		Prefecture:  body.Prefecture,
		Region:      body.Region,
		FoundedYear: body.FoundedYear,
		Website:     body.Website,
		Description: body.DescriptionI18n,
	})
	if err != nil {
		return nil, err
	}
	if err := h.Repos.Admin.LogAction(ctx, tx, adminID, "brewery", out.ID, "create",
		nil,
		map[string]any{"name_en": body.NameI18n.EN}); err != nil {
		return nil, err
	}
	if err := tx.Commit(ctx); err != nil {
		return nil, err
	}
	return out, nil
}

func (h *Handler) updateBreweryTx(ctx context.Context, adminID, id string, body AdminBreweryUpdate) (*repository.AdminBreweryRow, error) {
	tx, err := h.Repos.DB.Begin(ctx)
	if err != nil {
		return nil, err
	}
	defer func() { _ = tx.Rollback(ctx) }()

	out, err := h.Repos.Breweries.Update(ctx, tx, id, repository.BreweryUpdateInput{
		Name:        body.NameI18n,
		Prefecture:  body.Prefecture,
		Region:      body.Region,
		FoundedYear: body.FoundedYear,
		Website:     body.Website,
		Description: body.DescriptionI18n,
	})
	if err != nil {
		return nil, err
	}
	if err := h.Repos.Admin.LogAction(ctx, tx, adminID, "brewery", id, "update",
		nil,
		map[string]any{"name_en": out.Name.EN}); err != nil {
		return nil, err
	}
	if err := tx.Commit(ctx); err != nil {
		return nil, err
	}
	return out, nil
}

func (h *Handler) softDeleteBreweryTx(ctx context.Context, adminID, id string) error {
	tx, err := h.Repos.DB.Begin(ctx)
	if err != nil {
		return err
	}
	defer func() { _ = tx.Rollback(ctx) }()

	if err := h.Repos.Breweries.SoftDelete(ctx, tx, id); err != nil {
		return err
	}
	if err := h.Repos.Admin.LogAction(ctx, tx, adminID, "brewery", id, "soft_delete", nil, nil); err != nil {
		return err
	}
	return tx.Commit(ctx)
}

func (h *Handler) restoreBreweryTx(ctx context.Context, adminID, id string) error {
	tx, err := h.Repos.DB.Begin(ctx)
	if err != nil {
		return err
	}
	defer func() { _ = tx.Rollback(ctx) }()

	if err := h.Repos.Breweries.Restore(ctx, tx, id); err != nil {
		return err
	}
	if err := h.Repos.Admin.LogAction(ctx, tx, adminID, "brewery", id, "restore", nil, nil); err != nil {
		return err
	}
	return tx.Commit(ctx)
}
