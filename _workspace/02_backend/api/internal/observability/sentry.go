package observability

import (
	"fmt"
	"time"

	"github.com/getsentry/sentry-go"
	"github.com/kamos/api/internal/config"
)

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
	})
	if err != nil {
		return nil, fmt.Errorf("InitSentry: %w", err)
	}
	IsSentryEnabled = true
	return func(timeout time.Duration) {
		sentry.Flush(timeout)
	}, nil
}
