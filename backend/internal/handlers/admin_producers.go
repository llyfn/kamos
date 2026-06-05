// admin_producers.go — admin direct CRUD over producers.
//
// Every mutation runs inside a single pgx.Tx that bundles the moderation
// _log audit row, so the change + audit commit atomically. DELETE returns
// 409 PRODUCER_HAS_LIVE_BEVERAGES when at least one beverage still
// references the producer with deleted_at IS NULL.
//
// Producer locality is captured via `prefecture_id` (FK into
// `prefectures`). Admin clients send `prefecture_slug`; this handler
// resolves it to a UUID before the write. Unknown slug → 422
// INVALID_PREFECTURE_SLUG (mirrors `category_slug` on beverages).
package handlers

import (
	"context"
	"errors"
	"net/http"

	"github.com/go-chi/chi/v5"

	"github.com/kamos/api/internal/cache"
	"github.com/kamos/api/internal/cursor"
	"github.com/kamos/api/internal/domain"
	"github.com/kamos/api/internal/httperr"
	"github.com/kamos/api/internal/repository"
)

// errUnknownPrefectureSlug is returned by the prefecture-slug resolver
// when the supplied slug does not match any row in `prefectures`. The
// handler maps this to 422 INVALID_PREFECTURE_SLUG (the canonical 47
// slugs are seeded in `prefectures`).
var errUnknownPrefectureSlug = errors.New("unknown prefecture_slug")

// errEmptyPrefectureSlugOnCreate is returned when an AdminProducerCreate
// payload sends `prefecture_slug: ""`. OpenAPI's Create pattern is
// `^[a-z0-9_]+$` (non-empty); the contract is "omit the field if no
// prefecture is intended". The handler maps this to the same 422
// INVALID_PREFECTURE_SLUG response code with a more specific message.
var errEmptyPrefectureSlugOnCreate = errors.New("empty prefecture_slug on create")

// AdminListProducers — GET /v1/admin/producers
//
// Query params:
//   - q: optional websearch query (FTS via idx_producers_name_tsv)
//   - id: optional UUID exact-match (short-circuits cursor)
//   - include_deleted=1: include soft-deleted rows (admin "trash" view)
//   - cursor: opaque cursor
//   - limit: 1..50, default 20
func (h *Handler) AdminListProducers(w http.ResponseWriter, r *http.Request) {
	limit := parseLimit(r, 20, 50)
	c, err := parseCursor(r)
	if err != nil {
		h.writeErr(w, "AdminListProducers cursor", err)
		return
	}
	q := optString(r.URL.Query().Get("q"))
	id := optString(r.URL.Query().Get("id"))
	includeDeleted := r.URL.Query().Get("include_deleted") == "1"

	items, err := h.Repos.Producers.AdminList(r.Context(), repository.AdminProducerListParams{
		Q:              q,
		IDExact:        id,
		IncludeDeleted: includeDeleted,
		CursorTs:       optTimestamp(c),
		CursorID:       optString(c.ID),
		Limit:          limit,
	})
	if err != nil {
		h.writeErr(w, "AdminListProducers", err)
		return
	}
	page, next, hasMore := cursor.SliceAndCursor(items, limit, func(b repository.AdminProducerRow) cursor.Cursor {
		return cursor.Cursor{CreatedAt: b.CreatedAt, ID: b.ID}
	})
	httperr.WriteJSON(w, http.StatusOK, cursor.Page[repository.AdminProducerRow]{
		Items: page, NextCursor: next, HasMore: hasMore,
	})
}

// AdminGetProducer — GET /v1/admin/producers/{id}
// Returns the row including soft-deleted (admin needs to see the
// tombstone to restore it).
func (h *Handler) AdminGetProducer(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	if id == "" {
		httperr.WriteError(w, http.StatusBadRequest, "BAD_REQUEST", "missing producer id")
		return
	}
	row, err := h.Repos.Producers.AdminDetail(r.Context(), id)
	if err != nil {
		h.writeErr(w, "AdminGetProducer", err)
		return
	}
	httperr.WriteJSON(w, http.StatusOK, row)
}

