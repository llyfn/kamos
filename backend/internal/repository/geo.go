// geo.go — regions + prefectures (migration 016).
//
// Seed-only reference tables. The repository here is read-only; admin
// has no mutation endpoints because the seed is canonical (8 regions,
// 47 prefectures, JIS order). The handler caches the full graph with
// a long TTL — the data effectively never changes.

package repository

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/kamos/api/internal/domain"
)

// GeoRepo wraps the regions + prefectures lookups.
type GeoRepo struct{ db *pgxpool.Pool }

// ListRegionsWithPrefectures returns the full region → prefecture graph
// in canonical sort order (regions.sort_order, then prefectures.sort_order).
// One round-trip via array_agg avoids the N+1 a per-region prefecture
// pull would cause; the dataset is tiny (8 rows × ≤47 prefectures each)
// so a single ORDER BY pass is also cheap. Returned slices are in seed
// order so the admin UI does not need to re-sort.
func (r *GeoRepo) ListRegionsWithPrefectures(ctx context.Context) ([]domain.RegionWithPrefectures, error) {
	// One row per (region, prefecture). The handler collapses into
	// the nested response shape so we don't have to teach pgx about
	// array_agg of composite types here.
	const q = `
SELECT
  r.id, r.slug, r.name_i18n, r.sort_order,
  p.id, p.slug, p.name_i18n, p.sort_order
FROM regions r
LEFT JOIN prefectures p ON p.region_id = r.id
ORDER BY r.sort_order, p.sort_order, p.slug;`
	rows, err := r.db.Query(ctx, q)
	if err != nil {
		return nil, fmt.Errorf("GeoRepo.ListRegionsWithPrefectures: %w", err)
	}
	defer rows.Close()

	// Preserve first-seen region order (matches ORDER BY r.sort_order).
	var (
		out      []domain.RegionWithPrefectures
		byRegion = map[string]int{} // region id → index into out
	)
	for rows.Next() {
		var (
			rID, rSlug string
			rNameJSON  []byte
			rOrder     int
			pID        *string
			pSlug      *string
			pNameJSON  []byte
			pOrder     *int
		)
		if err := rows.Scan(&rID, &rSlug, &rNameJSON, &rOrder, &pID, &pSlug, &pNameJSON, &pOrder); err != nil {
			return nil, fmt.Errorf("GeoRepo.ListRegionsWithPrefectures scan: %w", err)
		}
		idx, ok := byRegion[rID]
		if !ok {
			rName, _ := domain.I18nFromJSON(rNameJSON)
			out = append(out, domain.RegionWithPrefectures{
				ID:          rID,
				Slug:        rSlug,
				Name:        rName,
				SortOrder:   rOrder,
				Prefectures: nil,
			})
			idx = len(out) - 1
			byRegion[rID] = idx
		}
		// The LEFT JOIN can yield NULL prefecture columns when a region
		// has no prefectures (shouldn't happen with the seed, but we
		// must not append a phantom row).
		if pID != nil && *pID != "" {
			pName, _ := domain.I18nFromJSON(pNameJSON)
			order := 0
			if pOrder != nil {
				order = *pOrder
			}
			out[idx].Prefectures = append(out[idx].Prefectures, domain.PrefectureInline{
				ID:        *pID,
				Slug:      *pSlug,
				Name:      pName,
				SortOrder: order,
			})
		}
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	// Guarantee non-nil slices so the JSON encoder emits [] rather
	// than null for regions with zero prefectures.
	for i := range out {
		if out[i].Prefectures == nil {
			out[i].Prefectures = []domain.PrefectureInline{}
		}
	}
	return out, nil
}

// PrefectureIDForSlug resolves a prefectures.slug → id. Returns
// domain.ErrNotFound when the slug is unknown; the admin producer handler
// maps that to 422 INVALID_PREFECTURE_SLUG. Backed by the unique index
// on prefectures.slug.
func (r *GeoRepo) PrefectureIDForSlug(ctx context.Context, slug string) (string, error) {
	const q = `SELECT id FROM prefectures WHERE slug = $1;`
	var id string
	if err := r.db.QueryRow(ctx, q, slug).Scan(&id); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return "", domain.ErrNotFound
		}
		return "", fmt.Errorf("GeoRepo.PrefectureIDForSlug: %w", err)
	}
	return id, nil
}
