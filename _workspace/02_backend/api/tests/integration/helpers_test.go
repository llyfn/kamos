//go:build integration
// +build integration

// Package integration runs the API against a real Postgres 18 instance.
// Build tag `integration` keeps these tests out of the default `go test`
// run. Set INTEGRATION_DATABASE_URL to the test database connection
// string before invoking `go test -tags=integration ./tests/integration/...`.
package integration

import (
	"bytes"
	"context"
	"encoding/json"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/kamos/api/internal/auth"
	"github.com/kamos/api/internal/config"
	"github.com/kamos/api/internal/handlers"
	"github.com/kamos/api/internal/repository"
	"github.com/kamos/api/internal/server"
)

// We share one pool across the whole test run; truncateAll resets state
// between cases.
var (
	poolOnce sync.Once
	pool     *pgxpool.Pool
	poolErr  error
)

func getPool(t *testing.T) *pgxpool.Pool {
	t.Helper()
	poolOnce.Do(func() {
		dsn := os.Getenv("INTEGRATION_DATABASE_URL")
		if dsn == "" {
			poolErr = errSkip("INTEGRATION_DATABASE_URL is not set")
			return
		}
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		pool, poolErr = pgxpool.New(ctx, dsn)
		if poolErr != nil {
			return
		}
		if err := pool.Ping(ctx); err != nil {
			poolErr = err
			return
		}
	})
	if poolErr != nil {
		t.Fatalf("pool: %v", poolErr)
	}
	return pool
}

type skipErr string

func (e skipErr) Error() string { return string(e) }

func errSkip(s string) error { return skipErr(s) }

// truncateAll wipes every table except the two seed tables that the SPEC
// expects to be present (beverage_categories + flavor_tags). CASCADE
// removes dependent rows; RESTART IDENTITY would reset any sequences (not
// strictly necessary here because the IDs are UUIDs).
func truncateAll(t *testing.T) {
	t.Helper()
	p := getPool(t)
	ctx := context.Background()
	// Discover the table list at runtime so a new migration can't slip past.
	rows, err := p.Query(ctx, `
SELECT tablename FROM pg_tables
WHERE schemaname = 'public'
  AND tablename NOT IN ('beverage_categories','flavor_tags');`)
	if err != nil {
		t.Fatalf("list tables: %v", err)
	}
	defer rows.Close()
	var names []string
	for rows.Next() {
		var n string
		if err := rows.Scan(&n); err != nil {
			t.Fatalf("scan: %v", err)
		}
		names = append(names, `"`+n+`"`)
	}
	if err := rows.Err(); err != nil {
		t.Fatalf("rows: %v", err)
	}
	if len(names) == 0 {
		return
	}
	sql := "TRUNCATE TABLE " + strings.Join(names, ", ") + " RESTART IDENTITY CASCADE;"
	if _, err := p.Exec(ctx, sql); err != nil {
		t.Fatalf("truncate: %v", err)
	}
}

// newServer builds the full chi router with real repositories and starts
// it on an httptest server. The caller is responsible for srv.Close().
//
// Rate limiting is OFF by default so cross-cutting integration tests
// (which fire dozens of requests from a single localhost IP in a tight
// loop) don't flake on the production limits. Tests that *want* the
// limiter enabled call newServerWithRateLimit.
func newServer(t *testing.T) *httptest.Server {
	t.Helper()
	return buildServer(t, true /*disableRateLimit*/)
}

// newServerWithRateLimit builds the same router with rate limiting
// enabled — used by ratelimit_integration_test.go.
func newServerWithRateLimit(t *testing.T) *httptest.Server {
	t.Helper()
	return buildServer(t, false)
}

func buildServer(t *testing.T, disableRateLimit bool) *httptest.Server {
	t.Helper()
	return buildServerWithTTL(t, disableRateLimit, time.Hour, 30*24*time.Hour, nil)
}

