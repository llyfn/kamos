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
func New(log *slog.Logger, signer *auth.Signer, h *handlers.Handler) http.Handler {
	r := chi.NewRouter()
	r.Use(middleware.RequestID)
	r.Use(middleware.Recover(log))
	r.Use(middleware.AccessLog(log))

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

		// Auth — all public.
		r.Route("/auth", func(r chi.Router) {
			r.Post("/register", h.Register)
			r.Post("/login", h.Login)
			r.Post("/google", h.GoogleLogin)
			r.Post("/verify-email", h.VerifyEmail)
			// Authed:
			r.With(middleware.Auth(signer)).Post("/resend-verification", h.ResendVerification)
			r.With(middleware.Auth(signer)).Post("/password-change", h.PasswordChange)
			r.With(middleware.Auth(signer)).Post("/email-change", h.EmailChange)
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

		// Authed surface.
		r.Group(func(r chi.Router) {
			r.Use(middleware.Auth(signer))

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