// AdminCreateProducer — POST /v1/admin/producers
func (h *Handler) AdminCreateProducer(w http.ResponseWriter, r *http.Request) {
	uid, ok := h.authedID(w, r)
	if !ok {
		return
	}
	var body AdminProducerCreate
	if err := decodeJSON(r, &body); err != nil {
		h.writeErr(w, "AdminCreateProducer decode", err)
		return
	}
	if err := body.Validate(); err != nil {
		h.writeErr(w, "AdminCreateProducer validate", err)
		return
	}
	// Resolve prefecture_slug → prefecture_id before the write. Empty
	// slug stays nil (no curated prefecture).
	prefID, err := h.resolveOptionalPrefectureID(r.Context(), body.PrefectureSlug, false)
	if err != nil {
		h.writePrefectureErr(w, "AdminCreateProducer", err)
		return
	}

	out, err := h.createProducerTx(r.Context(), uid, body, prefID)
	if err != nil {
		h.writeErr(w, "AdminCreateProducer", err)
		return
	}
	httperr.WriteJSON(w, http.StatusCreated, out)
}

// AdminUpdateProducer — PATCH /v1/admin/producers/{id}
func (h *Handler) AdminUpdateProducer(w http.ResponseWriter, r *http.Request) {
	uid, ok := h.authedID(w, r)
	if !ok {
		return
	}
	id := chi.URLParam(r, "id")
	if id == "" {
		httperr.WriteError(w, http.StatusBadRequest, "BAD_REQUEST", "missing producer id")
		return
	}
	var body AdminProducerUpdate
	if err := decodeJSON(r, &body); err != nil {
		h.writeErr(w, "AdminUpdateProducer decode", err)
		return
	}
	if err := body.Validate(); err != nil {
		h.writeErr(w, "AdminUpdateProducer validate", err)
		return
	}
	// Resolve prefecture_slug → prefecture_id. allowClear=true since on
	// update, an explicit empty slug clears the column to NULL.
	prefID, err := h.resolveOptionalPrefectureID(r.Context(), body.PrefectureSlug, true)
	if err != nil {
		h.writePrefectureErr(w, "AdminUpdateProducer", err)
		return
	}

	out, err := h.updateProducerTx(r.Context(), uid, id, body, prefID)
	if err != nil {
		h.writeErr(w, "AdminUpdateProducer", err)
		return
	}
	// Invalidate the producer LRU + notify peer replicas so a stale row
	// doesn't linger after the rename / description change.
	if h.Caches != nil {
		h.Caches.ProducerDetail.InvalidatePrefix(id + ":")
	}
	cache.NotifyInvalidation(context.WithoutCancel(r.Context()), h.DB, h.Log, "producer:"+id)
	httperr.WriteJSON(w, http.StatusOK, out)
}

// AdminSoftDeleteProducer — DELETE /v1/admin/producers/{id}
// Returns 409 PRODUCER_HAS_LIVE_BEVERAGES if any live beverage still
// references the producer.
func (h *Handler) AdminSoftDeleteProducer(w http.ResponseWriter, r *http.Request) {
	uid, ok := h.authedID(w, r)
	if !ok {
		return
	}
	id := chi.URLParam(r, "id")
	if id == "" {
		httperr.WriteError(w, http.StatusBadRequest, "BAD_REQUEST", "missing producer id")
		return
	}
	if err := h.softDeleteProducerTx(r.Context(), uid, id); err != nil {
		h.writeErr(w, "AdminSoftDeleteProducer", err)
		return
	}
	if h.Caches != nil {
		h.Caches.ProducerDetail.InvalidatePrefix(id + ":")
	}
	cache.NotifyInvalidation(context.WithoutCancel(r.Context()), h.DB, h.Log, "producer:"+id)
	w.WriteHeader(http.StatusNoContent)
}

// AdminRestoreProducer — POST /v1/admin/producers/{id}/restore
func (h *Handler) AdminRestoreProducer(w http.ResponseWriter, r *http.Request) {
	uid, ok := h.authedID(w, r)
	if !ok {
		return
	}
	id := chi.URLParam(r, "id")
	if id == "" {
		httperr.WriteError(w, http.StatusBadRequest, "BAD_REQUEST", "missing producer id")
		return
	}
	if err := h.restoreProducerTx(r.Context(), uid, id); err != nil {
		h.writeErr(w, "AdminRestoreProducer", err)
		return
	}
	if h.Caches != nil {
		h.Caches.ProducerDetail.InvalidatePrefix(id + ":")
	}
	cache.NotifyInvalidation(context.WithoutCancel(r.Context()), h.DB, h.Log, "producer:"+id)
	// Return the freshly-restored row.
	out, err := h.Repos.Producers.AdminDetail(r.Context(), id)
	if err != nil {
		h.writeErr(w, "AdminRestoreProducer refetch", err)
		return
	}
	httperr.WriteJSON(w, http.StatusOK, out)
}

