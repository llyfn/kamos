// Package repository implements the pgx-backed data access layer. The SQL
// here matches docs/db/query_patterns.md as closely as possible — when in
// doubt, that file wins.
package repository

import (
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/kamos/api/internal/domain"
)

// Repos bundles the per-domain repositories. Handlers take a *Repos so they
// can mix domains without a constructor explosion.
type Repos struct {
	DB            *pgxpool.Pool
	Users         *UserRepo
	Beverages     *BeverageRepo
	Producers     *ProducerRepo
	Checkins      *CheckinRepo
	Comments      *CommentRepo
	Feed          *FeedRepo
	Social        *SocialRepo
	Collections   *CollectionRepo
	Search        *SearchRepo
	Taxonomy      *TaxonomyRepo
	RefreshTokens *RefreshTokenRepo
	PhotoUploads  *PhotoUploadRepo
	Venues        *VenueRepo
	Admin         *AdminRepo
	ModerationLog *ModerationLogRepo
	Geo           *GeoRepo
}

// New wires the bundle.
func New(db *pgxpool.Pool) *Repos {
	return &Repos{
		DB:            db,
		Users:         &UserRepo{db: db},
		Beverages:     &BeverageRepo{db: db},
		Producers:     &ProducerRepo{db: db},
		Checkins:      &CheckinRepo{db: db},
		Comments:      &CommentRepo{db: db},
		Feed:          &FeedRepo{db: db},
		Social:        &SocialRepo{db: db},
		Collections:   &CollectionRepo{db: db},
		Search:        &SearchRepo{db: db},
		Taxonomy:      &TaxonomyRepo{db: db},
		RefreshTokens: &RefreshTokenRepo{db: db},
		PhotoUploads:  &PhotoUploadRepo{db: db},
		Venues:        &VenueRepo{db: db},
		Admin:         &AdminRepo{db: db},
		ModerationLog: &ModerationLogRepo{db: db},
		Geo:           &GeoRepo{db: db},
	}
}

// wrapNoRows maps pgx.ErrNoRows to domain.ErrNotFound. Anything else is
// wrapped with the op name for traceability.
func wrapNoRows(op string, err error) error {
	if err == nil {
		return nil
	}
	if errors.Is(err, pgx.ErrNoRows) {
		return domain.ErrNotFound
	}
	return fmt.Errorf("%s: %w", op, err)
}
