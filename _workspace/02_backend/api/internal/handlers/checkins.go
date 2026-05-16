package handlers

import (
	"encoding/json"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/kamos/api/internal/apierror"
	"github.com/kamos/api/internal/domain"
	"github.com/kamos/api/internal/observability"
	"github.com/kamos/api/internal/repository"
)

// CreateCheckin — POST /v1/check-ins.
func (h *Handler) CreateCheckin(w http.ResponseWriter, r *http.Request) {
	uid, ok := h.authedID(w, r)
	if !ok {
		return
	}
	var req domain.CreateCheckinRequest
	if err := decodeJSON(r, &req); err != nil {
		h.writeErr(w, "CreateCheckin decode", err)
		return
	}
	if err := req.Validate(); err != nil {
		h.writeErr(w, "CreateCheckin validate", err)
		return
	}
	// Phase 4 — SEC-001: bound + sanitize venue strings before the upsert path
	// to keep poisoned payloads out of the shared venues table.
	if err := req.Venue.Validate(); err != nil {
		h.writeErr(w, "CreateCheckin validate venue", err)
		return
	}
	exists, err := h.Repos.Beverages.Exists(r.Context(), req.BeverageID)
	if err != nil {
		h.writeErr(w, "CreateCheckin exists", err)
		return
	}
	if !exists {
		apierror.WriteError(w, http.StatusNotFound, "NOT_FOUND", "beverage not found")
		return
	}

	// Phase 4 — optional venue tag. Three accepted shapes (see domain doc):
	//   { id }                                  → look up; 404 if missing.
	//   { foursquare_id, name, ... }            → upsert by fsq id.
	//   anything else (incl. empty {})          → silent drop.
	venueID, err := h.resolveCheckinVenue(r, req.Venue)
	if err != nil {
		h.writeErr(w, "CreateCheckin venue", err)
		return
	}

	p := repository.CreateCheckinParams{
		UserID:       uid,
		BeverageID:   req.BeverageID,
		Rating:       req.Rating,
		ReviewText:   req.Review,
		PurchaseType: req.PurchaseType,
		ServingStyle: req.ServingStyle,
		PhotoURLs:    req.Photos,
		TagSlugs:     req.Tags,
		VenueID:      venueID,
	}
	if req.Price != nil {
		amt := req.Price.Amount
		ccy := req.Price.Currency
		md := req.Price.Mode
		p.PriceAmount = &amt
		p.PriceCcy = &ccy
		p.PriceUnit = &md
	}
	id, _, err := h.Repos.Checkins.Create(r.Context(), p)
	if err != nil {
		h.writeErr(w, "CreateCheckin", err)
		return
	}
	out, err := h.Repos.Checkins.Get(r.Context(), id, uid)
	if err != nil {
		h.writeErr(w, "CreateCheckin reload", err)
		return
	}
	// Phase 7 — bust the BeverageDetail cache for every locale of this
	// beverage: the trigger has already updated avg_rating and
	// check_in_count, so the cached pointer is now stale.
	h.invalidateBeverageDetail(req.BeverageID)
	// Business metric for the OTel meter. No-op when OTel is disabled.
	observability.IncCheckinsCreated(r.Context())
	apierror.WriteJSON(w, http.StatusCreated, out)
}

// invalidateBeverageDetail busts every locale-suffixed entry for the
// given beverage. Cheap (cache size <= 1000) and best-effort —
// downstream HTTP caches still honor max-age=300 from the
// Cache-Control header, but in-process readers see fresh data
// immediately.
func (h *Handler) invalidateBeverageDetail(beverageID string) {
	if h.Caches == nil || beverageID == "" {
		return
	}
	h.Caches.BeverageDetail.InvalidatePrefix(beverageID + ":")
}

// GetCheckin — GET /v1/check-ins/{id}.
//
// Status: scaffold-for-Phase6 (comments need a check-in detail view) and
// Phase5 (admin moderation surface). Endpoint is intentionally pre-wired;
// no Flutter caller in MVP.
func (h *Handler) GetCheckin(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	viewerID := ""
	if v := authedIDOrEmpty(r); v != "" {
		viewerID = v
	}
	c, err := h.Repos.Checkins.Get(r.Context(), id, viewerID)
	if err != nil {
		h.writeErr(w, "GetCheckin", err)
		return
	}
	apierror.WriteJSON(w, http.StatusOK, c)
}

