package handlers

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"

	"github.com/go-chi/chi/v5"

	"github.com/kamos/api/internal/cache"
	"github.com/kamos/api/internal/domain"
	"github.com/kamos/api/internal/httperr"
	"github.com/kamos/api/internal/observability"
	"github.com/kamos/api/internal/repository"
)

// CreateCheckin — POST /v1/check-ins.
//
// Stage 3 (architectural refactor): the body's orchestration (beverage-
// existence gate, venue resolve, multi-row insert, cache invalidate,
// counter bump) now lives in CheckinService.Create. The handler does
// decode → validate → call → respond.
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
	// SEC-001: bound + sanitize venue strings before the upsert path
	// to keep poisoned payloads out of the shared venues table.
	if err := req.Venue.Validate(); err != nil {
		h.writeErr(w, "CreateCheckin validate venue", err)
		return
	}
	if h.Services != nil && h.Services.Checkin != nil {
		out, err := h.Services.Checkin.Create(r.Context(), uid, req)
		if err != nil {
			h.writeErr(w, "CreateCheckin", err)
			return
		}
		httperr.WriteJSON(w, http.StatusCreated, out)
		return
	}
	// Legacy fallback (tests that don't construct services): pre-Stage-3 path.
	exists, err := h.Repos.Beverages.Exists(r.Context(), req.BeverageID)
	if err != nil {
		h.writeErr(w, "CreateCheckin exists", err)
		return
	}
	if !exists {
		httperr.WriteError(w, http.StatusNotFound, "NOT_FOUND", "beverage not found")
		return
	}
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
	h.invalidateBeverageDetail(r.Context(), req.BeverageID)
	observability.IncCheckinsCreated(r.Context())
	httperr.WriteJSON(w, http.StatusCreated, out)
}

// invalidateBeverageDetail busts every locale-suffixed entry for the
// given beverage. Cheap (cache size <= 1000) and best-effort —
// downstream HTTP caches still honor max-age=300 from the
// Cache-Control header, but in-process readers see fresh data
// immediately. Stage 4: also fire a pg_notify so peer replicas bust
// their copies; the notify is fire-and-forget (silent on nil DB).
func (h *Handler) invalidateBeverageDetail(ctx context.Context, beverageID string) {
	if beverageID == "" {
		return
	}
	if h.Caches != nil {
		h.Caches.BeverageDetail.InvalidatePrefix(beverageID + ":")
	}
	// WithoutCancel keeps the request's trace context but detaches
	// cancellation: a client disconnect right after commit must not skip
	// the peer-replica invalidation, or readers on other replicas go stale.
	cache.NotifyInvalidation(context.WithoutCancel(ctx), h.DB, h.Log, "beverage:"+beverageID)
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
	httperr.WriteJSON(w, http.StatusOK, c)
}

