// Internal-package tests for VerifyEmailPage. The handler reaches into
// h.Repos.Users which is a concrete *UserRepo holding a (nil) pgx pool —
// any call would panic in the integration-suite sense. We thread a fake
// through the verifyEmailPageUsers seam instead so the test stays
// pgx-free, matching the handlers_internal_test.go style.
package handlers

import (
	"context"
	"io"
	"log/slog"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/kamos/api/internal/config"
	"github.com/kamos/api/internal/domain"
)

// fakeVerifyUsers is a minimal in-memory implementation of
// verifyEmailPageUsers driven by per-test closures.
type fakeVerifyUsers struct {
	findByToken func(ctx context.Context, token string) (string, error)
	findByID    func(ctx context.Context, id string) (*domain.User, error)
	mark        func(ctx context.Context, userID, token string) error

	markCalled int
}

func (f *fakeVerifyUsers) FindUserByVerificationToken(ctx context.Context, token string) (string, error) {
	return f.findByToken(ctx, token)
}
func (f *fakeVerifyUsers) FindByID(ctx context.Context, id string) (*domain.User, error) {
	return f.findByID(ctx, id)
}
func (f *fakeVerifyUsers) MarkEmailVerified(ctx context.Context, userID, token string) error {
	f.markCalled++
	if f.mark != nil {
		return f.mark(ctx, userID, token)
	}
	return nil
}

func newVerifyPageHandler() *Handler {
	return &Handler{
		Cfg: &config.Config{AppBaseURL: "http://localhost", Env: "test"},
		Log: slog.New(slog.NewTextHandler(io.Discard, nil)),
	}
}

// 200: valid unused token + unverified user → MarkEmailVerified called, page
// renders the "Verified" content in the requested locale.
func TestVerifyEmailPage_Success(t *testing.T) {
	h := newVerifyPageHandler()
	users := &fakeVerifyUsers{
		findByToken: func(_ context.Context, token string) (string, error) {
			if token != "good-token" {
				t.Fatalf("unexpected token %q", token)
			}
			return "u-1", nil
		},
		findByID: func(_ context.Context, id string) (*domain.User, error) {
			return &domain.User{ID: id, EmailVerified: false, Locale: "en"}, nil
		},
	}
	rr := httptest.NewRecorder()
	req := httptest.NewRequest("GET", "/verify?token=good-token", nil)
	h.verifyEmailPage(rr, req, users)

	if rr.Code != 200 {
		t.Fatalf("status: %d body=%s", rr.Code, rr.Body.String())
	}
	if got := rr.Header().Get("Content-Type"); !strings.HasPrefix(got, "text/html") {
		t.Errorf("Content-Type: %q", got)
	}
	if got := rr.Header().Get("Cache-Control"); got != "no-store" {
		t.Errorf("Cache-Control: %q", got)
	}
	if users.markCalled != 1 {
		t.Errorf("MarkEmailVerified called %d times, want 1", users.markCalled)
	}
	if !strings.Contains(rr.Body.String(), "Email verified") {
		t.Errorf("body missing en success copy: %s", rr.Body.String())
	}
}

// 200: token is still fresh but users.email_verified is already TRUE → render
// AlreadyVerified and DO NOT call MarkEmailVerified.
func TestVerifyEmailPage_AlreadyVerified(t *testing.T) {
	h := newVerifyPageHandler()
	users := &fakeVerifyUsers{
		findByToken: func(_ context.Context, _ string) (string, error) {
			return "u-1", nil
		},
		findByID: func(_ context.Context, id string) (*domain.User, error) {
			return &domain.User{ID: id, EmailVerified: true, Locale: "en"}, nil
		},
		mark: func(_ context.Context, _, _ string) error {
			t.Fatal("MarkEmailVerified must not be called when already verified")
			return nil
		},
	}
	rr := httptest.NewRecorder()
	req := httptest.NewRequest("GET", "/verify?token=good-token", nil)
	h.verifyEmailPage(rr, req, users)

	if rr.Code != 200 {
		t.Fatalf("status: %d", rr.Code)
	}
	if users.markCalled != 0 {
		t.Errorf("MarkEmailVerified call count: %d, want 0", users.markCalled)
	}
	if !strings.Contains(rr.Body.String(), "Already verified") {
		t.Errorf("body missing already-verified copy: %s", rr.Body.String())
	}
}

