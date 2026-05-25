package handlers

import (
	"context"
	"errors"
	"net/http"

	"github.com/kamos/api/internal/domain"
	"github.com/kamos/api/internal/email"
)

// verifyEmailPageUsers is the user-repo slice the GET /verify landing
// handler depends on. Declared here so handler-level tests can substitute
// a fake without bringing up a real pgx pool.
type verifyEmailPageUsers interface {
	FindUserByVerificationToken(ctx context.Context, token string) (string, error)
	FindByID(ctx context.Context, id string) (*domain.User, error)
	MarkEmailVerified(ctx context.Context, userID, token string) error
}

// VerifyEmailPage renders the post-click HTML landing page for the email
// verification flow. The route is mounted at top-level GET /verify (public,
// no JWT). It accepts:
//
//	?token=<raw>   — the verification token; missing/unknown → Invalid (400)
//	?lang=<en|ja|ko> — optional UI locale; default en
//
// SPEC §6.5 i18n fallback applies: unsupported locales render in English.
func (h *Handler) VerifyEmailPage(w http.ResponseWriter, r *http.Request) {
	h.verifyEmailPage(w, r, h.Repos.Users)
}

// verifyEmailPage is the testable seam — VerifyEmailPage delegates here so
// internal tests can inject a fake users repo.
func (h *Handler) verifyEmailPage(w http.ResponseWriter, r *http.Request, users verifyEmailPageUsers) {
	locale := pickLandingLocale(r.URL.Query().Get("lang"))
	token := r.URL.Query().Get("token")
	if token == "" {
		h.renderLanding(w, locale, "Invalid", http.StatusBadRequest)
		return
	}

	userID, err := users.FindUserByVerificationToken(r.Context(), token)
	if err != nil {
		// ErrTokenExpired (no live row) and ErrNotFound both render as
		// the generic Invalid screen — same UX, no need to leak which.
		if !errors.Is(err, domain.ErrTokenExpired) && !errors.Is(err, domain.ErrNotFound) {
			h.Log.Warn("VerifyEmailPage: find token", "err", err)
		}
		h.renderLanding(w, locale, "Invalid", http.StatusBadRequest)
		return
	}

	// Already-verified short-circuit: a user can hold a fresh token row
	// (24h TTL) while users.email_verified is already TRUE from an earlier
	// click on a different token. We DO NOT call MarkEmailVerified here so
	// the unused token row stays consumable by the actual owner if they
	// follow a fresh link later in the same window.
	user, err := users.FindByID(r.Context(), userID)
	if err != nil {
		h.Log.Warn("VerifyEmailPage: find user", "err", err, "user_id", userID)
		h.renderLanding(w, locale, "Invalid", http.StatusBadRequest)
		return
	}
	if user.EmailVerified {
		h.renderLanding(w, locale, "AlreadyVerified", http.StatusOK)
		return
	}

	if err := users.MarkEmailVerified(r.Context(), userID, token); err != nil {
		h.Log.Warn("VerifyEmailPage: mark verified", "err", err, "user_id", userID)
		h.renderLanding(w, locale, "Invalid", http.StatusBadRequest)
		return
	}
	h.renderLanding(w, locale, "Verified", http.StatusOK)
}

// renderLanding writes the locale-appropriate landing page. Template-render
// failures degrade to a tiny plain-text fallback so a broken template never
// turns into a blank screen for the user.
func (h *Handler) renderLanding(w http.ResponseWriter, locale, status string, code int) {
	body, err := email.RenderLanding(locale, status)
	w.Header().Set("Cache-Control", "no-store")
	if err != nil {
		h.Log.Warn("VerifyEmailPage: render landing", "err", err, "locale", locale, "status", status)
		w.Header().Set("Content-Type", "text/plain; charset=utf-8")
		w.WriteHeader(code)
		_, _ = w.Write([]byte(status))
		return
	}
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.WriteHeader(code)
	// #nosec G705 — body is html/template output (contextually escaped); the
	// only template bindings are LandingData{Status, AppName}, both bounded
	// to a closed set of strings ("Verified"/"AlreadyVerified"/"Invalid"
	// and "KAMOS"). No user input flows in.
	_, _ = w.Write([]byte(body))
}

// pickLandingLocale normalizes the ?lang= query param to the supported set,
// defaulting to "en" for anything else. Mirrors the email.Render fallback
// rule so URL-driven locale and the email body locale stay aligned.
func pickLandingLocale(raw string) string {
	switch raw {
	case "en", "ja", "ko":
		return raw
	default:
		return "en"
	}
}
