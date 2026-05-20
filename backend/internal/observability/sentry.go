package observability

import (
	"fmt"
	"strings"
	"time"

	"github.com/getsentry/sentry-go"

	"github.com/kamos/api/internal/config"
)

// sensitiveAuthPaths get their request body redacted in Sentry events.
// These endpoints accept credentials in the body (passwords, refresh
// tokens) and must never be sent to a third-party error-tracking vendor.
var sensitiveAuthPaths = map[string]struct{}{
	"/v1/auth/login":    {},
	"/v1/auth/register": {},
	"/v1/auth/refresh":  {},
	"/v1/auth/logout":   {},
}

// scrubEvent strips credential-bearing fields from a Sentry event before
// it leaves the process. Authorization and Cookie headers are always
// redacted; the request body is redacted entirely for sensitiveAuthPaths.
// Exported only for the unit test; not part of the public API.
func scrubEvent(event *sentry.Event, _ *sentry.EventHint) *sentry.Event {
	if event == nil || event.Request == nil {
		return event
	}
	// URL may include a query string; strip it before path comparison so
	// /v1/auth/login?foo=bar still matches.
	path := event.Request.URL
	if i := strings.Index(path, "?"); i >= 0 {
		path = path[:i]
	}
	if event.Request.Headers != nil {
		if _, ok := event.Request.Headers["Authorization"]; ok {
			event.Request.Headers["Authorization"] = "[REDACTED]"
		}
		if _, ok := event.Request.Headers["Cookie"]; ok {
			event.Request.Headers["Cookie"] = "[REDACTED]"
		}
	}
	if event.Request.Cookies != "" {
		event.Request.Cookies = "[REDACTED]"
	}
	if _, ok := sensitiveAuthPaths[path]; ok && event.Request.Data != "" {
		event.Request.Data = "[REDACTED — auth path]"
	}
	return event
}

// FlushFunc forwards any buffered events to Sentry. Always safe to call —
// it's a no-op when Sentry was never initialized.
type FlushFunc func(timeout time.Duration)

// IsSentryEnabled is set true once InitSentry successfully configures the
// SDK. Middleware uses this to decide whether to invoke sentry hooks. We
// avoid sentry.CurrentHub().Client() == nil checks inside hot paths.
var IsSentryEnabled bool

// InitSentry configures the SDK from cfg.SentryDSN. An empty DSN yields
// (no-op flush, nil) — no SDK init at all. We disable Sentry's own tracing
// because we ship traces via OTel; Sentry is errors-only here.
func InitSentry(cfg *config.Config) (FlushFunc, error) {
	if cfg.SentryDSN == "" {
		return func(time.Duration) {}, nil
	}
	err := sentry.Init(sentry.ClientOptions{
		Dsn:              cfg.SentryDSN,
		Environment:      cfg.Env,
		Release:          cfg.Version,
		EnableTracing:    false,
		TracesSampleRate: 0,
		BeforeSend:       scrubEvent,
	})
	if err != nil {
		return nil, fmt.Errorf("InitSentry: %w", err)
	}
	IsSentryEnabled = true
	return func(timeout time.Duration) {
		sentry.Flush(timeout)
	}, nil
}
