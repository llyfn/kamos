package handlers_test

import (
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

// newVenueTestServer mirrors newTestServer in handlers_test.go but is local
// to keep this file independent. Repositories are nil-backed; only handlers
// that short-circuit at validation reach return without panic.
func newVenueTestServer(t *testing.T) (http.Handler, *auth.Signer) {
	t.Helper()
	cfg := &config.Config{
		AppBaseURL: "http://localhost",
		JWTSecret:  "test-secret-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
		JWTTTL:     time.Hour,
		Env:        "test",
		// Disable rate-limit middleware in this handler-only test harness.
		RateLimitDisabled: true,
	}
	signer := auth.NewSigner(cfg.JWTSecret, cfg.JWTTTL)
	log := slog.New(slog.NewTextHandler(io.Discard, nil))
	repos := &repository.Repos{
		Users:         &repository.UserRepo{},
		Beverages:     &repository.BeverageRepo{},
		Breweries:     &repository.BreweryRepo{},
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
	// SEC-006: nil softDelete — handler-only tests don't bring up the cache.
	return server.New(log, signer, nil, h), signer
}

type venuesErrBody struct {
	Error string `json:"error"`
	Code  string `json:"code"`
}

func decodeVenueErr(t *testing.T, body io.Reader) venuesErrBody {
	t.Helper()
	var e venuesErrBody
	if err := json.NewDecoder(body).Decode(&e); err != nil {
		t.Fatalf("decode body: %v", err)
	}
	return e
}

// Empty `q` is rejected at the handler with 422 VALIDATION.
func TestVenueSearch_EmptyQuery(t *testing.T) {
	srv, signer := newVenueTestServer(t)
	tok, _ := signer.Sign("u-1", "yamamoto")
	rr := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, "/v1/venues/search?q=", nil)
	req.Header.Set("Authorization", "Bearer "+tok)
	srv.ServeHTTP(rr, req)
	if rr.Code != http.StatusUnprocessableEntity {
		t.Fatalf("status: %d body=%s", rr.Code, rr.Body.String())
	}
	body := decodeVenueErr(t, rr.Body)
	if body.Code != "VALIDATION" {
		t.Errorf("code: %q", body.Code)
	}
}

// SEC-007: `q` longer than 100 runes is rejected with 422 VALIDATION before
// the Foursquare client is ever consulted.
func TestVenueSearch_QueryTooLong(t *testing.T) {
	srv, signer := newVenueTestServer(t)
	tok, _ := signer.Sign("u-1", "yamamoto")
	bigQ := strings.Repeat("a", 101)
	rr := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, "/v1/venues/search?q="+bigQ, nil)
	req.Header.Set("Authorization", "Bearer "+tok)
	srv.ServeHTTP(rr, req)
	if rr.Code != http.StatusUnprocessableEntity {
		t.Fatalf("status: %d body=%s", rr.Code, rr.Body.String())
	}
	body := decodeVenueErr(t, rr.Body)
	if body.Code != "VALIDATION" {
		t.Errorf("code: %q", body.Code)
	}
	if !strings.Contains(body.Error, "too long") {
		t.Errorf("error message: %q", body.Error)
	}
}

// lat without lng is a 422 before any upstream call.
func TestVenueSearch_LatWithoutLng(t *testing.T) {
	srv, signer := newVenueTestServer(t)
	tok, _ := signer.Sign("u-1", "yamamoto")
	rr := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, "/v1/venues/search?q=daikoku&lat=35.6", nil)
	req.Header.Set("Authorization", "Bearer "+tok)
	srv.ServeHTTP(rr, req)
	if rr.Code != http.StatusUnprocessableEntity {
		t.Fatalf("status: %d body=%s", rr.Code, rr.Body.String())
	}
	body := decodeVenueErr(t, rr.Body)
	if body.Code != "VALIDATION" {
		t.Errorf("code: %q", body.Code)
	}
}
