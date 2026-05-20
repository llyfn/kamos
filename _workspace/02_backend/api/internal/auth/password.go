package auth

import (
	"errors"
	"fmt"

	"golang.org/x/crypto/bcrypt"
)

// Bcrypt cost — 12 is a reasonable 2025 default; ~250ms on a modern laptop.
const bcryptCost = 12

// dummyBcryptHash is a bcrypt-of-random-string used by VerifyDummyPassword
// to equalize wall-clock time on the "user not found" path during login
// (SEC-018). Computed once at process init so we pay the bcrypt cost ahead
// of any login attempt rather than per-call.
//
// The plaintext is intentionally not stored — we just need a real bcrypt
// hash so CompareHashAndPassword does the same constant-time work as the
// "wrong password" branch.
var dummyBcryptHash []byte

func init() {
	// Any input works; the user-supplied password will never match it.
	h, err := bcrypt.GenerateFromPassword([]byte("kamos-login-dummy"), bcryptCost)
	if err != nil {
		// bcrypt failure at init means the crypto package is unusable;
		// crash is the right answer.
		panic(fmt.Errorf("auth: precompute dummy bcrypt hash: %w", err))
	}
	dummyBcryptHash = h
}

// VerifyDummyPassword runs bcrypt.CompareHashAndPassword against a
// precomputed dummy hash. The result is intentionally discarded — the
// caller wants only the timing side-effect. Used by the Login handler on
// the "email not found" branch so wall-clock time matches "wrong
// password" (SEC-018).
func VerifyDummyPassword(plain string) {
	_ = bcrypt.CompareHashAndPassword(dummyBcryptHash, []byte(plain))
}

// HashPassword returns a bcrypt hash suitable for storage.
func HashPassword(plain string) (string, error) {
	h, err := bcrypt.GenerateFromPassword([]byte(plain), bcryptCost)
	if err != nil {
		return "", fmt.Errorf("HashPassword: %w", err)
	}
	return string(h), nil
}

// VerifyPassword compares a plaintext password against a stored bcrypt hash.
// Returns nil on match, a non-nil error otherwise.
func VerifyPassword(hash, plain string) error {
	if hash == "" {
		return errors.New("VerifyPassword: empty hash")
	}
	if err := bcrypt.CompareHashAndPassword([]byte(hash), []byte(plain)); err != nil {
		return fmt.Errorf("VerifyPassword: %w", err)
	}
	return nil
}
