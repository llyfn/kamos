// Command worker is the KAMOS background-job runner. It is the only
// process that should hold the in-process scheduler — the API server
// (cmd/server) no longer registers jobs at all. This split lets the API
// scale horizontally (N replicas behind a load balancer) while the
// worker stays at a single replica so each job ticks exactly once per
// interval.
//
// Belt-and-suspenders: the scheduler also wraps each tick in
// pg_try_advisory_lock so a misconfigured deploy that still runs jobs
// in N API replicas would fail safe — only the first to grab the lock
// fires the job body.
//
// The worker mirrors cmd/server's bootstrap (env + config + Sentry +
// OTel + Prometheus + graceful shutdown) but DOES NOT spin up an HTTP
// listener for the API surface, and DOES NOT need auth / Google / mailer
// dependencies. It DOES expose Prometheus on a separate port (default
// 9091) so the same scrape config can reach both processes.
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

	"github.com/kamos/api/internal/config"
	"github.com/kamos/api/internal/jobs"
	"github.com/kamos/api/internal/observability"
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
	// vars are empty.
	initCtx, initCancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer initCancel()

	otelShutdown, err := observability.InitOTel(initCtx, cfg)
	if err != nil {
		log.Error("otel init", "err", err)
		initCancel() // gocritic can't see this — it pattern-matches `defer + os.Exit`.
		os.Exit(1)   //nolint:gocritic // initCancel() called explicitly above.
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

	// Storage for photo_orphan_cleanup. Same pattern as the API:
	// Disabled{} when R2 isn't configured, real R2 client otherwise.
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

	// Prometheus scrape endpoint on a dedicated port (default 9091) so
	// scrape configs can target the worker separately from the API.
	metricsPort := os.Getenv("WORKER_METRICS_PORT")
	if metricsPort == "" {
		metricsPort = "9091"
	}
	metricsMux := http.NewServeMux()
	metricsMux.Handle("/metrics", observability.PromHandler())
	metricsMux.HandleFunc("/healthz", func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(`{"status":"ok"}`))
	})
	metricsSrv := &http.Server{
		Addr:              ":" + metricsPort,
		Handler:           metricsMux,
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       15 * time.Second,
		WriteTimeout:      30 * time.Second,
		IdleTimeout:       120 * time.Second,
	}

	// Background-job scheduler. Same four maintenance jobs that used to
	// run in cmd/server. Each job tick is guarded by a pg advisory lock
	// (see scheduler.go), so even if two workers run by mistake only one
	// fires the body.
	sched := jobs.NewScheduler(context.Background(), log, pool)
	sched.Register("username_hold_cleanup", time.Hour, jobs.JobUsernameHoldCleanup(log))
	sched.Register("email_verification_cleanup", 6*time.Hour, jobs.JobEmailVerificationCleanup(log))
	sched.Register("avg_rating_sweep", 24*time.Hour, jobs.JobAvgRatingSweep(log))
	sched.Register("photo_orphan_cleanup", time.Hour, jobs.JobPhotoOrphanCleanup(log, store))
	sched.Start()
	defer sched.Stop()

	go func() {
		log.Info("worker metrics starting", "port", metricsPort, "env", cfg.Env, "version", cfg.Version)
		if err := metricsSrv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			log.Error("metrics listen", "err", err)
			os.Exit(1)
		}
	}()

	log.Info("worker ready", "jobs", 4, "env", cfg.Env, "version", cfg.Version)

	// Graceful shutdown.
	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)
	<-sigCh
	log.Info("shutting down")

	shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer shutdownCancel()
	if err := metricsSrv.Shutdown(shutdownCtx); err != nil {
		log.Error("metrics shutdown", "err", err)
	}
}
