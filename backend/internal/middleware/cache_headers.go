package middleware

import "net/http"

// CacheControl sets the Cache-Control header BEFORE the handler runs.
//
// Mount per-route:
//
//	r.With(middleware.CacheControl("public, max-age=300, stale-while-revalidate=86400")).
//	    Get("/v1/beverages/{id}", h.GetBeverage)
//
// Design note: the header is set BEFORE next.ServeHTTP, not after.
// If we set it after, a handler that decided to write its own
// Cache-Control (e.g., a private response on the public-profile route)
// would already have flushed headers by the time we tried — wWriteHeader
// locks the header map once called. Pre-setting lets the inner handler
// override us by calling w.Header().Set("Cache-Control", "...") before
// it writes the body, which is the standard Go convention.
func CacheControl(value string) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			w.Header().Set("Cache-Control", value)
			next.ServeHTTP(w, r)
		})
	}
}

// noStoreValue is the canonical "do not cache, anywhere, at any tier"
// header. The four directives are belt-and-braces against legacy clients
// and intermediaries:
//
//   - no-store          → MUST NOT store any part of this response.
//   - no-cache          → MUST revalidate with the origin before serving.
//   - must-revalidate   → stale responses MUST NOT be served.
//   - max-age=0         → immediately stale even if some tier ignores no-store.
//
// Together this is the strongest "do not cache" signal HTTP can carry.
const noStoreValue = "no-store, no-cache, must-revalidate, max-age=0"

// NoStore tags the response as never-cacheable. fix —
// ETag is mounted globally for the "every GET gets it for free" property,
// but every route that isn't intentionally cacheable must declare
// `no-store` so heuristic-caching intermediaries don't treat an ETagged
// 200 as eligible to share across viewers (RFC 7234 §4.2.2).
//
// Pairs with CacheControl: every GET on the authed surface gets either a
// CacheControl(...) wrapper (the 5 documented public-cacheable routes) OR
// a NoStore wrapper (everything else). The TestCacheControlPresentOnAll
// GetRoutes integration test fail-closes the contract.
func NoStore(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Cache-Control", noStoreValue)
		next.ServeHTTP(w, r)
	})
}
