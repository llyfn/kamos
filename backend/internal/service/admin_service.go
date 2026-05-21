package service

import (
	"context"
	"errors"
	"log/slog"

	"github.com/kamos/api/internal/domain"
	"github.com/kamos/api/internal/repository"
)

// AdminService owns the moderation surface: approve / reject beverage
// requests, moderate check-ins + comments, suspend users, update roles.
// Each method orchestrates the multi-repo writes + cache invalidation +
// observability dance.
type AdminService struct {
	log      *slog.Logger
	admin    AdminRepo
	checkins AdminCheckinRepo
	tokens   AdminRefreshRepo
	caches   cacheAdapter
	// roles is the optional RBAC cache invalidator. Set by the handler
	// layer (it owns the RoleResolver). Nil-safe.
	roles RoleCacheInvalidator
}

// RoleCacheInvalidator is the slice of *middleware.RoleResolver the
// admin service uses to evict cached role entries after a role/suspend
// write. Defined here so service doesn't import middleware.
type RoleCacheInvalidator interface {
	Invalidate(userID string)
}

// WithRoleCache wires the RBAC cache so role changes flush the per-user
// entry on commit. Idempotent; nil-safe.
func (s *AdminService) WithRoleCache(inv RoleCacheInvalidator) *AdminService {
	if s != nil {
		s.roles = inv
	}
	return s
}

// AdminRepo is the slice of repository.AdminRepo this service uses.
type AdminRepo interface {
	ApproveBeverageRequest(ctx context.Context, p repository.ApproveBeverageRequestParams) (string, error)
	RejectBeverageRequest(ctx context.Context, requestID, reviewerID, notes string) error
	ModerateCheckin(ctx context.Context, checkinID, moderatorID string, notes *string) error
	SuspendUser(ctx context.Context, userID, moderatorID string) error
	UpdateUserRole(ctx context.Context, userID, moderatorID string, role domain.UserRole) error
	ListBeverageRequests(ctx context.Context, p repository.ListBeverageRequestsParams) ([]repository.BeverageRequestRow, error)
	ListUsers(ctx context.Context, p repository.ListUsersParams) ([]repository.AdminUserRow, error)
}

// AdminCheckinRepo is the slice we need from CheckinRepo (pre-fetch the
// beverage_id before ModerateCheckin so we can bust the cache after the
// trigger fires).
type AdminCheckinRepo interface {
	Get(ctx context.Context, id, viewerID string) (*domain.Checkin, error)
}

// AdminRefreshRepo is the slice we need from RefreshTokenRepo for user
// suspension (revoke every active refresh token).
type AdminRefreshRepo interface {
	RevokeAllForUser(ctx context.Context, userID string) (int, error)
}

func newAdminService(d Deps) *AdminService {
	s := &AdminService{
		log:    d.Log,
		caches: cacheAdapter{c: d.Caches, db: d.DB, log: d.Log},
	}
	if d.Repos != nil {
		s.admin = d.Repos.Admin
		s.checkins = d.Repos.Checkins
		s.tokens = d.Repos.RefreshTokens
	}
	return s
}

// ApproveBeverageRequest orchestrates the multi-write approve flow + cache bust.
func (s *AdminService) ApproveBeverageRequest(ctx context.Context, p repository.ApproveBeverageRequestParams) (string, error) {
	bevID, err := s.admin.ApproveBeverageRequest(ctx, p)
	if err != nil {
		return "", err
	}
	if p.BreweryID != "" {
		s.caches.InvalidateBreweryDetail(ctx, p.BreweryID)
	}
	return bevID, nil
}

// RejectBeverageRequest pass-through.
func (s *AdminService) RejectBeverageRequest(ctx context.Context, requestID, reviewerID, notes string) error {
	return s.admin.RejectBeverageRequest(ctx, requestID, reviewerID, notes)
}

// ModerateCheckin owns the (Get beverage_id → ModerateCheckin → invalidate
// beverage cache) dance currently in handlers/admin.go.
func (s *AdminService) ModerateCheckin(ctx context.Context, checkinID, moderatorID string, notes *string) error {
	var bevID string
	if cached, err := s.checkins.Get(ctx, checkinID, moderatorID); err == nil {
		bevID = cached.Beverage.ID
	}
	if err := s.admin.ModerateCheckin(ctx, checkinID, moderatorID, notes); err != nil {
		return err
	}
	s.caches.InvalidateBeverageDetail(ctx, bevID)
	return nil
}

// SuspendUser owns the suspend + refresh-token revoke combo. The
// SoftDeleteCache.Add() call stays at the handler today (the cache is
// process-local and shouldn't be a service dependency). SEC-027: the
// role cache for the suspended user is flushed immediately so any
// in-flight admin request stops seeing the old role on next refresh.
func (s *AdminService) SuspendUser(ctx context.Context, userID, moderatorID string) error {
	if err := s.admin.SuspendUser(ctx, userID, moderatorID); err != nil {
		return err
	}
	if _, err := s.tokens.RevokeAllForUser(ctx, userID); err != nil {
		return err
	}
	if s.roles != nil {
		s.roles.Invalidate(userID)
	}
	return nil
}

// UpdateUserRole owns the role write + RBAC cache flush.
func (s *AdminService) UpdateUserRole(ctx context.Context, userID, moderatorID string, role domain.UserRole) error {
	if err := s.admin.UpdateUserRole(ctx, userID, moderatorID, role); err != nil {
		return err
	}
	if s.roles != nil {
		s.roles.Invalidate(userID)
	}
	return nil
}

// ListBeverageRequests pass-through.
func (s *AdminService) ListBeverageRequests(ctx context.Context, p repository.ListBeverageRequestsParams) ([]repository.BeverageRequestRow, error) {
	return s.admin.ListBeverageRequests(ctx, p)
}

// ListUsers pass-through.
func (s *AdminService) ListUsers(ctx context.Context, p repository.ListUsersParams) ([]repository.AdminUserRow, error) {
	return s.admin.ListUsers(ctx, p)
}

var (
	_ = errors.Is
	_ = domain.ErrNotFound
)