// UpdateCheckin — PATCH /v1/check-ins/{id}.
//
// Status: scaffold-for-Phase5 (admin edit surface). Endpoint is intentionally
// pre-wired; no Flutter caller in MVP.
func (h *Handler) UpdateCheckin(w http.ResponseWriter, r *http.Request) {
	uid, ok := h.authedID(w, r)
	if !ok {
		return
	}
	id := chi.URLParam(r, "id")

	// Decode into a raw map first so we can distinguish "field absent" from
	// "field present and null" for the clear-out semantics.
	var raw map[string]json.RawMessage
	if err := json.NewDecoder(r.Body).Decode(&raw); err != nil {
		h.writeErr(w, "UpdateCheckin decode", err)
		return
	}
	if _, found := raw["beverage_id"]; found {
		apierror.WriteError(w, http.StatusUnprocessableEntity, "VALIDATION",
			"beverage_id cannot be changed after a check-in is created")
		return
	}
	// Re-decode the same raw map into the typed struct. Unknown fields would
	// have already been caught above (none are accepted on this endpoint),
	// so strict-decode is unnecessary on the second pass — every json tag
	// on UpdateCheckinRequest (including the `clear_*` flags) is known.
	var req domain.UpdateCheckinRequest
	rawBytes, _ := json.Marshal(raw)
	if err := json.Unmarshal(rawBytes, &req); err != nil {
		h.writeErr(w, "UpdateCheckin decode typed", err)
		return
	}
	if err := req.Validate(); err != nil {
		h.writeErr(w, "UpdateCheckin validate", err)
		return
	}
	// Detect clear semantics: null in JSON means clear.
	if v, ok := raw["rating"]; ok && string(v) == "null" {
		req.ClearRating = true
	}
	if v, ok := raw["review"]; ok && string(v) == "null" {
		req.ClearReview = true
	}
	if v, ok := raw["price"]; ok && string(v) == "null" {
		req.ClearPrice = true
	}
	up := repository.UpdateCheckinParams{
		ID:           id,
		UserID:       uid,
		Rating:       req.Rating,
		ClearRating:  req.ClearRating,
		Review:       req.Review,
		ClearReview:  req.ClearReview,
		ClearPrice:   req.ClearPrice,
		PurchaseType: req.PurchaseType,
		ServingStyle: req.ServingStyle,
		Tags:         req.Tags,
	}
	if req.Price != nil {
		amt := req.Price.Amount
		ccy := req.Price.Currency
		md := req.Price.Mode
		up.PriceAmount = &amt
		up.PriceCcy = &ccy
		up.PriceUnit = &md
	}
	if err := h.Repos.Checkins.Update(r.Context(), up); err != nil {
		h.writeErr(w, "UpdateCheckin", err)
		return
	}
	out, err := h.Repos.Checkins.Get(r.Context(), id, uid)
	if err != nil {
		h.writeErr(w, "UpdateCheckin reload", err)
		return
	}
	// Phase 7 — invalidate even when only non-rating fields changed: the
	// detail response includes review/tags surfaced via recent_check_ins.
	h.invalidateBeverageDetail(out.Beverage.ID)
	apierror.WriteJSON(w, http.StatusOK, out)
}

// DeleteCheckin — DELETE /v1/check-ins/{id}.
//
// Status: scaffold-for-Phase5 (admin moderation). Endpoint is intentionally
// pre-wired; no Flutter caller in MVP.
func (h *Handler) DeleteCheckin(w http.ResponseWriter, r *http.Request) {
	uid, ok := h.authedID(w, r)
	if !ok {
		return
	}
	id := chi.URLParam(r, "id")
	// Phase 7 — fetch the beverage_id before soft-deleting so we know which
	// LRU entry to bust. If the Get fails we still attempt the delete; the
	// cache TTL ceiling (5m) bounds the staleness window. Get + SoftDelete
	// is two PK lookups in the same request — cheap.
	var bevID string
	if cached, err := h.Repos.Checkins.Get(r.Context(), id, uid); err == nil {
		bevID = cached.Beverage.ID
	}
	if err := h.Repos.Checkins.SoftDelete(r.Context(), id, uid); err != nil {
		h.writeErr(w, "DeleteCheckin", err)
		return
	}
	h.invalidateBeverageDetail(bevID)
	w.WriteHeader(http.StatusNoContent)
}

// Phase 3 — the MVP scaffold accepted `{ url }` (any URL the client claimed
// to have stored somewhere). That contract is replaced by a 3-step flow:
//
//   1. POST /v1/uploads/photo-presign   → server returns a presigned PUT URL.
//   2. Client PUTs the bytes to R2 with the supplied Content-Type header.
//   3. POST /v1/check-ins/{id}/photos with `{ "upload_id": <uuid> }`. The
//      server promotes the photo_uploads row to 'attached', looks up the
//      public URL for the blob_key, and inserts into check_in_photos.
//
// We do NOT verify the client's PUT against R2 in Phase 3 — the orphan
// cleanup job sweeps anything that never reaches 'attached'. A future
// hardening pass can add a HEAD check before the attach.
//
// The mobile clients in the field at MVP did not expose a photo upload UI,
// so the wire change is acceptable.
type uploadPhotoRequest struct {
	UploadID string `json:"upload_id"`
}

