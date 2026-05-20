package middleware

import (
	"log/slog"
	"net/http"

	"github.com/getsentry/sentry-go"
	"github.com/go-chi/chi/v5"

	"github.com/kamos/api/internal/httperr"
	"github.com/kamos/api/internal/observability"

	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/codes"
	"go.opentelemetry.io/otel/trace"
)

// tracerName is fixed; we don't want a per-handler tracer fan-out.
const tracerName = "github.com/kamos/api"

// Trace wraps each request in a span. The span name uses the chi route
// pattern (e.g. "HTTP GET /v1/users/{username}") so cardinality stays
// bounded. Status code, method, route, and request id are recorded.
//
// When OTel is disabled this is effectively a no-op: the global
// TracerProvider is the default noop provider, so Start() returns a
// non-recording span. We still wrap to keep the middleware chain stable.
func Trace(next http.Handler) http.Handler {
	tr := otel.Tracer(tracerName)
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Pull the chi route pattern after routing — chi populates it.
		// We need to defer the span name until then, so we start with a
		// placeholder and rename via SpanFromContext after ServeHTTP.
		// Stage 5 (PERF-030): `http.target` (raw URL path) is high-
		// cardinality — every UUID in /v1/check-ins/{id} blows up the
		// span attribute set in OTel and the search index downstream.
		// We start the span with just the method, then attach the
		// chi-resolved route pattern as `http.route` after the handler
		// runs (see below).
		ctx, span := tr.Start(r.Context(), "HTTP "+r.Method,
			trace.WithSpanKind(trace.SpanKindServer),
			trace.WithAttributes(
				attribute.String("http.method", r.Method),
			),
		)
		defer span.End()

		if rid := RequestIDFromContext(r.Context()); rid != "" {
			span.SetAttributes(attribute.String("kamos.request_id", rid))
		}

		sr := &statusRecorder{ResponseWriter: w}
		next.ServeHTTP(sr, r.WithContext(ctx))

		// Resolve the chi route AFTER the handler ran. Chi only populates
		// RoutePattern() once routing has matched.
		if rc := chi.RouteContext(r.Context()); rc != nil {
			if pattern := rc.RoutePattern(); pattern != "" {
				span.SetName("HTTP " + r.Method + " " + pattern)
				span.SetAttributes(attribute.String("http.route", pattern))
			}
		}
		status := sr.status
		if status == 0 {
			status = http.StatusOK
		}
		span.SetAttributes(attribute.Int("http.status_code", status))
		if status >= 500 {
			span.SetStatus(codes.Error, http.StatusText(status))
		}
	})
}

// RecoverWithSentry is a drop-in replacement for Recover that also forwards
// the panic to Sentry when configured. When Sentry is disabled the Sentry
// call is skipped — no warning, no degraded behavior.
func RecoverWithSentry(log *slog.Logger) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			defer func() {
				if rec := recover(); rec != nil {
					if observability.IsSentryEnabled {
						hub := sentry.CurrentHub().Clone()
						hub.RecoverWithContext(r.Context(), rec)
					}
					log.Error("panic",
						"err", rec,
						"path", r.URL.Path,
						"method", r.Method,
						"request_id", RequestIDFromContext(r.Context()),
					)
					httperr.WriteError(w, http.StatusInternalServerError, "INTERNAL", "internal error")
				}
			}()
			next.ServeHTTP(w, r)
		})
	}
}