// buildServerWithTTL is like buildServer but lets the caller pin the access
// + refresh TTLs. `logSink`, when non-nil, captures every slog line — used by
// the refresh re-use-detection test to assert the WARN log fires.
func buildServerWithTTL(
	t *testing.T,
	disableRateLimit bool,
	jwtTTL, refreshTTL time.Duration,
	logSink io.Writer,
) *httptest.Server {
	t.Helper()
	p := getPool(t)
	cfg := &config.Config{
		AppBaseURL:        "http://localhost",
		JWTSecret:         "integration-secret-please-replace-aaaaaaaaaaaa",
		JWTTTL:            jwtTTL,
		RefreshTTL:        refreshTTL,
		Env:               "test",
		RateLimitDisabled: disableRateLimit,
	}
	signer := auth.NewSigner(cfg.JWTSecret, cfg.JWTTTL)
	var handler slog.Handler
	if logSink != nil {
		handler = slog.NewJSONHandler(logSink, &slog.HandlerOptions{Level: slog.LevelDebug})
	} else {
		handler = slog.NewTextHandler(io.Discard, nil)
	}
	log := slog.New(handler)
	repos := repository.New(p)
	google := auth.NewGoogleVerifier("")
	// SEC-006: bring up a real soft-delete cache backed by the test DB.
	// 30s refresh is generous for an integration suite; tests that need
	// immediate revocation rely on the DeleteMe handler's synchronous
	// Add() call rather than waiting for the periodic refresh.
	softDelete := auth.NewSoftDeleteCache(p, 30*time.Second, jwtTTL+time.Hour)
	h := handlers.New(cfg, log, repos, signer, google).
		WithSoftDeleteCache(softDelete)
	mux := server.New(log, signer, softDelete, h)
	return httptest.NewServer(mux)
}

// doReq is a generic HTTP helper. The body is JSON-marshalled when not nil.
func doReq(t *testing.T, srv *httptest.Server, method, path, token string, body any) (int, []byte) {
	t.Helper()
	var reader io.Reader
	if body != nil {
		b, err := json.Marshal(body)
		if err != nil {
			t.Fatalf("marshal: %v", err)
		}
		reader = bytes.NewReader(b)
	}
	req, err := http.NewRequest(method, srv.URL+path, reader)
	if err != nil {
		t.Fatalf("new request: %v", err)
	}
	if body != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("do: %v", err)
	}
	defer resp.Body.Close()
	out, err := io.ReadAll(resp.Body)
	if err != nil {
		t.Fatalf("read body: %v", err)
	}
	return resp.StatusCode, out
}

// authResponse mirrors domain.AuthResponse so we don't need to import the
// domain package and possibly mis-name fields.
type authResponse struct {
	User struct {
		ID            string `json:"id"`
		Username      string `json:"username"`
		Email         string `json:"email"`
		EmailVerified bool   `json:"email_verified"`
	} `json:"user"`
	AccessToken      string `json:"access_token"`
	RefreshToken     string `json:"refresh_token"`
	TokenType        string `json:"token_type"`
	ExpiresIn        int64  `json:"expires_in"`
	RefreshExpiresIn int64  `json:"refresh_expires_in"`
}

// mustRegister POSTs /v1/auth/register and returns the issued token + user id.
func mustRegister(t *testing.T, srv *httptest.Server, username, email, password string) (string, string) {
	t.Helper()
	body := map[string]any{
		"username":     username,
		"email":        email,
		"password":     password,
		"display_name": username,
		"locale":       "en",
	}
	code, raw := doReq(t, srv, http.MethodPost, "/v1/auth/register", "", body)
	if code != http.StatusCreated {
		t.Fatalf("register %s: status=%d body=%s", username, code, raw)
	}
	var resp authResponse
	if err := json.Unmarshal(raw, &resp); err != nil {
		t.Fatalf("register decode: %v", err)
	}
	if resp.AccessToken == "" || resp.User.ID == "" {
		t.Fatalf("register: missing token/id: %s", raw)
	}
	return resp.AccessToken, resp.User.ID
}