// 400: missing/empty token → Invalid screen, no repo calls.
func TestVerifyEmailPage_MissingToken(t *testing.T) {
	h := newVerifyPageHandler()
	users := &fakeVerifyUsers{
		findByToken: func(_ context.Context, _ string) (string, error) {
			t.Fatal("FindUserByVerificationToken must not be called when token is empty")
			return "", nil
		},
	}
	rr := httptest.NewRecorder()
	req := httptest.NewRequest("GET", "/verify", nil)
	h.verifyEmailPage(rr, req, users)

	if rr.Code != 400 {
		t.Fatalf("status: %d", rr.Code)
	}
	if !strings.Contains(rr.Body.String(), "Verification link invalid") {
		t.Errorf("body missing invalid copy: %s", rr.Body.String())
	}
}

// 400: token is unknown (FindUserByVerificationToken returns ErrTokenExpired
// per repository contract for "no row matched").
func TestVerifyEmailPage_UnknownToken(t *testing.T) {
	h := newVerifyPageHandler()
	users := &fakeVerifyUsers{
		findByToken: func(_ context.Context, _ string) (string, error) {
			return "", domain.ErrTokenExpired
		},
	}
	rr := httptest.NewRecorder()
	req := httptest.NewRequest("GET", "/verify?token=nope", nil)
	h.verifyEmailPage(rr, req, users)

	if rr.Code != 400 {
		t.Fatalf("status: %d", rr.Code)
	}
	if !strings.Contains(rr.Body.String(), "Verification link invalid") {
		t.Errorf("body missing invalid copy: %s", rr.Body.String())
	}
}

// Locale routing: ?lang=ja returns the ja template (distinctive Japanese
// success string), unspecified ?lang defaults to en.
func TestVerifyEmailPage_Locale(t *testing.T) {
	users := func() *fakeVerifyUsers {
		return &fakeVerifyUsers{
			findByToken: func(_ context.Context, _ string) (string, error) { return "u-1", nil },
			findByID: func(_ context.Context, id string) (*domain.User, error) {
				return &domain.User{ID: id, EmailVerified: false, Locale: "en"}, nil
			},
		}
	}

	t.Run("ja", func(t *testing.T) {
		h := newVerifyPageHandler()
		rr := httptest.NewRecorder()
		req := httptest.NewRequest("GET", "/verify?token=t&lang=ja", nil)
		h.verifyEmailPage(rr, req, users())
		if rr.Code != 200 {
			t.Fatalf("status: %d", rr.Code)
		}
		// ja template uses「メールアドレスを確認しました」
		if !strings.Contains(rr.Body.String(), "メールアドレスを確認しました") {
			t.Errorf("body missing ja success copy: %s", rr.Body.String())
		}
	})

	t.Run("default en", func(t *testing.T) {
		h := newVerifyPageHandler()
		rr := httptest.NewRecorder()
		req := httptest.NewRequest("GET", "/verify?token=t", nil)
		h.verifyEmailPage(rr, req, users())
		if rr.Code != 200 {
			t.Fatalf("status: %d", rr.Code)
		}
		if !strings.Contains(rr.Body.String(), "Email verified") {
			t.Errorf("body missing en success copy: %s", rr.Body.String())
		}
	})

	t.Run("unsupported falls back to en", func(t *testing.T) {
		h := newVerifyPageHandler()
		rr := httptest.NewRecorder()
		req := httptest.NewRequest("GET", "/verify?token=t&lang=zh", nil)
		h.verifyEmailPage(rr, req, users())
		if rr.Code != 200 {
			t.Fatalf("status: %d", rr.Code)
		}
		if !strings.Contains(rr.Body.String(), "Email verified") {
			t.Errorf("body missing en success copy: %s", rr.Body.String())
		}
	})
}
