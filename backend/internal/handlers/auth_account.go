package handlers

import (
	"net/http"

	"github.com/kamos/api/internal/auth"
	"github.com/kamos/api/internal/domain"
	"github.com/kamos/api/internal/httperr"
)

// VerifyEmail consumes a verification token.
func (h *Handler) VerifyEmail(w http.ResponseWriter, r *http.Request) {
	var req domain.VerifyEmailRequest
	if err := decodeJSON(r, &req); err != nil {
		h.writeErr(w, "VerifyEmail decode", err)
		return
	}
	if err := req.Validate(); err != nil {
		h.writeErr(w, "VerifyEmail validate", err)
		return
	}
	userID, err := h.Repos.Users.FindUserByVerificationToken(r.Context(), req.Token)
	if err != nil {
		h.writeErr(w, "VerifyEmail find", err)
		return
	}
	if err := h.Repos.Users.MarkEmailVerified(r.Context(), userID, req.Token); err != nil {
		h.writeErr(w, "VerifyEmail mark", err)
		return
	}
	httperr.WriteJSON(w, http.StatusOK, map[string]bool{"verified": true})
}

// ResendVerification issues a fresh 24h token (authed).
func (h *Handler) ResendVerification(w http.ResponseWriter, r *http.Request) {
	uid, ok := h.authedID(w, r)
	if !ok {
		return
	}
	token, _ := randomToken(32)
	if err := h.Repos.Users.CreateVerificationToken(r.Context(), uid, token); err != nil {
		h.writeErr(w, "ResendVerification", err)
		return
	}
	user, err := h.Repos.Users.FindByID(r.Context(), uid)
	if err != nil {
		// Best-effort: we already inserted the token, do not 500 the client.
		h.Log.Warn("ResendVerification: lookup user", "err", err, "user_id", uid)
	} else {
		h.sendVerificationEmail(r, user, token)
	}
	httperr.WriteJSON(w, http.StatusAccepted, map[string]bool{"sent": true})
}

// PasswordChange implements POST /v1/auth/password-change.
func (h *Handler) PasswordChange(w http.ResponseWriter, r *http.Request) {
	uid, ok := h.authedID(w, r)
	if !ok {
		return
	}
	var req domain.PasswordChangeRequest
	if err := decodeJSON(r, &req); err != nil {
		h.writeErr(w, "PasswordChange decode", err)
		return
	}
	if err := req.Validate(); err != nil {
		h.writeErr(w, "PasswordChange validate", err)
		return
	}
	currentHash, err := h.Repos.Users.LoadPasswordHash(r.Context(), uid)
	if err != nil {
		h.writeErr(w, "PasswordChange load", err)
		return
	}
	if err := auth.VerifyPassword(currentHash, req.CurrentPassword); err != nil {
		httperr.WriteError(w, http.StatusUnauthorized, "INVALID_CREDENTIAL", "current password is incorrect")
		return
	}
	newHash, err := auth.HashPassword(req.NewPassword)
	if err != nil {
		h.writeErr(w, "PasswordChange hash", err)
		return
	}
	if err := h.Repos.Users.UpdatePasswordHash(r.Context(), uid, newHash); err != nil {
		h.writeErr(w, "PasswordChange update", err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// EmailChange implements POST /v1/auth/email-change. Triggers re-verification.
func (h *Handler) EmailChange(w http.ResponseWriter, r *http.Request) {
	uid, ok := h.authedID(w, r)
	if !ok {
		return
	}
	var req domain.EmailChangeRequest
	if err := decodeJSON(r, &req); err != nil {
		h.writeErr(w, "EmailChange decode", err)
		return
	}
	if err := req.Validate(); err != nil {
		h.writeErr(w, "EmailChange validate", err)
		return
	}
	taken, err := h.Repos.Users.EmailExists(r.Context(), req.NewEmail)
	if err != nil {
		h.writeErr(w, "EmailChange exists", err)
		return
	}
	if taken {
		httperr.WriteError(w, http.StatusConflict, "EMAIL_TAKEN", "email is already registered")
		return
	}
	if err := h.Repos.Users.UpdateEmail(r.Context(), uid, req.NewEmail); err != nil {
		h.writeErr(w, "EmailChange update", err)
		return
	}
	token, _ := randomToken(32)
	if err := h.Repos.Users.CreateVerificationToken(r.Context(), uid, token); err != nil {
		h.Log.Error("EmailChange token", "err", err)
	}
	// UpdateEmail above already pointed the user row at NewEmail; reload to
	// pick that up so the mailer dispatches to the new address.
	user, err := h.Repos.Users.FindByID(r.Context(), uid)
	if err != nil {
		h.Log.Warn("EmailChange: lookup user", "err", err, "user_id", uid)
	} else {
		h.sendVerificationEmail(r, user, token)
	}
	httperr.WriteJSON(w, http.StatusAccepted, map[string]bool{"re_verification_sent": true})
}
