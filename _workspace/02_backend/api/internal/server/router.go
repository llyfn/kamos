// Package server wires the chi router with middleware and handlers.
package server

import (
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/kamos/api/internal/auth"
	"github.com/kamos/api/internal/domain"
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
//
// softDelete may be nil — in that case the auth middleware skips the SEC-006
// revocation check. main.go always passes a real cache; tests pass nil when
// they don't care about revocation semantics.
//
// roleResolver is derived from the handler's Repos.DB when non-nil. Passing
// it explicitly keeps server.New testable with stub repos (a nil resolver
// fails closed on every admin route).
func New(log *slog.Logger, signer *auth.Signer, softDelete *auth.SoftDeleteCache, h *handlers.Handler) http.Handler {
	var roleResolver *middleware.RoleResolver
	if h != nil && h.Repos != nil && h.Repos.DB != nil {
		roleResolver = middleware.NewRoleResolver(h.Repos.DB)
	}
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
			r.With(middleware.Auth(signer, softDelete)).Post("/resend-verification", h.ResendVerification)
			r.With(middleware.Auth(signer, softDelete)).Post("/password-change", h.PasswordChange)
			r.With(middleware.Auth(signer, softDelete)).Post("/email-change", h.EmailChange)
			r.With(middleware.Auth(signer, softDelete)).Post("/logout", h.Logout)
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
			r.Use(middleware.OptionalAuth(signer, softDelete))
			r.Get("/users/{username}", h.GetUser)
			r.Get("/users/{username}/check-ins", h.GetUserCheckins)
			r.Get("/users/{username}/followers", h.GetUserFollowers)
			r.Get("/users/{username}/following", h.GetUserFollowing)
			r.Get("/check-ins/{id}", h.GetCheckin)

			// Phase 6a — public collections discovery feed. OptionalAuth
			// because the response shape is identical for anon and authed
			// viewers; we add the middleware so a future "personalized
			// discovery" overlay can plug in without re-routing.
			r.Get("/collections/public", h.ListPublicCollections)

			// Phase 6a — comment list is also a public-read surface.
			// OptionalAuth for forward compatibility (we may add a
			// "you_replied" or similar viewer-relative field).
			r.Get("/check-ins/{id}/comments", h.ListComments)

			// Phase 6a — collection detail is OptionalAuth so the
			// discovery feed → detail-screen route works for non-owners
			// of public collections (and for anonymous link visitors).
			// Handler enforces the visibility gate: owner sees their
			// own row, anyone sees a public row, anything else is 404.
			r.Get("/collections/{id}", h.GetCollection)
		})

		// Authed surface. Per-user limit on top of the global IP limit
		// (60 rps, burst 120 — comfortable for power users).
		r.Group(func(r chi.Router) {
			r.Use(middleware.Auth(signer, softDelete))
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

			// Uploads — Phase 3 presigned PUT flow.
			r.Post("/uploads/photo-presign", h.PhotoPresign)

			// Venues — Phase 4 Foursquare-backed search proxy. 503
			// VENUE_SEARCH_DISABLED when FOURSQUARE_API_KEY is unset.
			//
			// SEC-004: a tight per-user limit on top of the global authed
			// 60/120 limiter. 5 rps / burst 10 keeps a single account from
			// exhausting the paid Foursquare budget with varying ?q= values.
			if rateLimited {
				r.With(middleware.RateLimitByUser(log, 5, 10)).Get("/venues/search", h.VenueSearch)
			} else {
				r.Get("/venues/search", h.VenueSearch)
			}

			// Social.
			r.Post("/users/{username}/follow", h.Follow)
			r.Delete("/users/{username}/follow", h.Unfollow)
			r.Get("/follow-requests", h.FollowRequests)
			r.Post("/follow-requests/{id}/approve", h.ApproveFollowRequest)
			r.Post("/follow-requests/{id}/decline", h.DeclineFollowRequest)

			// Collections.
			r.Get("/collections", h.ListCollections)
			r.Post("/collections", h.CreateCollection)
			// GET /v1/collections/{id} is mounted under OptionalAuth
			// above so anonymous viewers can read public collections.
			r.Patch("/collections/{id}", h.UpdateCollection)
			r.Delete("/collections/{id}", h.DeleteCollection)
			r.Post("/collections/{id}/entries", h.AddCollectionEntry)
			r.Patch("/collections/{id}/entries/{beverage_id}", h.UpdateCollectionEntry)
			r.Delete("/collections/{id}/entries/{beverage_id}", h.RemoveCollectionEntry)

			// Beverage feedback.
			r.Post("/beverage-requests", h.SubmitBeverageRequest)

			// Phase 6a — comments. POST is heavily spammable, so we
			// stack a tight per-user limit on top of the global authed
			// 60/120: 3 rps / burst 6 caps comment-spam attempts without
			// throttling legit conversation.
			if rateLimited {
				r.With(middleware.RateLimitByUser(log, 3, 6)).
					Post("/check-ins/{id}/comments", h.CreateComment)
			} else {
				r.Post("/check-ins/{id}/comments", h.CreateComment)
			}
			r.Delete("/comments/{id}", h.DeleteComment)
		})

		// Phase 5a — admin surface. Authed + role-gated per-route. Generous
		// per-user rate limit (30/60) — admin tooling fires bursts of
		// reads during triage but doesn't need the 60/120 of the regular
		// authed surface.
		r.Route("/admin", func(r chi.Router) {
			r.Use(middleware.Auth(signer, softDelete))
			if rateLimited {
				r.Use(middleware.RateLimitByUser(log, 30, 60))
			}

			// Moderator-or-admin endpoints — triage, listing, soft-delete of
			// individual rows.
			modOrAdmin := roleResolver.RequireRole(domain.RoleModerator, domain.RoleAdmin)
			r.With(modOrAdmin).Get("/beverage-requests", h.AdminListBeverageRequests)
			r.With(modOrAdmin).Post("/beverage-requests/{id}/reject", h.AdminRejectBeverageRequest)
			r.With(modOrAdmin).Post("/check-ins/{id}/moderate", h.AdminModerateCheckin)
			r.With(modOrAdmin).Get("/users", h.AdminListUsers)

			// Phase 6a — comment moderation surface. Both endpoints
			// (review list + per-row soft-delete) are moderator-or-admin.
			r.With(modOrAdmin).Get("/comments", h.AdminListComments)
			r.With(modOrAdmin).Post("/comments/{id}/moderate", h.AdminModerateComment)

			// Admin-only endpoints — destructive or privilege-altering.
			adminOnly := roleResolver.RequireRole(domain.RoleAdmin)
			r.With(adminOnly).Post("/beverage-requests/{id}/approve", h.AdminApproveBeverageRequest)
			r.With(adminOnly).Post("/users/{id}/suspend", h.AdminSuspendUser)
			r.With(adminOnly).Post("/users/{id}/role", h.AdminUpdateUserRole)
		})
	})

	return r
}
