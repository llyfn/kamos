package domain

import "time"

// ---------------------------------------------------------------------------
// Beverage / Brewery
// ---------------------------------------------------------------------------

type Brewery struct {
	ID            string      `json:"id"`
	Name          I18nText    `json:"name"`
	Prefecture    *Prefecture `json:"prefecture,omitempty"`
	FoundedYear   *int        `json:"founded_year,omitempty"`
	Website       *string     `json:"website,omitempty"`
	Description   *I18nText   `json:"description,omitempty"`
	CreatedAt     time.Time   `json:"created_at"`
	BeverageCount *int        `json:"beverage_count,omitempty"`
}

type CategoryLabel struct {
	Slug      string   `json:"slug"`       // 'nihonshu' | 'shochu' | 'liqueur'
	LabelI18n I18nText `json:"label_i18n"` // SPEC §2.1 canonical strings
}

type Beverage struct {
	ID             string        `json:"id"`
	Name           I18nText      `json:"name"`
	Brewery        Brewery       `json:"brewery"`
	Category       CategoryLabel `json:"category"`
	Subcategory    *I18nText     `json:"subcategory,omitempty"`
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
	Brewery       BreweryRef    `json:"brewery"`
	Category      CategoryLabel `json:"category"`
	LabelImageURL *string       `json:"label_image_url,omitempty"`
}

// BreweryRef is the compact brewery embedding used by check-ins, feed,
// and collection entries. Prefecture is nested (and carries its own
// embedded Region) when known; absent otherwise.
type BreweryRef struct {
	ID         string      `json:"id"`
	Name       I18nText    `json:"name"`
	Prefecture *Prefecture `json:"prefecture,omitempty"`
}
