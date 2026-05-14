// Package server wires the chi router with middleware and handlers.
package server

import (
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/kamos/api/internal/auth"
	"github.com/kamos/api/internal/handlers"
	"github.com/kamos/api/internal/middleware"

	"log/slog"
)

// New constructs the HTTP handler tree.
//
// Middleware order:
//   - RequestID   — first so subsequent middleware can log it.
//   - Trace       — span starts before recover/log so panics show up in OTel.
//   - RecoverWithSentry — converts panics to 500s and forwards to Sentry.
//   - AccessLog   — logs the final status code.
//   - RateLimitByIP — global; rejects abusive callers before any business logic.
//
// Stricter per-group limits (auth brute-force / per-user fairness) layer
// inside their respective r.Route / r.Group blocks below.
func New(log *slog.Logger, signer *auth.Signer, h *handlers.Handler) http.Handler {
	r := chi.NewRouter()
	r.Use(middleware.RequestID)
	r.Use(middleware.Trace)
	r.Use(middleware.RecoverWithSentry(log))
	r.Use(middleware.AccessLog(log))
	// Global IP-based rate limit. 30 rps, burst 60 — well above any
	// legitimate single-client traffic, low enough to throttle scrapers.
	// RATE_LIMIT_DISABLED=1 bypasses the limit entirely (test runs,
	// localhost stress checks); the integration suite and the README
	// document this. Production must leave RATE_LIMIT_DISABLED unset.
	rateLimited := h.Cfg == nil || !h.Cfg.RateLimitDisabled
	if rateLimited {
		r.Use(middleware.RateLimitByIP(log, 30, 60))
	}

	// Health. Expose both /health (project convention) and /healthz (k8s
	// convention, also documented in DEPLOYMENT.md §6 and used by the
	// docker-compose healthcheck).
	healthHandler := func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(`{"status":"ok"}`))
	}
	r.Get("/health", healthHandler)
	r.Get("/healthz", healthHandler)

	r.Route("/v1", func(r chi.Router) {

		// Auth — all public. Stricter per-IP cap to mitigate
		// brute-force / enumeration against /v1/auth/* (5 rps, burst 10).
		r.Route("/auth", func(r chi.Router) {
			if rateLimited {
				r.Use(middleware.RateLimitByIP(log, 5, 10))
			}
			r.Post("/register", h.Register)
			r.Post("/login", h.Login)
			r.Post("/google", h.GoogleLogin)
			r.Post("/verify-email", h.VerifyEmail)
			// Phase 2 — rotating refresh tokens. Public: possession of the
			// raw secret IS the credential. Still covered by the auth-group
			// 5 rps / burst 10 limit above.
			r.Post("/refresh", h.RefreshToken)
			// Authed:
			r.With(middleware.Auth(signer)).Post("/resend-verification", h.ResendVerification)
			r.With(middleware.Auth(signer)).Post("/password-change", h.PasswordChange)
			r.With(middleware.Auth(signer)).Post("/email-change", h.EmailChange)
			r.With(middleware.Auth(signer)).Post("/logout", h.Logout)
		})

		// Taxonomy — public reads.
		r.Get("/categories", h.Categories)
		r.Get("/flavor-tags", h.FlavorTags)

		// Beverages / breweries — public reads.
		r.Get("/beverages", h.ListBeverages)
		r.Get("/beverages/{id}", h.GetBeverage)
		r.Get("/beverages/{id}/check-ins", h.GetBeverageCheckins)
		r.Get("/breweries", h.ListBreweries)
		r.Get("/breweries/{id}", h.GetBrewery)

		// Search — public.
		r.Get("/search", h.Search)

		// Users (public reads, with optional auth for follow state).
		r.Group(func(r chi.Router) {
			r.Use(middleware.OptionalAuth(signer))
			r.Get("/users/{username}", h.GetUser)
			r.Get("/users/{username}/check-ins", h.GetUserCheckins)
			r.Get("/users/{username}/followers", h.GetUserFollowers)
			r.Get("/users/{username}/following", h.GetUserFollowing)
			r.Get("/check-ins/{id}", h.GetCheckin)
		})

		// Authed surface. Per-user limit on top of the global IP limit
		// (60 rps, burst 120 — comfortable for power users).
		r.Group(func(r chi.Router) {
			r.Use(middleware.Auth(signer))
			if rateLimited {
				r.Use(middleware.RateLimitByUser(log, 60, 120))
			}

			r.Get("/users/me", h.GetMe)
			r.Patch("/users/me", h.UpdateMe)
			r.Delete("/users/me", h.DeleteMe)

			// Feed.
			r.Get("/feed", h.Feed)

			// Check-ins (write paths).
			r.Post("/check-ins", h.CreateCheckin)
			r.Patch("/check-ins/{id}", h.UpdateCheckin)
			r.Delete("/check-ins/{id}", h.DeleteCheckin)
			r.Post("/check-ins/{id}/photos", h.UploadCheckinPhoto)
			r.Post("/check-ins/{id}/toast", h.ToggleToast)

			// Social.
			r.Post("/users/{username}/follow", h.Follow)
			r.Delete("/users/{username}/follow", h.Unfollow)
			r.Get("/follow-requests", h.FollowRequests)
			r.Post("/follow-requests/{id}/approve", h.ApproveFollowRequest)
			r.Post("/follow-requests/{id}/decline", h.DeclineFollowRequest)

			// Collections.
			r.Get("/collections", h.ListCollections)
			r.Post("/collections", h.CreateCollection)
			r.Get("/collections/{id}", h.GetCollection)
			r.Patch("/collections/{id}", h.RenameCollection)
			r.Delete("/collections/{id}", h.DeleteCollection)
			r.Post("/collections/{id}/entries", h.AddCollectionEntry)
			r.Patch("/collections/{id}/entries/{beverage_id}", h.UpdateCollectionEntry)
			r.Delete("/collections/{id}/entries/{beverage_id}", h.RemoveCollectionEntry)

			// Beverage feedback.
			r.Post("/beverage-requests", h.SubmitBeverageRequest)
		})
	})

	return r
}
