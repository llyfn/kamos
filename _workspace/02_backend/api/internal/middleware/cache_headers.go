package middleware

import "net/http"

// CacheControl sets the Cache-Control header BEFORE the handler runs.
//
// Mount per-route:
//
//	r.With(middleware.CacheControl("public, max-age=300, stale-while-revalidate=86400")).
//	    Get("/v1/beverages/{id}", h.GetBeverage)
//
// Phase 7 design note: the header is set BEFORE next.ServeHTTP, not after.
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
