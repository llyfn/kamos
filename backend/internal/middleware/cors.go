package middleware

import (
	"net/http"
	"strings"
)

// CORSConfig is the runtime configuration for the CORS middleware. Origins
// is an exact-match allowlist; wildcards are intentionally not supported
// (SEC-002) — the admin Vite dev server is one known origin and any
// production admin domain is added explicitly.
type CORSConfig struct {
	AllowedOrigins []string
}

// CORS returns a middleware that handles preflight OPTIONS short-circuits
// and writes per-request CORS headers when the Origin matches the
// allowlist. Sets the following headers on matched requests:
//
//   - Access-Control-Allow-Origin: <echo of matched Origin>
//   - Access-Control-Allow-Credentials: true
//   - Access-Control-Allow-Methods: GET, POST, PATCH, DELETE, OPTIONS
//   - Access-Control-Allow-Headers: Content-Type, Authorization, X-Request-Id
//   - Access-Control-Max-Age: 600
//   - Vary: Origin
//
// Allow-Credentials is required because the admin SPA calls the API with
// credentials:'include' for its HttpOnly cookie auth. Echoing the exact
// matched origin (never "*") is what lets a credentialed cross-origin
// request succeed; the allowlist is exact-match (SEC-002), so this is safe.
//
// Unmatched origins fall through with no CORS headers; the browser will
// fail the request locally. Mount AFTER RequestID/Recover/AccessLog so
// cross-origin failures still trace through observability.
func CORS(cfg CORSConfig) func(http.Handler) http.Handler {
	// Normalize the allowlist once.
	normalized := make([]string, 0, len(cfg.AllowedOrigins))
	for _, o := range cfg.AllowedOrigins {
		o = strings.TrimSpace(o)
		if o == "" {
			continue
		}
		normalized = append(normalized, o)
	}
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			origin := r.Header.Get("Origin")
			if origin != "" && isAllowed(normalized, origin) {
				w.Header().Set("Access-Control-Allow-Origin", origin)
				w.Header().Set("Access-Control-Allow-Credentials", "true")
				w.Header().Set("Vary", "Origin")
				w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PATCH, DELETE, OPTIONS")
				w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization, X-Request-Id")
				w.Header().Set("Access-Control-Max-Age", "600")
			}
			// Preflight short-circuit. Browsers send OPTIONS with the
			// Access-Control-Request-Method header; reply 204 either way
			// because chi otherwise responds 405 to OPTIONS on routes
			// that only declare GET/POST.
			if r.Method == http.MethodOptions {
				w.WriteHeader(http.StatusNoContent)
				return
			}
			next.ServeHTTP(w, r)
		})
	}
}

func isAllowed(allow []string, origin string) bool {
	for _, a := range allow {
		if a == origin {
			return true
		}
	}
	return false
}

// ParseAllowedOrigins splits a comma-separated env-var value into an origin
// allowlist. Empty / whitespace entries are dropped. Helper for the router
// wiring so the comma-splitting logic doesn't live in main.go.
func ParseAllowedOrigins(csv string) []string {
	if csv == "" {
		return nil
	}
	parts := strings.Split(csv, ",")
	out := make([]string, 0, len(parts))
	for _, p := range parts {
		p = strings.TrimSpace(p)
		if p != "" {
			out = append(out, p)
		}
	}
	return out
}
