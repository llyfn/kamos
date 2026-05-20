package service

import (
	"context"
	"errors"
	"log/slog"
	"time"

	"github.com/kamos/api/internal/apierror"
	"github.com/kamos/api/internal/domain"
	"github.com/kamos/api/internal/repository"
)

// CommentService owns the comment write paths. Visibility gating + insert +
// observability + soft-delete-with-moderation-log all live here so handlers
// shrink to decode → validate → call → respond.
type CommentService struct {
	log      *slog.Logger
	comments CommentRepo
	checkins CommentCheckinRepo
	users    CommentUserRepo
}

// CommentRepo is the slice of repository.CommentRepo this service uses.
type CommentRepo interface {
	Create(ctx context.Context, checkInID, userID, body string) (*domain.Comment, error)
	Get(ctx context.Context, id string) (*domain.Comment, error)
	List(ctx context.Context, checkInID string, cursorTs *time.Time, cursorID *string, limit int) ([]domain.Comment, error)
	ListForAdmin(ctx context.Context, onlyDeleted bool, cursorTs *time.Time, cursorID *string, limit int) ([]repository.AdminCommentRow, error)
	SoftDelete(ctx context.Context, commentID, moderatorID string, isAdmin bool, notes *string) error
}

// CommentCheckinRepo is the slice the comment service needs from the
// CheckinRepo (just the privacy gate).
type CommentCheckinRepo interface {
	AssertViewerCanSeeCheckin(ctx context.Context, checkInID, viewerID string) error
}

// CommentUserRepo is the slice for role-resolution on the admin-delete path.
type CommentUserRepo interface {
	GetUserRole(ctx context.Context, userID string) (domain.UserRole, error)
}

func newCommentService(d Deps) *CommentService {
	s := &CommentService{log: d.Log}
	if d.Repos != nil {
		s.comments = d.Repos.Comments
		s.checkins = d.Repos.Checkins
		s.users = d.Repos.Users
	}
	return s
}

// List orchestrates the comment-thread read with the parent-privacy gate.
func (s *CommentService) List(ctx context.Context, checkInID, viewerID string, cursorTs *time.Time, cursorID *string, limit int) ([]domain.Comment, error) {
	if err := s.checkins.AssertViewerCanSeeCheckin(ctx, checkInID, viewerID); err != nil {
		return nil, err
	}
	return s.comments.List(ctx, checkInID, cursorTs, cursorID, limit)
}

// Create orchestrates the insert. (Rate-limiting lives at the router.)
func (s *CommentService) Create(ctx context.Context, checkInID, userID, body string) (*domain.Comment, error) {
	return s.comments.Create(ctx, checkInID, userID, body)
}

// Delete owns the role-aware soft-delete: owner is always allowed; non-
// owners must be moderator or admin. The admin path writes a
// moderation_log row.
func (s *CommentService) Delete(ctx context.Context, commentID, viewerID string, notes *string) (isAdminPath bool, err error) {
	c, err := s.comments.Get(ctx, commentID)
	if err != nil {
		return false, err
	}
	isOwner := c.User.ID == viewerID
	if !isOwner {
		role, err := s.users.GetUserRole(ctx, viewerID)
		if err != nil {
			return false, err
		}
		if role != domain.RoleAdmin && role != domain.RoleModerator {
			return false, apierror.ErrForbidden
		}
		isAdminPath = true
	}
	if !isAdminPath {
		notes = nil // owners can send notes; ignore.
	}
	if err := s.comments.SoftDelete(ctx, commentID, viewerID, isAdminPath, notes); err != nil {
		return isAdminPath, err
	}
	return isAdminPath, nil
}

// ModerateForAdmin is the admin-only delete path (notes always recorded).
func (s *CommentService) ModerateForAdmin(ctx context.Context, commentID, moderatorID string, notes *string) error {
	return s.comments.SoftDelete(ctx, commentID, moderatorID, true, notes)
}

// ListForAdmin pass-through.
func (s *CommentService) ListForAdmin(ctx context.Context, onlyDeleted bool, cursorTs *time.Time, cursorID *string, limit int) ([]repository.AdminCommentRow, error) {
	return s.comments.ListForAdmin(ctx, onlyDeleted, cursorTs, cursorID, limit)
}

var _ = errors.Is
