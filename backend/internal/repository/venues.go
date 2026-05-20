package repository

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/kamos/api/internal/apierror"
	"github.com/kamos/api/internal/domain"
)

// VenueRepo backs the Phase 4 optional venue tag on check-ins. The Foursquare
// HTTP client lives in internal/foursquare; this repository works purely in
// domain types so it has no upstream-API knowledge. The handler is the seam
// that translates foursquare.Place into the upsert input here.
type VenueRepo struct{ db *pgxpool.Pool }

// UpsertVenueInput is the data the handler hands the repository after
// validating the CheckinVenue payload (or after parsing a foursquare.Place).
// `FoursquareID` is required — free-form (no-fsq) venues aren't accepted in
// Phase 4 and would need a separate insert path.
type UpsertVenueInput struct {
	FoursquareID string
	Name         string
	Address      *string
	Lat          *float64
	Lng          *float64
	Country      *string
	Prefecture   *string
	Locality     *string
}

// UpsertByFoursquareID inserts on miss; on a `foursquare_id` conflict it
// touches `updated_at` only and returns the existing id (first-writer-wins).
//
// SECURITY (SEC-002): the previous last-writer-wins behavior — re-writing
// every mutable column from the incoming payload — let any authed client
// silently overwrite the shared venue row's name/address/coords with
// whatever they claimed about that foursquare_id. We trust the first
// inserter as ground truth until a backend-side Foursquare refresh job
// exists (post-MVP). The `RETURNING id` clause works on the touch-only
// branch because PostgreSQL still emits the row.
func (r *VenueRepo) UpsertByFoursquareID(ctx context.Context, in UpsertVenueInput) (string, error) {
	if in.FoursquareID == "" {
		return "", fmt.Errorf("UpsertByFoursquareID: foursquare_id is required")
	}
	if in.Name == "" {
		return "", fmt.Errorf("UpsertByFoursquareID: name is required")
	}
	const q = `
INSERT INTO venues (foursquare_id, name, address, lat, lng, country, prefecture, locality)
VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
ON CONFLICT (foursquare_id) DO UPDATE SET
  updated_at = now()
RETURNING id;`
	var id string
	if err := r.db.QueryRow(ctx, q,
		in.FoursquareID, in.Name, in.Address,
		in.Lat, in.Lng,
		in.Country, in.Prefecture, in.Locality,
	).Scan(&id); err != nil {
		return "", fmt.Errorf("VenueRepo.UpsertByFoursquareID: %w", err)
	}
	return id, nil
}

// GetByID returns the full venue row. Maps pgx.ErrNoRows to NotFound so the
// handler can answer 404 without inspecting the underlying driver error.
func (r *VenueRepo) GetByID(ctx context.Context, id string) (*domain.Venue, error) {
	const q = `
SELECT id, foursquare_id, name, address, lat, lng,
       country, prefecture, locality, created_at, updated_at
FROM venues
WHERE id = $1;`
	var v domain.Venue
	err := r.db.QueryRow(ctx, q, id).Scan(
		&v.ID, &v.FoursquareID, &v.Name, &v.Address, &v.Lat, &v.Lng,
		&v.Country, &v.Prefecture, &v.Locality, &v.CreatedAt, &v.UpdatedAt,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, apierror.ErrNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("VenueRepo.GetByID: %w", err)
	}
	return &v, nil
}