// UploadCheckinPhoto — POST /v1/check-ins/{id}/photos.
//
// Attaches a previously-presigned blob to a check-in. The 4-photo cap is
// still enforced by AddPhoto.
func (h *Handler) UploadCheckinPhoto(w http.ResponseWriter, r *http.Request) {
	uid, ok := h.authedID(w, r)
	if !ok {
		return
	}
	id := chi.URLParam(r, "id")
	var req uploadPhotoRequest
	if err := decodeJSON(r, &req); err != nil {
		h.writeErr(w, "UploadCheckinPhoto decode", err)
		return
	}
	if req.UploadID == "" {
		apierror.WriteError(w, http.StatusUnprocessableEntity, "VALIDATION", "upload_id is required")
		return
	}

	upload, err := h.Repos.PhotoUploads.FindByID(r.Context(), req.UploadID)
	if err != nil {
		h.writeErr(w, "UploadCheckinPhoto find upload", err)
		return
	}
	// Ownership match — never let a user attach someone else's blob.
	if upload.UserID != uid {
		apierror.WriteError(w, http.StatusNotFound, "NOT_FOUND", "upload not found")
		return
	}
	// Already-attached / orphaned rows can't be reused.
	if upload.Status == "attached" || upload.Status == "orphaned" {
		apierror.WriteError(w, http.StatusConflict, "UPLOAD_NOT_COMPLETED",
			"upload already attached or orphaned")
		return
	}

	// PublicURL on Disabled returns ""; the integration test documents that
	// the row goes in with an empty url under the "no R2 configured" mode.
	publicURL := h.Storage.PublicURL(upload.BlobKey)
	photo, err := h.Repos.Checkins.AddPhoto(r.Context(), id, uid, publicURL)
	if err != nil {
		h.writeErr(w, "UploadCheckinPhoto attach", err)
		return
	}
	if err := h.Repos.PhotoUploads.MarkAttached(r.Context(), upload.ID, id); err != nil {
		// Photo row is already committed; log and move on so the client
		// doesn't see a half-failure.
		h.Log.Warn("UploadCheckinPhoto mark attached", "err", err,
			"upload_id", upload.ID, "check_in_id", id)
	}
	apierror.WriteJSON(w, http.StatusCreated, photo)
}

// ToggleToast — POST /v1/check-ins/{id}/toast.
// Idempotent: toggles the row, returns the fresh count + you_toasted.
func (h *Handler) ToggleToast(w http.ResponseWriter, r *http.Request) {
	uid, ok := h.authedID(w, r)
	if !ok {
		return
	}
	id := chi.URLParam(r, "id")
	state, err := h.Repos.Checkins.ToggleToast(r.Context(), uid, id)
	if err != nil {
		h.writeErr(w, "ToggleToast", err)
		return
	}
	apierror.WriteJSON(w, http.StatusOK, state)
}

// authedIDOrEmpty returns the authed user id or empty when missing.
func authedIDOrEmpty(r *http.Request) string {
	if u := mwUser(r); u != nil {
		return u.ID
	}
	return ""
}

// resolveCheckinVenue translates the optional CheckinVenue payload into a
// venue UUID for the check-in row. nil return means "no venue" (the FK
// stays NULL). Returns ErrNotFound if `id` was supplied but the venue
// doesn't exist; that maps to 404 via writeErr.
func (h *Handler) resolveCheckinVenue(r *http.Request, v *domain.CheckinVenue) (*string, error) {
	if v == nil {
		return nil, nil
	}
	if v.ID != nil && *v.ID != "" {
		got, err := h.Repos.Venues.GetByID(r.Context(), *v.ID)
		if err != nil {
			return nil, err
		}
		id := got.ID
		return &id, nil
	}
	if v.FoursquareID != nil && *v.FoursquareID != "" && v.Name != nil && *v.Name != "" {
		id, err := h.Repos.Venues.UpsertByFoursquareID(r.Context(), repository.UpsertVenueInput{
			FoursquareID: *v.FoursquareID,
			Name:         *v.Name,
			Address:      v.Address,
			Lat:          v.Lat,
			Lng:          v.Lng,
			Country:      v.Country,
			Prefecture:   v.Prefecture,
			Locality:     v.Locality,
		})
		if err != nil {
			return nil, err
		}
		return &id, nil
	}
	// Silent drop — incomplete venue payload (e.g., empty object).
	return nil, nil
}
