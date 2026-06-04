// These tests exercise the handler/router layer at points that do NOT
// require a real database: authentication enforcement, request decoding,
// and validation. Repository-success paths (which need pgx) are covered
// by tests/integration with a real Postgres 18.
//
// We use an external test package so we can import server.New (which
// itself imports handlers) without an import cycle.
package handlers_test

import (
	"bytes"
	"encoding/json"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/kamos/api/internal/auth"
	"github.com/kamos/api/internal/config"
	"github.com/kamos/api/internal/handlers"
	"github.com/kamos/api/internal/repository"
	"github.com/kamos/api/internal/server"
)

// newTestServer returns a chi router that has nil repositories — so any
// handler that talks to the DB will panic. That is acceptable; these tests
// only exercise routes that short-circuit at auth or validation.
func newTestServer(t *testing.T) (http.Handler, *auth.Signer) {
	t.Helper()
	cfg := &config.Config{
		AppBaseURL: "http://localhost",
		JWTSecret:  "test-secret-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
		JWTTTL:     time.Hour,
		Env:        "test",
	}
	signer := auth.NewSigner(cfg.JWTSecret, cfg.JWTTTL)
	log := slog.New(slog.NewTextHandler(io.Discard, nil))
	// Stub repos: the concrete types each hold an unexported *pgxpool.Pool
	// (nil here). Handlers we test in this file return before dereferencing
	// it.
	repos := &repository.Repos{
		Users:         &repository.UserRepo{},
		Beverages:     &repository.BeverageRepo{},
		Producers:     &repository.ProducerRepo{},
		Checkins:      &repository.CheckinRepo{},
		Feed:          &repository.FeedRepo{},
		Social:        &repository.SocialRepo{},
		Collections:   &repository.CollectionRepo{},
		Search:        &repository.SearchRepo{},
		Taxonomy:      &repository.TaxonomyRepo{},
		RefreshTokens: &repository.RefreshTokenRepo{},
		PhotoUploads:  &repository.PhotoUploadRepo{},
	}
	google := auth.NewGoogleVerifier("")
	h := handlers.New(cfg, log, repos, signer, google)
	// SEC-006: nil softDelete is intentional — these tests exercise
	// auth/validation short-circuits that don't depend on revocation state.
	return server.New(log, signer, nil, h), signer
}

// decodeAPIError matches the canonical { error, code } body shape used by
// every error response.
type errBody struct {
	Error string `json:"error"`
	Code  string `json:"code"`
}

func decodeErrBody(t *testing.T, body io.Reader) errBody {
	t.Helper()
	var e errBody
	if err := json.NewDecoder(body).Decode(&e); err != nil {
		t.Fatalf("decode body: %v", err)
	}
	return e
}

// /health returns {"status":"ok"} (the only fully synthetic endpoint).
func TestHealth(t *testing.T) {
	srv, _ := newTestServer(t)
	rr := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, "/health", nil)
	srv.ServeHTTP(rr, req)
	if rr.Code != http.StatusOK {
		t.Fatalf("status: %d", rr.Code)
	}
	var body map[string]string
	if err := json.Unmarshal(rr.Body.Bytes(), &body); err != nil {
		t.Fatalf("body: %v", err)
	}
	if body["status"] != "ok" {
		t.Errorf("status field: %q", body["status"])
	}
}

