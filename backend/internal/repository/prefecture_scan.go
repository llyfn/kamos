// prefecture_scan.go — shared helpers for scanning the nullable
// brewery → prefecture → region join chain (migration 016).
//
// Every brewery SELECT in this package joins LEFT against
// `prefectures p` and `regions r` so a brewery without a curated
// `prefecture_id` still scans into a non-error result with all join
// columns NULL. The helpers here keep the SELECT lists + scan helpers
// in one place so a future column addition (or a switch back to a
// stored-procedure call) only touches one file.

package repository

import "github.com/kamos/api/internal/domain"

// breweryPrefectureSelectCols is the SELECT-list fragment that pulls
// the prefecture + region columns needed to populate
// domain.Brewery.Prefecture. Mounted INSIDE the brewery SELECT lists
// after the brewery's own columns. The order is fixed; scanPrefecture
// must consume exactly these eight columns in this order.
//
// NOTE: callers that JOIN with their own aliases must use these names:
//   - `p` for prefectures
//   - `r` for regions
const breweryPrefectureSelectCols = `
  p.id, p.slug, p.name_i18n, p.sort_order,
  r.id, r.slug, r.name_i18n, r.sort_order`

// breweryPrefectureJoinClause is the LEFT JOIN suffix that produces
// the columns scanPrefecture expects. Append this AFTER the breweries
// alias in any query that includes breweryPrefectureSelectCols.
const breweryPrefectureJoinClause = `
LEFT JOIN prefectures p ON p.id = br.prefecture_id
LEFT JOIN regions r ON r.id = p.region_id`

// breweriesPrefectureJoinClause is the LEFT JOIN variant for queries
// that alias the brewery table as `b` (e.g. the admin brewery list).
const breweriesPrefectureJoinClause = `
LEFT JOIN prefectures p ON p.id = b.prefecture_id
LEFT JOIN regions r ON r.id = p.region_id`

// prefectureScan carries the raw join columns; the caller passes
// pointers to these into Row.Scan and then calls toPrefecture to get
// the domain object (nil when the brewery has no curated prefecture).
type prefectureScan struct {
	prefID        *string
	prefSlug      *string
	prefNameJSON  []byte
	prefSortOrder *int
	regID         *string
	regSlug       *string
	regNameJSON   []byte
	regSortOrder  *int
}

// scanArgs returns the eight pointers expected by Row.Scan for the
// breweryPrefectureSelectCols block, in declaration order. Spread into
// Scan's variadic argument list with `...`.
func (p *prefectureScan) scanArgs() []any {
	return []any{
		&p.prefID, &p.prefSlug, &p.prefNameJSON, &p.prefSortOrder,
		&p.regID, &p.regSlug, &p.regNameJSON, &p.regSortOrder,
	}
}

// toPrefecture materializes a *domain.Prefecture, or returns nil when
// the brewery has no curated prefecture_id (every join column is NULL).
func (p *prefectureScan) toPrefecture() *domain.Prefecture {
	if p.prefID == nil || *p.prefID == "" {
		return nil
	}
	prefName, _ := domain.I18nFromJSON(p.prefNameJSON)
	out := domain.Prefecture{
		ID:        *p.prefID,
		Slug:      derefString(p.prefSlug),
		Name:      prefName,
		SortOrder: derefInt(p.prefSortOrder),
	}
	if p.regID != nil && *p.regID != "" {
		regName, _ := domain.I18nFromJSON(p.regNameJSON)
		out.Region = domain.Region{
			ID:        *p.regID,
			Slug:      derefString(p.regSlug),
			Name:      regName,
			SortOrder: derefInt(p.regSortOrder),
		}
	}
	return &out
}

func derefString(p *string) string {
	if p == nil {
		return ""
	}
	return *p
}

func derefInt(p *int) int {
	if p == nil {
		return 0
	}
	return *p
}
