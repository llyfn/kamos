// Package cursor encodes opaque keyset cursors for list endpoints.
// Every list endpoint in the API uses cursor pagination per SPEC §6.6.
package cursor

import (
	"encoding/base64"
	"encoding/json"
	"errors"
	"time"

	"github.com/kamos/api/internal/apierror"
)

// Cursor is the opaque payload encoded into a base64 token.
// CreatedAt + ID is the keyset on which feed/profile/beverage check-in lists
// sort. For non-time-ordered lists (e.g. popularity search), reuse the same
// shape with the numeric value stuffed into Score. `Type` is used only by
// /v1/search to disambiguate which sub-stream the cursor is mid-page in
// (`beverage` while draining beverages, `brewery` once the cursor has
// crossed into breweries).
type Cursor struct {
	CreatedAt time.Time `json:"c,omitempty"`
	ID        string    `json:"i,omitempty"`
	Score     *int64    `json:"s,omitempty"`
	Type      string    `json:"t,omitempty"`
}

// Encode produces a URL-safe base64 of the JSON representation.
func Encode(c Cursor) string {
	raw, _ := json.Marshal(c)
	return base64.RawURLEncoding.EncodeToString(raw)
}

// Decode parses an opaque cursor string back into a Cursor. Empty input is
// treated as "no cursor" and returns the zero value without error.
func Decode(s string) (Cursor, error) {
	var c Cursor
	if s == "" {
		return c, nil
	}
	raw, err := base64.RawURLEncoding.DecodeString(s)
	if err != nil {
		// Be tolerant of standard padding too.
		raw, err = base64.StdEncoding.DecodeString(s)
		if err != nil {
			return c, errors.Join(apierror.ErrBadRequest, errors.New("invalid cursor"))
		}
	}
	if err := json.Unmarshal(raw, &c); err != nil {
		return c, errors.Join(apierror.ErrBadRequest, errors.New("invalid cursor"))
	}
	return c, nil
}

// Page is the canonical list response shape. T is the item type.
type Page[T any] struct {
	Items      []T    `json:"items"`
	NextCursor string `json:"next_cursor,omitempty"`
	HasMore    bool   `json:"has_more"`
}

// SliceAndCursor takes a slice that was queried with `LIMIT n+1` and a
// function that produces a Cursor for any item; it returns the truncated
// slice (length ≤ n), the next cursor string (empty when no more), and
// whether there are more results.
func SliceAndCursor[T any](rows []T, limit int, key func(T) Cursor) (items []T, next string, hasMore bool) {
	if len(rows) > limit {
		hasMore = true
		items = rows[:limit]
		next = Encode(key(items[limit-1]))
		return
	}
	items = rows
	return
}
