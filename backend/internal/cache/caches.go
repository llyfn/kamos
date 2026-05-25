package cache

import (
	"strings"
	"time"

	"github.com/kamos/api/internal/domain"
)

// Caches bundles every named cache the handlers use. Boot wires this once
// (see cmd/server/main.go) and the Handler holds a pointer.
//
// Sizing & TTL rationale per the roadmap entry + the four cache
// targets named there:
//
// - Categories: one row per locale × ~3 locales — tiny. Size 4 leaves
// room for an "all-locales" key without growth. TTL 1h: the taxonomy
// barely ever changes; a 1h staleness window is invisible to users.
//
// - FlavorTags: same shape as Categories.
//
// - BeverageDetail: thousands of beverages, but a long tail. 1000-entry
// LRU covers every popular beverage with room to spare. TTL 5m because
// avg_rating drifts as new check-ins land; a longer TTL would surface
// stale ratings to the user. Write-path invalidation (commit 4) plus
// the 5m ceiling keeps drift bounded.
//
// - ProducerDetail: smaller catalog (~hundreds). Size 500, TTL 10m —
// check-in counts roll up here too but a producer's aggregate moves
// slower than a single beverage's.
//
// BeverageDetail and ProducerDetail store VALUE
// types (not pointers). Go semantics guarantee Get returns a struct
// copy, which prevents a future per-viewer overlay from leaking
// mutations across viewers. The copy cost is ~1 KB per Get/Set —
// negligible compared to the saved DB round-trip.
type Caches struct {
	Categories     *LRU[string, []domain.CategoryLabel]
	FlavorTags     *LRU[string, []domain.FlavorTag]
	Regions        *LRU[string, []domain.RegionWithPrefectures]
	BeverageDetail *LRU[string, domain.BeverageDetail]
	ProducerDetail *LRU[string, domain.Producer]
}

// sizing tuples lifted to named constants so future
// tuning (e.g. after working-set telemetry from /metrics) happens in one
// place instead of being scattered across NewCaches + any test that
// asserts on capacity.
const (
	categoriesCacheSize = 4
	categoriesCacheTTL  = time.Hour

	flavorTagsCacheSize = 4
	flavorTagsCacheTTL  = time.Hour

	// Regions: same shape as Categories / FlavorTags (locale-axis cache
	// key) and the same long TTL — the 8 regions × 47 prefectures
	// reference graph is seed-only data that effectively never changes
	// during a deploy window.
	regionsCacheSize = 4
	regionsCacheTTL  = time.Hour

	beverageDetailCacheSize = 1000
	beverageDetailCacheTTL  = 5 * time.Minute

	producerDetailCacheSize = 500
	producerDetailCacheTTL  = 10 * time.Minute
)

// NewCaches constructs the bundle with the sizing.
func NewCaches() *Caches {
	return &Caches{
		Categories:     NewLRU[string, []domain.CategoryLabel]("categories", categoriesCacheSize, categoriesCacheTTL),
		FlavorTags:     NewLRU[string, []domain.FlavorTag]("flavor_tags", flavorTagsCacheSize, flavorTagsCacheTTL),
		Regions:        NewLRU[string, []domain.RegionWithPrefectures]("regions", regionsCacheSize, regionsCacheTTL),
		BeverageDetail: NewLRU[string, domain.BeverageDetail]("beverage_detail", beverageDetailCacheSize, beverageDetailCacheTTL),
		ProducerDetail: NewLRU[string, domain.Producer]("producer_detail", producerDetailCacheSize, producerDetailCacheTTL),
	}
}

// SetObservers wires the same hit/miss callbacks onto every named cache in
// the bundle. Call once at boot after registering the Prometheus counter.
func (c *Caches) SetObservers(onHit, onMiss func(name string)) {
	c.Categories.SetObservers(onHit, onMiss)
	c.FlavorTags.SetObservers(onHit, onMiss)
	c.Regions.SetObservers(onHit, onMiss)
	c.BeverageDetail.SetObservers(onHit, onMiss)
	c.ProducerDetail.SetObservers(onHit, onMiss)
}

// InvalidatePrefix is the cross-replica entry point used by the
// LISTEN/NOTIFY invalidator. It parses the payload (a free-form string
// from cache.NotifyInvalidation) and routes it to the appropriate
// typed-cache InvalidatePrefix call.
//
// Payload grammar:
//
//	"beverage:<id>" → BeverageDetail.InvalidatePrefix(id + ":")
//	"producer:<id>" → ProducerDetail.InvalidatePrefix(id + ":")
//	"taxonomy" → Categories.InvalidatePrefix("") + FlavorTags.InvalidatePrefix("")
//
// Empty payloads, unknown prefixes, and nil receivers all no-op — the
// invalidator MUST stay alive across schema drift.
func (c *Caches) InvalidatePrefix(payload string) {
	if c == nil || payload == "" {
		return
	}
	switch {
	case payload == "taxonomy":
		c.Categories.InvalidatePrefix("")
		c.FlavorTags.InvalidatePrefix("")
		c.Regions.InvalidatePrefix("")
	case strings.HasPrefix(payload, "beverage:"):
		id := strings.TrimPrefix(payload, "beverage:")
		if id != "" {
			c.BeverageDetail.InvalidatePrefix(id + ":")
		}
	case strings.HasPrefix(payload, "producer:"):
		id := strings.TrimPrefix(payload, "producer:")
		if id != "" {
			c.ProducerDetail.InvalidatePrefix(id + ":")
		}
	}
}
