// admin_checkins.go — admin check-in moderation. Split out of
// admin.go in Stage 3.
package handlers

import (
	"net/http"

	"github.com/go-chi/chi/v5"

	"github.com/kamos/api/internal/httperr"
)

// AdminModerateCheckin — POST /v1/admin/check-ins/{id}/moderate
//
// Soft-deletes the check-in. The optional `notes` body field is not yet
// persisted (no audit table historically) — it's logged for now.
//
// mirrors the owner-side DeleteCheckin shape — we
// fetch the beverage_id BEFORE the moderate call so we can bust the
// BeverageDetail cache after the trigger has recomputed avg_rating +
// check_in_count. Without this, a moderator action could be invisible
// from the public beverage page for up to the 5-minute TTL ceiling.
func (h *Handler) AdminModerateCheckin(w http.ResponseWriter, r *http.Request) {
	uid, ok := h.authedID(w, r)
	if !ok {
		return
	}
	checkinID := chi.URLParam(r, "id")
	if checkinID == "" {
		httperr.WriteError(w, http.StatusBadRequest, "BAD_REQUEST", "missing check-in id")
		return
	}
	// Body is optional; we accept and log it but don't fail on parse error.
	var body struct {
		Notes string `json:"notes,omitempty"`
	}
	_ = decodeJSON(r, &body) // tolerate empty / missing
	var notesPtr *string
	if body.Notes != "" {
		notesPtr = &body.Notes
	}
	// Fetch the beverage_id before the soft-delete so we can bust the cache
	// after. If the Get fails (e.g., already-deleted), bevID stays empty and
	// the invalidate call below is a no-op — the cache TTL still bounds
	// staleness at 5m in that edge case.
	var bevID string
	if cached, err := h.Repos.Checkins.Get(r.Context(), checkinID, uid); err == nil {
		bevID = cached.Beverage.ID
	}
	if err := h.Repos.Admin.ModerateCheckin(r.Context(), checkinID, uid, notesPtr); err != nil {
		h.writeErr(w, "AdminModerateCheckin", err)
		return
	}
	h.invalidateBeverageDetail(r.Context(), bevID)
	h.Log.Info("admin moderation",
		"action", "checkin_delete",
		"check_in_id", checkinID,
		"moderator_id", uid,
		"notes", body.Notes,
	)
	w.WriteHeader(http.StatusNoContent)
}
