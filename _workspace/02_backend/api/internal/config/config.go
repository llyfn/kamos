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
type Config struct {
	Port               string
	DatabaseURL        string
	JWTSecret          string
	JWTTTL             time.Duration
	GoogleClientID     string
	GoogleClientSecret string
	SMTPHost           string
	SMTPPort           int
	SMTPUser           string
	SMTPPass           string
	AppBaseURL         string
	Env                string // "dev" | "prod"
}

// Load reads env vars and returns a Config, erroring on missing required
// values. .env loading is intentionally NOT implemented here — that is the
// shell's responsibility (use `set -a; source .env; set +a` or godotenv at the
// edge).
func Load() (*Config, error) {
	c := &Config{
		Port:               getenv("PORT", "8080"),
		DatabaseURL:        os.Getenv("DATABASE_URL"),
		JWTSecret:          os.Getenv("JWT_SECRET"),
		GoogleClientID:     os.Getenv("GOOGLE_CLIENT_ID"),
		GoogleClientSecret: os.Getenv("GOOGLE_CLIENT_SECRET"),
		SMTPHost:           os.Getenv("SMTP_HOST"),
		SMTPUser:           os.Getenv("SMTP_USER"),
		SMTPPass:           os.Getenv("SMTP_PASS"),
		AppBaseURL:         getenv("APP_BASE_URL", "http://localhost:3000"),
		Env:                getenv("APP_ENV", "dev"),
	}

	ttlStr := getenv("JWT_TTL", "720h")
	ttl, err := time.ParseDuration(ttlStr)
	if err != nil {
		return nil, fmt.Errorf("Load: invalid JWT_TTL %q: %w", ttlStr, err)
	}
	c.JWTTTL = ttl

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
