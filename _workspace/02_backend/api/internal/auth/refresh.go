// Package auth — refresh-token helpers.
//
// Refresh tokens are opaque, cryptographically-random secrets the server
// hands to the client at login. The DB stores ONLY the SHA-256 hash of the
// raw secret, never the raw secret itself. On rotation the server computes
// the same hash from the presented secret and looks it up.
//
// SHA-256 is appropriate here (preimage-resistant) — the token has full
// entropy, so a slow KDF would gain nothing while paying a lookup cost on
// every refresh call.
package auth

import (
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"fmt"
	"time"
)

// DefaultRefreshTTL is the lifetime applied when no override (env REFRESH_TTL)
// is configured. 30 days lines up with typical mobile re-auth cadence and is
// the value documented in DEPLOYMENT.md §3.
const DefaultRefreshTTL = 30 * 24 * time.Hour

// refreshSecretBytes — 32 random bytes → 43 base64-rawurl characters. The
// secret carries 256 bits of entropy, comfortably above any brute-force
// concern (and well above what bcrypt-of-password protects).
const refreshSecretBytes = 32

// NewRefreshSecret generates a cryptographically-random refresh secret and
// returns (raw, hash). `raw` is the base64-rawurl-encoded 43-char string the
// caller sends to the client; `hash` is the 32-byte SHA-256 digest that the
// caller persists. The raw secret must NEVER be stored or logged.
func NewRefreshSecret() (string, []byte, error) {
	b := make([]byte, refreshSecretBytes)
	if _, err := rand.Read(b); err != nil {
		return "", nil, fmt.Errorf("NewRefreshSecret: %w", err)
	}
	raw := base64.RawURLEncoding.EncodeToString(b)
	h := sha256.Sum256([]byte(raw))
	return raw, h[:], nil
}

// HashRefreshToken returns the SHA-256 digest of the raw refresh secret. The
// digest is what the repository compares against `refresh_tokens.token_hash`.
func HashRefreshToken(raw string) []byte {
	h := sha256.Sum256([]byte(raw))
	return h[:]
}
