package auth

import (
	"errors"
	"fmt"

	"golang.org/x/crypto/bcrypt"
)

// Bcrypt cost — 12 is a reasonable 2025 default; ~250ms on a modern laptop.
const bcryptCost = 12

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
