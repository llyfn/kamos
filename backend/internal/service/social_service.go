package service

import (
	"context"
	"log/slog"
)

// SocialService owns the follow / unfollow / approve / decline flows.
// Today the handlers call SocialRepo directly with a per-method shape;
// this service hosts those calls behind one bundle and gives us a single
// place to add cross-cutting concerns later (cache busts on follow-state,
// notification dispatch, etc).
type SocialService struct {
	log    *slog.Logger
	social SocialRepo
}

// SocialRepo is the slice of repository.SocialRepo this service uses.
type SocialRepo interface {
	Follow(ctx context.Context, follower, followed string) (string, error)
	Unfollow(ctx context.Context, follower, followed string) error
	Approve(ctx context.Context, followedID, followerID string) error
	Decline(ctx context.Context, followedID, followerID string) error
}

func newSocialService(d Deps) *SocialService {
	s := &SocialService{log: d.Log}
	if d.Repos != nil {
		s.social = d.Repos.Social
	}
	return s
}

// Follow is a thin pass-through. The follower-self gate lives in the repo
// (returns ErrFollowSelf); handler maps to 422.
func (s *SocialService) Follow(ctx context.Context, follower, followed string) (string, error) {
	return s.social.Follow(ctx, follower, followed)
}

// Unfollow is a thin pass-through.
func (s *SocialService) Unfollow(ctx context.Context, follower, followed string) error {
	return s.social.Unfollow(ctx, follower, followed)
}

// Approve is a thin pass-through.
func (s *SocialService) Approve(ctx context.Context, followedID, followerID string) error {
	return s.social.Approve(ctx, followedID, followerID)
}

// Decline is a thin pass-through.
func (s *SocialService) Decline(ctx context.Context, followedID, followerID string) error {
	return s.social.Decline(ctx, followedID, followerID)
}
