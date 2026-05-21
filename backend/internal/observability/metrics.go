package observability

import (
	"context"
	"sync"

	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/metric"
)

const meterName = "github.com/kamos/api"

// One counter for . The roadmap calls for keeping this small; new
// counters live in this file as the surface grows.
var (
	metricsOnce            sync.Once
	checkinsCreatedCounter metric.Int64Counter
)

// initMetrics is lazy + idempotent: the first call resolves the global
// meter (works whether OTel is enabled or not — the default meter
// provider is a noop). Subsequent calls reuse the cached counter.
func initMetrics() {
	metricsOnce.Do(func() {
		meter := otel.Meter(meterName)
		c, err := meter.Int64Counter(
			"checkins_created_total",
			metric.WithDescription("Number of check-ins successfully created."),
		)
		if err == nil {
			checkinsCreatedCounter = c
		}
		// On error the counter stays nil; IncCheckinsCreated below guards
		// for that so callers don't have to.
	})
}

// IncCheckinsCreated bumps the check-ins-created counter by 1. Safe to
// call from any goroutine, safe to call before OTel is initialized
// (defaults to a noop counter).
func IncCheckinsCreated(ctx context.Context) {
	initMetrics()
	if checkinsCreatedCounter == nil {
		return
	}
	checkinsCreatedCounter.Add(ctx, 1)
}
