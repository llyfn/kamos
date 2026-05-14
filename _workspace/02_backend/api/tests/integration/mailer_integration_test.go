//go:build integration
// +build integration

package integration

import (
	"bytes"
	"net/http"
	"strings"
	"testing"
	"time"
)

// Under the default test harness, RESEND_API_KEY is empty so the mailer is
// LogMailer. Registering a user must:
//   - succeed (no error from the mailer Send call),
//   - emit an INFO line containing the /verify?token= link (so dev can
//     copy/paste it from the logs),
//   - emit a "mail_logged" line with the user's email + subject so an
//     operator can see what would have shipped.
func TestRegisterEmitsVerificationLink(t *testing.T) {
	truncateAll(t)
	var logs bytes.Buffer
	srv := buildServerWithTTL(t, true, time.Hour, 30*24*time.Hour, &logs)
	defer srv.Close()

	body := map[string]any{
		"username":     "mailer1",
		"email":        "mailer1@example.com",
		"password":     "hunter2hunter2",
		"display_name": "Mailer One",
		"locale":       "en",
	}
	code, _ := doReq(t, srv, http.MethodPost, "/v1/auth/register", "", body)
	if code != http.StatusCreated {
		t.Fatalf("register: %d", code)
	}

	captured := logs.String()
	if !strings.Contains(captured, "/verify?token=") {
		t.Errorf("verification link not logged. captured: %s", captured)
	}
	if !strings.Contains(captured, "mail_logged") {
		t.Errorf("mail_logged INFO not emitted. captured: %s", captured)
	}
	if !strings.Contains(captured, "Verify your KAMOS email") {
		t.Errorf("English subject not in log. captured: %s", captured)
	}
}

// A Japanese-locale registration uses the JA template subject in the
// LogMailer line.
func TestRegisterUsesJapaneseSubjectForJALocale(t *testing.T) {
	truncateAll(t)
	var logs bytes.Buffer
	srv := buildServerWithTTL(t, true, time.Hour, 30*24*time.Hour, &logs)
	defer srv.Close()

	body := map[string]any{
		"username":     "mailerja",
		"email":        "mailerja@example.com",
		"password":     "hunter2hunter2",
		"display_name": "Mailer JA",
		"locale":       "ja",
	}
	code, _ := doReq(t, srv, http.MethodPost, "/v1/auth/register", "", body)
	if code != http.StatusCreated {
		t.Fatalf("register: %d", code)
	}
	if !strings.Contains(logs.String(), "KAMOSメールアドレスの確認") {
		t.Errorf("JA subject not in log: %s", logs.String())
	}
}
