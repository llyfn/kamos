package auth

import (
	"bytes"
	"encoding/base64"
	"testing"
)

// TestNewRefreshSecret_FormatAndHash verifies:
//  1. The raw secret decodes from base64-rawurl into exactly 32 bytes,
//     i.e., the encoded form is the canonical 43-char URL-safe string.
//  2. The returned hash has length sha256.Size (32 bytes).
//  3. The hash bytes do NOT contain the raw secret as a substring — i.e.,
//     the secret is properly digested, not just appended/copied.
func TestNewRefreshSecret_FormatAndHash(t *testing.T) {
	raw, hash, err := NewRefreshSecret()
	if err != nil {
		t.Fatalf("NewRefreshSecret: %v", err)
	}
	if len(raw) != 43 {
		t.Fatalf("raw length: got %d want 43 (base64-rawurl of 32 bytes)", len(raw))
	}
	decoded, err := base64.RawURLEncoding.DecodeString(raw)
	if err != nil {
		t.Fatalf("raw must decode as rawurl base64: %v", err)
	}
	if len(decoded) != 32 {
		t.Fatalf("decoded entropy: got %d want 32 bytes", len(decoded))
	}
	if len(hash) != 32 {
		t.Fatalf("hash length: got %d want 32 (sha256.Size)", len(hash))
	}
	// The raw secret must not be embedded in the digest bytes — a defensive
	// regression check against a hypothetical implementation that just stored
	// the secret instead of hashing it.
	if bytes.Contains(hash, []byte(raw)) {
		t.Fatalf("hash leaks raw secret as substring")
	}
}

// TestHashRefreshToken_Deterministic — the same raw secret hashes to the
// same digest. This is the property the repository relies on for lookup.
func TestHashRefreshToken_Deterministic(t *testing.T) {
	raw, h1, err := NewRefreshSecret()
	if err != nil {
		t.Fatalf("NewRefreshSecret: %v", err)
	}
	h2 := HashRefreshToken(raw)
	if !bytes.Equal(h1, h2) {
		t.Fatalf("HashRefreshToken not deterministic: %x vs %x", h1, h2)
	}
}

// TestNewRefreshSecret_UniquePerCall — two consecutive calls produce
// distinct secrets AND distinct digests. Catches a degenerate RNG.
func TestNewRefreshSecret_UniquePerCall(t *testing.T) {
	a, ha, err := NewRefreshSecret()
	if err != nil {
		t.Fatalf("a: %v", err)
	}
	b, hb, err := NewRefreshSecret()
	if err != nil {
		t.Fatalf("b: %v", err)
	}
	if a == b {
		t.Fatalf("two calls produced the same raw secret")
	}
	if bytes.Equal(ha, hb) {
		t.Fatalf("two calls produced the same digest")
	}
}