// mustLogin POSTs /v1/auth/login and returns the issued token.
func mustLogin(t *testing.T, srv *httptest.Server, email, password string) string {
	t.Helper()
	body := map[string]any{"email": email, "password": password}
	code, raw := doReq(t, srv, http.MethodPost, "/v1/auth/login", "", body)
	if code != http.StatusOK {
		t.Fatalf("login: status=%d body=%s", code, raw)
	}
	var resp authResponse
	if err := json.Unmarshal(raw, &resp); err != nil {
		t.Fatalf("login decode: %v", err)
	}
	if resp.AccessToken == "" {
		t.Fatalf("login: missing token")
	}
	return resp.AccessToken
}

// seedBeverage inserts a brewery + beverage and returns the beverage id.
// `extra` is a map of column overrides written directly into the JSONB
// name field — used by the ko-fallback test.
func seedBeverage(t *testing.T, name string) string {
	t.Helper()
	return seedBeverageWithNames(t, name, name, name)
}

func seedBeverageWithNames(t *testing.T, enName, jaName, koName string) string {
	t.Helper()
	p := getPool(t)
	ctx := context.Background()
	// Use the seeded `nihonshu` category id.
	var catID string
	if err := p.QueryRow(ctx,
		`SELECT id FROM beverage_categories WHERE slug = 'nihonshu' LIMIT 1;`).Scan(&catID); err != nil {
		t.Fatalf("look up category: %v", err)
	}
	// Build the i18n JSON: en + ja required; ko optional.
	nameI18n := map[string]string{"en": enName, "ja": jaName}
	if koName != "" {
		nameI18n["ko"] = koName
	}
	nameJSON, _ := json.Marshal(nameI18n)
	breweryNameJSON, _ := json.Marshal(map[string]string{
		"en": "Test Brewery",
		"ja": "テスト酒造",
	})

	var breweryID string
	if err := p.QueryRow(ctx, `
INSERT INTO breweries (name_i18n) VALUES ($1::jsonb) RETURNING id;`, string(breweryNameJSON)).Scan(&breweryID); err != nil {
		t.Fatalf("seed brewery: %v", err)
	}
	var bevID string
	if err := p.QueryRow(ctx, `
INSERT INTO beverages (brewery_id, category_id, category_slug, name_i18n)
VALUES ($1, $2, 'nihonshu', $3::jsonb) RETURNING id;`,
		breweryID, catID, string(nameJSON)).Scan(&bevID); err != nil {
		t.Fatalf("seed beverage: %v", err)
	}
	return bevID
}

// errBodyShape matches the canonical { error, code } body shape.
type errBodyShape struct {
	Error string `json:"error"`
	Code  string `json:"code"`
}

// mustInsertPendingUpload inserts a photo_uploads row in 'pending' state and
// returns its id. Used by photo-attach tests that need a row but can't go
// through PhotoPresign (which is 503 under Disabled storage).
func mustInsertPendingUpload(t *testing.T, p *pgxpool.Pool, userID, blobKey string) string {
	t.Helper()
	const q = `
INSERT INTO photo_uploads (user_id, blob_key, content_type, byte_size)
VALUES ($1, $2, 'image/jpeg', 1024)
RETURNING id;`
	var id string
	if err := p.QueryRow(context.Background(), q, userID, blobKey).Scan(&id); err != nil {
		t.Fatalf("insert pending upload: %v", err)
	}
	return id
}

// setUserPrivacy flips a user's privacy_mode column via SQL.
func setUserPrivacy(t *testing.T, userID, mode string) {
	t.Helper()
	p := getPool(t)
	if _, err := p.Exec(context.Background(),
		`UPDATE users SET privacy_mode = $2 WHERE id = $1;`, userID, mode); err != nil {
		t.Fatalf("setUserPrivacy: %v", err)
	}
}
