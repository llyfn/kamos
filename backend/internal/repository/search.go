package repository

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/kamos/api/internal/domain"
)

type SearchRepo struct{ db *pgxpool.Pool }

// SearchResult is a sum type: only one of Beverage/Brewery is non-nil.
type SearchResult struct {
	Type     string           `json:"type"` // 'beverage' | 'brewery'
	Beverage *domain.Beverage `json:"beverage,omitempty"`
	Brewery  *domain.Brewery  `json:"brewery,omitempty"`
}

// SearchBeverages fetches up to limit+1 beverages matching q, keyset-
// paginated by id. `cursorID` is the inclusive-exclusive (`<`) id boundary;
// nil for the first page.
func (r *SearchRepo) SearchBeverages(ctx context.Context, q string, cursorID *string, limit int) ([]SearchResult, error) {
	if limit <= 0 {
		limit = 20
	}
	const bq = beverageSelect + `
WHERE to_tsvector('simple',
        coalesce(b.name_i18n->>'en','') || ' ' ||
        coalesce(b.name_i18n->>'ja','') || ' ' ||
        coalesce(b.name_i18n->>'ko','')
      ) @@ plainto_tsquery('simple', $1)
  AND ($2::text IS NULL OR b.id::text < $2)
ORDER BY b.check_in_count DESC, b.id DESC
LIMIT $3;`
	rows, err := r.db.Query(ctx, bq, q, cursorID, limit+1)
	if err != nil {
		return nil, fmt.Errorf("SearchBeverages: %w", err)
	}
	defer rows.Close()
	brepo := BeverageRepo{db: r.db}
	var out []SearchResult
	for rows.Next() {
		bv, err := scanBeverage(rows)
		if err != nil {
			return nil, fmt.Errorf("SearchBeverages scan: %w", err)
		}
		d, err := brepo.toBeverage(bv)
		if err != nil {
			return nil, err
		}
		out = append(out, SearchResult{Type: "beverage", Beverage: &d})
	}
	return out, rows.Err()
}

// SearchBreweries fetches up to limit+1 breweries matching q.
func (r *SearchRepo) SearchBreweries(ctx context.Context, q string, cursorID *string, limit int) ([]SearchResult, error) {
	if limit <= 0 {
		limit = 20
	}
	const brq = `
SELECT id, name_i18n, prefecture, region, founded_year, website, description_i18n, created_at
FROM breweries
WHERE to_tsvector('simple',
        coalesce(name_i18n->>'en','') || ' ' ||
        coalesce(name_i18n->>'ja','') || ' ' ||
        coalesce(name_i18n->>'ko','')
      ) @@ plainto_tsquery('simple', $1)
  AND ($2::text IS NULL OR id::text < $2)
ORDER BY id DESC
LIMIT $3;`
	rows, err := r.db.Query(ctx, brq, q, cursorID, limit+1)
	if err != nil {
		return nil, fmt.Errorf("SearchBreweries: %w", err)
	}
	defer rows.Close()
	var out []SearchResult
	for rows.Next() {
		b, err := scanBrewery(rows)
		if err != nil {
			return nil, fmt.Errorf("SearchBreweries scan: %w", err)
		}
		out = append(out, SearchResult{Type: "brewery", Brewery: b})
	}
	return out, rows.Err()
}
