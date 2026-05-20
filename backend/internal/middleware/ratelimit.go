package middleware

import (
	"log/slog"
	"net"
	"net/http"
	"strconv"
	"sync"
	"sync/atomic"
	"time"

	"golang.org/x/time/rate"

	"github.com/kamos/api/internal/httperr"
)

// idleEvictAfter controls how long an idle limiter stays in the map.
// The GC ticker drops entries older than this — keeps memory bounded for
// long-lived processes facing rotating client IPs.
const idleEvictAfter = 10 * time.Minute

// limiterEntry tracks a per-key limiter and its last access timestamp.
// lastAccessUnixNano is atomic so we can update it without taking the
// outer sync.Map lock on the hot path.
type limiterEntry struct {
	lim                *rate.Limiter
	lastAccessUnixNano atomic.Int64
}

// limiterStore maps an identifier (IP or user id) to a rate.Limiter and
// evicts idle entries on a fixed cadence. Safe for concurrent use.
type limiterStore struct {
	rps   float64
	burst int
	m     sync.Map // string → *limiterEntry
}

func newLimiterStore(rps float64, burst int) *limiterStore {
	s := &limiterStore{rps: rps, burst: burst}
	// One package-wide janitor goroutine per store. The goroutine exits
	// when the process exits — we don't track lifetime here because
	// each store lives for the life of the server.
	go s.janitor()
	return s
}

func (s *limiterStore) get(key string) *rate.Limiter {
	now := time.Now().UnixNano()
	if v, ok := s.m.Load(key); ok {
		e := v.(*limiterEntry)
		e.lastAccessUnixNano.Store(now)
		return e.lim
	}
	e := &limiterEntry{lim: rate.NewLimiter(rate.Limit(s.rps), s.burst)}
	e.lastAccessUnixNano.Store(now)
	actual, _ := s.m.LoadOrStore(key, e)
	final := actual.(*limiterEntry)
	final.lastAccessUnixNano.Store(now)
	return final.lim
}

func (s *limiterStore) janitor() {
	t := time.NewTicker(idleEvictAfter)
	defer t.Stop()
	for range t.C {
		cutoff := time.Now().Add(-idleEvictAfter).UnixNano()
		s.m.Range(func(k, v any) bool {
			e := v.(*limiterEntry)
			if e.lastAccessUnixNano.Load() < cutoff {
				s.m.Delete(k)
			}
			return true
		})
	}
}

// clientIP extracts the host portion of r.RemoteAddr (which is "host:port").
// We deliberately do NOT honor X-Forwarded-For here — if the deployment
// puts a reverse proxy in front, that proxy must either rate-limit itself
// or set RemoteAddr via PROXY protocol. Trusting XFF without validation
// would let any client spoof their identifier and bypass the limit.
func clientIP(r *http.Request) string {
	host, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		return r.RemoteAddr
	}
	return host
}

// RateLimitByIP enforces a token-bucket per remote IP. When the bucket is
// empty: 429 + body {"error":"rate_limited","code":"RATE_LIMITED"} plus
// a Retry-After: 1 header. Log line is INFO with the keyed identifier;
// no stack trace.
func RateLimitByIP(log *slog.Logger, rps float64, burst int) func(http.Handler) http.Handler {
	store := newLimiterStore(rps, burst)
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			ip := clientIP(r)
			lim := store.get(ip)
			if !lim.Allow() {
				w.Header().Set("Retry-After", "1")
				if log != nil {
					log.Info("rate_limit_exceeded",
						"key", "ip:"+ip,
						"path", r.URL.Path,
						"method", r.Method,
					)
				}
				httperr.WriteError(w, http.StatusTooManyRequests, "RATE_LIMITED", "rate_limited")
				return
			}
			next.ServeHTTP(w, r)
		})
	}
}

// RateLimitByUser enforces a token-bucket per authed user. Must run AFTER
// Auth middleware. On unauthed requests (no user in context) this is a
// no-op — letting upstream IP limits do the work.
func RateLimitByUser(log *slog.Logger, rps float64, burst int) func(http.Handler) http.Handler {
	store := newLimiterStore(rps, burst)
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			uid := UserIDFromContext(r.Context())
			if uid == "" {
				next.ServeHTTP(w, r)
				return
			}
			lim := store.get(uid)
			if !lim.Allow() {
				w.Header().Set("Retry-After", "1")
				if log != nil {
					log.Info("rate_limit_exceeded",
						"key", "user:"+uid,
						"path", r.URL.Path,
						"method", r.Method,
					)
				}
				httperr.WriteError(w, http.StatusTooManyRequests, "RATE_LIMITED", "rate_limited")
				return
			}
			next.ServeHTTP(w, r)
		})
	}
}

// retryAfterSeconds formats a retry-after delta. Used only by tests; the
// hot path hard-codes "1" because both limits operate at sub-second cadence.
func retryAfterSeconds(d time.Duration) string {
	if d < time.Second {
		return "1"
	}
	return strconv.Itoa(int(d.Seconds()))
}
