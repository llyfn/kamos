package observability

import (
	"testing"

	"github.com/getsentry/sentry-go"
)

// scrubEvent must redact Authorization + Cookie headers and the entire
// request body on the documented auth paths. Regression guard against the
// /v1/auth/refresh refresh-secret leak the Phase 2 QA report flagged.
func TestScrubEventRedactsAuthBodyAndHeaders(t *testing.T) {
	ev := &sentry.Event{
		Request: &sentry.Request{
			URL:    "/v1/auth/refresh",
			Method: "POST",
			Headers: map[string]string{
				"Authorization": "Bearer X",
				"Cookie":        "session=abc",
				"X-Request-ID":  "keep-me",
			},
			Data: `{"refresh_token":"sekret"}`,
		},
	}
	out := scrubEvent(ev, nil)
	if got := out.Request.Headers["Authorization"]; got != "[REDACTED]" {
		t.Errorf("Authorization header: got %q", got)
	}
	if got := out.Request.Headers["Cookie"]; got != "[REDACTED]" {
		t.Errorf("Cookie header: got %q", got)
	}
	if got := out.Request.Headers["X-Request-ID"]; got != "keep-me" {
		t.Errorf("non-sensitive header changed: got %q", got)
	}
	if got := out.Request.Data; got != "[REDACTED — auth path]" {
		t.Errorf("body: got %q", got)
	}
}

// Non-auth paths must keep their body intact (we still need the payload
// to debug API errors). Authorization is always redacted regardless.
func TestScrubEventLeavesNonAuthBodyAlone(t *testing.T) {
	ev := &sentry.Event{
		Request: &sentry.Request{
			URL:     "/v1/check-ins",
			Method:  "POST",
			Headers: map[string]string{"Authorization": "Bearer X"},
			Data:    `{"beverage_id":"bev-1"}`,
		},
	}
	out := scrubEvent(ev, nil)
	if got := out.Request.Headers["Authorization"]; got != "[REDACTED]" {
		t.Errorf("Authorization on non-auth path: got %q", got)
	}
	if got := out.Request.Data; got != `{"beverage_id":"bev-1"}` {
		t.Errorf("non-auth body changed: got %q", got)
	}
}

// Query strings on auth paths must not bypass the redaction.
func TestScrubEventHandlesQueryStringOnAuthPath(t *testing.T) {
	ev := &sentry.Event{
		Request: &sentry.Request{
			URL:  "/v1/auth/login?next=/feed",
			Data: `{"password":"hunter2"}`,
		},
	}
	out := scrubEvent(ev, nil)
	if got := out.Request.Data; got != "[REDACTED — auth path]" {
		t.Errorf("body with query string: got %q", got)
	}
}

// Nil event and nil Request must be safe.
func TestScrubEventNilSafe(t *testing.T) {
	if scrubEvent(nil, nil) != nil {
		t.Error("nil event must round-trip as nil")
	}
	ev := &sentry.Event{}
	if scrubEvent(ev, nil) != ev {
		t.Error("event with nil Request must round-trip unchanged")
	}
}
