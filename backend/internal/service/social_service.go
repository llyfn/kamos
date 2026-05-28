package service

import (
	"context"
	"errors"
	"fmt"
	"log/slog"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// SocialService owns the follow / unfollow / approve / decline flows.
// Each mutating call wraps the source-event SQL + notification emit in a
// single transaction so the inbox stays consistent with the underlying
// `follows` row.
type SocialService struct {
	log    *slog.Logger
	db     *pgxpool.Pool
	social SocialRepo
	notifs *NotificationService
}

// SocialRepo is the slice of repository.SocialRepo this service uses.
type SocialRepo interface {
	FollowTx(ctx context.Context, tx pgx.Tx, follower, followed string) (status string, created bool, err error)
	UnfollowTx(ctx context.Context, tx pgx.Tx, follower, followed string) (prevStatus string, err error)
	ApproveTx(ctx context.Context, tx pgx.Tx, followedID, followerID string) error
	DeclineTx(ctx context.Context, tx pgx.Tx, followedID, followerID string) error
}

func newSocialService(d Deps, notifs *NotificationService) *SocialService {
	s := &SocialService{log: d.Log, db: d.DB, notifs: notifs}
	if d.Repos != nil {
		s.social = d.Repos.Social
	}
	return s
}

// Follow wraps INSERT INTO follows + the matching notification emit in a
// single transaction. Public targets get a `follow` row; private targets
// get a `follow_request` row. Idempotent re-follows do not emit (created
// flag is false).
func (s *SocialService) Follow(ctx context.Context, follower, followed string) (string, error) {
	if s.db == nil {
		return "", errors.New("SocialService.Follow: nil db pool")
	}
	tx, err := s.db.Begin(ctx)
	if err != nil {
		return "", fmt.Errorf("SocialService.Follow begin: %w", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()

	status, created, err := s.social.FollowTx(ctx, tx, follower, followed)
	if err != nil {
		return "", err
	}
	if created {
		switch status {
		case "accepted":
			if err := s.notifs.EmitFollow(ctx, tx, followed, follower); err != nil {
				return "", fmt.Errorf("SocialService.Follow emit: %w", err)
			}
		case "pending":
			if err := s.notifs.EmitFollowRequest(ctx, tx, followed, follower); err != nil {
				return "", fmt.Errorf("SocialService.Follow emit: %w", err)
			}
		}
	}
	if err := tx.Commit(ctx); err != nil {
		return "", fmt.Errorf("SocialService.Follow commit: %w", err)
	}
	return status, nil
}

// Unfollow deletes the row and, if it was a `pending` request, also
// removes the `follow_request` notification from the would-be approver's
// inbox so a withdrawn request stops showing.
func (s *SocialService) Unfollow(ctx context.Context, follower, followed string) error {
	if s.db == nil {
		return errors.New("SocialService.Unfollow: nil db pool")
	}
	tx, err := s.db.Begin(ctx)
	if err != nil {
		return fmt.Errorf("SocialService.Unfollow begin: %w", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()

	prev, err := s.social.UnfollowTx(ctx, tx, follower, followed)
	if err != nil {
		return err
	}
	if prev == "pending" {
		if err := s.notifs.RemoveFollowRequest(ctx, tx, followed, follower); err != nil {
			return fmt.Errorf("SocialService.Unfollow cleanup: %w", err)
		}
	}
	if err := tx.Commit(ctx); err != nil {
		return fmt.Errorf("SocialService.Unfollow commit: %w", err)
	}
	return nil
}

// Approve flips a pending request to accepted, emits `follow_approved` to
// the original requester, and removes the now-stale `follow_request` row
// from the approver's inbox.
func (s *SocialService) Approve(ctx context.Context, followedID, followerID string) error {
	if s.db == nil {
		return errors.New("SocialService.Approve: nil db pool")
	}
	tx, err := s.db.Begin(ctx)
	if err != nil {
		return fmt.Errorf("SocialService.Approve begin: %w", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()

	if err := s.social.ApproveTx(ctx, tx, followedID, followerID); err != nil {
		return err
	}
	// EmitFollowApproved is recipient=requester (followerID), actor=approver (followedID).
	// The same call also deletes the approver's `follow_request` row.
	if err := s.notifs.EmitFollowApproved(ctx, tx, followerID, followedID); err != nil {
		return fmt.Errorf("SocialService.Approve emit: %w", err)
	}
	if err := tx.Commit(ctx); err != nil {
		return fmt.Errorf("SocialService.Approve commit: %w", err)
	}
	return nil
}

// Decline removes the pending request and drops the matching
// `follow_request` notification from the decliner's inbox.
func (s *SocialService) Decline(ctx context.Context, followedID, followerID string) error {
	if s.db == nil {
		return errors.New("SocialService.Decline: nil db pool")
	}
	tx, err := s.db.Begin(ctx)
	if err != nil {
		return fmt.Errorf("SocialService.Decline begin: %w", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()

	if err := s.social.DeclineTx(ctx, tx, followedID, followerID); err != nil {
		return err
	}
	if err := s.notifs.RemoveFollowRequest(ctx, tx, followedID, followerID); err != nil {
		return fmt.Errorf("SocialService.Decline cleanup: %w", err)
	}
	if err := tx.Commit(ctx); err != nil {
		return fmt.Errorf("SocialService.Decline commit: %w", err)
	}
	return nil
}
