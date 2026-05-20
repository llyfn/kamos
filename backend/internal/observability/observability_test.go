package observability

import (
	"context"
	"testing"
	"time"

	"github.com/kamos/api/internal/config"
)

// InitOTel returns immediately (no-op shutdown, nil error) when
// OTEL_EXPORTER_OTLP_ENDPOINT is empty. This is the "vendor disabled"
// path that must work on every dev machine.
func TestInitOTelDisabledWhenEndpointEmpty(t *testing.T) {
	shutdown, err := InitOTel(context.Background(), &config.Config{})
	if err != nil {
		t.Fatalf("InitOTel disabled: %v", err)
	}
	if shutdown == nil {
		t.Fatalf("shutdown is nil")
	}
	if err := shutdown(context.Background()); err != nil {
		t.Errorf("no-op shutdown returned error: %v", err)
	}
}

// InitSentry returns (no-op flush, nil) when SENTRY_DSN is empty. We
// also confirm IsSentryEnabled stays false.
func TestInitSentryDisabledWhenDSNEmpty(t *testing.T) {
	IsSentryEnabled = false
	flush, err := InitSentry(&config.Config{})
	if err != nil {
		t.Fatalf("InitSentry disabled: %v", err)
	}
	if flush == nil {
		t.Fatalf("flush is nil")
	}
	flush(time.Millisecond) // must not panic
	if IsSentryEnabled {
		t.Errorf("IsSentryEnabled flipped true with empty DSN")
	}
}

// parseHeaders handles the three documented shapes: empty, single pair,
// multi-pair with whitespace. Malformed entries are silently skipped.
func TestParseHeaders(t *testing.T) {
	cases := []struct {
		name string
		in   string
		want map[string]string
	}{
		{"empty", "", nil},
		{"single", "Authorization=Basic abc", map[string]string{"Authorization": "Basic abc"}},
		{"multi", " a=1 , b=2 ", map[string]string{"a": "1", "b": "2"}},
		{"malformed dropped", "good=1,bad", map[string]string{"good": "1"}},
		{"empty key dropped", "=v,k=1", map[string]string{"k": "1"}},
	}
	for _, tc := range cases {
		tc := tc
		t.Run(tc.name, func(t *testing.T) {
			got := parseHeaders(tc.in)
			if tc.want == nil {
				if got != nil {
					t.Errorf("want nil, got %v", got)
				}
				return
			}
			if len(got) != len(tc.want) {
				t.Fatalf("len: got %v want %v", got, tc.want)
			}
			for k, v := range tc.want {
				if got[k] != v {
					t.Errorf("%q: got %q want %q", k, got[k], v)
				}
			}
		})
	}
}

// parseEndpoint strips http/https and any trailing path, and reports
// whether the scheme was secure.
func TestParseEndpoint(t *testing.T) {
	cases := []struct {
		in         string
		wantHost   string
		wantSecure bool
	}{
		{"https://otlp-gateway.grafana.net/otlp", "otlp-gateway.grafana.net", true},
		{"http://localhost:4318", "localhost:4318", false},
		{"localhost:4318", "localhost:4318", true},
	}
	for _, tc := range cases {
		tc := tc
		t.Run(tc.in, func(t *testing.T) {
			host, secure := parseEndpoint(tc.in)
			if host != tc.wantHost {
				t.Errorf("host: got %q want %q", host, tc.wantHost)
			}
			if secure != tc.wantSecure {
				t.Errorf("secure: got %v want %v", secure, tc.wantSecure)
			}
		})
	}
}
