package middleware

import (
	"net/http"
	"net/http/httptest"
	"testing"
)

func okNext() http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusOK)
	})
}

func TestRequireCSRF_GetPassesThrough(t *testing.T) {
	h := RequireCSRF(okNext())
	w := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, "/v1/admin/users", nil)
	h.ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Fatalf("GET status=%d, want 200", w.Code)
	}
}

func TestRequireCSRF_PostRejectsMissingHeader(t *testing.T) {
	h := RequireCSRF(okNext())
	w := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodPost, "/v1/admin/x", nil)
	req.AddCookie(&http.Cookie{Name: adminCSRFCookie, Value: "abc"})
	h.ServeHTTP(w, req)
	if w.Code != http.StatusForbidden {
		t.Fatalf("missing header status=%d, want 403", w.Code)
	}
}

func TestRequireCSRF_PostRejectsMissingCookie(t *testing.T) {
	h := RequireCSRF(okNext())
	w := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodPost, "/v1/admin/x", nil)
	req.Header.Set(csrfHeader, "abc")
	h.ServeHTTP(w, req)
	if w.Code != http.StatusForbidden {
		t.Fatalf("missing cookie status=%d, want 403", w.Code)
	}
}

func TestRequireCSRF_PostRejectsMismatch(t *testing.T) {
	h := RequireCSRF(okNext())
	w := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodPost, "/v1/admin/x", nil)
	req.AddCookie(&http.Cookie{Name: adminCSRFCookie, Value: "abc"})
	req.Header.Set(csrfHeader, "xyz")
	h.ServeHTTP(w, req)
	if w.Code != http.StatusForbidden {
		t.Fatalf("mismatch status=%d, want 403", w.Code)
	}
}

func TestRequireCSRF_PostAcceptsMatch(t *testing.T) {
	h := RequireCSRF(okNext())
	w := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodPost, "/v1/admin/x", nil)
	req.AddCookie(&http.Cookie{Name: adminCSRFCookie, Value: "abc"})
	req.Header.Set(csrfHeader, "abc")
	h.ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Fatalf("match status=%d, want 200", w.Code)
	}
}

func TestRequireCSRF_PostAcceptsURLEncodedMatch(t *testing.T) {
	h := RequireCSRF(okNext())
	w := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodPost, "/v1/admin/x", nil)
	// Some proxies URL-encode cookie values; the middleware must tolerate
	// "%2F" on either side as long as the decoded form matches.
	req.AddCookie(&http.Cookie{Name: adminCSRFCookie, Value: "ab%2Fc"})
	req.Header.Set(csrfHeader, "ab/c")
	h.ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Fatalf("url-encoded match status=%d, want 200", w.Code)
	}
}
