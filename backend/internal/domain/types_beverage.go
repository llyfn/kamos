package domain

import "time"

// ---------------------------------------------------------------------------
// Beverage / Producer
// ---------------------------------------------------------------------------

type Producer struct {
	ID          string      `json:"id"`
	Name        I18nText    `json:"name"`
	Prefecture  *Prefecture `json:"prefecture,omitempty"`
	FoundedYear *int        `json:"founded_year,omitempty"`
	Website     *string     `json:"website,omitempty"`
	Description *I18nText   `json:"description,omitempty"`
	// ImageURL is the optional admin-uploaded image (logo / brewery photo /
	// label collage). Resolved server-side from a `photo_uploads` row with
	// `purpose='producer'` and persisted as a public R2 URL on
	// producers.image_url. Absent-when-unknown (Go omitempty).
	ImageURL      *string   `json:"image_url,omitempty"`
	CreatedAt     time.Time `json:"created_at"`
	BeverageCount *int      `json:"beverage_count,omitempty"`
}

type CategoryLabel struct {
	Slug      string   `json:"slug"`       // 'nihonshu' | 'shochu' | 'liqueur'
	LabelI18n I18nText `json:"label_i18n"` // SPEC §2.1 canonical strings
}

// Subcategory is the slim reference shape carried on Beverage. The
// canonical source is the `beverage_subcategories` row joined via
// `beverages.subcategory_id`; admin manages these via
// /v1/admin/subcategories.
//
// As a dual-source fallback the API may still surface a legacy free-text
// subcategory (no id/slug/category_slug) for rows whose
// `beverages.subcategory_id` is NULL but whose legacy `subcategory_i18n`
// JSONB is set. Clients should treat id/slug as optional during that
// window; a follow-up migration drops the legacy column once every
// beverage is backfilled.
type Subcategory struct {
	ID           string   `json:"id"`
	CategoryID   string   `json:"category_id"`
	CategorySlug string   `json:"category_slug"`
	Slug         string   `json:"slug"`
	Name         I18nText `json:"name"`
	SortOrder    int16    `json:"sort_order"`
}

type Beverage struct {
	ID             string        `json:"id"`
	Name           I18nText      `json:"name"`
	Producer       Producer      `json:"producer"`
	Category       CategoryLabel `json:"category"`
	Subcategory    *Subcategory  `json:"subcategory,omitempty"`
	ABV            *float64      `json:"abv,omitempty"`
	PolishingRatio *int          `json:"polishing_ratio,omitempty"`
	FlavorProfile  []string      `json:"flavor_profile"` // tag slugs
	Description    *I18nText     `json:"description,omitempty"`
	LabelImageURL  *string       `json:"label_image_url,omitempty"`
	AvgRating      *float64      `json:"avg_rating"`
	CheckInCount   int           `json:"check_in_count"`
	CreatedAt      time.Time     `json:"created_at"`
}

// BeverageDetail is a Beverage plus aggregated flavor and recent check-ins.
type BeverageDetail struct {
	Beverage
	AggregatedFlavor []FlavorAggregate `json:"aggregated_flavor"`
	RecentCheckins   []CheckinSummary  `json:"recent_check_ins"`
}

type FlavorAggregate struct {
	Slug      string   `json:"slug"`
	Dimension string   `json:"dimension"`
	Name      I18nText `json:"name"`
	Uses      int      `json:"uses"`
}

type FlavorTag struct {
	ID        string   `json:"id"`
	Slug      string   `json:"slug"`
	Dimension string   `json:"dimension"`
	Name      I18nText `json:"name"`
}

type BeverageRef struct {
	ID            string        `json:"id"`
	Name          I18nText      `json:"name"`
	Producer      ProducerRef   `json:"producer"`
	Category      CategoryLabel `json:"category"`
	Subcategory   *Subcategory  `json:"subcategory,omitempty"`
	LabelImageURL *string       `json:"label_image_url,omitempty"`
}

// ProducerRef is the compact producer embedding used by check-ins, feed,
// and collection entries. Prefecture is nested (and carries its own
// embedded Region) when known; absent otherwise.
type ProducerRef struct {
	ID         string      `json:"id"`
	Name       I18nText    `json:"name"`
	Prefecture *Prefecture `json:"prefecture,omitempty"`
	// ImageURL mirrors Producer.ImageURL on the compact embed so the
	// check-in card / feed item can render the optional 16-dp producer
	// thumbnail without a second fetch. Absent-when-unknown.
	ImageURL *string `json:"image_url,omitempty"`
}
