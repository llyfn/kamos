package httperr

import (
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/kamos/api/internal/domain"
)

// decodeBody decodes an error response into an APIError.
func decodeBody(t *testing.T, body io.Reader) APIError {
	t.Helper()
	var e APIError
	if err := json.NewDecoder(body).Decode(&e); err != nil {
		t.Fatalf("decode body: %v", err)
	}
	return e
}

func TestWriteJSONStatusAndContentType(t *testing.T) {
	rr := httptest.NewRecorder()
	WriteJSON(rr, http.StatusAccepted, map[string]int{"x": 1})
	if rr.Code != http.StatusAccepted {
		t.Errorf("status: got %d want %d", rr.Code, http.StatusAccepted)
	}
	if ct := rr.Header().Get("Content-Type"); ct != "application/json" {
		t.Errorf("Content-Type: %q", ct)
	}
}

func TestWriteJSONNilBody(t *testing.T) {
	rr := httptest.NewRecorder()
	WriteJSON(rr, http.StatusNoContent, nil)
	if rr.Code != http.StatusNoContent {
		t.Errorf("status: %d", rr.Code)
	}
	if rr.Body.Len() != 0 {
		t.Errorf("nil body should not write any bytes; got %q", rr.Body.String())
	}
}

func TestWriteErrorShape(t *testing.T) {
	rr := httptest.NewRecorder()
	WriteError(rr, http.StatusTeapot, "TEAPOT", "i am a teapot")
	if rr.Code != http.StatusTeapot {
		t.Fatalf("status: %d", rr.Code)
	}
	got := decodeBody(t, rr.Body)
	if got.Code != "TEAPOT" || got.Error != "i am a teapot" {
		t.Errorf("body: %+v", got)
	}
}

// Each sentinel must map to the expected status code AND code field.
func TestWriteFromSentinels(t *testing.T) {
	cases := []struct {
		name       string
		err        error
		wantStatus int
		wantCode   string
	}{
		{"unauthorized", domain.ErrUnauthorized, http.StatusUnauthorized, "UNAUTHORIZED"},
		{"forbidden", domain.ErrForbidden, http.StatusForbidden, "FORBIDDEN"},
		{"not_found", domain.ErrNotFound, http.StatusNotFound, "NOT_FOUND"},
		{"beverage_not_found", domain.ErrBeverageNotFound, http.StatusNotFound, "NOT_FOUND"},
		{"checkin_not_found", domain.ErrCheckinNotFound, http.StatusNotFound, "NOT_FOUND"},
		{"conflict", domain.ErrConflict, http.StatusConflict, "CONFLICT"},
		{"username_held", domain.ErrUsernameHeld, http.StatusConflict, "USERNAME_HELD"},
		{"email_taken", domain.ErrEmailTaken, http.StatusConflict, "EMAIL_TAKEN"},
		{"validation", domain.ErrValidation, http.StatusUnprocessableEntity, "VALIDATION"},
		{"photo_cap", domain.ErrPhotoCapExceeded, http.StatusUnprocessableEntity, "PHOTO_CAP_EXCEEDED"},
		{"collection_full", domain.ErrCollectionFull, http.StatusUnprocessableEntity, "COLLECTION_FULL"},
		{"follow_self", domain.ErrFollowSelf, http.StatusUnprocessableEntity, "FOLLOW_SELF"},
		{"bad_request", domain.ErrBadRequest, http.StatusBadRequest, "BAD_REQUEST"},
		{"invalid_credential", domain.ErrInvalidCredential, http.StatusUnauthorized, "INVALID_CREDENTIAL"},
		{"token_expired", domain.ErrTokenExpired, http.StatusGone, "TOKEN_EXPIRED"},
		{"rate_limited", domain.ErrRateLimited, http.StatusTooManyRequests, "RATE_LIMITED"},
	}
	log := slog.New(slog.NewTextHandler(io.Discard, nil))
	for _, tc := range cases {
		tc := tc
		t.Run(tc.name, func(t *testing.T) {
			rr := httptest.NewRecorder()
			WriteFrom(rr, log, "op", tc.err)
			if rr.Code != tc.wantStatus {
				t.Errorf("status: got %d want %d", rr.Code, tc.wantStatus)
			}
			body := decodeBody(t, rr.Body)
			if body.Code != tc.wantCode {
				t.Errorf("code: got %q want %q", body.Code, tc.wantCode)
			}
			if body.Error == "" {
				t.Errorf("error field is empty")
			}
		})
	}
}

// Wrapped sentinels are recognized via errors.Is.
func TestWriteFromWrappedSentinel(t *testing.T) {
	rr := httptest.NewRecorder()
	log := slog.New(slog.NewTextHandler(io.Discard, nil))
	WriteFrom(rr, log, "op", fmt.Errorf("Foo.Bar: %w", domain.ErrNotFound))
	if rr.Code != http.StatusNotFound {
		t.Errorf("status: %d", rr.Code)
	}
}

// Unknown errors map to a generic 500 with code INTERNAL and a "internal
// error" message — the underlying error MUST NOT leak to the client.
func TestWriteFromUnknownGenericFiveHundred(t *testing.T) {
	rr := httptest.NewRecorder()
	log := slog.New(slog.NewTextHandler(io.Discard, nil))
	leaky := errors.New("secret database password is hunter2")
	WriteFrom(rr, log, "op", leaky)
	if rr.Code != http.StatusInternalServerError {
		t.Errorf("status: %d", rr.Code)
	}
	got := decodeBody(t, rr.Body)
	if got.Code != "INTERNAL" {
		t.Errorf("code: %q", got.Code)
	}
	if got.Error != "internal error" {
		t.Errorf("client-visible message should be generic, got %q", got.Error)
	}
	// Critically: the original message must not appear on the wire.
	if got.Error == leaky.Error() {
		t.Errorf("internal error leaked to client")
	}
}

// codeOf returns a stable string for every named conflict / validation
// sentinel; the default branch is "ERROR".
func TestCodeOfDefault(t *testing.T) {
	if c := codeOf(errors.New("random")); c != "ERROR" {
		t.Errorf("codeOf default: %q", c)
	}
}

// New helpers introduced in Stage 3: cover each of the four convenience
// shortcuts.
func TestWriteHelpersShape(t *testing.T) {
	cases := []struct {
		name string
		fn   func(http.ResponseWriter)
		want APIError
		code int
	}{
		{"unauthorized", WriteUnauthorized, APIError{Error: "unauthorized", Code: "UNAUTHORIZED"}, http.StatusUnauthorized},
		{"forbidden", WriteForbidden, APIError{Error: "forbidden", Code: "FORBIDDEN"}, http.StatusForbidden},
		{"not_found", WriteNotFound, APIError{Error: "not found", Code: "NOT_FOUND"}, http.StatusNotFound},
	}
	for _, tc := range cases {
		tc := tc
		t.Run(tc.name, func(t *testing.T) {
			rr := httptest.NewRecorder()
			tc.fn(rr)
			if rr.Code != tc.code {
				t.Errorf("status: got %d want %d", rr.Code, tc.code)
			}
			got := decodeBody(t, rr.Body)
			if got != tc.want {
				t.Errorf("body: got %+v want %+v", got, tc.want)
			}
		})
	}
	// WriteValidation has a parameter.
	rr := httptest.NewRecorder()
	WriteValidation(rr, "bad field")
	if rr.Code != http.StatusUnprocessableEntity {
		t.Errorf("validation status: %d", rr.Code)
	}
	got := decodeBody(t, rr.Body)
	if got.Code != "VALIDATION" || got.Error != "bad field" {
		t.Errorf("validation body: %+v", got)
	}
}