// ---- transaction helpers ----
//
// Each helper opens a tx, executes the repo mutation, writes the
// moderation_log row via AdminRepo.LogAction, and commits. They live
// here (handler layer) rather than in the repo because the moderation
// _log coupling is an admin concept, not a domain concept of producers.

func (h *Handler) createProducerTx(ctx context.Context, adminID string, body AdminProducerCreate, prefectureID *string) (*repository.AdminProducerRow, error) {
	imageURL, uploadID, err := h.resolveProducerImageUpload(ctx, adminID, body.ImageUploadID)
	if err != nil {
		return nil, err
	}

	tx, err := h.Repos.DB.Begin(ctx)
	if err != nil {
		return nil, err
	}
	defer func() { _ = tx.Rollback(ctx) }()

	out, err := h.Repos.Producers.Create(ctx, tx, repository.ProducerCreateInput{
		Name:         body.NameI18n,
		PrefectureID: prefectureID,
		FoundedYear:  body.FoundedYear,
		Website:      body.Website,
		Description:  body.DescriptionI18n,
		ImageURL:     imageURL,
	})
	if err != nil {
		return nil, err
	}
	if err := h.Repos.Admin.LogAction(ctx, tx, adminID, "producer", out.ID, "create",
		nil,
		map[string]any{"name_en": body.NameI18n.EN}); err != nil {
		return nil, err
	}
	if err := tx.Commit(ctx); err != nil {
		return nil, err
	}
	// MarkAttached after commit — orphan-cleanup belt-and-suspenders. A
	// failure here is logged, not rolled back, so we don't lose the
	// already-committed producer row over an attach-flag write.
	if uploadID != "" {
		if err := h.Repos.PhotoUploads.MarkAttached(ctx, uploadID, out.ID); err != nil {
			h.Log.Warn("createProducerTx mark upload attached",
				"err", err, "upload_id", uploadID, "producer_id", out.ID)
		}
	}
	return out, nil
}

func (h *Handler) updateProducerTx(ctx context.Context, adminID, id string, body AdminProducerUpdate, prefectureID *string) (*repository.AdminProducerRow, error) {
	// Tri-state imageURLPtr: &""  → NULL the column, &URL → set, nil → leave.
	var imageURLPtr *string
	var uploadID string
	switch {
	case body.ClearImage:
		empty := ""
		imageURLPtr = &empty
	case body.ImageUploadID != nil && *body.ImageUploadID != "":
		resolved, uid, err := h.resolveProducerImageUpload(ctx, adminID, body.ImageUploadID)
		if err != nil {
			return nil, err
		}
		imageURLPtr = resolved
		uploadID = uid
	}

	tx, err := h.Repos.DB.Begin(ctx)
	if err != nil {
		return nil, err
	}
	defer func() { _ = tx.Rollback(ctx) }()

	out, err := h.Repos.Producers.Update(ctx, tx, id, repository.ProducerUpdateInput{
		Name:         body.NameI18n,
		PrefectureID: prefectureID,
		FoundedYear:  body.FoundedYear,
		Website:      body.Website,
		Description:  body.DescriptionI18n,
		ImageURL:     imageURLPtr,
	})
	if err != nil {
		return nil, err
	}
	if err := h.Repos.Admin.LogAction(ctx, tx, adminID, "producer", id, "update",
		nil,
		map[string]any{"name_en": out.Name.EN}); err != nil {
		return nil, err
	}
	if err := tx.Commit(ctx); err != nil {
		return nil, err
	}
	if uploadID != "" {
		if err := h.Repos.PhotoUploads.MarkAttached(ctx, uploadID, id); err != nil {
			h.Log.Warn("updateProducerTx mark upload attached",
				"err", err, "upload_id", uploadID, "producer_id", id)
		}
	}
	return out, nil
}

