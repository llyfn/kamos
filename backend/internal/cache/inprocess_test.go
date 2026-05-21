package cache

import (
	"context"
	"testing"
	"time"
)

func TestInProcessBackendGetSet(t *testing.T) {
	b := NewInProcessBackend(nil)
	ctx := context.Background()

	// Miss: empty cache.
	if v, ok, err := b.Get(ctx, "nope"); err != nil || ok || v != nil {
		t.Fatalf("miss path: got (%q, %v, %v)", v, ok, err)
	}
	if err := b.Set(ctx, "k", []byte("v"), time.Minute); err != nil {
		t.Fatalf("Set: %v", err)
	}
	// Hit: same key returns the value.
	v, ok, err := b.Get(ctx, "k")
	if err != nil || !ok || string(v) != "v" {
		t.Fatalf("hit path: got (%q, %v, %v)", v, ok, err)
	}

	hits, misses := b.Stats()
	if hits != 1 {
		t.Fatalf("hits: want 1, got %d", hits)
	}
	if misses != 1 {
		t.Fatalf("misses: want 1, got %d", misses)
	}
}

func TestInProcessBackendDeletePrefix(t *testing.T) {
	b := NewInProcessBackend(nil)
	ctx := context.Background()

	for k, v := range map[string]string{
		"bev:1:en": "a",
		"bev:1:ja": "b",
		"bev:1:ko": "c",
		"bev:2:en": "d",
		"brew:1":   "e",
	} {
		if err := b.Set(ctx, k, []byte(v), time.Minute); err != nil {
			t.Fatalf("Set %q: %v", k, err)
		}
	}

	if err := b.DeletePrefix(ctx, "bev:1:"); err != nil {
		t.Fatalf("DeletePrefix: %v", err)
	}

	for _, k := range []string{"bev:1:en", "bev:1:ja", "bev:1:ko"} {
		if _, ok, _ := b.Get(ctx, k); ok {
			t.Fatalf("%s should be evicted", k)
		}
	}
	for _, k := range []string{"bev:2:en", "brew:1"} {
		if _, ok, _ := b.Get(ctx, k); !ok {
			t.Fatalf("%s should survive", k)
		}
	}
}

func TestInProcessBackendCloseNoop(t *testing.T) {
	b := NewInProcessBackend(nil)
	if err := b.Close(); err != nil {
		t.Fatalf("Close: %v", err)
	}
	// Repeated close is safe.
	if err := b.Close(); err != nil {
		t.Fatalf("Close again: %v", err)
	}
}
