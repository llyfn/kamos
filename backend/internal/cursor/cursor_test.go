package cursor

import (
	"encoding/base64"
	"encoding/json"
	"strings"
	"testing"
	"time"
)

// testKey is the HMAC signing key used by every test in this file. Installed
// once by TestMain so all unit tests run against a known key without each
// test re-wiring it.
var testKey = []byte("cursor-unit-test-key-aaaaaaaaaaaaaaa")

func TestMain(m *testing.M) {
	SetSigningKey(testKey)
	m.Run()
}

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

// SEC-005: encoded cursors must contain the MAC separator.
func TestCursorRoundTripIsSigned(t *testing.T) {
	c := Cursor{ID: "abc"}
	s := Encode(c)
	if !strings.Contains(s, ".") {
		t.Fatalf("Encode(%+v) = %q — expected '.' separator between payload + MAC", c, s)
	}
	got, err := Decode(s)
	if err != nil {
		t.Fatalf("Decode: %v", err)
	}
	if got.ID != "abc" {
		t.Errorf("ID round-trip: got %q want abc", got.ID)
	}
}

// SEC-005: a flipped bit in the payload section must be rejected by the
// MAC verification step.
func TestCursorTamperRejected(t *testing.T) {
	original := Encode(Cursor{ID: "abc", CreatedAt: time.Now().UTC()})
	dot := strings.LastIndex(original, ".")
	if dot <= 0 {
		t.Fatalf("encoded cursor missing separator: %q", original)
	}
	payloadB64 := original[:dot]
	macB64 := original[dot+1:]

	// Decode, flip one byte in the payload JSON, re-encode without
	// touching the MAC.
	payload, err := base64.RawURLEncoding.DecodeString(payloadB64)
	if err != nil {
		t.Fatalf("decode payload: %v", err)
	}
	if len(payload) == 0 {
		t.Fatalf("empty payload")
	}
	// Flip the first byte so the JSON is still parseable in shape but the
	// MAC will mismatch. Just XOR with a tiny bit pattern.
	tampered := make([]byte, len(payload))
	copy(tampered, payload)
	tampered[0] ^= 0x01

	tamperedCursor := base64.RawURLEncoding.EncodeToString(tampered) + "." + macB64
	if _, err := Decode(tamperedCursor); err == nil {
		t.Fatalf("expected Decode to reject tampered cursor; original=%q tampered=%q", original, tamperedCursor)
	}
}

// SEC-005: a missing MAC section (legacy / unsigned cursor) must be rejected.
func TestCursorUnsignedRejected(t *testing.T) {
	// Build a cursor without the MAC suffix.
	raw, _ := json.Marshal(Cursor{ID: "abc"})
	unsigned := base64.RawURLEncoding.EncodeToString(raw)
	if _, err := Decode(unsigned); err == nil {
		t.Fatalf("expected Decode to reject unsigned cursor %q", unsigned)
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
	// Pack a non-JSON payload but sign it with the correct key so the MAC
	// passes — the payload-unmarshal step must catch the corruption.
	payload := []byte("not-json")
	mac := sign(payload, testKey)
	s := base64.RawURLEncoding.EncodeToString(payload) + "." +
		base64.RawURLEncoding.EncodeToString(mac)
	if _, err := Decode(s); err == nil {
		t.Fatalf("expected JSON error for non-JSON payload")
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
