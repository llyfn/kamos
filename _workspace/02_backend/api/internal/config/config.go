// Package config loads runtime configuration from environment variables.
// All env reads happen here, once at startup. Business logic never touches
// os.Getenv directly.
package config

import (
	"fmt"
	"os"
	"strconv"
	"time"
)

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
