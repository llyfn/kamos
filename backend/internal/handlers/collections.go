package handlers

import (
	"net/http"

	"github.com/go-chi/chi/v5"

	"github.com/kamos/api/internal/cursor"
	"github.com/kamos/api/internal/domain"
	"github.com/kamos/api/internal/httperr"
	"github.com/kamos/api/internal/middleware"
	"github.com/kamos/api/internal/repository"
)

// ListPublicCollections — GET /v1/collections/public.
//
// Public discovery feed of collections users have flipped to visibility =
// 'public'. OptionalAuth: the endpoint works without a Bearer token; when a
// token is present, the handler does nothing extra (no follow-state hints
// on collections — that's a profile-screen concern).
//
// Cursor-paginated on (created_at, id) DESC, page size default 20 / max 50.
func (h *Handler) ListPublicCollections(w http.ResponseWriter, r *http.Request) {
	limit := parseLimit(r, 20, 50)
	c, err := parseCursor(r)
	if err != nil {
		h.writeErr(w, "ListPublicCollections cursor", err)
		return
	}
	items, err := h.Repos.Collections.ListPublic(r.Context(),
		optTimestamp(c), optString(c.ID), limit)
	if err != nil {
		h.writeErr(w, "ListPublicCollections", err)
		return
	}
	page, next, hasMore := cursor.SliceAndCursor(items, limit, func(row domain.CollectionWithOwner) cursor.Cursor {
		return cursor.Cursor{CreatedAt: row.CreatedAt, ID: row.ID}
	})
	httperr.WriteJSON(w, http.StatusOK, cursor.Page[domain.CollectionWithOwner]{
		Items: page, NextCursor: next, HasMore: hasMore,
	})
}

// ListCollections — GET /v1/collections.
func (h *Handler) ListCollections(w http.ResponseWriter, r *http.Request) {
	uid, ok := h.authedID(w, r)
	if !ok {
		return
	}
	rows, err := h.Repos.Collections.List(r.Context(), uid)
	if err != nil {
		h.writeErr(w, "ListCollections", err)
		return
	}
	// Collections list is bounded (default 2 + N user-created); we still wrap
	// in the canonical Page shape so the client uses one code path.
	httperr.WriteJSON(w, http.StatusOK, cursor.Page[domain.Collection]{
		Items: rows, HasMore: false,
	})
}

// CreateCollection — POST /v1/collections.
func (h *Handler) CreateCollection(w http.ResponseWriter, r *http.Request) {
	uid, ok := h.authedID(w, r)
	if !ok {
		return
	}
	var req domain.CreateCollectionRequest
	if err := decodeJSON(r, &req); err != nil {
		h.writeErr(w, "CreateCollection decode", err)
		return
	}
	if err := req.Validate(); err != nil {
		h.writeErr(w, "CreateCollection validate", err)
		return
	}
	c, err := h.Repos.Collections.Create(r.Context(), uid, req.Name)
	if err != nil {
		h.writeErr(w, "CreateCollection", err)
		return
	}
	httperr.WriteJSON(w, http.StatusCreated, c)
}

// GetCollection — GET /v1/collections/{id}.
//
// OptionalAuth. Visibility rule:
//   - Owner can read their own collection (any visibility).
//   - Anyone (including anonymous) can read a `public` collection.
//   - All other cases collapse to 404 — do NOT 403, which would leak
//     existence of private rows. This mirrors the SPEC §3 private-account
//     handling on `GET /v1/check-ins/{id}`.
//
// The Entries projection is included for the owner and for anyone hitting
// a public collection — the discovery feed deep-links here, so non-owners
// need to see the contents.
func (h *Handler) GetCollection(w http.ResponseWriter, r *http.Request) {
	// viewerID is "" for anonymous requests; only used for the ownership
	// branch of the visibility decision.
	var viewerID string
	if u := middleware.UserFromContext(r.Context()); u != nil {
		viewerID = u.ID
	}

	id := chi.URLParam(r, "id")
	c, err := h.Repos.Collections.Get(r.Context(), id)
	if err != nil {
		h.writeErr(w, "GetCollection", err)
		return
	}

	// Visibility gate. Owner always passes; everyone else must hit a
	// public row. Private-to-non-owner collapses to 404 (do not leak).
	isOwner := viewerID != "" && c.OwnerID == viewerID
	if !isOwner && c.Visibility != "public" {
		httperr.WriteError(w, http.StatusNotFound, "NOT_FOUND", "not found")
		return
	}

	limit := parseLimit(r, 50, 100)
	cur, err := parseCursor(r)
	if err != nil {
		h.writeErr(w, "GetCollection cursor", err)
		return
	}
	ts, cid := optTimestamp(cur), optString(cur.ID)
	// Entries are owner-agnostic (the row passes the visibility gate above).
	// The Entries repo function uses the collection's own owner for its
	// ownership-baked join, so pass c.OwnerID instead of viewerID — this
	// lets a non-owner view a public collection's entries.
	entries, err := h.Repos.Collections.Entries(r.Context(), c.OwnerID, id, ts, cid, limit)
	if err != nil {
		h.writeErr(w, "GetCollection entries", err)
		return
	}
	items, next, hasMore := cursor.SliceAndCursor(entries, limit, func(e domain.CollectionEntry) cursor.Cursor {
		return cursor.Cursor{CreatedAt: e.AddedAt, ID: e.Beverage.ID}
	})
	out := struct {
		domain.Collection
		Entries cursor.Page[domain.CollectionEntry] `json:"entries"`
	}{Collection: *c, Entries: cursor.Page[domain.CollectionEntry]{Items: items, NextCursor: next, HasMore: hasMore}}
	httperr.WriteJSON(w, http.StatusOK, out)
}

