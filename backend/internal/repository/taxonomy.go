package repository

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/kamos/api/internal/domain"
)

type TaxonomyRepo struct{ db *pgxpool.Pool }

// Categories returns the three SPEC §2.1 rows.
func (r *TaxonomyRepo) Categories(ctx context.Context) ([]domain.CategoryLabel, error) {
	const q = `SELECT slug, name_i18n FROM beverage_categories ORDER BY sort_order;`
	rows, err := r.db.Query(ctx, q)
	if err != nil {
		return nil, fmt.Errorf("Categories: %w", err)
	}
	defer rows.Close()
	var out []domain.CategoryLabel
	for rows.Next() {
		var c domain.CategoryLabel
		var nameJSON []byte
		if err := rows.Scan(&c.Slug, &nameJSON); err != nil {
			return nil, fmt.Errorf("Categories scan: %w", err)
		}
		c.LabelI18n, _ = domain.I18nFromJSON(nameJSON)
		out = append(out, c)
	}
	return out, rows.Err()
}

// FlavorTags returns all flavor tags grouped by dimension.
func (r *TaxonomyRepo) FlavorTags(ctx context.Context) ([]domain.FlavorTag, error) {
	const q = `SELECT id, slug, dimension, name_i18n FROM flavor_tags ORDER BY dimension, sort_order;`
	rows, err := r.db.Query(ctx, q)
	if err != nil {
		return nil, fmt.Errorf("FlavorTags: %w", err)
	}
	defer rows.Close()
	var out []domain.FlavorTag
	for rows.Next() {
		var t domain.FlavorTag
		var nameJSON []byte
		if err := rows.Scan(&t.ID, &t.Slug, &t.Dimension, &nameJSON); err != nil {
			return nil, fmt.Errorf("FlavorTags scan: %w", err)
		}
		t.Name, _ = domain.I18nFromJSON(nameJSON)
		out = append(out, t)
	}
	return out, rows.Err()
}
