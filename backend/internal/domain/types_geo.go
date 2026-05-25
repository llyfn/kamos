package domain

import "time"

// ---------------------------------------------------------------------------
// Regions + prefectures (migration 016)
// ---------------------------------------------------------------------------
//
// `regions` carries the 8 traditional Japanese regions; `prefectures` the
// 47 prefectures, each FK'd to a region. Both are seed-only reference
// tables: there are no mutation endpoints. `producers.prefecture_id`
// references a single prefecture; the producer's region is therefore
// derivable via `producers.prefecture_id → prefectures.region_id`. The
// public Producer response nests `Prefecture` (which carries its own
// embedded `Region`) instead of the flat free-text columns the schema
// used to expose.

// Region is one row of the `regions` reference table. Used standalone by
// the prefecture embedding and inside `RegionWithPrefectures` for the
// flat /v1/reference/regions response.
type Region struct {
	ID        string    `json:"id"`
	Slug      string    `json:"slug"`
	Name      I18nText  `json:"name"`
	SortOrder int       `json:"sort_order"`
	CreatedAt time.Time `json:"created_at,omitempty"`
}

// Prefecture is one row of the `prefectures` reference table. The region
// is embedded so a producer's `prefecture` field carries enough context to
// render "Niigata (Chūbu)" without a second lookup.
type Prefecture struct {
	ID        string    `json:"id"`
	Slug      string    `json:"slug"`
	Name      I18nText  `json:"name"`
	SortOrder int       `json:"sort_order"`
	Region    Region    `json:"region"`
	CreatedAt time.Time `json:"created_at,omitempty"`
}

// RegionWithPrefectures is the flattened shape returned by
// GET /v1/reference/regions. Each entry carries the region's i18n name
// and the ordered list of its prefectures so a single round-trip is
// enough to populate an admin or filter UI. Prefectures here drop the
// `region` back-reference (the parent Region is the container) to
// avoid the redundant nested copy.
type RegionWithPrefectures struct {
	ID          string             `json:"id"`
	Slug        string             `json:"slug"`
	Name        I18nText           `json:"name"`
	SortOrder   int                `json:"sort_order"`
	Prefectures []PrefectureInline `json:"prefectures"`
}

// PrefectureInline is the per-prefecture shape inside
// RegionWithPrefectures. It omits the region back-reference (the
// container is the region) and the created_at timestamp (seed data,
// not interesting to the client).
type PrefectureInline struct {
	ID        string   `json:"id"`
	Slug      string   `json:"slug"`
	Name      I18nText `json:"name"`
	SortOrder int      `json:"sort_order"`
}
