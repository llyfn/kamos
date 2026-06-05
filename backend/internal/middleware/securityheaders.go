package middleware

import (
	"net/http"
	"os"
)

// SecurityHeaders sets standard HTTP security-response headers on every
// outbound response (SEC-007):
//
//   - Strict-Transport-Security: max-age=63072000; includeSubDomains; preload
//     (only when the request is HTTPS or FORCE_HSTS=1 in env, so local
//     plain-HTTP dev doesn't fight with browsers that lock onto the
//     header).
//   - X-Content-Type-Options: nosniff
//   - X-Frame-Options: DENY
//   - Referrer-Policy: strict-origin-when-cross-origin
//   - Permissions-Policy: camera=(), microphone=(), geolocation=()
//
// No CSP — the API doesn't serve HTML.
func SecurityHeaders(next http.Handler) http.Handler {
	forceHSTS := os.Getenv("FORCE_HSTS") == "1"
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Compute "is HTTPS" cheaply: TLS connection or X-Forwarded-Proto
		// from a trusted edge. The header check is permissive — production
		// deployments behind a TLS-terminating proxy expect the value.
		isHTTPS := r.TLS != nil ||
			r.Header.Get("X-Forwarded-Proto") == "https" ||
			r.URL.Scheme == "https" ||
			forceHSTS
		if isHTTPS {
			w.Header().Set("Strict-Transport-Security",
				"max-age=63072000; includeSubDomains; preload")
		}
		w.Header().Set("X-Content-Type-Options", "nosniff")
		w.Header().Set("X-Frame-Options", "DENY")
		w.Header().Set("Referrer-Policy", "strict-origin-when-cross-origin")
		w.Header().Set("Permissions-Policy", "camera=(), microphone=(), geolocation=()")
		next.ServeHTTP(w, r)
	})
}
