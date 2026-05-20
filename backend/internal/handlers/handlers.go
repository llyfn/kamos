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

	"github.com/kamos/api/internal/auth"
	"github.com/kamos/api/internal/cache"
	"github.com/kamos/api/internal/config"
	"github.com/kamos/api/internal/cursor"
	"github.com/kamos/api/internal/domain"
	"github.com/kamos/api/internal/email"
	"github.com/kamos/api/internal/foursquare"
	"github.com/kamos/api/internal/httperr"
	"github.com/kamos/api/internal/middleware"
	"github.com/kamos/api/internal/repository"
	"github.com/kamos/api/internal/service"
	"github.com/kamos/api/internal/storage"
)

// Handler is the bundle every route handler shares.
//
// Stage 3 (architectural refactor): the orchestration logic for the write
// paths is being lifted into `internal/service.Bundle`. Handlers still hold
// the legacy direct-repo fields below (`Repos`, `Signer`, `Mailer`, etc.)
// for the read-path code that hasn't been service-ified yet, but every
// multi-write flow flows through `h.Services.<X>.<Method>(ctx, …)`.
//
// The plan is to retire the legacy direct-repo fields once every endpoint
// has been migrated; that's why `Services` is the only field added in
// Stage 3 — the old fields remain for binary compatibility with the test
// suite during the migration window.
type Handler struct {
	Cfg        *config.Config
	Log        *slog.Logger
	Repos      *repository.Repos
	Signer     *auth.Signer
	Google     *auth.GoogleVerifier
	Storage    storage.Storage
	Mailer     email.Mailer
	Foursquare *foursquare.Client
	// SoftDelete is the SEC-006 in-memory revocation cache. Nil-safe — the
	// DeleteMe handler skips Add() when nil, which is the test-helper path
	// (tests that don't bring up the cache also don't care about revocation
	// semantics). Production wiring lives in cmd/server/main.go.
	SoftDelete *auth.SoftDeleteCache
	// Caches is the Phase 7 in-process LRU bundle (taxonomy + beverage +
	// brewery hot rows). Nil-safe — handlers null-check before using; tests
	// that don't care about caching pass nil and the path falls through to
	// the DB on every call.
	Caches *cache.Caches
	// Services hosts the orchestration layer (Stage 3 refactor). Nil-safe:
	// handlers that pre-date the migration fall back to the legacy
	// direct-repo path when Services is nil.
	Services *service.Bundle
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

// WithSoftDeleteCache wires the SEC-006 revocation cache. Nil-safe; callers
// (tests) that don't care about revocation pass nil and DeleteMe simply
// skips the immediate-Add() call.
func (h *Handler) WithSoftDeleteCache(c *auth.SoftDeleteCache) *Handler {
	h.SoftDelete = c
	return h
}

// WithCaches wires the Phase 7 LRU bundle. Nil-safe; tests that don't
// care about caching can either omit this call (no bundle) or pass a
// fresh one for isolation.
func (h *Handler) WithCaches(c *cache.Caches) *Handler {
	h.Caches = c
	return h
}

// WithServices wires the orchestration bundle (Stage 3 refactor). Nil-safe
// at runtime; tests that haven't been migrated continue to work because the
// handlers fall back to the legacy direct-repo path when Services is nil.
func (h *Handler) WithServices(s *service.Bundle) *Handler {
	h.Services = s
	return h
}

// buildServices is the package-internal helper that constructs the service
// bundle from the handler's existing dependencies. main.go uses this so the
// wiring stays in one place; tests can opt-in by calling h.WithServices.
func (h *Handler) buildServices() *service.Bundle {
	return service.New(service.Deps{
		Cfg:        h.Cfg,
		Log:        h.Log,
		Repos:      h.Repos,
		Signer:     h.Signer,
		Mailer:     h.Mailer,
		Caches:     h.Caches,
		SoftDelete: h.SoftDelete,
	})
}

// EnsureServices wires Services when it is currently nil. Idempotent.
// Called by main.go after every other With* setter has been applied so
// the bundle picks up Mailer / Caches / SoftDelete.
func (h *Handler) EnsureServices() *Handler {
	if h.Services == nil {
		h.Services = h.buildServices()
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
		return errors.Join(domain.ErrBadRequest, err)
	}
	return nil
}

// writeErr maps an error to an HTTP response using the canonical body shape
// and the handler's logger for any internal-error stack.
func (h *Handler) writeErr(w http.ResponseWriter, op string, err error) {
	if errors.Is(err, domain.ErrValidation) {
		// Extract message after the sentinel prefix.
		msg := err.Error()
		if i := strings.Index(msg, ": "); i >= 0 {
			msg = msg[i+2:]
		}
		httperr.WriteError(w, http.StatusUnprocessableEntity, "VALIDATION", msg)
		return
	}
	httperr.WriteFrom(w, h.Log, op, err)
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
		httperr.WriteError(w, http.StatusUnauthorized, "UNAUTHORIZED", "unauthorized")
		return "", false
	}
	return u.ID, true
}

// localeKey extracts a short cache-key axis from the request's Accept-Language
// header. We only care about the first 2 chars of the primary tag — "en-US"
// and "en-GB" collapse to "en" — because KAMOS only ships en/ja/ko.
//
// Phase 7a MINOR-2 fix: unsupported locales (e.g. "zh") map to "en" so the
// cache-key axis stays bounded to {en, ja, ko, any} regardless of what
// misbehaving clients send. "any" is reserved for the empty-header case so
// callers that pre-resolved to EN still hit a distinct LRU slot.
func localeKey(r *http.Request) string {
	h := r.Header.Get("Accept-Language")
	if h == "" {
		return "any"
	}
	// Take everything before the first comma + drop region suffix.
	primary := h
	if i := strings.IndexAny(primary, ",;"); i >= 0 {
		primary = primary[:i]
	}
	primary = strings.TrimSpace(primary)
	if primary == "" {
		return "any"
	}
	if len(primary) >= 2 {
		primary = strings.ToLower(primary[:2])
	} else {
		primary = strings.ToLower(primary)
	}
	switch primary {
	case "en", "ja", "ko":
		return primary
	default:
		// Map unsupported locales to the EN fallback bucket — I18nText.Resolve
		// already returns EN for these, so collapsing the cache key avoids
		// redundant entries.
		return "en"
	}
}
