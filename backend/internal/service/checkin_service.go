package service

import (
	"context"
	"fmt"
	"log/slog"
	"time"

	"github.com/kamos/api/internal/domain"
	"github.com/kamos/api/internal/observability"
	"github.com/kamos/api/internal/repository"
)

// CheckinService owns the check-in write paths. Every method that mutates
// the check-ins surface lives here; handlers shrink to decode → validate →
// call → respond.
type CheckinService struct {
	log       *slog.Logger
	checkins  CheckinRepo
	beverages CheckinBeverageRepo
	venues    CheckinVenueRepo
	caches    cacheAdapter
	onCreated counterFn
}

// CheckinRepo is the slice of repository.CheckinRepo this service uses.
type CheckinRepo interface {
	Create(ctx context.Context, p repository.CreateCheckinParams) (string, time.Time, error)
	Get(ctx context.Context, id, viewerID string) (*domain.Checkin, error)
	Update(ctx context.Context, p repository.UpdateCheckinParams) error
	SoftDelete(ctx context.Context, id, userID string) error
	AddPhoto(ctx context.Context, checkinID, userID, photoURL string) (domain.PhotoRef, error)
	ToggleToast(ctx context.Context, userID, checkinID string) (domain.ToastState, error)
}

// CheckinBeverageRepo is the slice of repository.BeverageRepo this service
// uses (just existence checks for the "does this beverage exist?" gate).
type CheckinBeverageRepo interface {
	Exists(ctx context.Context, id string) (bool, error)
}

// CheckinVenueRepo is the slice of repository.VenueRepo this service uses.
type CheckinVenueRepo interface {
	UpsertByFoursquareID(ctx context.Context, in repository.UpsertVenueInput) (string, error)
	GetByID(ctx context.Context, id string) (*domain.Venue, error)
}

func newCheckinService(d Deps) *CheckinService {
	s := &CheckinService{
		log:       d.Log,
		caches:    cacheAdapter{c: d.Caches, db: d.DB, log: d.Log},
		onCreated: observability.IncCheckinsCreated,
	}
	if d.Repos != nil {
		s.checkins = d.Repos.Checkins
		s.beverages = d.Repos.Beverages
		s.venues = d.Repos.Venues
	}
	return s
}

// Create owns the full check-in create dance: beverage-exists check →
// venue resolve → insert check-in + photos + tags (in repo tx) → reload
// hydrated → invalidate caches → bump counter.
func (s *CheckinService) Create(ctx context.Context, userID string, req domain.CreateCheckinRequest) (*domain.Checkin, error) {
	exists, err := s.beverages.Exists(ctx, req.BeverageID)
	if err != nil {
		return nil, fmt.Errorf("CheckinService.Create exists: %w", err)
	}
	if !exists {
		return nil, domain.ErrBeverageNotFound
	}
	venueID, err := s.resolveVenue(ctx, req.Venue)
	if err != nil {
		return nil, err
	}
	p := repository.CreateCheckinParams{
		UserID:       userID,
		BeverageID:   req.BeverageID,
		Rating:       req.Rating,
		ReviewText:   req.Review,
		PurchaseType: req.PurchaseType,
		ServingStyle: req.ServingStyle,
		PhotoURLs:    req.Photos,
		TagSlugs:     req.Tags,
		VenueID:      venueID,
	}
	if req.Price != nil {
		amt := req.Price.Amount
		ccy := req.Price.Currency
		md := req.Price.Mode
		p.PriceAmount = &amt
		p.PriceCcy = &ccy
		p.PriceUnit = &md
	}
	id, _, err := s.checkins.Create(ctx, p)
	if err != nil {
		return nil, fmt.Errorf("CheckinService.Create insert: %w", err)
	}
	out, err := s.checkins.Get(ctx, id, userID)
	if err != nil {
		return nil, fmt.Errorf("CheckinService.Create reload: %w", err)
	}
	s.caches.InvalidateBeverageDetail(ctx, req.BeverageID)
	if s.onCreated != nil {
		s.onCreated(ctx)
	}
	return out, nil
}

// Update owns the check-in update + cache-bust dance.
func (s *CheckinService) Update(ctx context.Context, userID, id string, req domain.UpdateCheckinRequest) (*domain.Checkin, error) {
	up := repository.UpdateCheckinParams{
		ID:           id,
		UserID:       userID,
		Rating:       req.Rating,
		ClearRating:  req.ClearRating,
		Review:       req.Review,
		ClearReview:  req.ClearReview,
		ClearPrice:   req.ClearPrice,
		PurchaseType: req.PurchaseType,
		ServingStyle: req.ServingStyle,
		Tags:         req.Tags,
	}
	if req.Price != nil {
		amt := req.Price.Amount
		ccy := req.Price.Currency
		md := req.Price.Mode
		up.PriceAmount = &amt
		up.PriceCcy = &ccy
		up.PriceUnit = &md
	}
	if err := s.checkins.Update(ctx, up); err != nil {
		return nil, err
	}
	out, err := s.checkins.Get(ctx, id, userID)
	if err != nil {
		return nil, fmt.Errorf("CheckinService.Update reload: %w", err)
	}
	s.caches.InvalidateBeverageDetail(ctx, out.Beverage.ID)
	return out, nil
}

// Delete owns the check-in soft-delete + cache-bust dance.
func (s *CheckinService) Delete(ctx context.Context, userID, id string) error {
	var bevID string
	if cached, err := s.checkins.Get(ctx, id, userID); err == nil {
		bevID = cached.Beverage.ID
	}
	if err := s.checkins.SoftDelete(ctx, id, userID); err != nil {
		return err
	}
	s.caches.InvalidateBeverageDetail(ctx, bevID)
	return nil
}

// ToggleToast is a thin pass-through; included on the service so handlers
// don't depend on the repo directly for write paths.
func (s *CheckinService) ToggleToast(ctx context.Context, userID, checkinID string) (domain.ToastState, error) {
	return s.checkins.ToggleToast(ctx, userID, checkinID)
}

// AddPhoto is a thin pass-through. The full presign + attach flow lives
// in the handler today; this service-method exists so the handler can
// route the actual DB write through services rather than the repo.
func (s *CheckinService) AddPhoto(ctx context.Context, checkinID, userID, publicURL string) (domain.PhotoRef, error) {
	return s.checkins.AddPhoto(ctx, checkinID, userID, publicURL)
}

// resolveVenue translates the optional CheckinVenue payload into a venue
// UUID for the check-in row. nil result + nil error = "no venue" (FK NULL).
func (s *CheckinService) resolveVenue(ctx context.Context, v *domain.CheckinVenue) (*string, error) {
	if v == nil {
		return nil, nil
	}
	if v.ID != nil && *v.ID != "" {
		got, err := s.venues.GetByID(ctx, *v.ID)
		if err != nil {
			return nil, err
		}
		id := got.ID
		return &id, nil
	}
	if v.FoursquareID != nil && *v.FoursquareID != "" && v.Name != nil && *v.Name != "" {
		id, err := s.venues.UpsertByFoursquareID(ctx, repository.UpsertVenueInput{
			FoursquareID: *v.FoursquareID,
			Name:         *v.Name,
			Address:      v.Address,
			Lat:          v.Lat,
			Lng:          v.Lng,
			Country:      v.Country,
			Prefecture:   v.Prefecture,
			Locality:     v.Locality,
		})
		if err != nil {
			return nil, err
		}
		return &id, nil
	}
	return nil, nil // silent drop
}
