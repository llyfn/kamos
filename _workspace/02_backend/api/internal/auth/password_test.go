package auth

import (
	"strings"
	"testing"
)

// Hash + verify round-trips and rejects the wrong password.
func TestPasswordHashAndVerify(t *testing.T) {
	const pw = "correct-horse-battery-staple"
	h, err := HashPassword(pw)
	if err != nil {
		t.Fatalf("HashPassword: %v", err)
	}
	if h == "" {
		t.Fatalf("HashPassword returned empty hash")
	}
	if h == pw {
		t.Fatalf("HashPassword returned plaintext")
	}
	if err := VerifyPassword(h, pw); err != nil {
		t.Errorf("VerifyPassword good password: %v", err)
	}
	if err := VerifyPassword(h, "wrong-password"); err == nil {
		t.Errorf("VerifyPassword wrong password: want error, got nil")
	}
}

// Verifying against an empty stored hash must fail without panicking.
func TestVerifyPasswordEmptyHash(t *testing.T) {
	if err := VerifyPassword("", "anything"); err == nil {
		t.Fatalf("expected error for empty hash")
	}
}

// bcrypt truncates inputs longer than 72 bytes. Two passwords that share the
// first 72 bytes but differ after that hash equivalently — we document this
// behavior so callers aren't surprised.
func TestPasswordBcrypt72ByteTruncation(t *testing.T) {
	long := strings.Repeat("a", 72)
	longer := long + "DIFFERENT_TAIL_BYTES"
	h, err := HashPassword(long)
	if err != nil {
		t.Fatalf("HashPassword: %v", err)
	}
	// The original 72-byte password verifies.
	if err := VerifyPassword(h, long); err != nil {
		t.Fatalf("VerifyPassword exact: %v", err)
	}
	// bcrypt ignores bytes past index 71, so the extended password ALSO
	// verifies. If this ever stops being true (e.g. bcrypt switch), the
	// password-change flow needs revisiting.
	if err := VerifyPassword(h, longer); err != nil {
		t.Errorf("VerifyPassword extended past 72 bytes: want nil (bcrypt truncation), got %v", err)
	}
}

// Hashing the same password twice should produce different hashes (bcrypt
// embeds a fresh salt).
func TestPasswordHashSaltedDifferently(t *testing.T) {
	const pw = "salty-passwords"
	h1, err := HashPassword(pw)
	if err != nil {
		t.Fatalf("HashPassword 1: %v", err)
	}
	h2, err := HashPassword(pw)
	if err != nil {
		t.Fatalf("HashPassword 2: %v", err)
	}
	if h1 == h2 {
		t.Errorf("two hashes of the same password were identical (no salt?)")
	}
}
