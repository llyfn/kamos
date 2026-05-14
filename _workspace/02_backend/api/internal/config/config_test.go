package config

import (
	"os"
	"path/filepath"
	"testing"
	"time"
)

// withEnv sets env vars for the duration of a test and restores them after.
func withEnv(t *testing.T, kv map[string]string) {
	t.Helper()
	saved := map[string]string{}
	for k := range kv {
		saved[k] = os.Getenv(k)
	}
	for k, v := range kv {
		if v == "" {
			_ = os.Unsetenv(k)
		} else {
			_ = os.Setenv(k, v)
		}
	}
	t.Cleanup(func() {
		for k, v := range saved {
			if v == "" {
				_ = os.Unsetenv(k)
			} else {
				_ = os.Setenv(k, v)
			}
		}
	})
}

func TestLoadRequiresDatabaseURL(t *testing.T) {
	withEnv(t, map[string]string{
		"DATABASE_URL": "",
		"JWT_SECRET":   "x",
	})
	if _, err := Load(); err == nil {
		t.Fatalf("expected error when DATABASE_URL missing")
	}
}

func TestLoadRequiresJWTSecret(t *testing.T) {
	withEnv(t, map[string]string{
		"DATABASE_URL": "postgres://x/x",
		"JWT_SECRET":   "",
	})
	if _, err := Load(); err == nil {
		t.Fatalf("expected error when JWT_SECRET missing")
	}
}

func TestLoadParsesJWTTTL(t *testing.T) {
	withEnv(t, map[string]string{
		"DATABASE_URL": "postgres://x/x",
		"JWT_SECRET":   "secret",
		"JWT_TTL":      "30m",
	})
	c, err := Load()
	if err != nil {
		t.Fatalf("Load: %v", err)
	}
	if c.JWTTTL != 30*time.Minute {
		t.Errorf("JWTTTL: %v", c.JWTTTL)
	}
}

func TestLoadRejectsBadJWTTTL(t *testing.T) {
	withEnv(t, map[string]string{
		"DATABASE_URL": "postgres://x/x",
		"JWT_SECRET":   "secret",
		"JWT_TTL":      "not-a-duration",
	})
	if _, err := Load(); err == nil {
		t.Fatalf("expected error for malformed JWT_TTL")
	}
}

func TestLoadDefaults(t *testing.T) {
	withEnv(t, map[string]string{
		"DATABASE_URL": "postgres://x/x",
		"JWT_SECRET":   "secret",
		"PORT":         "",
		"APP_ENV":      "",
		"APP_BASE_URL": "",
		"JWT_TTL":      "",
		"SMTP_PORT":    "",
	})
	c, err := Load()
	if err != nil {
		t.Fatalf("Load: %v", err)
	}
	if c.Port != "8080" {
		t.Errorf("Port: %q", c.Port)
	}
	if c.Env != "dev" {
		t.Errorf("Env: %q", c.Env)
	}
	if c.JWTTTL != 720*time.Hour {
		t.Errorf("JWTTTL: %v", c.JWTTTL)
	}
	if c.AppBaseURL == "" {
		t.Errorf("AppBaseURL default empty")
	}
	if c.SMTPPort != 587 {
		t.Errorf("SMTPPort default: %d", c.SMTPPort)
	}
}

func TestLoadRejectsBadSMTPPort(t *testing.T) {
	withEnv(t, map[string]string{
		"DATABASE_URL": "postgres://x/x",
		"JWT_SECRET":   "secret",
		"SMTP_PORT":    "not-a-number",
	})
	if _, err := Load(); err == nil {
		t.Fatalf("expected SMTP_PORT parse error")
	}
}

// LoadDotenv is a no-op when APP_ENV=production.
func TestLoadDotenvProductionIsNoOp(t *testing.T) {
	withEnv(t, map[string]string{"APP_ENV": "production"})
	// Should return without error; we cannot assert side effects but the
	// function must not panic.
	LoadDotenv()
}

// LoadDotenv loads keys from a local.env in CWD when present and APP_ENV
// is not production. Real env vars always win (non-overriding behavior).
func TestLoadDotenvLoadsLocalEnv(t *testing.T) {
	dir := t.TempDir()
	envFile := filepath.Join(dir, "local.env")
	if err := os.WriteFile(envFile, []byte("KAMOS_TEST_KEY=from-dotenv\n"), 0o600); err != nil {
		t.Fatalf("write: %v", err)
	}
	cwd, _ := os.Getwd()
	if err := os.Chdir(dir); err != nil {
		t.Fatalf("chdir: %v", err)
	}
	t.Cleanup(func() { _ = os.Chdir(cwd) })

	withEnv(t, map[string]string{
		"APP_ENV":         "test",
		"KAMOS_TEST_KEY":  "",
	})
	LoadDotenv()
	if got := os.Getenv("KAMOS_TEST_KEY"); got != "from-dotenv" {
		t.Errorf("expected KAMOS_TEST_KEY=from-dotenv after LoadDotenv, got %q", got)
	}
}

// godotenv is non-overriding; an already-set env var is NOT overwritten.
func TestLoadDotenvDoesNotOverride(t *testing.T) {
	dir := t.TempDir()
	envFile := filepath.Join(dir, "local.env")
	if err := os.WriteFile(envFile, []byte("KAMOS_TEST_OVR=from-dotenv\n"), 0o600); err != nil {
		t.Fatalf("write: %v", err)
	}
	cwd, _ := os.Getwd()
	if err := os.Chdir(dir); err != nil {
		t.Fatalf("chdir: %v", err)
	}
	t.Cleanup(func() { _ = os.Chdir(cwd) })

	withEnv(t, map[string]string{
		"APP_ENV":        "test",
		"KAMOS_TEST_OVR": "from-real-env",
	})
	LoadDotenv()
	if got := os.Getenv("KAMOS_TEST_OVR"); got != "from-real-env" {
		t.Errorf("expected real env to win; got %q", got)
	}
}
