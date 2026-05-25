package service

import (
	"context"
	"log/slog"
	"time"

	"github.com/jackc/pgx/v5"

	"github.com/kamos/api/internal/domain"
)

// NotificationService owns the inbox read path and the emit hooks called
// from the toast / comment / follow paths.
//
// SPEC §5.4: every emit MUST run in the same transaction as the source
// event. The emit methods take a pgx.Tx and are called from a service that
// has already opened the source-event tx (CheckinService.ToggleToast,
// CommentService.Create, SocialService.Follow/Approve/Decline/Unfollow).
//
// Self-action filtering: every Emit* method short-circuits when
// recipient == actor so the DB CHECK notifications_no_self never fires
// for a legitimate caller. The CHECK is the backstop, not the gate.
type NotificationService struct {
	log           *slog.Logger
	notifications NotificationRepo
}

// NotificationRepo is the slice of repository.NotificationRepo this service
// uses. Defined here (consumer-side) so the service is testable with a
// hand-rolled fake.
type NotificationRepo interface {
	InsertToastTx(ctx context.Context, tx pgx.Tx, recipientID, actorID, checkInID string) error
	InsertCommentTx(ctx context.Context, tx pgx.Tx, recipientID, actorID, checkInID, commentID string) error
	InsertFollowTx(ctx context.Context, tx pgx.Tx, recipientID, actorID string) error
	InsertFollowRequestTx(ctx context.Context, tx pgx.Tx, recipientID, actorID string) error
	InsertFollowApprovedTx(ctx context.Context, tx pgx.Tx, recipientID, actorID string) error
	DeleteFollowRequestTx(ctx context.Context, tx pgx.Tx, recipientID, actorID string) error
	ListByRecipient(ctx context.Context, recipientID string, cursorTs *time.Time, cursorID *string, limit int) ([]domain.Notification, error)
	CountUnread(ctx context.Context, recipientID string) (int, error)
	MarkRead(ctx context.Context, recipientID string, ids []string) (int, error)
	MarkAllRead(ctx context.Context, recipientID string) (int, error)
}

func newNotificationService(d Deps) *NotificationService {
	s := &NotificationService{log: d.Log}
	if d.Repos != nil {
		s.notifications = d.Repos.Notifications
	}
	return s
}

// skip centralizes the "this emit is a no-op" precondition every Emit*
// method shares: SPEC §5.4's self-action exclusion + defensive guards
// against a nil receiver / unwired repo / empty id from a misconfigured
// caller. The DB CHECK notifications_no_self is the backstop.
func (s *NotificationService) skip(recipientID, actorID string) bool {
	return s == nil || s.notifications == nil ||
		recipientID == "" || actorID == "" || recipientID == actorID
}

// EmitToast inserts a `toast` notification. No-op when recipient == actor.
func (s *NotificationService) EmitToast(ctx context.Context, tx pgx.Tx, recipientID, actorID, checkInID string) error {
	if s.skip(recipientID, actorID) {
		return nil
	}
	return s.notifications.InsertToastTx(ctx, tx, recipientID, actorID, checkInID)
}

// EmitComment inserts a `comment` notification. No-op when recipient == actor.
func (s *NotificationService) EmitComment(ctx context.Context, tx pgx.Tx, recipientID, actorID, checkInID, commentID string) error {
	if s.skip(recipientID, actorID) {
		return nil
	}
	return s.notifications.InsertCommentTx(ctx, tx, recipientID, actorID, checkInID, commentID)
}

// EmitFollow inserts a `follow` notification (public auto-accept path).
// No-op when recipient == actor — should never happen; defensive guard
// matches the repo's ErrFollowSelf gate.
func (s *NotificationService) EmitFollow(ctx context.Context, tx pgx.Tx, recipientID, actorID string) error {
	if s.skip(recipientID, actorID) {
		return nil
	}
	return s.notifications.InsertFollowTx(ctx, tx, recipientID, actorID)
}

// EmitFollowRequest inserts a `follow_request` notification (private path).
func (s *NotificationService) EmitFollowRequest(ctx context.Context, tx pgx.Tx, recipientID, actorID string) error {
	if s.skip(recipientID, actorID) {
		return nil
	}
	return s.notifications.InsertFollowRequestTx(ctx, tx, recipientID, actorID)
}

// EmitFollowApproved inserts a `follow_approved` notification AND deletes
// the original `follow_request` row from the approver's inbox so the inbox
// stays clean.
//
// recipientID = original requester (the one who sent the follow request),
// actorID    = the approver (the original `followed_id`).
func (s *NotificationService) EmitFollowApproved(ctx context.Context, tx pgx.Tx, recipientID, actorID string) error {
	if s.skip(recipientID, actorID) {
		return nil
	}
	if err := s.notifications.InsertFollowApprovedTx(ctx, tx, recipientID, actorID); err != nil {
		return err
	}
	// Approver's inbox previously held a `follow_request` row from the
	// requester; drop it now that the request has reached a terminal state.
	return s.notifications.DeleteFollowRequestTx(ctx, tx, actorID, recipientID)
}

// RemoveFollowRequest deletes the pending `follow_request` notification
// from the recipient's inbox. Called by Decline and by Unfollow when the
// underlying follow row was still `pending` (the requester withdrew before
// approval). Idempotent.
//
// recipientID = the approver/decliner whose inbox holds the request row,
// actorID    = the requester.
func (s *NotificationService) RemoveFollowRequest(ctx context.Context, tx pgx.Tx, recipientID, actorID string) error {
	if s == nil || s.notifications == nil || recipientID == "" || actorID == "" {
		return nil
	}
	return s.notifications.DeleteFollowRequestTx(ctx, tx, recipientID, actorID)
}

// List pages through the recipient's inbox.
func (s *NotificationService) List(ctx context.Context, recipientID string, cursorTs *time.Time, cursorID *string, limit int) ([]domain.Notification, error) {
	return s.notifications.ListByRecipient(ctx, recipientID, cursorTs, cursorID, limit)
}

// CountUnread returns the unread count for the recipient's badge dot.
func (s *NotificationService) CountUnread(ctx context.Context, recipientID string) (int, error) {
	return s.notifications.CountUnread(ctx, recipientID)
}

// MarkRead marks the supplied ids read for the recipient.
//
// Pool-scoped IDOR: SQL WHERE restricts UPDATE to recipient_user_id = $caller
// (see handler doc for oracle rationale).
func (s *NotificationService) MarkRead(ctx context.Context, recipientID string, ids []string) (int, error) {
	return s.notifications.MarkRead(ctx, recipientID, ids)
}

// MarkAllRead flips every unread row for the recipient.
func (s *NotificationService) MarkAllRead(ctx context.Context, recipientID string) (int, error) {
	return s.notifications.MarkAllRead(ctx, recipientID)
}
