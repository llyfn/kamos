package repository

import "github.com/kamos/api/internal/domain"

// subcategoryRefScan reads the six columns produced by subcategoryJoinCols
// (alias `sc`) into a slim domain.Subcategory used by BeverageRef. Mirrors
// prefectureScan: pass scanArgs()... to Row.Scan and call toSubcategory()
// to materialize a *domain.Subcategory (nil when the LEFT JOIN missed).
type subcategoryRefScan struct {
	id           *string
	categoryID   *string
	categorySlug *string
	slug         *string
	nameJSON     []byte
	sortOrder    *int16
}

func (s *subcategoryRefScan) scanArgs() []any {
	return []any{
		&s.id,
		&s.categoryID,
		&s.categorySlug,
		&s.slug,
		&s.nameJSON,
		&s.sortOrder,
	}
}

func (s *subcategoryRefScan) toSubcategory() *domain.Subcategory {
	if s.id == nil || *s.id == "" {
		return nil
	}
	name, _ := domain.I18nFromJSON(s.nameJSON)
	var sort16 int16
	if s.sortOrder != nil {
		sort16 = *s.sortOrder
	}
	return &domain.Subcategory{
		ID:           *s.id,
		CategoryID:   derefString(s.categoryID),
		CategorySlug: derefString(s.categorySlug),
		Slug:         derefString(s.slug),
		Name:         name,
		SortOrder:    sort16,
	}
}
