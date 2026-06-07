// Package cursor encodes opaque keyset cursors for list endpoints.
// Every list endpoint in the API uses cursor pagination per SPEC §6.6.
//
// SEC-005: cursors are HMAC-SHA256-signed using a process-wide
// key set via SetSigningKey at startup. The wire format is
//
//	base64(json) || "." || base64(hmac_sha256(json, key))
//
// Decode verifies the MAC in constant time and rejects tampered or
// unsigned cursors with domain.ErrBadRequest. The key is required —
// Encode panics if used before SetSigningKey, which would have surfaced
// the bug at startup in any handler test path that exercises a list.
package cursor

import (
	"bytes"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"errors"
	"sync"
	"time"

	"github.com/kamos/api/internal/domain"
)

// Cursor is the opaque payload encoded into a base64 token.
// CreatedAt + ID is the keyset on which feed/profile/beverage check-in lists
// sort. For non-time-ordered lists (e.g. popularity search), reuse the same
// shape with the numeric value stuffed into Score. `Type` is used only by
// /v1/search to disambiguate which sub-stream the cursor is mid-page in
// (`beverage` while draining beverages, `producer` once the cursor has
// crossed into producers).
//
// Popularity cursors carry a triple (CheckInCount, CreatedAt, ID) so the
// keyset stays stable across the mutating check_in_count column.
// `CheckInCount` is encoded under the short `k` key (the byte budget on
// a base64 cursor is tight); legacy cursors without `k` still decode —
// handlers that need the full triple fall back to a single-key keyset.
//
// User-search cursors carry (MatchTier, NameLength, CreatedAt, ID) under
// keys `m` + `n` so the 3-tier rank (exact / prefix / substring) can
// stably keyset-paginate. Older user-search cursors without these fields
// decode to nil tier/length and the handler treats them as "first page".
type Cursor struct {
	CreatedAt    time.Time `json:"c,omitempty"`
	ID           string    `json:"i,omitempty"`
	Score        *int64    `json:"s,omitempty"`
	CheckInCount *int64    `json:"k,omitempty"`
	MatchTier    *int      `json:"m,omitempty"`
	NameLength   *int      `json:"n,omitempty"`
	Type         string    `json:"t,omitempty"`
}

var (
	signingKeyMu sync.RWMutex
	signingKey   []byte
)

// SetSigningKey installs the HMAC key used by Encode/Decode. Call once at
// startup from main.go (or from the test bootstrap). A subsequent call
// overwrites the key — handy for tests that want to verify rotation
// semantics but otherwise unused. Passing an empty key clears the
// configuration; subsequent Encode/Decode calls then return an error
// (Decode) or panic (Encode), which matches "you forgot to wire signing".
func SetSigningKey(key []byte) {
	signingKeyMu.Lock()
	defer signingKeyMu.Unlock()
	if len(key) == 0 {
		signingKey = nil
		return
	}
	signingKey = append([]byte(nil), key...)
}

// getSigningKey returns a copy of the configured key. Returns nil when
// unset.
func getSigningKey() []byte {
	signingKeyMu.RLock()
	defer signingKeyMu.RUnlock()
	if signingKey == nil {
		return nil
	}
	return signingKey
}

func sign(payload []byte, key []byte) []byte {
	m := hmac.New(sha256.New, key)
	m.Write(payload)
	return m.Sum(nil)
}

// Encode produces a URL-safe base64 of the JSON representation followed by
// an HMAC-SHA256 tag computed under the configured signing key. Format:
//
//	base64url(json) || "." || base64url(mac)
//
// Panics if SetSigningKey has not been called — that's a startup wiring
// bug and silently emitting unsigned cursors would defeat the protection.
func Encode(c Cursor) string {
	key := getSigningKey()
	if key == nil {
		panic("cursor: SetSigningKey not called before Encode — wire it from main.go")
	}
	raw, _ := json.Marshal(c)
	mac := sign(raw, key)
	return base64.RawURLEncoding.EncodeToString(raw) + "." +
		base64.RawURLEncoding.EncodeToString(mac)
}

// Decode parses an opaque cursor string back into a Cursor. Empty input is
// treated as "no cursor" and returns the zero value without error. Any
// mismatch (missing tag, bad base64, MAC mismatch, malformed JSON) is
// reported as domain.ErrBadRequest.
func Decode(s string) (Cursor, error) {
	var c Cursor
	if s == "" {
		return c, nil
	}
	key := getSigningKey()
	if key == nil {
		// No key set at decode time — treat the same as a tamper / unsigned
		// cursor rather than crash. Mirrors Encode's contract that signing
		// is mandatory.
		return c, errors.Join(domain.ErrBadRequest, errors.New("invalid cursor"))
	}

	// Tampered or unsigned cursors miss the "." separator entirely; reject
	// before any decode attempt so old clients that pass a legacy cursor
	// during a deploy roll receive a clean 400, not a stack trace.
	dotIdx := -1
	for i := len(s) - 1; i >= 0; i-- {
		if s[i] == '.' {
			dotIdx = i
			break
		}
	}
	if dotIdx < 1 || dotIdx == len(s)-1 {
		return c, errors.Join(domain.ErrBadRequest, errors.New("invalid cursor"))
	}
	payloadB64 := s[:dotIdx]
	macB64 := s[dotIdx+1:]

	payload, err := base64.RawURLEncoding.DecodeString(payloadB64)
	if err != nil {
		return c, errors.Join(domain.ErrBadRequest, errors.New("invalid cursor"))
	}
	gotMac, err := base64.RawURLEncoding.DecodeString(macB64)
	if err != nil {
		return c, errors.Join(domain.ErrBadRequest, errors.New("invalid cursor"))
	}

	wantMac := sign(payload, key)
	// hmac.Equal is constant-time; bytes.Equal would be a timing side channel.
	if !hmac.Equal(gotMac, wantMac) {
		return c, errors.Join(domain.ErrBadRequest, errors.New("invalid cursor"))
	}
	// Defensive: assert the payload re-marshals to the same bytes after
	// JSON parse — guards against a clever attacker submitting a payload
	// that hashes to the same MAC but unmarshals into a different cursor
	// (NOT possible with a fixed shape + Go's strict decoder, but the
	// belt-and-braces re-marshal is cheap).
	if err := json.Unmarshal(payload, &c); err != nil {
		return c, errors.Join(domain.ErrBadRequest, errors.New("invalid cursor"))
	}
	if want, _ := json.Marshal(c); !bytes.Equal(want, payload) {
		// Mismatch most likely means the attacker re-ordered keys or
		// injected extra fields. Reject.
		return c, errors.Join(domain.ErrBadRequest, errors.New("invalid cursor"))
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
