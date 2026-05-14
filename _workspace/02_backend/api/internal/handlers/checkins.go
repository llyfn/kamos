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
	exists, err := h.Repos.Beverages.Exists(r.Context(), req.BeverageID)
	if err != nil {
		h.writeErr(w, "CreateCheckin exists", err)
		return
	}
	if !exists {
		apierror.WriteError(w, http.StatusNotFound, "NOT_FOUND", "beverage not found")
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
	// Business metric for the OTel meter. No-op when OTel is disabled.
	observability.IncCheckinsCreated(r.Context())
	apierror.WriteJSON(w, http.StatusCreated, out)
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
	if err := h.Repos.Checkins.SoftDelete(r.Context(), id, uid); err != nil {
		h.writeErr(w, "DeleteCheckin", err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// UploadCheckinPhoto — POST /v1/check-ins/{id}/photos.
//
// Photo upload strategy (decision): for MVP we accept a JSON body
//   { "url": "<https://...>" }
// and store the URL on the row. Multipart upload + S3 / Cloudinary is wired up
// later by either (a) adding an /uploads endpoint that returns a presigned URL
// and posting the resulting URL here, or (b) accepting multipart here once
// blob storage is configured. This choice keeps the API surface storage-
// agnostic for now. The 4-photo cap is enforced by the repository.
//
// CONFIGURE: see README_backend.md "Photo storage" before wiring real uploads.
type uploadPhotoRequest struct {
	URL string `json:"url"`
}

// UploadCheckinPhoto — POST /v1/check-ins/{id}/photos.
//
// Status: scaffold-for-Phase3 (real photo upload flow will wire on top of
// this endpoint). Endpoint is intentionally pre-wired; no Flutter caller in
// MVP.
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
	if req.URL == "" {
		apierror.WriteError(w, http.StatusUnprocessableEntity, "VALIDATION", "url is required")
		return
	}
	photo, err := h.Repos.Checkins.AddPhoto(r.Context(), id, uid, req.URL)
	if err != nil {
		h.writeErr(w, "UploadCheckinPhoto", err)
		return
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
