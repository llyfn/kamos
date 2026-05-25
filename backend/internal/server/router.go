// Package server wires the chi router with middleware and handlers.
package server

import (
	"net/http"

	"github.com/go-chi/chi/v5"

	"github.com/kamos/api/internal/auth"
	"github.com/kamos/api/internal/domain"
	"github.com/kamos/api/internal/handlers"
	"github.com/kamos/api/internal/middleware"
	"github.com/kamos/api/internal/observability"

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
// Caching contract:
//
//   - middleware.ETag is mounted GLOBALLY (line ~50). Every 2xx GET response
//     gets a strong ETag for free.
//   - To prevent a heuristic-caching intermediary from treating an ETagged
//     200 as eligible to share across viewers, every GET under /v1 ALSO
//     gets a freshness declaration: EITHER CacheControl(...) (the 5
//     documented public-cacheable routes) OR NoStore (everything else,
//     including authed feed/list/profile/check-in/comments/admin pages
//     and any auth surface that might land as a GET in the future).
//   - NoStore is applied at the /v1 route-group level; CacheControl
//     wrappers on the 5 cacheable routes run INSIDE NoStore and override
//     the header, since both set Cache-Control before calling next.
//   - New GET routes that omit both will be flagged by
//     TestCacheControlPresentOnAllGetRoutes in the integration suite.
//
// softDelete may be nil — in that case the auth middleware skips the SEC-006
// revocation check. main.go always passes a real cache; tests pass nil when
// they don't care about revocation semantics.
//
// roleResolver is derived from the handler's Repos.DB when non-nil. Passing
// it explicitly keeps server.New testable with stub repos (a nil resolver
// fails closed on every admin route).
//
//nolint:funlen // route table: a flat list of r.Get/r.Post registrations; grouping into sub-funcs hurts at-a-glance routing.
func New(log *slog.Logger, signer *auth.Signer, softDelete *auth.SoftDeleteCache, h *handlers.Handler) http.Handler {
	var roleResolver *middleware.RoleResolver
	if h != nil && h.Repos != nil && h.Repos.DB != nil {
		roleResolver = middleware.NewRoleResolver(h.Repos.DB)
		// SEC-027 — wire the role cache into AdminService so role/suspend
		// writes flush the per-user entry immediately. Idempotent.
		if h.Services != nil && h.Services.Admin != nil {
			h.Services.Admin.WithRoleCache(roleResolver)
		}
	}
	r := chi.NewRouter()
	r.Use(middleware.RequestID)
	r.Use(middleware.Trace)
	r.Use(middleware.RecoverWithSentry(log))
	r.Use(middleware.AccessLog(log))
	// SEC-007 — security response headers on every response (HSTS,
	// nosniff, frame-deny, referrer-policy, permissions-policy).
	r.Use(middleware.SecurityHeaders)
	// SEC-002 — CORS allowlist. Mounted after observability so a denied
	// origin still trace/log; mounted before any business handler so the
	// preflight OPTIONS short-circuit hits before the route lookup.
	var allowedOrigins []string
	if h != nil && h.Cfg != nil {
		allowedOrigins = h.Cfg.CORSAllowedOrigins
	}
	r.Use(middleware.CORS(middleware.CORSConfig{AllowedOrigins: allowedOrigins}))
	// global ETag middleware. Only acts on GET/HEAD + 2xx
	// (see internal/middleware/etag.go); other methods pass through with
	// no overhead. Mounted globally rather than per-route so a new GET
	// route gets ETag support by default — write paths are unaffected.
	r.Use(middleware.ETag)
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

	// Email-verification landing page. Top-level (NOT under /v1) so the
	// click-through URL the user sees in their inbox stays short, and
	// public — possession of the token IS the credential. Rate-limited by
	// the global IP limiter above (when enabled).
	r.Get("/verify", h.VerifyEmailPage)

	// Prometheus scrape endpoint. The bundle of counters
	// includes cache_requests_total{cache,outcome} fed by the cache
	// package's hit/miss observers. Mount unauthenticated: production
	// scrapers run on the same internal network; if external scrapers
	// arrive later, add an auth or network-policy gate then.
	r.Handle("/metrics", observability.PromHandler())

	r.Route("/v1", func(r chi.Router) {
		// SEC-003 — global body-size cap for /v1. 1 MiB is generous for
		// any JSON request the API accepts (photos go through R2
		// presigned PUT, not through the API). The auth subgroup
		// overrides this to 64 KiB.
		r.Use(middleware.MaxBytes(1 << 20))
		// default-deny for downstream caching. Every
		// route under /v1 starts with `Cache-Control: no-store, ...`;
		// the 5 documented cacheable routes override this with their own
		// CacheControl(...) wrapper, which runs INSIDE this middleware and
		// sets the header last. See package doc above.
		r.Use(middleware.NoStore)

		// Auth — all public. Stricter per-IP cap to mitigate
		// brute-force / enumeration against /v1/auth/* (5 rps, burst 10).
		r.Route("/auth", func(r chi.Router) {
			// SEC-003 — auth payloads are tiny; tighten to 64 KiB.
			r.Use(middleware.MaxBytes(1 << 16))
			if rateLimited {
				r.Use(middleware.RateLimitByIP(log, 5, 10))
			}
			r.Post("/register", h.Register)
			r.Post("/login", h.Login)
			r.Post("/google", h.GoogleLogin)
			r.Post("/verify-email", h.VerifyEmail)
			// rotating refresh tokens. Public: possession of the
			// raw secret IS the credential. Still covered by the auth-group
			// 5 rps / burst 10 limit above.
			r.Post("/refresh", h.RefreshToken)
			// Authed:
			r.With(middleware.Auth(signer, softDelete)).Post("/resend-verification", h.ResendVerification)
			r.With(middleware.Auth(signer, softDelete)).Post("/password-change", h.PasswordChange)
			r.With(middleware.Auth(signer, softDelete)).Post("/email-change", h.EmailChange)
			r.With(middleware.Auth(signer, softDelete)).Post("/logout", h.Logout)

			// Stage 4 — admin cookie auth surface. admin-login + admin-
			// refresh are public (refresh reads its own cookie; possession
			// of the raw secret IS the credential). admin-logout requires
			// AdminAuth so we can identify the user for refresh revocation.
			r.Post("/admin-login", h.AdminLogin)
			r.Post("/admin-refresh", h.AdminRefresh)
			r.With(middleware.AdminAuth(signer, softDelete)).Post("/admin-logout", h.AdminLogout)
		})

		// Taxonomy — public reads. long Cache-Control TTL (1h)
		// because the taxonomy effectively never changes during a deploy
		// window. stale-while-revalidate lets intermediaries serve from
		// cache while they background-refresh.
		r.With(middleware.CacheControl("public, max-age=3600, stale-while-revalidate=86400")).
			Get("/categories", h.Categories)
		r.With(middleware.CacheControl("public, max-age=3600, stale-while-revalidate=86400")).
			Get("/flavor-tags", h.FlavorTags)
		// Reference data (migration 016): regions + prefectures. Public,
		// same TTL bucket as the taxonomy endpoints above. Pinned under
		// /v1/reference/ to keep the URL space tidy for future seed
		// reference tables (countries, currencies, …).
		r.With(middleware.CacheControl("public, max-age=3600, stale-while-revalidate=86400")).
			Get("/reference/regions", h.Regions)

		// Beverages / producers — public reads. Beverage detail uses a
		// shorter TTL (5m) because avg_rating + check_in_count drift as
		// new check-ins land; the in-process LRU invalidator (commit 4)
		// busts the entry on write, but downstream caches honor the
		// header for clients that don't replay our invalidation.
		// Producer TTL is 10m — same shape, slower-moving aggregates.
		r.Get("/beverages", h.ListBeverages)
		r.With(middleware.CacheControl("public, max-age=300, stale-while-revalidate=86400")).
			Get("/beverages/{id}", h.GetBeverage)
		r.Get("/beverages/{id}/check-ins", h.GetBeverageCheckins)
		r.Get("/producers", h.ListProducers)
		r.With(middleware.CacheControl("public, max-age=600, stale-while-revalidate=86400")).
			Get("/producers/{id}", h.GetProducer)

		// Search — public.
		r.Get("/search", h.Search)

		// Users (public reads, with optional auth for follow state).
		r.Group(func(r chi.Router) {
			r.Use(middleware.OptionalAuth(signer, softDelete))
			// Static-segment routes must precede the {username} catch-
			// alls so chi doesn't bind "search" to the path param.
			r.Get("/users/search", h.SearchUsers)
			// public-profile response varies by the viewer's
			// follow state (follow_state, restricted), so we can't share
			// a LRU entry across viewers and we can't mark it public
			// without leaking one viewer's relationship to another via
			// downstream caches. Cache-Control: private + must-revalidate
			// means "only the end-user's browser/app may cache, and only
			// after re-validating with us each time". The ETag layer
			// still helps — same viewer, same state → 304.
			r.With(middleware.CacheControl("private, must-revalidate")).
				Get("/users/{username}", h.GetUser)
			r.Get("/users/{username}/check-ins", h.GetUserCheckins)
			r.Get("/users/{username}/collections", h.GetUserCollections)
			r.Get("/users/{username}/followers", h.GetUserFollowers)
			r.Get("/users/{username}/following", h.GetUserFollowing)
			r.Get("/check-ins/{id}", h.GetCheckin)

			// comment list is also a public-read surface.
			// OptionalAuth for forward compatibility (we may add a
			// "you_replied" or similar viewer-relative field).
			r.Get("/check-ins/{id}/comments", h.ListComments)
			// GET /v1/collections/public was removed when the public-
			// collections discovery surface shipped to the bin. Per-user
			// collection browsing is now served by GET
			// /v1/users/{username}/collections (visibility-gated).

			// collection detail is OptionalAuth so the
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

			// Uploads — presigned PUT flow.
			// SEC-008: tight per-user limit on top of the global authed
			// 60/120 cap. 2 rps / burst 4 prevents a single account from
			// minting hundreds of presigns per second while still
			// allowing the SPEC 4-photos-per-check-in burst.
			if rateLimited {
				r.With(middleware.RateLimitByUser(log, 2, 4)).
					Post("/uploads/photo-presign", h.PhotoPresign)
			} else {
				r.Post("/uploads/photo-presign", h.PhotoPresign)
			}

			// Venues — Foursquare-backed search proxy. 503
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
			// GET /v1/follow-requests was retired in Phase 4 — the
			// notifications inbox subsumed the list. Inline Approve /
			// Decline actions still post against the rows below.
			r.Post("/follow-requests/{id}/approve", h.ApproveFollowRequest)
			r.Post("/follow-requests/{id}/decline", h.DeclineFollowRequest)

			// Notifications inbox (SPEC §5.4). Read paths only; emits
			// happen inside the source-event transactions (toast / comment
			// / follow). mark-read carries its own per-user limit on top of
			// the global authed 60/120 so a scroll-driven batch of
			// "viewed-row -> mark read" requests doesn't burn the headroom.
			r.Get("/notifications", h.ListNotifications)
			r.Get("/notifications/unread-count", h.UnreadNotificationCount)
			if rateLimited {
				r.With(middleware.RateLimitByUser(log, 1, 60)).
					Post("/notifications/read", h.MarkNotificationsRead)
			} else {
				r.Post("/notifications/read", h.MarkNotificationsRead)
			}

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

			// comments. POST is heavily spammable, so we
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

		// admin surface. Authed + role-gated per-route. Generous
		// per-user rate limit (30/60) — admin tooling fires bursts of
		// reads during triage but doesn't need the 60/120 of the regular
		// authed surface. Stage 4: AdminAuth replaces Auth so the React
		// admin client can authenticate via HttpOnly cookies (SEC-001);
		// RequireCSRF enforces the double-submit pattern on mutating
		// requests (GET / HEAD / OPTIONS skip internally).
		r.Route("/admin", func(r chi.Router) {
			r.Use(middleware.AdminAuth(signer, softDelete))
			r.Use(middleware.RequireCSRF)
			if rateLimited {
				r.Use(middleware.RateLimitByUser(log, 30, 60))
			}

			// Moderator-or-admin endpoints — triage, listing, soft-delete of
			// individual rows.
			modOrAdmin := roleResolver.RequireRole(domain.RoleModerator, domain.RoleAdmin)
			// Cookie-authable identity endpoint for the React admin client.
			// /v1/users/me is Bearer-only (mobile); the admin holds its JWT in
			// the kamos_admin_access cookie (Path=/v1/admin), so the SPA reads
			// its own identity here. Reuses GetMe — AdminAuth populates the same
			// context user as Auth.
			r.With(modOrAdmin).Get("/me", h.GetMe)
			r.With(modOrAdmin).Get("/beverage-requests", h.AdminListBeverageRequests)
			r.With(modOrAdmin).Post("/beverage-requests/{id}/reject", h.AdminRejectBeverageRequest)
			r.With(modOrAdmin).Post("/check-ins/{id}/moderate", h.AdminModerateCheckin)
			r.With(modOrAdmin).Get("/users", h.AdminListUsers)

			// Stage 7 (M-8.1) — moderator audit trail (read only).
			// Moderator-or-admin: it's a read, both roles should see
			// history. Write happens inside each admin action's
			// transaction (see admin.go::insertModerationLog).
			r.With(modOrAdmin).Get("/moderation-log", h.AdminListModerationLog)

			// comment moderation surface. Both endpoints
			// (review list + per-row soft-delete) are moderator-or-admin.
			r.With(modOrAdmin).Get("/comments", h.AdminListComments)
			r.With(modOrAdmin).Post("/comments/{id}/moderate", h.AdminModerateComment)

			// Admin-only endpoints — destructive or privilege-altering.
			adminOnly := roleResolver.RequireRole(domain.RoleAdmin)
			r.With(adminOnly).Post("/beverage-requests/{id}/approve", h.AdminApproveBeverageRequest)
			r.With(adminOnly).Post("/users/{id}/suspend", h.AdminSuspendUser)
			r.With(adminOnly).Post("/users/{id}/role", h.AdminUpdateUserRole)

			// Stage 8 — direct catalog CRUD. Admin-only (stronger
			// privilege than moderating user submissions): a moderator
			// can triage the beverage-request queue but cannot write
			// canonical entries. Tighten now; product can relax GET to
			// modOrAdmin later if needed.
			r.With(adminOnly).Get("/beverages", h.AdminListBeverages)
			r.With(adminOnly).Get("/beverages/{id}", h.AdminGetBeverage)
			r.With(adminOnly).Post("/beverages", h.AdminCreateBeverage)
			r.With(adminOnly).Patch("/beverages/{id}", h.AdminUpdateBeverage)
			r.With(adminOnly).Delete("/beverages/{id}", h.AdminSoftDeleteBeverage)
			r.With(adminOnly).Post("/beverages/{id}/restore", h.AdminRestoreBeverage)

			r.With(adminOnly).Get("/producers", h.AdminListProducers)
			r.With(adminOnly).Get("/producers/{id}", h.AdminGetProducer)
			r.With(adminOnly).Post("/producers", h.AdminCreateProducer)
			r.With(adminOnly).Patch("/producers/{id}", h.AdminUpdateProducer)
			r.With(adminOnly).Delete("/producers/{id}", h.AdminSoftDeleteProducer)
			r.With(adminOnly).Post("/producers/{id}/restore", h.AdminRestoreProducer)
		})
	})

	return r
}
