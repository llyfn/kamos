// Package handlers — auth shared helpers.
//
// Stage 3 split: the actual HTTP handlers for the auth endpoints now live
// in auth_credentials.go (Register/Login/GoogleLogin), auth_tokens.go
// (RefreshToken/Logout), and auth_account.go (VerifyEmail/Resend/
// PasswordChange/EmailChange). This file keeps the receiver helpers that
// every group reaches for: sendVerificationEmail, refreshTTL, issueAuthPair.
package handlers

import (
	"net/http"
	"time"

	"github.com/kamos/api/internal/auth"
	"github.com/kamos/api/internal/domain"
	"github.com/kamos/api/internal/email"
	"github.com/kamos/api/internal/middleware"
)

// sendVerificationEmail renders the locale-appropriate template and ships
// it via the configured mailer. Errors are logged at WARN; we never fail the
// triggering request — verification mail is best-effort.
func (h *Handler) sendVerificationEmail(r *http.Request, user *domain.User, token string) {
	link := h.Cfg.AppBaseURL + "/verify?token=" + token
	data := email.TemplateData{
		DisplayName:  user.DisplayName,
		VerifyLink:   link,
		AppName:      "KAMOS",
		SupportEmail: "support@kamos.app",
	}
	locale := user.Locale
	subject, htmlBody, textBody, err := email.Render("verify_email", locale, data)
	if err != nil {
		h.Log.Warn("verification_email_render", "err", err, "user_id", user.ID)
		return
	}
	// SEC-011: only log the raw link in non-production. The LogMailer dev
	// path already prints the link on Send(); the redundant log here used
	// to fire unconditionally and put live verification URLs into the
	// production access log.
	if h.Cfg != nil && h.Cfg.Env != "production" {
		h.Log.Info("verification link", "user_id", user.ID, "link", link)
	}
	if err := h.Mailer.Send(r.Context(), user.Email, subject, htmlBody, textBody); err != nil {
		h.Log.Warn("verification_email_send", "err", err, "user_id", user.ID)
	}
}

// refreshTTL returns the configured refresh TTL, or the package default.
func (h *Handler) refreshTTL() time.Duration {
	if h.Cfg != nil && h.Cfg.RefreshTTL > 0 {
		return h.Cfg.RefreshTTL
	}
	return auth.DefaultRefreshTTL
}

// issueAuthPair generates a fresh access JWT and a new originating refresh
// token (parent_id = nil, family_id = self) for the given user. Used by
// register / login / google login.
func (h *Handler) issueAuthPair(r *http.Request, user *domain.User) (string, string, error) {
	access, err := h.Signer.Sign(user.ID, user.Username)
	if err != nil {
		return "", "", err
	}
	raw, hash, err := auth.NewRefreshSecret()
	if err != nil {
		return "", "", err
	}
	if _, err := h.Repos.RefreshTokens.Insert(
		r.Context(), user.ID, hash, nil, "", h.refreshTTL(),
	); err != nil {
		return "", "", err
	}
	return access, raw, nil
}

// Compile-time ref to keep middleware import alive across files.
var _ = middleware.UserFromContext
