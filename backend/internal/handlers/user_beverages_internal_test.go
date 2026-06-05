// Internal-package tests for the user-beverages cursor encoder. The
// encoder turns a UserBeverageRow + sort axis into the opaque cursor
// envelope; the round-trip property (Encode → Decode → same fields)
// is what the integration test relies on for stable pagination.

package handlers

import (
	"testing"
	"time"

	"github.com/kamos/api/internal/cursor"
	"github.com/kamos/api/internal/domain"
	"github.com/kamos/api/internal/repository"
)

func init() {
	// Encode panics if signing isn't configured; the test harness sets
	// the same key main.go would. Repeated calls are safe — signing key
	// is process-wide.
	cursor.SetSigningKey([]byte("user-beverages-test-key-aaaaaaaaaaaaaa"))
}

// TestEncodeUserBeverageCursor_Rating — rating sort puts the user_avg
// scaled into Score and the beverage id into ID. A null rating uses
// the documented sentinel.
func TestEncodeUserBeverageCursor_Rating(t *testing.T) {
	t.Run("non-null rating", func(t *testing.T) {
		v := 4.25
		row := domain.UserBeverageRow{
			Beverage:      domain.BeverageRef{ID: "00000000-0000-0000-0000-000000000001"},
			UserAvgRating: &v,
		}
		c := encodeUserBeverageCursor(repository.SortUserBeverageRating, row)
		if c.ID != row.Beverage.ID {
			t.Errorf("ID = %q, want %q", c.ID, row.Beverage.ID)
		}
		if c.Score == nil {
			t.Fatal("Score must be non-nil for rating sort")
		}
		want := int64(4.25 * float64(repository.UserBeverageRatingCursorScale))
		if *c.Score != want {
			t.Errorf("Score = %d, want %d", *c.Score, want)
		}
	})
	t.Run("null rating uses sentinel", func(t *testing.T) {
		row := domain.UserBeverageRow{
			Beverage: domain.BeverageRef{ID: "00000000-0000-0000-0000-000000000002"},
		}
		c := encodeUserBeverageCursor(repository.SortUserBeverageRating, row)
		if c.Score == nil || *c.Score != repository.UserBeverageRatingNullSentinel {
			t.Errorf("Score = %v, want %d", c.Score, repository.UserBeverageRatingNullSentinel)
		}
	})
}

// TestEncodeUserBeverageCursor_LastCheckin — last-checkin sort stuffs
// the timestamp into CreatedAt.
func TestEncodeUserBeverageCursor_LastCheckin(t *testing.T) {
	ts := time.Date(2026, 5, 30, 12, 0, 0, 0, time.UTC)
	row := domain.UserBeverageRow{
		Beverage:      domain.BeverageRef{ID: "abc"},
		LastCheckinAt: ts,
	}
	c := encodeUserBeverageCursor(repository.SortUserBeverageLastCheckin, row)
	if !c.CreatedAt.Equal(ts) {
		t.Errorf("CreatedAt = %v, want %v", c.CreatedAt, ts)
	}
	if c.ID != "abc" {
		t.Errorf("ID = %q, want abc", c.ID)
	}
}

// TestEncodeUserBeverageCursor_ProducerCategory — string sort axes
// stuff the producer_id / category_slug into Type.
func TestEncodeUserBeverageCursor_ProducerCategory(t *testing.T) {
	row := domain.UserBeverageRow{
		Beverage: domain.BeverageRef{
			ID:       "bev",
			Producer: domain.ProducerRef{ID: "prod-uuid"},
			Category: domain.CategoryLabel{Slug: "nihonshu"},
		},
	}
	c := encodeUserBeverageCursor(repository.SortUserBeverageProducer, row)
	if c.Type != "prod-uuid" {
		t.Errorf("producer Type = %q, want prod-uuid", c.Type)
	}
	c = encodeUserBeverageCursor(repository.SortUserBeverageCategory, row)
	if c.Type != "nihonshu" {
		t.Errorf("category Type = %q, want nihonshu", c.Type)
	}
}

// TestEncodeUserBeverageCursor_Roundtrip — Encode → Decode roundtrip
// preserves every populated field. Mirrors what the next-page request
// path does.
func TestEncodeUserBeverageCursor_Roundtrip(t *testing.T) {
	v := 3.5
	row := domain.UserBeverageRow{
		Beverage:      domain.BeverageRef{ID: "11111111-1111-1111-1111-111111111111"},
		UserAvgRating: &v,
	}
	c := encodeUserBeverageCursor(repository.SortUserBeverageRating, row)
	encoded := cursor.Encode(c)
	decoded, err := cursor.Decode(encoded)
	if err != nil {
		t.Fatalf("decode: %v", err)
	}
	if decoded.ID != c.ID {
		t.Errorf("ID drift: %q vs %q", decoded.ID, c.ID)
	}
	if decoded.Score == nil || c.Score == nil || *decoded.Score != *c.Score {
		t.Errorf("Score drift: %v vs %v", decoded.Score, c.Score)
	}
}
