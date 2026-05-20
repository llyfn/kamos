// Package service hosts the orchestration layer between HTTP handlers and
// the repository / auth / cache / storage / mailer primitives. Each service
// owns the multi-repo writes + cache invalidation + observability dance for
// one aggregate; handlers shrink to decode → validate → call → respond.
//
// Service constructors take small focused interfaces (declared inside this
// package — the Go idiom of "define at the consumer"), not the god-bundle
// from internal/repository. This keeps each service unit-testable with a
// hand-rolled fake without dragging in pgxpool.
//
// The Bundle type is the one struct the handler layer holds; new services
// are added by extending Bundle, not by tweaking handlers individually.
package service

import (
	"context"
	"log/slog"

	"github.com/jackc/pgx/v5"

	"github.com/kamos/api/internal/auth"
	"github.com/kamos/api/internal/cache"
	"github.com/kamos/api/internal/config"
	"github.com/kamos/api/internal/email"
	"github.com/kamos/api/internal/repository"
)

// Bundle is the aggregate of every service. Handlers hold *Bundle; main.go
// constructs it once via New(...).
type Bundle struct {
	Auth    *AuthService
	Checkin *CheckinService
	Comment *CommentService
	Social  *SocialService
	Admin   *AdminService
}

// Deps is the wiring shape main.go passes to New. Each field is a primitive
// that one or more services consume. Tests can substitute fakes for any
// field — services depend on small interfaces declared in this package.
type Deps struct {
	Cfg        *config.Config
	Log        *slog.Logger
	Repos      *repository.Repos
	Signer     *auth.Signer
	Mailer     email.Mailer
	Caches     *cache.Caches
	SoftDelete *auth.SoftDeleteCache
}

// New wires every service from the given dependencies. Nil-safe for tests:
// missing dependencies become disabled features (e.g. a nil Mailer means
// AuthService.Register skips the verification mail).
func New(d Deps) *Bundle {
	return &Bundle{
		Auth:    newAuthService(d),
		Checkin: newCheckinService(d),
		Comment: newCommentService(d),
		Social:  newSocialService(d),
		Admin:   newAdminService(d),
	}
}

// CacheInvalidator is the slice of the cache bundle every write-path service
// uses to invalidate hot LRU entries after a commit. Implementations:
//   - *cache.Caches (production)
//   - nil (handlers' nil-Caches → invalidate becomes a no-op)
type CacheInvalidator interface {
	InvalidateBeverageDetail(beverageID string)
	InvalidateBreweryDetail(breweryID string)
}

// cacheAdapter wraps a *cache.Caches to satisfy CacheInvalidator. The
// no-op branch handles the nil case so callers don't sprinkle nil checks.
type cacheAdapter struct{ c *cache.Caches }

func (a cacheAdapter) InvalidateBeverageDetail(id string) {
	if a.c == nil || id == "" {
		return
	}
	a.c.BeverageDetail.InvalidatePrefix(id + ":")
}

func (a cacheAdapter) InvalidateBreweryDetail(id string) {
	if a.c == nil || id == "" {
		return
	}
	a.c.BreweryDetail.InvalidatePrefix(id + ":")
}

// observe is the centralized hook for business counters. Services call it
// instead of importing the observability package directly, so tests can
// observe a no-op slog without an OTel meter.
type counterFn func(context.Context)

// pgxTx is the slice of pgx.Tx used by services. Defined here so service
// implementations don't import pgx directly when they delegate to
// repository methods that already accept it.
type pgxTx = pgx.Tx