// resolveProducerImageUpload turns an optional photo_uploads.id into the
// public R2 URL the repository persists on producers.image_url. Errors:
// ErrNotFound (unknown upload or cross-admin reuse), ErrUploadNotCompleted
// (upload already attached or orphaned). Purpose='producer' is enforced
// at the admin-only presign route, not here.
func (h *Handler) resolveProducerImageUpload(ctx context.Context, adminID string, uploadID *string) (*string, string, error) {
	if uploadID == nil || *uploadID == "" {
		return nil, "", nil
	}
	upload, err := h.Repos.PhotoUploads.FindByID(ctx, *uploadID)
	if err != nil {
		return nil, "", err
	}
	if upload.UserID != adminID {
		return nil, "", domain.ErrNotFound
	}
	if upload.Status == "attached" || upload.Status == "orphaned" {
		return nil, "", domain.ErrUploadNotCompleted
	}
	url := h.Storage.PublicURL(upload.BlobKey)
	return &url, upload.ID, nil
}

// ---- prefecture slug resolution ----

// resolveOptionalPrefectureID converts a client-supplied prefecture_slug
// to the FK id used by ProducerCreateInput / ProducerUpdateInput. Returns:
//
//   - (nil, nil) when slug is nil → "leave column unchanged" on update,
//     or "no curated prefecture" on create.
//   - (ptr to "", nil) when slug is non-nil but empty AND allowClear is
//     true → explicit clear (Update path only).
//   - (ptr to id, nil) when the slug resolves.
//   - (nil, errEmptyPrefectureSlugOnCreate) when the slug is non-nil but
//     empty AND allowClear is false → handler maps to 422
//     INVALID_PREFECTURE_SLUG with a "cannot be empty on create" message
//     so the client knows to either omit the field or send a real slug.
//   - (nil, errUnknownPrefectureSlug) when the slug is non-empty but
//     not found in `prefectures` → handler maps to 422
//     INVALID_PREFECTURE_SLUG.
//
// allowClear=false on Create rejects an explicit empty slug — an unset
// prefecture on create is achieved by omitting the field entirely. This
// matches the OpenAPI `^[a-z0-9_]+$` (non-empty) pattern on
// AdminProducerCreate.prefecture_slug.
func (h *Handler) resolveOptionalPrefectureID(ctx context.Context, slug *string, allowClear bool) (*string, error) {
	if slug == nil {
		return nil, nil
	}
	if *slug == "" {
		if !allowClear {
			return nil, errEmptyPrefectureSlugOnCreate
		}
		empty := ""
		return &empty, nil
	}
	id, err := h.Repos.Geo.PrefectureIDForSlug(ctx, *slug)
	if err != nil {
		if errors.Is(err, domain.ErrNotFound) {
			return nil, errUnknownPrefectureSlug
		}
		return nil, err
	}
	return &id, nil
}

// writePrefectureErr maps the prefecture-slug sentinels to a stable 422
// response code; everything else flows through the usual writeErr path.
// Mirrors writeCategoryErr in admin_beverages.go.
func (h *Handler) writePrefectureErr(w http.ResponseWriter, op string, err error) {
	if errors.Is(err, errUnknownPrefectureSlug) {
		httperr.WriteError(w, http.StatusUnprocessableEntity, "INVALID_PREFECTURE_SLUG",
			"prefecture_slug must be a known prefecture (see GET /v1/reference/regions)")
		return
	}
	if errors.Is(err, errEmptyPrefectureSlugOnCreate) {
		httperr.WriteError(w, http.StatusUnprocessableEntity, "INVALID_PREFECTURE_SLUG",
			"prefecture_slug cannot be empty on create — omit the field if no prefecture is intended")
		return
	}
	h.writeErr(w, op, err)
}

func (h *Handler) softDeleteProducerTx(ctx context.Context, adminID, id string) error {
	tx, err := h.Repos.DB.Begin(ctx)
	if err != nil {
		return err
	}
	defer func() { _ = tx.Rollback(ctx) }()

	if err := h.Repos.Producers.SoftDelete(ctx, tx, id); err != nil {
		return err
	}
	if err := h.Repos.Admin.LogAction(ctx, tx, adminID, "producer", id, "soft_delete", nil, nil); err != nil {
		return err
	}
	return tx.Commit(ctx)
}

func (h *Handler) restoreProducerTx(ctx context.Context, adminID, id string) error {
	tx, err := h.Repos.DB.Begin(ctx)
	if err != nil {
		return err
	}
	defer func() { _ = tx.Rollback(ctx) }()

	if err := h.Repos.Producers.Restore(ctx, tx, id); err != nil {
		return err
	}
	if err := h.Repos.Admin.LogAction(ctx, tx, adminID, "producer", id, "restore", nil, nil); err != nil {
		return err
	}
	return tx.Commit(ctx)
}
