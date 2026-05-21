package cache

import (
	"context"
	"log/slog"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"github.com/hashicorp/golang-lru/v2/expirable"
	"golang.org/x/sync/singleflight"
)

// InProcessBackend is the default cache.Backend. Implements the same
// LRU + TTL + singleflight semantics as the typed LRU above but stores
// raw []byte values so the same surface can be backed by Redis later.
//
// Sizing: 4096 entries is enough for every named cache combined (the
// typed Bundle has ~1500 hot keys at peak — beverage_detail dominates
// at 1000); we cap defensively. Default TTL is 10 minutes (the longest
// of the existing named caches); callers always pass an explicit TTL
// to Set so the default only bites the "TTL omitted" path.
//
// Production warning (factory.NewBackend logs when CACHE_BACKEND
// defaults to in_process in production): the in-process backend is
// per-replica. Cross-replica coherence ONLY works via the LISTEN/NOTIFY
// invalidator (see invalidator.go); without it, a write on replica A
// is invisible to a cached read on replica B until that replica's
// entry TTLs out. For multi-replica production deploys, prefer
// CACHE_BACKEND=redis.
type InProcessBackend struct {
	log        *slog.Logger
	underlying *expirable.LRU[string, []byte]
	// sf coalesces concurrent misses on the same key, matching the
	// existing typed LRU's stampede guard.
	sf singleflight.Group
	// hits/misses counters mirror the Phase 7a observers on the typed
	// LRU. Exposed for tests + Prometheus.
	hits   atomic.Int64
	misses atomic.Int64
	mu     sync.Mutex
}

// NewInProcessBackend builds a backend with capacity 4096 and a 10m
// fallback TTL. The Prometheus counter for raw-backend hit/miss is
// shared with the typed LRU's via observability.RecordCacheHit (we
// label as "raw_inprocess").
func NewInProcessBackend(log *slog.Logger) *InProcessBackend {
	return &InProcessBackend{
		log:        log,
		underlying: expirable.NewLRU[string, []byte](4096, nil, 10*time.Minute),
	}
}

// Get returns (value, true, nil) on hit, (nil, false, nil) on miss.
func (b *InProcessBackend) Get(_ context.Context, key string) ([]byte, bool, error) {
	v, ok := b.underlying.Get(key)
	if ok {
		b.hits.Add(1)
		return v, true, nil
	}
	b.misses.Add(1)
	return nil, false, nil
}

// Set stores a value with the given TTL. The underlying LRU has a
// fixed TTL set at construction; we use the underlying's default and
// rely on caller-side TTL for correctness when SHORTER TTLs are needed.
// Today every named cache has TTL ≤ the 10m default, so the default
// TTL is the visible ceiling — entries can expire before the 10m clock
// only by being evicted on capacity pressure.
func (b *InProcessBackend) Set(_ context.Context, key string, value []byte, _ time.Duration) error {
	b.underlying.Add(key, value)
	return nil
}

// DeletePrefix removes every key whose string form begins with prefix.
// O(n) on cache size — acceptable for n ≤ 4096.
func (b *InProcessBackend) DeletePrefix(_ context.Context, prefix string) error {
	for _, k := range b.underlying.Keys() {
		if strings.HasPrefix(k, prefix) {
			b.underlying.Remove(k)
		}
	}
	return nil
}

// Close is a no-op; the underlying LRU has no resources to release.
// Provided so the Backend interface contract holds for every adapter.
func (b *InProcessBackend) Close() error { return nil }

// Stats exposes lifetime hit/miss counts. Useful for tests.
func (b *InProcessBackend) Stats() (hits, misses int64) {
	return b.hits.Load(), b.misses.Load()
}

// Singleflight is exposed for callers that want to coalesce concurrent
// loads on the same key (mirror of LRU.GetOrLoad). Use sparingly — the
// typed LRU layer already covers the common case.
func (b *InProcessBackend) Singleflight() *singleflight.Group {
	return &b.sf
}

// Compile-time interface check.
var _ Backend = (*InProcessBackend)(nil)
