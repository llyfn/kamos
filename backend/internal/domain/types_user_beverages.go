package domain

import "time"

// UserBeverageRow is one row of GET /v1/users/{username}/beverages — the
// distinct-beverage aggregation across a single user's check-ins.
//
// Row identity is the beverage. `UserAvgRating` averages the user's
// non-null ratings across the multiple check-ins on this beverage (null
// when every check-in was rating-less). `UserCheckinCount` counts ALL
// of the user's live check-ins on this beverage — including those with
// no rating — because the screen sentence is "I tried this N times".
// `GlobalAvgRating` / `GlobalCheckinCount` are read straight off
// beverages.avg_rating + beverages.check_in_count (the trigger-maintained
// aggregates).
type UserBeverageRow struct {
	Beverage           BeverageRef `json:"beverage"`
	UserAvgRating      *float64    `json:"user_avg_rating"`
	UserCheckinCount   int         `json:"user_checkin_count"`
	LastCheckinAt      time.Time   `json:"last_checkin_at"`
	GlobalAvgRating    *float64    `json:"global_avg_rating"`
	GlobalCheckinCount int         `json:"global_check_in_count"`
}