// Every authed route returns 401 without a token AND ships the canonical
// error body shape.
func TestAuthedRoutesRequireBearer(t *testing.T) {
	srv, _ := newTestServer(t)
	authedRoutes := []struct {
		method, path string
	}{
		{http.MethodGet, "/v1/users/me"},
		{http.MethodPatch, "/v1/users/me"},
		{http.MethodDelete, "/v1/users/me"},
		{http.MethodGet, "/v1/feed"},
		{http.MethodPost, "/v1/check-ins"},
		{http.MethodPatch, "/v1/check-ins/some-id"},
		{http.MethodDelete, "/v1/check-ins/some-id"},
		{http.MethodPost, "/v1/check-ins/some-id/photos"},
		{http.MethodPost, "/v1/check-ins/some-id/toast"},
		{http.MethodPost, "/v1/users/yamamoto/follow"},
		{http.MethodDelete, "/v1/users/yamamoto/follow"},
		{http.MethodPost, "/v1/follow-requests/u-1/approve"},
		{http.MethodPost, "/v1/follow-requests/u-1/decline"},
		{http.MethodGet, "/v1/collections"},
		{http.MethodPost, "/v1/collections"},
		// GET /v1/collections/{id} is OptionalAuth as of Phase 6a — the
		// public-discovery route deep-links here, so anonymous viewers
		// must succeed on public rows. Excluded from the bearer-required
		// list deliberately.
		{http.MethodPatch, "/v1/collections/c-1"},
		{http.MethodDelete, "/v1/collections/c-1"},
		{http.MethodPost, "/v1/collections/c-1/entries"},
		{http.MethodPatch, "/v1/collections/c-1/entries/b-1"},
		{http.MethodDelete, "/v1/collections/c-1/entries/b-1"},
		{http.MethodPost, "/v1/beverage-requests"},
		// slice 01 — PATCH /v1/comments/{id} is the comment edit endpoint.
		{http.MethodPatch, "/v1/comments/c-1"},
		{http.MethodPost, "/v1/auth/resend-verification"},
		{http.MethodPost, "/v1/auth/password-change"},
		{http.MethodPost, "/v1/auth/email-change"},
		// Phase 5a — admin routes. Auth fires first, so a missing token
		// returns 401 UNAUTHORIZED before RequireRole hits the DB.
		{http.MethodGet, "/v1/admin/beverage-requests"},
		{http.MethodPost, "/v1/admin/beverage-requests/req-1/approve"},
		{http.MethodPost, "/v1/admin/beverage-requests/req-1/reject"},
		{http.MethodPost, "/v1/admin/check-ins/c-1/moderate"},
		{http.MethodGet, "/v1/admin/users"},
		{http.MethodPost, "/v1/admin/users/u-1/role"},
		{http.MethodPost, "/v1/admin/users/u-1/suspend"},
	}
	for _, r := range authedRoutes {
		r := r
		t.Run(r.method+" "+r.path, func(t *testing.T) {
			rr := httptest.NewRecorder()
			req := httptest.NewRequest(r.method, r.path, nil)
			srv.ServeHTTP(rr, req)
			if rr.Code != http.StatusUnauthorized {
				t.Fatalf("expected 401, got %d body=%s", rr.Code, rr.Body.String())
			}
			body := decodeErrBody(t, rr.Body)
			if body.Code != "UNAUTHORIZED" {
				t.Errorf("code: %q", body.Code)
			}
			if body.Error == "" {
				t.Errorf("error field empty")
			}
		})
	}
}

// An invalid (malformed) bearer token is also rejected with 401.
func TestAuthedRouteInvalidBearer(t *testing.T) {
	srv, _ := newTestServer(t)
	rr := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, "/v1/users/me", nil)
	req.Header.Set("Authorization", "Bearer not-a-real-token")
	srv.ServeHTTP(rr, req)
	if rr.Code != http.StatusUnauthorized {
		t.Fatalf("status: %d", rr.Code)
	}
}

// Register validates the body BEFORE touching the repo, so the test passes
// even with a nil repo.
func TestRegisterValidationFailures(t *testing.T) {
	srv, _ := newTestServer(t)
	cases := []struct {
		name string
		body string
		want string // substring of the human message
	}{
		{
			"username too short",
			`{"username":"yo","email":"y@example.com","password":"password1"}`,
			"username",
		},
		{
			"bad email",
			`{"username":"yamamoto","email":"no-at","password":"password1"}`,
			"email",
		},
		{
			"short password",
			`{"username":"yamamoto","email":"y@example.com","password":"short"}`,
			"password",
		},
	}
	for _, tc := range cases {
		tc := tc
		t.Run(tc.name, func(t *testing.T) {
			rr := httptest.NewRecorder()
			req := httptest.NewRequest(http.MethodPost, "/v1/auth/register",
				bytes.NewReader([]byte(tc.body)))
			req.Header.Set("Content-Type", "application/json")
			srv.ServeHTTP(rr, req)
			if rr.Code != http.StatusUnprocessableEntity {
				t.Fatalf("status: %d body=%s", rr.Code, rr.Body.String())
			}
			body := decodeErrBody(t, rr.Body)
			if body.Code != "VALIDATION" {
				t.Errorf("code: %q", body.Code)
			}
			if !strings.Contains(body.Error, tc.want) {
				t.Errorf("body.Error %q does not contain %q", body.Error, tc.want)
			}
		})
	}
}

