package middleware

import (
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"net/http"
)

// ETag buffers the response body, computes a SHA-256 hash, sets a strong
// ETag header, and short-circuits with 304 Not Modified when the request
// has a matching If-None-Match header.
//
// Why strong (no `W/` prefix): Go's encoding/json emits struct fields in
// declaration order, and our domain types pin field order in the source.
// Two requests for the same logical entity therefore produce byte-
// identical JSON, which qualifies as strong-validator semantics — clients
// can rely on the ETag for byte-exact caching.
//
// Cost: one full-body buffer per request on routes where ETag is mounted.
// For our cacheable read endpoints (taxonomy, beverage / brewery detail,
// public profile) the response is a few KB at most; the extra alloc is
// invisible compared to the saved DB round-trip on a 304.
//
// Order in the middleware chain: ETag MUST run OUTSIDE (i.e., wrap) the
// inner handler, but it should run INSIDE CacheControl so the Cache-Control
// header is already on the response when we flush the 200 OR the 304.
//
// Limitations:
//   - We only hash 2xx responses. Errors (4xx/5xx) pass through unmodified.
//   - We skip the hash when the response body is empty (no Content-Length
//     advantage to a 304 over a 204).
//   - Streaming handlers won't benefit — they'd be buffered whole. None of
//     the cacheable KAMOS endpoints stream, so this is fine.
func ETag(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Only GET / HEAD are worth ETagging — write requests don't have
		// a cacheable response.
		if r.Method != http.MethodGet && r.Method != http.MethodHead {
			next.ServeHTTP(w, r)
			return
		}
		buf := &etagBuffer{
			ResponseWriter: w,
			body:           &bytes.Buffer{},
			status:         http.StatusOK,
		}
		next.ServeHTTP(buf, r)

		// 4xx/5xx: leave the body untouched, no ETag. We still need to
		// flush the captured status to the real writer; the inner
		// handler's WriteHeader was intercepted, so without this the
		// client would see a stale 200.
		if buf.status < 200 || buf.status >= 300 {
			w.WriteHeader(buf.status)
			_, _ = w.Write(buf.body.Bytes())
			return
		}
		if buf.body.Len() == 0 {
			w.WriteHeader(buf.status)
			return
		}

		// Compute strong validator over the JSON bytes.
		sum := sha256.Sum256(buf.body.Bytes())
		etag := `"` + hex.EncodeToString(sum[:8]) + `"`
		w.Header().Set("ETag", etag)

		if match := r.Header.Get("If-None-Match"); match != "" && match == etag {
			// Per RFC 7232 §4.1, a 304 must NOT include a body; per §4.1
			// it MUST include the ETag that matched. Cache-Control may
			// already be set by the CacheControl middleware — fine,
			// it's a valid 304 header.
			w.WriteHeader(http.StatusNotModified)
			return
		}
		w.WriteHeader(buf.status)
		_, _ = w.Write(buf.body.Bytes())
	})
}

// etagBuffer captures the response so we can hash it before flush.
// It implements http.ResponseWriter by intercepting Write + WriteHeader.
type etagBuffer struct {
	http.ResponseWriter
	body         *bytes.Buffer
	status       int
	wroteHeader  bool
}

func (e *etagBuffer) WriteHeader(code int) {
	if e.wroteHeader {
		return
	}
	e.status = code
	e.wroteHeader = true
	// Do NOT call e.ResponseWriter.WriteHeader yet — we may need to write
	// 304 instead. The outer ETag handler flushes once it knows.
}

func (e *etagBuffer) Write(b []byte) (int, error) {
	if !e.wroteHeader {
		// Mimic net/http: an unflushed Write implies 200.
		e.WriteHeader(http.StatusOK)
	}
	return e.body.Write(b)
}
