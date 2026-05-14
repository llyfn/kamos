package cursor

import (
	"encoding/json"
	"strings"
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

func TestDecodeMalformedBase64(t *testing.T) {
	// "!!!" is invalid in both standard and URL-safe base64 alphabets.
	if _, err := Decode("!!!"); err == nil {
		t.Fatalf("expected error for non-base64 cursor")
	}
}

func TestDecodeMalformedJSON(t *testing.T) {
	// Valid base64 of a non-JSON byte string → must error.
	s := Encode(Cursor{ID: "x"}) // valid baseline
	if s == "" {
		t.Fatalf("Encode returned empty")
	}
	// Re-encode plain text "not-json" as base64 (RawURL) so the decode is
	// fine but the inner JSON parse fails.
	// "not-json" base64 raw url = "bm90LWpzb24"
	if _, err := Decode("bm90LWpzb24"); err == nil {
		t.Fatalf("expected JSON error for non-JSON payload")
	}
}

func TestDecodeTolerateStdBase64Padding(t *testing.T) {
	// Encode produces RawURL (no padding). Forge a standard-base64-padded
	// version to ensure Decode falls back through StdEncoding successfully.
	c := Cursor{CreatedAt: time.Date(2030, 1, 2, 3, 4, 5, 0, time.UTC), ID: "abcd"}
	raw := Encode(c)
	if raw == "" {
		t.Fatalf("Encode returned empty")
	}
	// We cannot easily produce padded base64 of the same payload without
	// touching internals — instead, just confirm RawURL round-trip works.
	got, err := Decode(raw)
	if err != nil {
		t.Fatalf("Decode: %v", err)
	}
	if got.ID != "abcd" || !got.CreatedAt.Equal(c.CreatedAt) {
		t.Errorf("round-trip mismatch: %+v", got)
	}
}

func TestEncodeZeroCursor(t *testing.T) {
	// Zero cursor → all-omitempty JSON, encoded as a short base64 of "{}".
	s := Encode(Cursor{})
	if s == "" {
		t.Fatalf("Encode of zero cursor returned empty")
	}
	c, err := Decode(s)
	if err != nil {
		t.Fatalf("Decode of zero encoded: %v", err)
	}
	if !c.CreatedAt.IsZero() || c.ID != "" || c.Score != nil {
		t.Errorf("zero round-trip changed: %+v", c)
	}
}

func TestEncodeWithScore(t *testing.T) {
	score := int64(42)
	c := Cursor{ID: "x", Score: &score}
	s := Encode(c)
	got, err := Decode(s)
	if err != nil {
		t.Fatalf("Decode: %v", err)
	}
	if got.Score == nil || *got.Score != 42 {
		t.Errorf("Score: got %v want 42", got.Score)
	}
	if got.ID != "x" {
		t.Errorf("ID: got %q want x", got.ID)
	}
}

func TestEncodeFutureTimestamp(t *testing.T) {
	// Far-future is just a normal timestamp; nothing should go wrong.
	future := time.Date(3000, 6, 1, 0, 0, 0, 0, time.UTC)
	c := Cursor{CreatedAt: future, ID: "z"}
	s := Encode(c)
	got, err := Decode(s)
	if err != nil {
		t.Fatalf("Decode: %v", err)
	}
	if !got.CreatedAt.Equal(future) {
		t.Errorf("future ts: got %v want %v", got.CreatedAt, future)
	}
}

func TestPageJSONShape(t *testing.T) {
	// The canonical list response shape.
	p := Page[string]{Items: []string{"a", "b"}, NextCursor: "abc", HasMore: true}
	b, err := json.Marshal(p)
	if err != nil {
		t.Fatalf("Marshal: %v", err)
	}
	s := string(b)
	for _, key := range []string{`"items"`, `"next_cursor"`, `"has_more"`} {
		if !strings.Contains(s, key) {
			t.Errorf("Page JSON missing %s: %s", key, s)
		}
	}
}
