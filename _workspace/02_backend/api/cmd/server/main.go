// Command server is the KAMOS REST API entrypoint.
package main

import (
	"context"
	"errors"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/kamos/api/internal/auth"
	"github.com/kamos/api/internal/config"
	"github.com/kamos/api/internal/email"
	"github.com/kamos/api/internal/foursquare"
	"github.com/kamos/api/internal/handlers"
	"github.com/kamos/api/internal/jobs"
	"github.com/kamos/api/internal/observability"
	"github.com/kamos/api/internal/repository"
	"github.com/kamos/api/internal/server"
	"github.com/kamos/api/internal/storage"
)

func main() {
	log := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{Level: slog.LevelInfo}))
	slog.SetDefault(log)

	// Load local.env (when APP_ENV != "production") before reading env vars.
	// Real env vars always win — godotenv.Load is non-overriding by default.
	config.LoadDotenv()

	cfg, err := config.Load()
	if err != nil {
		log.Error("config", "err", err)
		os.Exit(1)
	}

	// Observability — both Init calls are no-ops when the respective env
	// vars are empty. We log "disabled" so operators can see at a glance
	// which side is unconfigured.
	initCtx, initCancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer initCancel()

	otelShutdown, err := observability.InitOTel(initCtx, cfg)
	if err != nil {
		log.Error("otel init", "err", err)
		os.Exit(1)
	}
	if cfg.OTLPEndpoint == "" {
		log.Info("otel disabled (OTEL_EXPORTER_OTLP_ENDPOINT unset)")
	} else {
		log.Info("otel enabled", "endpoint", cfg.OTLPEndpoint)
	}
	defer func() {
		shutdownCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		if err := otelShutdown(shutdownCtx); err != nil {
			log.Error("otel shutdown", "err", err)
		}
	}()

	sentryFlush, err := observability.InitSentry(cfg)
	if err != nil {
		log.Error("sentry init", "err", err)
		os.Exit(1)
	}
	if cfg.SentryDSN == "" {
		log.Info("sentry disabled (SENTRY_DSN unset)")
	} else {
		log.Info("sentry enabled")
	}
	defer sentryFlush(2 * time.Second)

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	pool, err := pgxpool.New(ctx, cfg.DatabaseURL)
	if err != nil {
		log.Error("pgxpool", "err", err)
		os.Exit(1)
	}
	if err := pool.Ping(ctx); err != nil {
		log.Error("pgxpool ping", "err", err)
		os.Exit(1)
	}
	defer pool.Close()

	repos := repository.New(pool)
	signer := auth.NewSigner(cfg.JWTSecret, cfg.JWTTTL)
	google := auth.NewGoogleVerifier(cfg.GoogleClientID)

	// SEC-006 — soft-deleted-user JWT revocation cache. The window MUST be
	// >= JWT_TTL: if a user soft-deletes their account, their tokens are
	// still verifiable until they expire, and we need the cache to keep
	// rejecting them for that full window.
	//
	// Default window: max(30m, JWT_TTL). Local dev runs with JWT_TTL=720h,
	// so the cache effectively holds soft-deletes from the last 30 days
	// (the same horizon as the username-release hold), which is the
	// correct upper bound.
	softDeleteWindow := 30 * time.Minute
	if cfg.JWTTTL > softDeleteWindow {
		softDeleteWindow = cfg.JWTTTL
	}
	softDelete := auth.NewSoftDeleteCache(pool, time.Minute, softDeleteWindow)
	// Run the refresh loop until shutdown. We derive a long-lived context
	// from Background; the loop exits cleanly when this context is canceled
	// at shutdown time below.
	softDeleteCtx, softDeleteCancel := context.WithCancel(context.Background())
	defer softDeleteCancel()
	go softDelete.Run(softDeleteCtx, log)

	// Phase 3 — blob storage. Two cases:
	//   (a) R2_ACCESS_KEY_ID + R2_BUCKET set → real Cloudflare R2 backend.
	//   (b) Either empty → Disabled (the presign endpoint returns 503,
	//       the orphan-cleanup job no-ops the Delete call). The API process
	//       boots cleanly without R2 credentials so dev unblocks.
	var store storage.Storage = storage.Disabled{}
	if cfg.R2AccessKeyID != "" && cfg.R2Bucket != "" {
		r2, err := storage.NewR2(initCtx,
			cfg.R2EndpointURL, cfg.R2AccessKeyID, cfg.R2SecretAccessKey,
			cfg.R2Bucket, cfg.R2PublicBaseURL)
		if err != nil {
			log.Error("storage init", "err", err)
			os.Exit(1)
		}
		store = r2
		log.Info("storage enabled", "bucket", cfg.R2Bucket)
	} else {
		log.Info("storage disabled (R2_BUCKET unset)")
	}

	// Phase 3 — outbound mail. RESEND_API_KEY + EMAIL_FROM both required
	// for real send; otherwise we log the verification link (dev default).
	mailer := email.NewMailer(cfg, log)
	if cfg.ResendAPIKey != "" && cfg.EmailFrom != "" {
		log.Info("mailer enabled", "provider", "resend", "from", cfg.EmailFrom)
	} else {
		log.Info("mailer disabled (RESEND_API_KEY or EMAIL_FROM unset) — using LogMailer")
	}

	// Phase 4 — Foursquare Places client. Empty FOURSQUARE_API_KEY puts the
	// client in Disabled mode; GET /v1/venues/search returns 503
	// VENUE_SEARCH_DISABLED in that case. The check-in venue.foursquare_id
	// upsert path is independent of this client and still works.
	fsq := foursquare.New(cfg.FoursquareAPIKey)
	if fsq.Disabled() {
		log.Info("foursquare disabled (FOURSQUARE_API_KEY unset)")
	} else {
		log.Info("foursquare enabled")
	}

	h := handlers.New(cfg, log, repos, signer, google).
		WithStorage(store).
		WithMailer(mailer).
		WithFoursquare(fsq).
		WithSoftDeleteCache(softDelete)
	mux := server.New(log, signer, softDelete, h)

	// Background-job scheduler — four maintenance jobs registered before
	// the HTTP server starts. The scheduler owns its own context derived
	// from a long-lived parent so jobs survive request churn but cleanly
	// stop on shutdown.
	sched := jobs.NewScheduler(context.Background(), log, pool)
	sched.Register("username_hold_cleanup", time.Hour, jobs.JobUsernameHoldCleanup(log))
	sched.Register("email_verification_cleanup", 6*time.Hour, jobs.JobEmailVerificationCleanup(log))
	sched.Register("avg_rating_sweep", 24*time.Hour, jobs.JobAvgRatingSweep(log))
	sched.Register("photo_orphan_cleanup", time.Hour, jobs.JobPhotoOrphanCleanup(log, store))
	sched.Start()
	defer sched.Stop()

	srv := &http.Server{
		Addr:              ":" + cfg.Port,
		Handler:           mux,
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       15 * time.Second,
		WriteTimeout:      30 * time.Second,
		IdleTimeout:       120 * time.Second,
	}

	go func() {
		log.Info("server starting", "port", cfg.Port, "env", cfg.Env, "version", cfg.Version)
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			log.Error("listen", "err", err)
			os.Exit(1)
		}
	}()

	// Graceful shutdown.
	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)
	<-sigCh
	log.Info("shutting down")

	shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer shutdownCancel()
	if err := srv.Shutdown(shutdownCtx); err != nil {
		log.Error("shutdown", "err", err)
	}
}