// /v1/auth/register with non-JSON body returns 422 (VALIDATION via Join).
func TestRegisterMalformedJSON(t *testing.T) {
	srv, _ := newTestServer(t)
	rr := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodPost, "/v1/auth/register",
		bytes.NewReader([]byte(`not-json`)))
	req.Header.Set("Content-Type", "application/json")
	srv.ServeHTTP(rr, req)
	// decodeJSON wraps in domain.ErrBadRequest; writeErr does not treat
	// it as VALIDATION — so it maps to 400.
	if rr.Code != http.StatusBadRequest {
		t.Fatalf("status: %d body=%s", rr.Code, rr.Body.String())
	}
	body := decodeErrBody(t, rr.Body)
	if body.Code != "BAD_REQUEST" {
		t.Errorf("code: %q", body.Code)
	}
}

// Login with empty email / password is rejected by Validate() before any
// DB access.
func TestLoginValidation(t *testing.T) {
	srv, _ := newTestServer(t)
	rr := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodPost, "/v1/auth/login",
		bytes.NewReader([]byte(`{"email":"","password":""}`)))
	srv.ServeHTTP(rr, req)
	if rr.Code != http.StatusUnprocessableEntity {
		t.Fatalf("status: %d", rr.Code)
	}
}

// Search without a `q` parameter is rejected at the handler boundary.
func TestSearchRequiresQuery(t *testing.T) {
	srv, _ := newTestServer(t)
	rr := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, "/v1/search", nil)
	srv.ServeHTTP(rr, req)
	if rr.Code != http.StatusUnprocessableEntity {
		t.Fatalf("status: %d body=%s", rr.Code, rr.Body.String())
	}
	body := decodeErrBody(t, rr.Body)
	if body.Code != "VALIDATION" {
		t.Errorf("code: %q", body.Code)
	}
}

// Create-checkin validation rejects rating 0.25 (not in 0.5 steps),
// without ever touching the DB.
func TestCreateCheckinRatingValidation(t *testing.T) {
	srv, signer := newTestServer(t)
	tok, err := signer.Sign("u-1", "yamamoto")
	if err != nil {
		t.Fatalf("Sign: %v", err)
	}
	rr := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodPost, "/v1/check-ins",
		bytes.NewReader([]byte(`{"beverage_id":"b-1","rating":0.25}`)))
	req.Header.Set("Authorization", "Bearer "+tok)
	srv.ServeHTTP(rr, req)
	if rr.Code != http.StatusUnprocessableEntity {
		t.Fatalf("status: %d body=%s", rr.Code, rr.Body.String())
	}
}

// Create-checkin with 5 photos is rejected by Validate() (≤ 4 cap).
func TestCreateCheckinPhotoCap(t *testing.T) {
	srv, signer := newTestServer(t)
	tok, _ := signer.Sign("u-1", "yamamoto")
	body := `{"beverage_id":"b-1","photos":["a","b","c","d","e"]}`
	rr := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodPost, "/v1/check-ins",
		bytes.NewReader([]byte(body)))
	req.Header.Set("Authorization", "Bearer "+tok)
	srv.ServeHTTP(rr, req)
	if rr.Code != http.StatusUnprocessableEntity {
		t.Fatalf("status: %d body=%s", rr.Code, rr.Body.String())
	}
}

// Update-checkin attempt to mutate beverage_id is rejected by handler
// pre-check before any DB call.
func TestUpdateCheckinBeverageImmutable(t *testing.T) {
	srv, signer := newTestServer(t)
	tok, _ := signer.Sign("u-1", "yamamoto")
	rr := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodPatch, "/v1/check-ins/some-id",
		bytes.NewReader([]byte(`{"beverage_id":"new-bev"}`)))
	req.Header.Set("Authorization", "Bearer "+tok)
	srv.ServeHTTP(rr, req)
	if rr.Code != http.StatusUnprocessableEntity {
		t.Fatalf("status: %d body=%s", rr.Code, rr.Body.String())
	}
}

