// Package cache is the in-process caching layer: a thin generic
// wrapper around hashicorp/golang-lru/v2/expirable that adds named
// instances + hit/miss observability counters.
//
// metrics established that reads on KAMOS are <4ms p95 — caching
// here is NOT a user-latency play. It's a SCALE play: cut DB load on the
// hot taxonomy / beverage / brewery rows, keep Foursquare quota in line,
// and absorb spikes from popular events without scaling Postgres.
//
// Design choice (per the roadmap entry): SKIP Redis. The default
// is in-process LRU + HTTP Cache-Control/ETag headers only. If a future
// metric proves the need (e.g., multi-instance cache coherence
// becomes a problem), a Redis tier can layer on top; today it would be
// premature.
//
// Cache values that the handler mutates per-viewer (e.g., injecting
// you_toasted on BeverageDetail) MUST be deep-copied at the call site
// before mutation. The cache returns the SAME pointer/slice it was
// given on Set, so mutation would leak across requests. Each consumer
// documents its deep-copy strategy at the call site.
package cache

import (
	"fmt"
	"strings"
	"sync/atomic"
	"time"

	"github.com/hashicorp/golang-lru/v2/expirable"
	"golang.org/x/sync/singleflight"
)

// LRU is a typed, named, observability-aware wrapper around an expirable
// LRU. Zero value is not usable — call NewLRU.
//
// The wrapper deliberately exposes a narrow surface (Get / Set / Invalidate
// / InvalidatePrefix / Stats / Name). The underlying expirable.LRU has
// more methods; if a caller needs one of them they should add a typed
// passthrough here rather than reaching past the abstraction.
type LRU[K comparable, V any] struct {
	name       string
	underlying *expirable.LRU[K, V]
	hits       atomic.Int64
	misses     atomic.Int64

	// onHit / onMiss fire on every Get. Used by the Prometheus counter
	// (commit 5) without coupling this package to client_golang.
	onHit  func(name string)
	onMiss func(name string)

	// sf coalesces concurrent misses on the same key. // without it, N concurrent requests on a hot key (e.g., the 5-minute
	// BeverageDetail TTL expiring during a campaign-driven spike) each
	// issue the same DB query trio. With it, one loader runs and the rest
	// share the result. See GetOrLoad.
	sf singleflight.Group
}

// NewLRU builds a typed LRU. `name` is used as the Prometheus label and in
// any debug output; pick a stable identifier (e.g. "beverage_detail").
// `size` is the entry cap; `ttl` is the per-entry lifetime (0 = no expiry,
// but every KAMOS cache supplies a real TTL — drift on the value side is
// the failure mode we worry about, not unbounded memory).
func NewLRU[K comparable, V any](name string, size int, ttl time.Duration) *LRU[K, V] {
	return &LRU[K, V]{
		name:       name,
		underlying: expirable.NewLRU[K, V](size, nil, ttl),
	}
}

// Name returns the cache's identifier (used for metrics labels).
func (c *LRU[K, V]) Name() string { return c.name }

// SetObservers wires Prometheus-style callbacks. Both may be nil.
// Pass a hit/miss recorder once at boot; the cache uses them on every Get.
func (c *LRU[K, V]) SetObservers(onHit, onMiss func(name string)) {
	c.onHit = onHit
	c.onMiss = onMiss
}

// Get returns (value, true) on hit, (zero, false) on miss.
func (c *LRU[K, V]) Get(key K) (V, bool) {
	v, ok := c.underlying.Get(key)
	if ok {
		c.hits.Add(1)
		if c.onHit != nil {
			c.onHit(c.name)
		}
		return v, true
	}
	c.misses.Add(1)
	if c.onMiss != nil {
		c.onMiss(c.name)
	}
	var zero V
	return zero, false
}

// Set stores a value with the cache's configured TTL.
func (c *LRU[K, V]) Set(key K, value V) {
	c.underlying.Add(key, value)
}

// GetOrLoad returns the cached value on hit, or invokes loader on miss and
// stores the result. Concurrent misses on the same key are coalesced via
// singleflight — only one loader runs; the rest receive the same value.
//
// closes the cache-stampede window on hot keys. The
// extra cost on the happy path (cache hit) is one mutex acquire and one
// map lookup inside singleflight, which is dwarfed by the saved DB
// round-trip on the miss path.
//
// Observability semantics: each call to GetOrLoad records at most one
// hit OR one miss (via the outer Get below). The singleflight double-
// check uses the underlying LRU directly so it does NOT double-count
// — otherwise a single miss-with-load would mis-attribute as two
// misses on the hit/miss counter.
//
// K must be a string in practice — the singleflight key is built via
// fmt.Sprint on K. Every KAMOS cache uses string keys today.
func (c *LRU[K, V]) GetOrLoad(key K, loader func() (V, error)) (V, error) {
	if v, ok := c.Get(key); ok {
		return v, nil
	}
	// singleflight.Group.Do dedupes by string key.
	sfKey := stringify(key)
	v, err, _ := c.sf.Do(sfKey, func() (any, error) {
		// Double-check via the underlying LRU (does NOT touch the hit/miss
		// observer counters): another concurrent caller may have populated
		// the cache between our outer Get and this loader running.
		if v, ok := c.underlying.Get(key); ok {
			return v, nil
		}
		loaded, err := loader()
		if err != nil {
			return loaded, err
		}
		c.Set(key, loaded)
		return loaded, nil
	})
	if err != nil {
		var zero V
		return zero, err
	}
	return v.(V), nil
}

// stringify converts a comparable cache key into a string for singleflight
// deduplication. K is `string` in every KAMOS cache today; the type-
// assertion fast-path keeps the happy path allocation-free.
func stringify(k any) string {
	if s, ok := k.(string); ok {
		return s
	}
	// Fallback for non-string keys. Not used today but keeps GetOrLoad
	// usable if a future cache pivots to a different key type. The
	// Sprintf path allocates; documented cost.
	return fmt.Sprintf("%v", k)
}

// Invalidate removes a single key. Safe to call on a missing key.
func (c *LRU[K, V]) Invalidate(key K) {
	c.underlying.Remove(key)
}

// Stats returns the lifetime hit / miss counts.
func (c *LRU[K, V]) Stats() (hits, misses int64) {
	return c.hits.Load(), c.misses.Load()
}

// InvalidatePrefix removes every key whose string form begins with prefix.
// Only meaningful when K is `string`; non-string key types are a no-op
// (the type assertion fails, hence the prefix scan is skipped).
//
// Used by write-path invalidation: a check-in update knows the beverage
// ID but not the locale suffix, so it busts every "<bev_id>:" entry in one
// call. O(n) on cache size — acceptable for our cache sizes (≤ 1000).
func (c *LRU[K, V]) InvalidatePrefix(prefix string) {
	for _, k := range c.underlying.Keys() {
		ks, ok := any(k).(string)
		if !ok {
			return // K isn't string; nothing to do.
		}
		if strings.HasPrefix(ks, prefix) {
			c.underlying.Remove(k)
		}
	}
}
