package handlers

import (
	"encoding/json"
	"net/http"

	"github.com/kamos/api/internal/apierror"
	"github.com/kamos/api/internal/domain"
)

// Categories — GET /v1/categories.
//
// Status: scaffold-for-Phase5 (admin needs server-validated taxonomy to
// populate dropdowns). Endpoint is intentionally pre-wired; Flutter uses
// the local `kCategoryStrings` constant in MVP.
func (h *Handler) Categories(w http.ResponseWriter, r *http.Request) {
	rows, err := h.Repos.Taxonomy.Categories(r.Context())
	if err != nil {
		h.writeErr(w, "Categories", err)
		return
	}
	apierror.WriteJSON(w, http.StatusOK, rows)
}

// FlavorTags — GET /v1/flavor-tags.
func (h *Handler) FlavorTags(w http.ResponseWriter, r *http.Request) {
	rows, err := h.Repos.Taxonomy.FlavorTags(r.Context())
	if err != nil {
		h.writeErr(w, "FlavorTags", err)
		return
	}
	apierror.WriteJSON(w, http.StatusOK, rows)
}

// SubmitBeverageRequest — POST /v1/beverage-requests.
//
// Status: scaffold-for-Phase5 (user-submitted beverages will wire the
// user-side form on top of this endpoint). Endpoint is intentionally
// pre-wired; no Flutter caller in MVP.
func (h *Handler) SubmitBeverageRequest(w http.ResponseWriter, r *http.Request) {
	uid, ok := h.authedID(w, r)
	if !ok {
		return
	}
	var req domain.BeverageRequest
	if err := decodeJSON(r, &req); err != nil {
		h.writeErr(w, "SubmitBeverageRequest decode", err)
		return
	}
	if err := req.Validate(); err != nil {
		h.writeErr(w, "SubmitBeverageRequest validate", err)
		return
	}
	payload, _ := json.Marshal(req.Payload)
	id, err := h.Repos.Beverages.SubmitAdditionRequest(r.Context(), &uid, payload)
	if err != nil {
		h.writeErr(w, "SubmitBeverageRequest", err)
		return
	}
	apierror.WriteJSON(w, http.StatusAccepted, map[string]string{"id": id})
}
