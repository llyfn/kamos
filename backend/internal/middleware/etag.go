package middleware

import (
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"net/http"
	"strings"
)

// containsNoStore is a tiny RFC 7234 §5.2.1.5 token check on a
// Cache-Control header value. We split on commas (and ignore
// whitespace) and look for an exact "no-store" token rather than a
// substring match — "no-store-test" would otherwise false-match.
func containsNoStore(cc string) bool {
	for _, part := range strings.Split(cc, ",") {
		if strings.EqualFold(strings.TrimSpace(part), "no-store") {
			return true
		}
	}
	return false
}

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
// Order-of-magnitude estimate (Phase 7a MAJOR-2): SHA-256 on a modern
// x86 CPU runs at ~500 MB/s, so the hash cost scales linearly with body
// size: 10 KB → ~20 µs, 100 KB → ~200 µs, 1 MB → ~2 ms, 5 MB → ~10 ms.
// Buffer alloc adds one bytes.Buffer per request on top.
//
// Size cap (Phase 7a MAJOR-2): bodies larger than etagMaxBufBytes
// (256 KB) bypass ETag computation entirely and flush as-is. This
// protects against a future regression that accidentally returns a
// huge response (e.g., misconfigured pagination yielding 1000 items
// instead of 20, or a future endpoint that embeds a base64 photo).
// Memory: at 1000 rps with mean 10 KB body, peak in-flight buffer
// allocation is ~10 MB, well within GC reach.
//
// Order in the middleware chain: ETag MUST run OUTSIDE (i.e., wrap) the
// inner handler, but it should run INSIDE CacheControl so the Cache-Control
// header is already on the response when we flush the 200 OR the 304.
//
// Limitations:
//   - We only hash 2xx responses. Errors (4xx/5xx) pass through unmodified.
//   - We skip the hash when the response body is empty (no Content-Length
//     advantage to a 304 over a 204).
//   - We skip the hash when the body exceeds etagMaxBufBytes.
//   - Streaming handlers won't benefit — they'd be buffered whole. None of
//     the cacheable KAMOS endpoints stream, so this is fine.
//
// ETag value is truncated SHA-256 (first 8 bytes / 16 hex chars). 64 bits
// of entropy gives a ~2^32 birthday-collision domain, which at our scale
// is fine: collisions across routes are inert because ETag is scoped to
// one URI's response, and within one route the collision probability
// over the cache's lifetime is negligible. Deliberate trade for shorter
// headers — MINOR-1 carry-over.
const etagMaxBufBytes = 256 * 1024

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
		// Phase 7a MAJOR-2: size cap. Bodies larger than etagMaxBufBytes
		// bypass the hash to avoid quietly bloating CPU + memory on a
		// future regression. The body still flushes normally.
		if buf.body.Len() > etagMaxBufBytes {
			w.WriteHeader(buf.status)
			_, _ = w.Write(buf.body.Bytes())
			return
		}
		// Stage 5 (PERF-019): skip the hash entirely on responses the
		// inner handler has already marked Cache-Control: no-store.
		// A no-store response is never re-read from cache, so a 304
		// roundtrip-save is impossible by construction. The SHA-256
		// + ETag header would be pure waste; bypassing matches the
		// short-circuit semantics of the empty-body and oversize paths.
		if cc := w.Header().Get("Cache-Control"); cc != "" && containsNoStore(cc) {
			w.WriteHeader(buf.status)
			_, _ = w.Write(buf.body.Bytes())
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
//
// Phase 7a MAJOR-3: the previous `wroteHeader bool` field was set in
// WriteHeader/Write but never read outside this type — the outer flush
// logic decides what to emit from `status` (defaults to 200) and
// `body.Len()` alone. Removing the dead field also removes the
// idempotency guard on WriteHeader; stdlib already documents
// "superfluous WriteHeader" as a developer error, so a handler that
// calls WriteHeader twice now sees the second call take effect (matching
// net/http when headers have not yet been flushed to the wire).
type etagBuffer struct {
	http.ResponseWriter
	body   *bytes.Buffer
	status int
}

func (e *etagBuffer) WriteHeader(code int) {
	e.status = code
	// Do NOT call e.ResponseWriter.WriteHeader yet — we may need to write
	// 304 instead. The outer ETag handler flushes once it knows.
}

func (e *etagBuffer) Write(b []byte) (int, error) {
	// status defaults to http.StatusOK in the constructor, so an
	// unflushed Write already maps to 200 without an extra branch.
	return e.body.Write(b)
}
