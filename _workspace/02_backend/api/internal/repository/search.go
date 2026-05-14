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

// Search performs cross-locale FTS on beverages OR breweries. When `typ` is
// empty it searches both — the result list interleaves them by id.
func (r *SearchRepo) Search(ctx context.Context, q string, typ *string, cursor *string, limit int) ([]SearchResult, error) {
	if limit <= 0 {
		limit = 20
	}

	doBev := typ == nil || *typ == "" || *typ == "beverage"
	doBrw := typ == nil || *typ == "" || *typ == "brewery"

	var out []SearchResult
	if doBev {
		const bq = beverageSelect + `
WHERE to_tsvector('simple',
        coalesce(b.name_i18n->>'en','') || ' ' ||
        coalesce(b.name_i18n->>'ja','') || ' ' ||
        coalesce(b.name_i18n->>'ko','')
      ) @@ plainto_tsquery('simple', $1)
  AND ($2::text IS NULL OR b.id::text < $2)
ORDER BY b.check_in_count DESC, b.id DESC
LIMIT $3;`
		rows, err := r.db.Query(ctx, bq, q, cursor, limit+1)
		if err != nil {
			return nil, fmt.Errorf("Search beverages: %w", err)
		}
		brepo := BeverageRepo{db: r.db}
		for rows.Next() {
			bv, err := scanBeverage(rows)
			if err != nil {
				rows.Close()
				return nil, fmt.Errorf("Search beverages scan: %w", err)
			}
			d, err := brepo.toBeverage(bv)
			if err != nil {
				rows.Close()
				return nil, err
			}
			out = append(out, SearchResult{Type: "beverage", Beverage: &d})
		}
		rows.Close()
	}
	if doBrw {
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
		rows, err := r.db.Query(ctx, brq, q, cursor, limit+1)
		if err != nil {
			return nil, fmt.Errorf("Search breweries: %w", err)
		}
		for rows.Next() {
			b, err := scanBrewery(rows)
			if err != nil {
				rows.Close()
				return nil, fmt.Errorf("Search breweries scan: %w", err)
			}
			out = append(out, SearchResult{Type: "brewery", Brewery: b})
		}
		rows.Close()
	}
	return out, nil
}
