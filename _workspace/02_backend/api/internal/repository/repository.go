// Package repository implements the pgx-backed data access layer. The SQL
// here matches _workspace/02_backend/db/query_patterns.md as closely as
// possible — when in doubt, that file wins.
package repository

import (
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/kamos/api/internal/apierror"
)

// Repos bundles the per-domain repositories. Handlers take a *Repos so they
// can mix domains without a constructor explosion.
type Repos struct {
	DB          *pgxpool.Pool
	Users       *UserRepo
	Beverages   *BeverageRepo
	Breweries   *BreweryRepo
	Checkins    *CheckinRepo
	Feed        *FeedRepo
	Social      *SocialRepo
	Collections *CollectionRepo
	Search      *SearchRepo
	Taxonomy    *TaxonomyRepo
}

// New wires the bundle.
func New(db *pgxpool.Pool) *Repos {
	return &Repos{
		DB:          db,
		Users:       &UserRepo{db: db},
		Beverages:   &BeverageRepo{db: db},
		Breweries:   &BreweryRepo{db: db},
		Checkins:    &CheckinRepo{db: db},
		Feed:        &FeedRepo{db: db},
		Social:      &SocialRepo{db: db},
		Collections: &CollectionRepo{db: db},
		Search:      &SearchRepo{db: db},
		Taxonomy:    &TaxonomyRepo{db: db},
	}
}

// wrapNoRows maps pgx.ErrNoRows to apierror.ErrNotFound. Anything else is
// wrapped with the op name for traceability.
func wrapNoRows(op string, err error) error {
	if err == nil {
		return nil
	}
	if errors.Is(err, pgx.ErrNoRows) {
		return apierror.ErrNotFound
	}
	return fmt.Errorf("%s: %w", op, err)
}
