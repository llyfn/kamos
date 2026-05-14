// Package config loads runtime configuration from environment variables.
// All env reads happen here, once at startup. Business logic never touches
// os.Getenv directly.
package config

import (
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"time"

	"github.com/joho/godotenv"
)

// LoadDotenv looks for a local.env file (in CWD, alongside the binary, or
// at any parent directory up to 5 levels) and loads it into the process
// environment when APP_ENV != "production". Real environment variables
// always win over dotenv values — godotenv.Load by default DOES NOT
// override pre-existing env vars, so this is safe.
//
// Intentionally separate from Load so tests can opt out.
func LoadDotenv() {
	if os.Getenv("APP_ENV") == "production" {
		return
	}
	candidates := []string{"local.env"}
	if exe, err := os.Executable(); err == nil {
		candidates = append(candidates, filepath.Join(filepath.Dir(exe), "local.env"))
	}
	// Walk up a few levels from CWD to find local.env at the repo root
	// (useful when running `go run ./cmd/server` from a nested dir).
	if cwd, err := os.Getwd(); err == nil {
		dir := cwd
		for i := 0; i < 5; i++ {
			candidates = append(candidates, filepath.Join(dir, "local.env"))
			parent := filepath.Dir(dir)
			if parent == dir {
				break
			}
			dir = parent
		}
	}
	for _, path := range candidates {
		if _, err := os.Stat(path); err == nil {
			// godotenv.Load is non-overriding by default — real env wins.
			_ = godotenv.Load(path)
			return
		}
	}
}

// Config holds every tunable the server needs.
//
// Google OAuth note: only `GoogleClientID` is needed server-side. The
// API verifies ID tokens by audience match against the client ID;
// no client *secret* is required for that flow. The secret stays out
// of the codebase entirely.
type Config struct {
	Port           string
	DatabaseURL    string
	JWTSecret      string
	JWTTTL         time.Duration
	RefreshTTL     time.Duration
	GoogleClientID string
	SMTPHost       string
	SMTPPort       int
	SMTPUser       string
	SMTPPass       string
	AppBaseURL     string
	Env            string // "dev" | "prod"

	// Observability — all optional. Empty values mean the feature is OFF
	// at startup; the SDK is never initialized in that case (no warnings,
	// no degraded behavior). See observability/otel.go + observability/sentry.go.
	Version       string // APP_VERSION; default "dev"
	OTLPEndpoint  string // OTEL_EXPORTER_OTLP_ENDPOINT; empty disables OTel
	OTLPHeaders   string // OTEL_EXPORTER_OTLP_HEADERS as "k1=v1,k2=v2"
	SentryDSN     string // SENTRY_DSN; empty disables Sentry

	// Rate-limit knob. Defaults are documented in DEPLOYMENT.md §3.
	// Set RATE_LIMIT_DISABLED=1 in integration tests / local stress runs
	// where the production caps would interfere. Production must leave
	// this unset.
	RateLimitDisabled bool

	// Phase 3 — blob storage (Cloudflare R2 / any S3-compatible). Empty
	// values mean the photo-upload feature is OFF; the presign endpoint
	// returns 503 STORAGE_DISABLED. See DEPLOYMENT.md §3.
	R2EndpointURL    string
	R2AccessKeyID    string
	R2SecretAccessKey string
	R2Bucket         string
	R2PublicBaseURL  string

	// Phase 3 — outbound mail via Resend. Empty values mean the mailer
	// logs the verification link instead of sending an email (dev default).
	ResendAPIKey string
	EmailFrom    string

	// Phase 4 — Foursquare Places API for the optional venue tag on
	// check-ins. Empty value means the feature is OFF: the search endpoint
	// returns 503 VENUE_SEARCH_DISABLED; check-in venue.foursquare_id
	// payloads still succeed (the upsert path does not need the API key).
	FoursquareAPIKey string
}

// Load reads env vars and returns a Config, erroring on missing required
// values. .env loading is intentionally NOT implemented here — that is the
// shell's responsibility (use `set -a; source .env; set +a` or godotenv at the
// edge).
func Load() (*Config, error) {
	c := &Config{
		Port:           getenv("PORT", "8080"),
		DatabaseURL:    os.Getenv("DATABASE_URL"),
		JWTSecret:      os.Getenv("JWT_SECRET"),
		GoogleClientID: os.Getenv("GOOGLE_CLIENT_ID"),
		SMTPHost:       os.Getenv("SMTP_HOST"),
		SMTPUser:       os.Getenv("SMTP_USER"),
		SMTPPass:       os.Getenv("SMTP_PASS"),
		AppBaseURL:     getenv("APP_BASE_URL", "http://localhost:3000"),
		Env:            getenv("APP_ENV", "dev"),
		Version:        getenv("APP_VERSION", "dev"),
		OTLPEndpoint:   os.Getenv("OTEL_EXPORTER_OTLP_ENDPOINT"),
		OTLPHeaders:    os.Getenv("OTEL_EXPORTER_OTLP_HEADERS"),
		SentryDSN:      os.Getenv("SENTRY_DSN"),
		RateLimitDisabled: os.Getenv("RATE_LIMIT_DISABLED") == "1",
		R2EndpointURL:     os.Getenv("R2_ENDPOINT_URL"),
		R2AccessKeyID:     os.Getenv("R2_ACCESS_KEY_ID"),
		R2SecretAccessKey: os.Getenv("R2_SECRET_ACCESS_KEY"),
		R2Bucket:          os.Getenv("R2_BUCKET"),
		R2PublicBaseURL:   os.Getenv("R2_PUBLIC_BASE_URL"),
		ResendAPIKey:      os.Getenv("RESEND_API_KEY"),
		EmailFrom:         os.Getenv("EMAIL_FROM"),
		FoursquareAPIKey:  os.Getenv("FOURSQUARE_API_KEY"),
	}

	// Access-token TTL. Phase 2 (refresh-tokens): default lowered from 720h
	// (long-lived MVP) to 15m. The env var still wins for operators that need
	// to pin a different value (e.g., integration tests force a known cadence).
	ttlStr := getenv("JWT_TTL", "15m")
	ttl, err := time.ParseDuration(ttlStr)
	if err != nil {
		return nil, fmt.Errorf("Load: invalid JWT_TTL %q: %w", ttlStr, err)
	}
	c.JWTTTL = ttl

	// Refresh-token TTL. Default 30 days (720h) — documented in DEPLOYMENT.md
	// §3 and matches the lifetime referenced by the refresh-rotation flow.
	rttlStr := getenv("REFRESH_TTL", "720h")
	rttl, err := time.ParseDuration(rttlStr)
	if err != nil {
		return nil, fmt.Errorf("Load: invalid REFRESH_TTL %q: %w", rttlStr, err)
	}
	c.RefreshTTL = rttl

	if v := os.Getenv("SMTP_PORT"); v != "" {
		p, err := strconv.Atoi(v)
		if err != nil {
			return nil, fmt.Errorf("Load: invalid SMTP_PORT %q: %w", v, err)
		}
		c.SMTPPort = p
	} else {
		c.SMTPPort = 587
	}

	if c.DatabaseURL == "" {
		return nil, fmt.Errorf("Load: DATABASE_URL is required")
	}
	if c.JWTSecret == "" {
		return nil, fmt.Errorf("Load: JWT_SECRET is required")
	}
	return c, nil
}

func getenv(k, def string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return def
}
