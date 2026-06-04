package service

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/kamos/api/internal/domain"
	"github.com/kamos/api/internal/observability"
	"github.com/kamos/api/internal/repository"
)

// CheckinService owns the check-in write paths. Every method that mutates
// the check-ins surface lives here; handlers shrink to decode → validate →
// call → respond.
type CheckinService struct {
	log       *slog.Logger
	db        *pgxpool.Pool
	checkins  CheckinRepo
	beverages CheckinBeverageRepo
	venues    CheckinVenueRepo
	notifs    *NotificationService
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
	CountPhotos(ctx context.Context, checkinID string) (int, error)
	// ToggleToastTx runs the full toggle in the supplied tx and reports
	// the new state plus the check-in owner (for the notification emit on
	// the "added" branch). owner == "" when the row was just removed —
	// the service skips the emit in that case.
	ToggleToastTx(ctx context.Context, tx pgx.Tx, userID, checkinID string) (state domain.ToastState, added bool, ownerID string, err error)
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

func newCheckinService(d Deps, notifs *NotificationService) *CheckinService {
	s := &CheckinService{
		log:       d.Log,
		db:        d.DB,
		notifs:    notifs,
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

// CheckinUpdateInput is the post-validation projection the handler passes
// to Update. The handler has already resolved photo upload IDs into the
// matching (public_url, upload_id) pairs via its PhotoUploadRepo + Storage
// references; the service just enforces the SPEC §4.2 4-photo cap and
// delegates the multi-row write to the repo.
type CheckinUpdateInput struct {
	Req               domain.UpdateCheckinRequest
	AddPhotoURLs      []string
	AddPhotoUploadIDs []string
	RemovePhotoURLs   []string
}

// Update owns the check-in update + cache-bust dance.
func (s *CheckinService) Update(ctx context.Context, userID, id string, in CheckinUpdateInput) (*domain.Checkin, error) {
	// SPEC §4.2 four-photo cap on the resulting set. We compute the
	// floor BEFORE the repo write so the canonical 422
	// PHOTO_CAP_EXCEEDED surfaces instead of the DB CHECK constraint
	// raising a generic 500.
	if len(in.AddPhotoURLs) > 0 || len(in.RemovePhotoURLs) > 0 {
		current, err := s.checkins.CountPhotos(ctx, id)
		if err != nil {
			return nil, fmt.Errorf("CheckinService.Update count: %w", err)
		}
		if current-len(in.RemovePhotoURLs)+len(in.AddPhotoURLs) > 4 {
			return nil, domain.ErrPhotoCapExceeded
		}
	}

	req := in.Req
	up := repository.UpdateCheckinParams{
		ID:                id,
		UserID:            userID,
		Rating:            req.Rating,
		ClearRating:       req.ClearRating,
		Review:            req.Review,
		ClearReview:       req.ClearReview,
		ClearPrice:        req.ClearPrice,
		PurchaseType:      req.PurchaseType,
		Tags:              req.Tags,
		AddPhotoURLs:      in.AddPhotoURLs,
		AddPhotoUploadIDs: in.AddPhotoUploadIDs,
		RemovePhotoURLs:   in.RemovePhotoURLs,
		TouchEdited:       updateTouchedAnyField(req, in),
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

// updateTouchedAnyField returns true when the PATCH carries at least one
// tracked-field change. A no-op PATCH (all fields absent) leaves edited_at
// alone so the "edited" marker doesn't flicker on a save with no diff.
//
// We deliberately treat "field present but unchanged" (e.g. rating set to
// its existing value) as a touch — the wire shape can't distinguish
// present-and-unchanged from present-and-changed without an extra DB
// round-trip, and the SPEC §4.4 contract says "any tracked-field change"
// rather than "any tracked-field write". Mirrors the §7 query-pattern note.
func updateTouchedAnyField(req domain.UpdateCheckinRequest, in CheckinUpdateInput) bool {
	switch {
	case req.Rating != nil, req.ClearRating,
		req.Review != nil, req.ClearReview,
		req.Price != nil, req.ClearPrice,
		req.PurchaseType != nil,
		req.Tags != nil,
		len(in.AddPhotoURLs) > 0,
		len(in.RemovePhotoURLs) > 0:
		return true
	}
	return false
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

// ToggleToast wraps the toast toggle in a single transaction so the
// notification emit on the "added" branch lands atomically with the
// toasts row INSERT. The DB pool is required to begin the tx; without it
// (tests that don't wire a pool), the call returns an error so the
// missing dependency is loud.
func (s *CheckinService) ToggleToast(ctx context.Context, userID, checkinID string) (domain.ToastState, error) {
	if s.db == nil {
		return domain.ToastState{}, errors.New("CheckinService.ToggleToast: nil db pool")
	}
	tx, err := s.db.Begin(ctx)
	if err != nil {
		return domain.ToastState{}, fmt.Errorf("CheckinService.ToggleToast begin: %w", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()

	state, added, ownerID, err := s.checkins.ToggleToastTx(ctx, tx, userID, checkinID)
	if err != nil {
		return domain.ToastState{}, err
	}
	if added && ownerID != "" && ownerID != userID {
		if err := s.notifs.EmitToast(ctx, tx, ownerID, userID, checkinID); err != nil {
			return domain.ToastState{}, fmt.Errorf("CheckinService.ToggleToast emit: %w", err)
		}
	}
	if err := tx.Commit(ctx); err != nil {
		return domain.ToastState{}, fmt.Errorf("CheckinService.ToggleToast commit: %w", err)
	}
	return state, nil
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
