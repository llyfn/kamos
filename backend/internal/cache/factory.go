package cache

import (
	"fmt"
	"log/slog"

	"github.com/kamos/api/internal/config"
)

// NewBackend selects a Backend implementation from config. Defaults to the
// in-process backend; CACHE_BACKEND=redis switches to the Redis adapter.
//
// Production safety: in production with the default in-process backend we
// log a WARN — multi-replica deploys MUST use Redis or accept the per-
// replica eventual-consistency window (writes invisible to other replicas
// until LISTEN/NOTIFY busts their entry).
func NewBackend(cfg *config.Config, log *slog.Logger) (Backend, error) {
	if cfg == nil {
		return NewInProcessBackend(log), nil
	}
	switch cfg.CacheBackend {
	case "redis":
		b, err := NewRedisBackend(cfg.CacheRedisURL, log)
		if err != nil {
			return nil, fmt.Errorf("NewBackend redis: %w", err)
		}
		log.Info("cache backend", "type", "redis")
		return b, nil
	case "", "in_process":
		if cfg.Env == "production" {
			log.Warn("cache backend in_process in production — multi-replica deploys require redis",
				"hint", "set CACHE_BACKEND=redis + CACHE_REDIS_URL to enable cross-replica coherence")
		}
		log.Info("cache backend", "type", "in_process")
		return NewInProcessBackend(log), nil
	default:
		return nil, fmt.Errorf("NewBackend: unknown CACHE_BACKEND %q", cfg.CacheBackend)
	}
}