// UpdateCollection — PATCH /v1/collections/{id}.
//
// was RenameCollection; now also accepts {visibility: ...} to
// flip between private and public. Either or both fields can be sent;
// missing-both is a 422.
func (h *Handler) UpdateCollection(w http.ResponseWriter, r *http.Request) {
	uid, ok := h.authedID(w, r)
	if !ok {
		return
	}
	id := chi.URLParam(r, "id")
	var req domain.UpdateCollectionRequest
	if err := decodeJSON(r, &req); err != nil {
		h.writeErr(w, "UpdateCollection decode", err)
		return
	}
	if err := req.Validate(); err != nil {
		h.writeErr(w, "UpdateCollection validate", err)
		return
	}
	c, err := h.Repos.Collections.Update(r.Context(), uid, id, repository.UpdateCollectionParams{
		Name:       req.Name,
		Visibility: req.Visibility,
	})
	if err != nil {
		h.writeErr(w, "UpdateCollection", err)
		return
	}
	httperr.WriteJSON(w, http.StatusOK, c)
}

// DeleteCollection — DELETE /v1/collections/{id}.
func (h *Handler) DeleteCollection(w http.ResponseWriter, r *http.Request) {
	uid, ok := h.authedID(w, r)
	if !ok {
		return
	}
	id := chi.URLParam(r, "id")
	if err := h.Repos.Collections.SoftDelete(r.Context(), uid, id); err != nil {
		h.writeErr(w, "DeleteCollection", err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// AddCollectionEntry — POST /v1/collections/{id}/entries.
func (h *Handler) AddCollectionEntry(w http.ResponseWriter, r *http.Request) {
	uid, ok := h.authedID(w, r)
	if !ok {
		return
	}
	id := chi.URLParam(r, "id")
	var req domain.AddCollectionEntryRequest
	if err := decodeJSON(r, &req); err != nil {
		h.writeErr(w, "AddCollectionEntry decode", err)
		return
	}
	if err := req.Validate(); err != nil {
		h.writeErr(w, "AddCollectionEntry validate", err)
		return
	}
	exists, err := h.Repos.Beverages.Exists(r.Context(), req.BeverageID)
	if err != nil {
		h.writeErr(w, "AddCollectionEntry exists", err)
		return
	}
	if !exists {
		httperr.WriteError(w, http.StatusNotFound, "NOT_FOUND", "beverage not found")
		return
	}
	if err := h.Repos.Collections.AddEntry(r.Context(), uid, id, req.BeverageID, req.Note); err != nil {
		h.writeErr(w, "AddCollectionEntry", err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// UpdateCollectionEntry — PATCH /v1/collections/{id}/entries/{beverage_id}.
//
// Status: scaffold-for-Phase6 (collection entry note edits, low cost to keep
// pre-wired). Endpoint is intentionally pre-wired; no Flutter caller in MVP.
func (h *Handler) UpdateCollectionEntry(w http.ResponseWriter, r *http.Request) {
	uid, ok := h.authedID(w, r)
	if !ok {
		return
	}
	id := chi.URLParam(r, "id")
	bevID := chi.URLParam(r, "beverage_id")
	var req domain.UpdateCollectionEntryRequest
	if err := decodeJSON(r, &req); err != nil {
		h.writeErr(w, "UpdateCollectionEntry decode", err)
		return
	}
	if err := req.Validate(); err != nil {
		h.writeErr(w, "UpdateCollectionEntry validate", err)
		return
	}
	if err := h.Repos.Collections.UpdateEntry(r.Context(), uid, id, bevID, req.Note); err != nil {
		h.writeErr(w, "UpdateCollectionEntry", err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// RemoveCollectionEntry — DELETE /v1/collections/{id}/entries/{beverage_id}.
func (h *Handler) RemoveCollectionEntry(w http.ResponseWriter, r *http.Request) {
	uid, ok := h.authedID(w, r)
	if !ok {
		return
	}
	id := chi.URLParam(r, "id")
	bevID := chi.URLParam(r, "beverage_id")
	if err := h.Repos.Collections.RemoveEntry(r.Context(), uid, id, bevID); err != nil {
		h.writeErr(w, "RemoveCollectionEntry", err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
