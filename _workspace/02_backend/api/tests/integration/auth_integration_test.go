//go:build integration
// +build integration

package integration

import (
	"encoding/json"
	"net/http"
	"strings"
	"testing"
)

// register → login → /v1/users/me returns the caller's email; the public
// profile endpoint MUST NOT return email (M3 invariant).
func TestAuthFullRoundtrip(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	const (
		uname = "yamamoto"
		email = "yamamoto@example.com"
		pwd   = "hunter2hunter2"
	)
	tok, userID := mustRegister(t, srv, uname, email, pwd)
	if userID == "" || tok == "" {
		t.Fatalf("register returned empty values")
	}

	// Login with the same creds succeeds and issues a fresh token.
	tok2 := mustLogin(t, srv, email, pwd)
	if tok2 == "" {
		t.Fatalf("login returned empty token")
	}

	// /v1/users/me uses the JWT we got back.
	code, body := doReq(t, srv, http.MethodGet, "/v1/users/me", tok2, nil)
	if code != http.StatusOK {
		t.Fatalf("GET /v1/users/me: status=%d body=%s", code, body)
	}
	var me map[string]any
	if err := json.Unmarshal(body, &me); err != nil {
		t.Fatalf("decode me: %v", err)
	}
	if got, _ := me["email"].(string); got != email {
		t.Errorf("/v1/users/me email: got %v want %s", me["email"], email)
	}
	if got, _ := me["username"].(string); got != uname {
		t.Errorf("/v1/users/me username: got %v want %s", me["username"], uname)
	}

	// The public profile endpoint MUST NOT include `email` or
	// `email_verified` (M3 fix).
	code, body = doReq(t, srv, http.MethodGet, "/v1/users/"+uname, "", nil)
	if code != http.StatusOK {
		t.Fatalf("GET /v1/users/%s: status=%d body=%s", uname, code, body)
	}
	s := string(body)
	for _, leak := range []string{`"email"`, `"email_verified"`, email} {
		if strings.Contains(s, leak) {
			t.Errorf("public profile leaks %q: %s", leak, s)
		}
	}
}

// Login with a wrong password is rejected with 401 + INVALID_CREDENTIAL.
func TestLoginInvalidCredentials(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	mustRegister(t, srv, "ham", "ham@example.com", "supersecret1")
	code, body := doReq(t, srv, http.MethodPost, "/v1/auth/login", "", map[string]string{
		"email":    "ham@example.com",
		"password": "wrong-password",
	})
	if code != http.StatusUnauthorized {
		t.Fatalf("status: %d body=%s", code, body)
	}
	var e map[string]any
	_ = json.Unmarshal(body, &e)
	if e["code"] != "INVALID_CREDENTIAL" {
		t.Errorf("code: %v", e["code"])
	}
}

// Re-using the same username is rejected with 409 USERNAME_HELD.
func TestRegisterUsernameConflict(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	mustRegister(t, srv, "dupe", "first@example.com", "password11")
	code, body := doReq(t, srv, http.MethodPost, "/v1/auth/register", "", map[string]any{
		"username":     "dupe",
		"email":        "second@example.com",
		"password":     "password22",
		"display_name": "dupe",
		"locale":       "en",
	})
	if code != http.StatusConflict {
		t.Fatalf("status: %d body=%s", code, body)
	}
	var e map[string]any
	_ = json.Unmarshal(body, &e)
	if e["code"] != "USERNAME_HELD" {
		t.Errorf("code: %v", e["code"])
	}
}

// Re-using the same email is rejected with 409 EMAIL_TAKEN.
func TestRegisterEmailConflict(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	mustRegister(t, srv, "first", "shared@example.com", "password11")
	code, body := doReq(t, srv, http.MethodPost, "/v1/auth/register", "", map[string]any{
		"username":     "second",
		"email":        "shared@example.com",
		"password":     "password22",
		"display_name": "second",
		"locale":       "en",
	})
	if code != http.StatusConflict {
		t.Fatalf("status: %d body=%s", code, body)
	}
	var e map[string]any
	_ = json.Unmarshal(body, &e)
	if e["code"] != "EMAIL_TAKEN" {
		t.Errorf("code: %v", e["code"])
	}
}
