package observability

import (
	"net/http"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

// cacheRequests is the cache observability counter. Two label
// dimensions:
//
//	cache — the named cache (categories, flavor_tags, beverage_detail,
//	 producer_detail). Cardinality bounded by what's registered
//	 in cache.NewCaches.
//	outcome — "hit" | "miss". Two values, fixed.
//
// Total cardinality: 4 × 2 = 8 series. Well within Prom's comfort zone.
//
// Grafana usage (see docs/history/qa/qa_phase7_grafana_panel.json):
//
//	hit rate by cache =
//	 sum by (cache) (rate(cache_requests_total{outcome="hit"}[5m]))
//	 /
//	 sum by (cache) (rate(cache_requests_total[5m]))
var cacheRequests = promauto.NewCounterVec(prometheus.CounterOpts{
	Name: "cache_requests_total",
	Help: "Cache lookups by cache name and outcome (hit|miss).",
}, []string{"cache", "outcome"})

// RecordCacheHit / RecordCacheMiss are the function-typed hooks plumbed
// into each cache.LRU via SetObservers. Keeping the API as bare funcs
// (not a method on a struct) lets the cache package stay free of any
// client_golang dependency.
func RecordCacheHit(name string)  { cacheRequests.WithLabelValues(name, "hit").Inc() }
func RecordCacheMiss(name string) { cacheRequests.WithLabelValues(name, "miss").Inc() }

// PromHandler returns the standard /metrics handler. Mount once at the
// router level. Exposes every counter registered with promauto, not just
// the cache one.
func PromHandler() http.Handler { return promhttp.Handler() }