// UpdateCheckin — PATCH /v1/check-ins/{id}.
//
// Stage 3 (ARCH-014) cleanup: the previous implementation decoded the body
// twice — first into a `map[string]json.RawMessage`, then re-marshalled and
// re-decoded into the typed request struct — only to detect "field present
// and null" for the clear-rating / clear-review / clear-price semantics.
//
// The new implementation does a single decode using the dedicated
// `updateCheckinPatch` shape that uses `json.RawMessage` for the three
// fields where null-vs-absent matters. The `beverage_id` poison-pill is
// rejected by `domain.UpdateCheckinRequest.Validate` after the patch is
// projected onto the typed request — saving the JSON-encode round trip.
//
// Wire contract: unchanged (still SPEC §4.4 — `beverage_id` not allowed,
// null on rating/review/price means "clear").
//
// Status: scaffold-for-Phase5 (admin edit surface).
func (h *Handler) UpdateCheckin(w http.ResponseWriter, r *http.Request) {
	uid, ok := h.authedID(w, r)
	if !ok {
		return
	}
	id := chi.URLParam(r, "id")

	var patch updateCheckinPatch
	if err := decodeJSON(r, &patch); err != nil {
		h.writeErr(w, "UpdateCheckin decode", err)
		return
	}
	req, err := patch.toRequest()
	if err != nil {
		h.writeErr(w, "UpdateCheckin patch", err)
		return
	}
	if err := req.Validate(); err != nil {
		h.writeErr(w, "UpdateCheckin validate", err)
		return
	}
	if h.Services != nil && h.Services.Checkin != nil {
		out, err := h.Services.Checkin.Update(r.Context(), uid, id, req)
		if err != nil {
			h.writeErr(w, "UpdateCheckin", err)
			return
		}
		httperr.WriteJSON(w, http.StatusOK, out)
		return
	}
	// Legacy fallback (tests that don't construct services).
	up := repository.UpdateCheckinParams{
		ID:           id,
		UserID:       uid,
		Rating:       req.Rating,
		ClearRating:  req.ClearRating,
		Review:       req.Review,
		ClearReview:  req.ClearReview,
		ClearPrice:   req.ClearPrice,
		PurchaseType: req.PurchaseType,
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
	h.invalidateBeverageDetail(r.Context(), out.Beverage.ID)
	httperr.WriteJSON(w, http.StatusOK, out)
}

// updateCheckinPatch is the single-decode wire shape for UpdateCheckin.
// json.RawMessage on the three null-detectable fields lets the handler
// distinguish "field absent" from "field present and null" without a
// double-decode (ARCH-014 fix).
//
// `beverage_id` is captured here purely so `decodeJSON`'s DisallowUnknownFields
// doesn't reject the legacy poison-pill payload with 400 — the poison check
// itself runs inside toRequest() so the response is the canonical 422.
type updateCheckinPatch struct {
	BeverageID   *string         `json:"beverage_id,omitempty"`
	Rating       json.RawMessage `json:"rating,omitempty"`
	Review       json.RawMessage `json:"review,omitempty"`
	Tags         *[]string       `json:"tags,omitempty"`
	Price        json.RawMessage `json:"price,omitempty"`
	PurchaseType *string         `json:"purchase_type,omitempty"`
}

// toRequest projects the patch onto domain.UpdateCheckinRequest, including
// the null-as-clear semantics for rating/review/price.
func (p updateCheckinPatch) toRequest() (domain.UpdateCheckinRequest, error) {
	req := domain.UpdateCheckinRequest{
		BeverageID:   p.BeverageID,
		Tags:         p.Tags,
		PurchaseType: p.PurchaseType,
	}
	// rating: null → clear; value → set; absent → no change.
	if len(p.Rating) > 0 {
		if string(p.Rating) == "null" {
			req.ClearRating = true
		} else {
			var v float64
			if err := json.Unmarshal(p.Rating, &v); err != nil {
				return req, errors.Join(domain.ErrBadRequest, err)
			}
			req.Rating = &v
		}
	}
	if len(p.Review) > 0 {
		if string(p.Review) == "null" {
			req.ClearReview = true
		} else {
			var v string
			if err := json.Unmarshal(p.Review, &v); err != nil {
				return req, errors.Join(domain.ErrBadRequest, err)
			}
			req.Review = &v
		}
	}
	if len(p.Price) > 0 {
		if string(p.Price) == "null" {
			req.ClearPrice = true
		} else {
			var v domain.Price
			if err := json.Unmarshal(p.Price, &v); err != nil {
				return req, errors.Join(domain.ErrBadRequest, err)
			}
			req.Price = &v
		}
	}
	return req, nil
}

// DeleteCheckin — DELETE /v1/check-ins/{id}.
//
// Stage 3: the (fetch beverage_id → soft-delete → invalidate cache) dance
// is now owned by CheckinService.Delete.
//
// Status: scaffold-for-Phase5 (admin moderation).
func (h *Handler) DeleteCheckin(w http.ResponseWriter, r *http.Request) {
	uid, ok := h.authedID(w, r)
	if !ok {
		return
	}
	id := chi.URLParam(r, "id")
	if h.Services != nil && h.Services.Checkin != nil {
		if err := h.Services.Checkin.Delete(r.Context(), uid, id); err != nil {
			h.writeErr(w, "DeleteCheckin", err)
			return
		}
		w.WriteHeader(http.StatusNoContent)
		return
	}
	// Legacy fallback (tests that don't construct services).
	var bevID string
	if cached, err := h.Repos.Checkins.Get(r.Context(), id, uid); err == nil {
		bevID = cached.Beverage.ID
	}
	if err := h.Repos.Checkins.SoftDelete(r.Context(), id, uid); err != nil {
		h.writeErr(w, "DeleteCheckin", err)
		return
	}
	h.invalidateBeverageDetail(r.Context(), bevID)
	w.WriteHeader(http.StatusNoContent)
}

// The MVP scaffold accepted `{ url }` (any URL the client claimed
// to have stored somewhere). That contract is replaced by a 3-step flow:
//
// 1. POST /v1/uploads/photo-presign → server returns a presigned PUT URL.
// 2. Client PUTs the bytes to R2 with the supplied Content-Type header.
// 3. POST /v1/check-ins/{id}/photos with `{ "upload_id": <uuid> }`. The
// server promotes the photo_uploads row to 'attached', looks up the
// public URL for the blob_key, and inserts into check_in_photos.
//
// We do NOT verify the client's PUT against R2 historically — the orphan
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
		httperr.WriteError(w, http.StatusUnprocessableEntity, "VALIDATION", "upload_id is required")
		return
	}

	upload, err := h.Repos.PhotoUploads.FindByID(r.Context(), req.UploadID)
	if err != nil {
		h.writeErr(w, "UploadCheckinPhoto find upload", err)
		return
	}
	// Ownership match — never let a user attach someone else's blob.
	if upload.UserID != uid {
		httperr.WriteError(w, http.StatusNotFound, "NOT_FOUND", "upload not found")
		return
	}
	// Already-attached / orphaned rows can't be reused.
	if upload.Status == "attached" || upload.Status == "orphaned" {
		httperr.WriteError(w, http.StatusConflict, "UPLOAD_NOT_COMPLETED",
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
	httperr.WriteJSON(w, http.StatusCreated, photo)
}

// ToggleToast — POST /v1/check-ins/{id}/toast.
// Idempotent: toggles the row, returns the fresh count + you_toasted.
func (h *Handler) ToggleToast(w http.ResponseWriter, r *http.Request) {
	uid, ok := h.authedID(w, r)
	if !ok {
		return
	}
	id := chi.URLParam(r, "id")
	var (
		state domain.ToastState
		err   error
	)
	if h.Services != nil && h.Services.Checkin != nil {
		state, err = h.Services.Checkin.ToggleToast(r.Context(), uid, id)
	} else {
		state, err = h.Repos.Checkins.ToggleToast(r.Context(), uid, id)
	}
	if err != nil {
		h.writeErr(w, "ToggleToast", err)
		return
	}
	httperr.WriteJSON(w, http.StatusOK, state)
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
