package cache

import (
	"context"
	"log/slog"

	"github.com/jackc/pgx/v5/pgxpool"
)

// notifyChannel is the Postgres LISTEN/NOTIFY channel every replica
// subscribes to for cross-replica cache invalidation. The payload is
// the cache prefix to bust (e.g. "beverage:<id>:", "producer:<id>:",
// "taxonomy"). Encoded as a free-form string to keep the protocol
// trivially debuggable from psql.
const notifyChannel = "kamos_cache_invalidate"

// NotifyInvalidation publishes a cache-bust signal to every replica
// listening on `kamos_cache_invalidate`. The local replica is
// responsible for invalidating its own LRU directly (see service
// write paths); this helper exists to broadcast the same signal to
// peers. Fire-and-forget: a NOTIFY failure is logged but never
// surfaced — the caller has already committed the write and the
// local replica is already coherent.
//
// Payload examples:
//
//	"beverage:<id>"  → buckets BeverageDetail entries beginning with the id
//	"producer:<id>"  → ProducerDetail
//	"taxonomy"       → Categories + FlavorTags
//
// Per-replica handling lives in Caches.InvalidatePrefix; this helper
// stays decoupled from the typed-cache shape.
func NotifyInvalidation(ctx context.Context, db *pgxpool.Pool, log *slog.Logger, payload string) {
	if db == nil || payload == "" {
		return
	}
	// pg_notify supports payloads up to 8000 bytes; our prefixes are
	// well under that ceiling. We use parameterized SQL so a future
	// caller can't inject a malicious payload — even though every
	// current caller passes a constant prefix + an internal UUID.
	if _, err := db.Exec(ctx, `SELECT pg_notify($1, $2)`, notifyChannel, payload); err != nil {
		if log != nil {
			log.Warn("cache_notify_failed", "err", err, "payload", payload)
		}
		return
	}
}

// notifyChannelName is exported for the invalidator (same package).
func notifyChannelName() string { return notifyChannel }
