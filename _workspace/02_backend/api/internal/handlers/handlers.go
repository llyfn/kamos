// Package handlers houses HTTP handlers, one file per domain. The shared
// Handler struct wires repositories, auth, logger and config.
package handlers

import (
	"context"
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
	"errors"
	"log/slog"
	"net/http"
	"strconv"
	"strings"

	"github.com/kamos/api/internal/apierror"
	"github.com/kamos/api/internal/auth"
	"github.com/kamos/api/internal/config"
	"github.com/kamos/api/internal/cursor"
	"github.com/kamos/api/internal/email"
	"github.com/kamos/api/internal/foursquare"
	"github.com/kamos/api/internal/middleware"
	"github.com/kamos/api/internal/repository"
	"github.com/kamos/api/internal/storage"
)

// Handler is the bundle every route handler shares.
type Handler struct {
	Cfg        *config.Config
	Log        *slog.Logger
	Repos      *repository.Repos
	Signer     *auth.Signer
	Google     *auth.GoogleVerifier
	Storage    storage.Storage
	Mailer     email.Mailer
	Foursquare *foursquare.Client
}

// New creates the bundle. Storage/Mailer/Foursquare default to disabled
// no-op implementations when nil is passed so test helpers don't need to
// wire them. Foursquare's Disabled mode is selected by passing an empty
// API key — see foursquare.New.
func New(cfg *config.Config, log *slog.Logger, repos *repository.Repos, signer *auth.Signer, google *auth.GoogleVerifier) *Handler {
	return &Handler{
		Cfg:        cfg,
		Log:        log,
		Repos:      repos,
		Signer:     signer,
		Google:     google,
		Storage:    storage.Disabled{},
		Mailer:     email.LogMailer{Log: log},
		Foursquare: foursquare.New(""),
	}
}

// WithStorage wires a real blob backend.
func (h *Handler) WithStorage(s storage.Storage) *Handler { h.Storage = s; return h }

// WithMailer wires a real mail backend.
func (h *Handler) WithMailer(m email.Mailer) *Handler { h.Mailer = m; return h }

// WithFoursquare wires a Foursquare client. A nil argument is ignored; passing
// an explicitly-Disabled client (empty API key) is valid and keeps the search
// endpoint behind the 503 VENUE_SEARCH_DISABLED gate.
func (h *Handler) WithFoursquare(c *foursquare.Client) *Handler {
	if c != nil {
		h.Foursquare = c
	}
	return h
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

func decodeJSON(r *http.Request, v any) error {
	dec := json.NewDecoder(r.Body)
	dec.DisallowUnknownFields()
	if err := dec.Decode(v); err != nil {
		return errors.Join(apierror.ErrBadRequest, err)
	}
	return nil
}

// writeErr maps an error to an HTTP response using the canonical body shape
// and the handler's logger for any internal-error stack.
func (h *Handler) writeErr(w http.ResponseWriter, op string, err error) {
	if errors.Is(err, apierror.ErrValidation) {
		// Extract message after the sentinel prefix.
		msg := err.Error()
		if i := strings.Index(msg, ": "); i >= 0 {
			msg = msg[i+2:]
		}
		apierror.WriteError(w, http.StatusUnprocessableEntity, "VALIDATION", msg)
		return
	}
	apierror.WriteFrom(w, h.Log, op, err)
}

// parseLimit reads ?limit=N within [1, max]; default `def`.
func parseLimit(r *http.Request, def, max int) int {
	if v := r.URL.Query().Get("limit"); v != "" {
		if n, err := strconv.Atoi(v); err == nil && n > 0 {
			if n > max {
				return max
			}
			return n
		}
	}
	return def
}

// parseCursor decodes the ?cursor= parameter; an empty cursor is valid.
func parseCursor(r *http.Request) (cursor.Cursor, error) {
	return cursor.Decode(r.URL.Query().Get("cursor"))
}

// randomToken produces a URL-safe random string for email verification etc.
func randomToken(n int) (string, error) {
	b := make([]byte, n)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	return base64.RawURLEncoding.EncodeToString(b), nil
}

// ctxBg shortens context for handlers that need a detached ctx (rare).
var _ = context.Background

// authedID returns the authed user's ID or writes 401. The bool indicates
// "ok to proceed".
func (h *Handler) authedID(w http.ResponseWriter, r *http.Request) (string, bool) {
	u := middleware.UserFromContext(r.Context())
	if u == nil {
		apierror.WriteError(w, http.StatusUnauthorized, "UNAUTHORIZED", "unauthorized")
		return "", false
	}
	return u.ID, true
}
