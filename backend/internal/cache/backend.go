package cache

import (
	"context"
	"time"
)

// Backend is the slice of cache operations every adapter exposes. Values
// are opaque []byte — callers JSON-marshal their typed value before Set
// and unmarshal after Get. This is the multi-replica abstraction layer:
// in-process callers route through this when they want their write to be
// visible across replicas (paired with cache.NotifyInvalidation), while
// the existing typed LRU bundle remains the read-path fast lane.
//
// Stage 4 — the in-process backend continues to back the typed Caches
// bundle (Categories / FlavorTags / BeverageDetail / ProducerDetail) used
// by handlers. The Redis backend is an optional alternative selected by
// CACHE_BACKEND=redis; when wired, the Bundle stays in front as an L1
// and Redis serves as an L2 + cross-replica coherence layer.
//
// Implementations MUST be safe for concurrent use. Get returns
// (value, true, nil) on hit, (nil, false, nil) on miss, and a non-nil
// error only when the underlying store fails (network blip on Redis, etc).
type Backend interface {
	Get(ctx context.Context, key string) ([]byte, bool, error)
	Set(ctx context.Context, key string, value []byte, ttl time.Duration) error
	DeletePrefix(ctx context.Context, prefix string) error
	Close() error
}