// PATCH /v1/comments/{id} without auth returns 401 — verifies the route
// is mounted on the authed surface (slice 01).
func TestUpdateCommentRequiresAuth(t *testing.T) {
	srv, _ := newTestServer(t)
	rr := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodPatch, "/v1/comments/c-1",
		bytes.NewReader([]byte(`{"body":"hi"}`)))
	srv.ServeHTTP(rr, req)
	if rr.Code != http.StatusUnauthorized {
		t.Fatalf("status: %d body=%s", rr.Code, rr.Body.String())
	}
}

// PATCH /v1/comments/{id} with an empty body fails validation before any
// DB call (mirrors the create-comment validation).
func TestUpdateCommentValidation(t *testing.T) {
	srv, signer := newTestServer(t)
	tok, _ := signer.Sign("u-1", "yamamoto")
	rr := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodPatch, "/v1/comments/c-1",
		bytes.NewReader([]byte(`{"body":""}`)))
	req.Header.Set("Authorization", "Bearer "+tok)
	srv.ServeHTTP(rr, req)
	if rr.Code != http.StatusUnprocessableEntity {
		t.Fatalf("status: %d body=%s", rr.Code, rr.Body.String())
	}
	body := decodeErrBody(t, rr.Body)
	if body.Code != "VALIDATION" {
		t.Errorf("code: %q", body.Code)
	}
}

// CreateCollection with no body fails validation (name required).
func TestCreateCollectionValidation(t *testing.T) {
	srv, signer := newTestServer(t)
	tok, _ := signer.Sign("u-1", "yamamoto")
	rr := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodPost, "/v1/collections",
		bytes.NewReader([]byte(`{"name":""}`)))
	req.Header.Set("Authorization", "Bearer "+tok)
	srv.ServeHTTP(rr, req)
	if rr.Code != http.StatusUnprocessableEntity {
		t.Fatalf("status: %d", rr.Code)
	}
}

// UploadCheckinPhoto without an upload_id is rejected by the handler.
// (Phase 3 replaced the MVP `{ url }` body with `{ upload_id }`.)
func TestUploadCheckinPhotoRequiresUploadID(t *testing.T) {
	srv, signer := newTestServer(t)
	tok, _ := signer.Sign("u-1", "yamamoto")
	rr := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodPost, "/v1/check-ins/some-id/photos",
		bytes.NewReader([]byte(`{"upload_id":""}`)))
	req.Header.Set("Authorization", "Bearer "+tok)
	srv.ServeHTTP(rr, req)
	if rr.Code != http.StatusUnprocessableEntity {
		t.Fatalf("status: %d", rr.Code)
	}
}

// Google login with empty id_token fails validation before the verifier
// runs.
func TestGoogleLoginValidation(t *testing.T) {
	srv, _ := newTestServer(t)
	rr := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodPost, "/v1/auth/google",
		bytes.NewReader([]byte(`{"id_token":""}`)))
	srv.ServeHTTP(rr, req)
	if rr.Code != http.StatusUnprocessableEntity {
		t.Fatalf("status: %d", rr.Code)
	}
}

// VerifyEmail with empty token is rejected.
func TestVerifyEmailValidation(t *testing.T) {
	srv, _ := newTestServer(t)
	rr := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodPost, "/v1/auth/verify-email",
		bytes.NewReader([]byte(`{"token":""}`)))
	srv.ServeHTTP(rr, req)
	if rr.Code != http.StatusUnprocessableEntity {
		t.Fatalf("status: %d", rr.Code)
	}
}

// Unknown route returns 404 (chi default), not 401 — the auth middleware
// only runs on registered routes.
func TestUnknownRoute(t *testing.T) {
	srv, _ := newTestServer(t)
	rr := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, "/v1/does-not-exist", nil)
	srv.ServeHTTP(rr, req)
	if rr.Code != http.StatusNotFound {
		t.Errorf("status: %d", rr.Code)
	}
}
