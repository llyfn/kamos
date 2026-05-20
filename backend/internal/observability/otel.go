// Package observability wires OpenTelemetry traces + metrics and Sentry
// error reporting. Both are feature-flag gated: missing env vars mean the
// SDK is never initialized, the server boots cleanly, and the returned
// shutdown/flush callbacks are no-ops.
package observability

import (
	"context"
	"fmt"
	"strings"
	"time"

	"github.com/kamos/api/internal/config"

	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/exporters/otlp/otlpmetric/otlpmetrichttp"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp"
	"go.opentelemetry.io/otel/propagation"
	"go.opentelemetry.io/otel/sdk/metric"
	"go.opentelemetry.io/otel/sdk/resource"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	semconv "go.opentelemetry.io/otel/semconv/v1.26.0"
)

// ShutdownFunc flushes any pending telemetry. Always safe to call, even
// when the SDK was never initialized.
type ShutdownFunc func(context.Context) error

// InitOTel wires the OTLP trace + metric exporters. If cfg.OTLPEndpoint
// is empty, this returns an immediate no-op shutdown and nil — no SDK
// init at all, no warnings, no degraded behavior.
//
// Endpoint format follows the OTel spec: a host (and optional port) the
// HTTP exporter dials. We split off any scheme and forward the rest to
// the exporter — Grafana Cloud and the OpenTelemetry Collector both
// accept e.g. "otlp-gateway-prod-eu-west-2.grafana.net".
func InitOTel(ctx context.Context, cfg *config.Config) (ShutdownFunc, error) {
	if cfg.OTLPEndpoint == "" {
		return func(context.Context) error { return nil }, nil
	}

	res, err := resource.New(ctx,
		resource.WithAttributes(
			semconv.ServiceName("kamos-api"),
			semconv.ServiceVersion(cfg.Version),
			semconv.DeploymentEnvironment(cfg.Env),
		),
	)
	if err != nil {
		return nil, fmt.Errorf("InitOTel: resource: %w", err)
	}

	endpoint, secure := parseEndpoint(cfg.OTLPEndpoint)
	headers := parseHeaders(cfg.OTLPHeaders)

	traceOpts := []otlptracehttp.Option{
		otlptracehttp.WithEndpoint(endpoint),
		otlptracehttp.WithHeaders(headers),
	}
	if !secure {
		traceOpts = append(traceOpts, otlptracehttp.WithInsecure())
	}
	traceExp, err := otlptracehttp.New(ctx, traceOpts...)
	if err != nil {
		return nil, fmt.Errorf("InitOTel: trace exporter: %w", err)
	}
	tp := sdktrace.NewTracerProvider(
		sdktrace.WithBatcher(traceExp),
		sdktrace.WithResource(res),
	)
	otel.SetTracerProvider(tp)
	otel.SetTextMapPropagator(propagation.NewCompositeTextMapPropagator(
		propagation.TraceContext{},
		propagation.Baggage{},
	))

	metricOpts := []otlpmetrichttp.Option{
		otlpmetrichttp.WithEndpoint(endpoint),
		otlpmetrichttp.WithHeaders(headers),
	}
	if !secure {
		metricOpts = append(metricOpts, otlpmetrichttp.WithInsecure())
	}
	metricExp, err := otlpmetrichttp.New(ctx, metricOpts...)
	if err != nil {
		// Best effort to stop the trace provider; we are about to fail anyway.
		_ = tp.Shutdown(ctx)
		return nil, fmt.Errorf("InitOTel: metric exporter: %w", err)
	}
	mp := metric.NewMeterProvider(
		metric.WithResource(res),
		metric.WithReader(metric.NewPeriodicReader(metricExp)),
	)
	otel.SetMeterProvider(mp)

	shutdown := func(parent context.Context) error {
		ctx, cancel := context.WithTimeout(parent, 5*time.Second)
		defer cancel()
		var firstErr error
		if err := tp.Shutdown(ctx); err != nil && firstErr == nil {
			firstErr = fmt.Errorf("trace shutdown: %w", err)
		}
		if err := mp.Shutdown(ctx); err != nil && firstErr == nil {
			firstErr = fmt.Errorf("metric shutdown: %w", err)
		}
		return firstErr
	}
	return shutdown, nil
}

// parseEndpoint strips scheme from a URL-style endpoint and reports whether
// the original was https. The OTLP HTTP exporter wants a bare host[:port].
func parseEndpoint(raw string) (host string, secure bool) {
	host = raw
	secure = true
	switch {
	case strings.HasPrefix(raw, "https://"):
		host = strings.TrimPrefix(raw, "https://")
	case strings.HasPrefix(raw, "http://"):
		host = strings.TrimPrefix(raw, "http://")
		secure = false
	}
	// Drop any trailing path / slashes; the exporter appends "/v1/traces" etc.
	if i := strings.IndexAny(host, "/?"); i >= 0 {
		host = host[:i]
	}
	return host, secure
}

// parseHeaders decodes a "k1=v1,k2=v2" string into a header map. Empty input
// yields a nil map. Malformed pairs are skipped silently — operators get
// log lines from the exporter if auth fails, no need to also fail boot.
func parseHeaders(raw string) map[string]string {
	if raw == "" {
		return nil
	}
	out := make(map[string]string)
	for _, pair := range strings.Split(raw, ",") {
		pair = strings.TrimSpace(pair)
		if pair == "" {
			continue
		}
		i := strings.Index(pair, "=")
		if i <= 0 {
			continue
		}
		k := strings.TrimSpace(pair[:i])
		v := strings.TrimSpace(pair[i+1:])
		if k != "" {
			out[k] = v
		}
	}
	return out
}
