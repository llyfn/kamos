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
	// Stage 8 (admin catalog soft-delete): exclude tombstoned rows from
	// /v1/search the same way List/Detail do.
	const bq = beverageListSelect + `
WHERE b.deleted_at IS NULL
  AND br.deleted_at IS NULL
  AND to_tsvector('simple',
        coalesce(b.name_i18n->>'en','') || ' ' ||
        coalesce(b.name_i18n->>'ja','') || ' ' ||
        coalesce(b.name_i18n->>'ko','')
      ) @@ plainto_tsquery('simple', $1)
  AND ($2::text IS NULL OR b.id < $2::uuid)
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
		bv, err := scanBeverageList(rows)
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
	// Stage 8: exclude tombstoned rows from public search.
	// Migration 016: prefecture is nested via the LEFT JOIN to
	// prefectures + regions (brewery.prefecture_id is nullable).
	const brq = `
SELECT b.id, b.name_i18n, b.founded_year, b.website, b.description_i18n, b.created_at,` + breweryPrefectureSelectCols + `
FROM breweries b` + breweriesPrefectureJoinClause + `
WHERE b.deleted_at IS NULL
  AND to_tsvector('simple',
        coalesce(b.name_i18n->>'en','') || ' ' ||
        coalesce(b.name_i18n->>'ja','') || ' ' ||
        coalesce(b.name_i18n->>'ko','')
      ) @@ plainto_tsquery('simple', $1)
  AND ($2::text IS NULL OR b.id < $2::uuid)
ORDER BY b.id DESC
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
