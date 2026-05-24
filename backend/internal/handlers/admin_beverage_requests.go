// admin_beverage_requests.go — admin queue for user-submitted
// beverage feedback. Split out of admin.go in Stage 3.
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

// AdminListBeverageRequests — GET /v1/admin/beverage-requests
//
// Query params:
// - status: pending|approved|rejected (optional; default: all)
// - cursor: opaque cursor token
// - limit: 1..50, default 20
func (h *Handler) AdminListBeverageRequests(w http.ResponseWriter, r *http.Request) {
	limit := parseLimit(r, 20, 50)
	c, err := parseCursor(r)
	if err != nil {
		h.writeErr(w, "AdminListBeverageRequests cursor", err)
		return
	}
	statusFilter := r.URL.Query().Get("status")
	switch statusFilter {
	case "", "pending", "approved", "rejected":
	default:
		httperr.WriteError(w, http.StatusUnprocessableEntity, "VALIDATION",
			"status must be one of: pending, approved, rejected")
		return
	}
	items, err := h.Repos.Admin.ListBeverageRequests(r.Context(), repository.ListBeverageRequestsParams{
		StatusFilter: statusFilter,
		CursorTs:     optTimestamp(c),
		CursorID:     optString(c.ID),
		Limit:        limit,
	})
	if err != nil {
		h.writeErr(w, "AdminListBeverageRequests", err)
		return
	}
	page, next, hasMore := cursor.SliceAndCursor(items, limit, func(b repository.BeverageRequestRow) cursor.Cursor {
		return cursor.Cursor{CreatedAt: b.CreatedAt, ID: b.ID}
	})
	httperr.WriteJSON(w, http.StatusOK, cursor.Page[repository.BeverageRequestRow]{
		Items: page, NextCursor: next, HasMore: hasMore,
	})
}

// AdminApproveBeverageRequest — POST /v1/admin/beverage-requests/{id}/approve
func (h *Handler) AdminApproveBeverageRequest(w http.ResponseWriter, r *http.Request) {
	uid, ok := h.authedID(w, r)
	if !ok {
		return
	}
	requestID := chi.URLParam(r, "id")
	if requestID == "" {
		httperr.WriteError(w, http.StatusBadRequest, "BAD_REQUEST", "missing request id")
		return
	}
	var body AdminApproveBeverageRequest
	if err := decodeJSON(r, &body); err != nil {
		h.writeErr(w, "AdminApproveBeverageRequest decode", err)
		return
	}
	if err := body.Validate(); err != nil {
		h.writeErr(w, "AdminApproveBeverageRequest validate", err)
		return
	}
	bevID, err := h.Repos.Admin.ApproveBeverageRequest(r.Context(), repository.ApproveBeverageRequestParams{
		RequestID:     requestID,
		BreweryID:     body.BreweryID,
		CategoryID:    body.CategoryID,
		NameI18n:      body.NameI18n,
		Subcategory:   body.Subcategory,
		ABV:           body.ABV,
		LabelImageURL: body.LabelImageURL,
		FlavorProfile: body.FlavorProfile,
		ReviewerID:    uid,
		Notes:         body.Notes,
	})
	if err != nil {
		h.writeErr(w, "AdminApproveBeverageRequest", err)
		return
	}
	// a new beverage just landed under this brewery. The brewery's
	// detail response shape doesn't actually change (the LRU caches the
	// brewery row only, not the inline beverages page), so this is
	// belt-and-braces: if the response ever embeds beverage_count or a
	// preview, the cache stays consistent. Stage 4: also fire NOTIFY so
	// peer replicas bust their copies.
	if body.BreweryID != "" {
		if h.Caches != nil {
			h.Caches.BreweryDetail.InvalidatePrefix(body.BreweryID + ":")
		}
		// WithoutCancel: keep the request trace context but don't let a client
		// disconnect skip the peer-replica invalidation. See invalidateBeverageDetail.
		cache.NotifyInvalidation(context.WithoutCancel(r.Context()), h.DB, h.Log, "brewery:"+body.BreweryID)
	}
	httperr.WriteJSON(w, http.StatusOK, map[string]string{
		"request_id":  requestID,
		"beverage_id": bevID,
	})
}

// AdminRejectBeverageRequest — POST /v1/admin/beverage-requests/{id}/reject
func (h *Handler) AdminRejectBeverageRequest(w http.ResponseWriter, r *http.Request) {
	uid, ok := h.authedID(w, r)
	if !ok {
		return
	}
	requestID := chi.URLParam(r, "id")
	if requestID == "" {
		httperr.WriteError(w, http.StatusBadRequest, "BAD_REQUEST", "missing request id")
		return
	}
	var body AdminRejectRequest
	if err := decodeJSON(r, &body); err != nil {
		h.writeErr(w, "AdminRejectBeverageRequest decode", err)
		return
	}
	if err := body.Validate(); err != nil {
		h.writeErr(w, "AdminRejectBeverageRequest validate", err)
		return
	}
	if err := h.Repos.Admin.RejectBeverageRequest(r.Context(), requestID, uid, body.Notes); err != nil {
		h.writeErr(w, "AdminRejectBeverageRequest", err)
		return
	}
	httperr.WriteJSON(w, http.StatusOK, map[string]string{
		"request_id": requestID,
		"status":     "rejected",
		"notes":      body.Notes,
	})
}
