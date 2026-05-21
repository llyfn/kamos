package cache

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"time"

	"github.com/redis/go-redis/v9"
)

// RedisBackend implements Backend against a single-node go-redis client.
// Selected by CACHE_BACKEND=redis. Production multi-replica deploys MUST
// use this backend; the in-process backend is per-replica only.
//
// Topology choice: single node, not a cluster. KAMOS's cache footprint is
// small (a few thousand hot keys) and the hit-rate dashboards from Stage
// 7 didn't justify clustering. If a future scale milestone needs it, we
// can switch to ClusterClient — the surface is identical.
//
// Eventual-consistency window: SET-then-DELETE crosses replicas in
// effectively zero milliseconds via the Redis hop. Combined with the
// pg LISTEN/NOTIFY bus (see invalidator.go), writes are visible cross-
// replica well under 1s in normal conditions.
type RedisBackend struct {
	log *slog.Logger
	cli *redis.Client
}

// NewRedisBackend connects to the given URL and pings to validate. URLs
// follow the standard redis://user:pass@host:port/db form; rediss:// is
// also accepted for TLS.
func NewRedisBackend(rawURL string, log *slog.Logger) (*RedisBackend, error) {
	if rawURL == "" {
		return nil, errors.New("NewRedisBackend: CACHE_REDIS_URL is required")
	}
	opt, err := redis.ParseURL(rawURL)
	if err != nil {
		return nil, fmt.Errorf("NewRedisBackend parse url: %w", err)
	}
	cli := redis.NewClient(opt)
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	if err := cli.Ping(ctx).Err(); err != nil {
		return nil, fmt.Errorf("NewRedisBackend ping: %w", err)
	}
	return &RedisBackend{log: log, cli: cli}, nil
}

// Get fetches a value. Returns (nil, false, nil) on miss, (value, true, nil)
// on hit, and a non-nil error on transport failure.
func (b *RedisBackend) Get(ctx context.Context, key string) ([]byte, bool, error) {
	v, err := b.cli.Get(ctx, key).Bytes()
	if err != nil {
		if errors.Is(err, redis.Nil) {
			return nil, false, nil
		}
		return nil, false, fmt.Errorf("RedisBackend.Get: %w", err)
	}
	return v, true, nil
}

// Set stores a value with the given TTL. A zero ttl means no expiry — we
// never call Set without a TTL, but the contract preserves Redis's native
// semantics so the abstraction doesn't surprise future callers.
func (b *RedisBackend) Set(ctx context.Context, key string, value []byte, ttl time.Duration) error {
	if err := b.cli.Set(ctx, key, value, ttl).Err(); err != nil {
		return fmt.Errorf("RedisBackend.Set: %w", err)
	}
	return nil
}

// DeletePrefix SCANs keys matching prefix* and UNLINKs them in batches.
// UNLINK is the non-blocking flavor of DEL — reclamation happens
// asynchronously in Redis, so a large bust doesn't stall foreground
// traffic. Cursor=0 is the start; loop until SCAN returns 0 again.
func (b *RedisBackend) DeletePrefix(ctx context.Context, prefix string) error {
	const pageSize = 100
	var cursor uint64
	pattern := prefix + "*"
	for {
		keys, next, err := b.cli.Scan(ctx, cursor, pattern, pageSize).Result()
		if err != nil {
			return fmt.Errorf("RedisBackend.DeletePrefix scan: %w", err)
		}
		if len(keys) > 0 {
			if err := b.cli.Unlink(ctx, keys...).Err(); err != nil {
				return fmt.Errorf("RedisBackend.DeletePrefix unlink: %w", err)
			}
		}
		if next == 0 {
			return nil
		}
		cursor = next
	}
}

// Close releases the redis client.
func (b *RedisBackend) Close() error {
	if b.cli == nil {
		return nil
	}
	return b.cli.Close()
}

// Compile-time interface check.
var _ Backend = (*RedisBackend)(nil)
