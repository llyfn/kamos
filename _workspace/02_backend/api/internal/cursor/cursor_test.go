package cursor

import (
	"testing"
	"time"
)

func TestEncodeDecodeRoundtrip(t *testing.T) {
	c := Cursor{CreatedAt: time.Date(2026, 5, 11, 12, 30, 0, 0, time.UTC), ID: "abc"}
	s := Encode(c)
	if s == "" {
		t.Fatalf("Encode returned empty string")
	}
	got, err := Decode(s)
	if err != nil {
		t.Fatalf("Decode: %v", err)
	}
	if !got.CreatedAt.Equal(c.CreatedAt) {
		t.Errorf("CreatedAt: got %v want %v", got.CreatedAt, c.CreatedAt)
	}
	if got.ID != c.ID {
		t.Errorf("ID: got %q want %q", got.ID, c.ID)
	}
}

func TestDecodeEmptyIsZero(t *testing.T) {
	c, err := Decode("")
	if err != nil {
		t.Fatalf("Decode(''): %v", err)
	}
	if !c.CreatedAt.IsZero() || c.ID != "" {
		t.Errorf("expected zero cursor, got %+v", c)
	}
}

func TestDecodeInvalidReturnsErr(t *testing.T) {
	if _, err := Decode("not-base64!!"); err == nil {
		t.Fatalf("expected error for malformed cursor")
	}
}

func TestSliceAndCursorPagination(t *testing.T) {
	type Item struct {
		ID string
		T  time.Time
	}
	base := time.Now()
	rows := []Item{
		{"a", base.Add(-1)},
		{"b", base.Add(-2)},
		{"c", base.Add(-3)},
		{"d", base.Add(-4)},
		{"e", base.Add(-5)},
		// limit will be 4 → has_more, next cursor on "d"
	}
	items, next, hasMore := SliceAndCursor(rows, 4, func(it Item) Cursor {
		return Cursor{CreatedAt: it.T, ID: it.ID}
	})
	if !hasMore {
		t.Fatalf("hasMore should be true")
	}
	if next == "" {
		t.Fatalf("expected next cursor")
	}
	if len(items) != 4 {
		t.Fatalf("len(items) = %d, want 4", len(items))
	}
	// last item must be "d", and decoded cursor must equal that item's id
	got, err := Decode(next)
	if err != nil {
		t.Fatalf("Decode: %v", err)
	}
	if got.ID != "d" {
		t.Errorf("next cursor id = %q, want %q", got.ID, "d")
	}
}

func TestSliceAndCursorLastPage(t *testing.T) {
	type Item struct{ ID string }
	rows := []Item{{"a"}, {"b"}}
	items, next, hasMore := SliceAndCursor(rows, 5, func(it Item) Cursor {
		return Cursor{ID: it.ID}
	})
	if hasMore {
		t.Errorf("hasMore should be false on last page")
	}
	if next != "" {
		t.Errorf("next should be empty on last page, got %q", next)
	}
	if len(items) != 2 {
		t.Errorf("len = %d want 2", len(items))
	}
}
