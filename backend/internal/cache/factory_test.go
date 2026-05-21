package cache

import (
	"io"
	"log/slog"
	"testing"

	"github.com/kamos/api/internal/config"
)

func discardLogger() *slog.Logger {
	return slog.New(slog.NewTextHandler(io.Discard, nil))
}

func TestNewBackendDefaultsToInProcess(t *testing.T) {
	cfg := &config.Config{CacheBackend: "in_process", Env: "dev"}
	b, err := NewBackend(cfg, discardLogger())
	if err != nil {
		t.Fatalf("NewBackend: %v", err)
	}
	defer b.Close()
	if _, ok := b.(*InProcessBackend); !ok {
		t.Fatalf("want *InProcessBackend, got %T", b)
	}
}

func TestNewBackendEmptyBackendDefaultsToInProcess(t *testing.T) {
	cfg := &config.Config{CacheBackend: "", Env: "dev"}
	b, err := NewBackend(cfg, discardLogger())
	if err != nil {
		t.Fatalf("NewBackend: %v", err)
	}
	defer b.Close()
	if _, ok := b.(*InProcessBackend); !ok {
		t.Fatalf("want *InProcessBackend, got %T", b)
	}
}

func TestNewBackendRedisRequiresURL(t *testing.T) {
	cfg := &config.Config{CacheBackend: "redis", CacheRedisURL: "", Env: "dev"}
	b, err := NewBackend(cfg, discardLogger())
	if err == nil {
		_ = b.Close()
		t.Fatalf("expected error when CACHE_BACKEND=redis without URL")
	}
}

func TestNewBackendUnknownRejected(t *testing.T) {
	cfg := &config.Config{CacheBackend: "memcache", Env: "dev"}
	b, err := NewBackend(cfg, discardLogger())
	if err == nil {
		_ = b.Close()
		t.Fatalf("expected error for unknown backend")
	}
}

func TestNewBackendNilConfig(t *testing.T) {
	b, err := NewBackend(nil, discardLogger())
	if err != nil {
		t.Fatalf("NewBackend(nil): %v", err)
	}
	defer b.Close()
	if _, ok := b.(*InProcessBackend); !ok {
		t.Fatalf("want *InProcessBackend, got %T", b)
	}
}
