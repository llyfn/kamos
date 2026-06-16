package auth

import (
	"context"
	"encoding/base64"
	"strings"
	"testing"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

func TestJWTRoundtrip(t *testing.T) {
	s := NewSigner("a-test-secret-of-sufficient-length-3xxxxxxxxxxxx", 1*time.Hour)
	tok, err := s.Sign("user-123", "yamamoto")
	if err != nil {
		t.Fatalf("Sign: %v", err)
	}
	claims, err := s.Verify(tok)
	if err != nil {
		t.Fatalf("Verify: %v", err)
	}
	if claims.UserID != "user-123" {
		t.Errorf("UserID: got %q want user-123", claims.UserID)
	}
	if claims.Username != "yamamoto" {
		t.Errorf("Username: got %q want yamamoto", claims.Username)
	}
}

func TestJWTRejectsModifiedToken(t *testing.T) {
	s := NewSigner("secret-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", time.Hour)
	tok, _ := s.Sign("u", "n")
	// Flip a whole signature byte. The final base64url char of the signature
	// only carries 4 significant bits, so flipping the last char can land on a
	// padding-only change that decodes identically; mutating a decoded byte
	// makes the tamper unconditionally observable.
	parts := strings.Split(tok, ".")
	sig, err := base64.RawURLEncoding.DecodeString(parts[2])
	if err != nil {
		t.Fatalf("decode signature: %v", err)
	}
	sig[0] ^= 0xFF
	parts[2] = base64.RawURLEncoding.EncodeToString(sig)
	bad := strings.Join(parts, ".")
	if _, err := s.Verify(bad); err == nil {
		t.Fatalf("expected verify failure on tampered token")
	}
}

func TestJWTRejectsExpired(t *testing.T) {
	s := NewSigner("secret-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", -time.Minute)
	tok, _ := s.Sign("u", "n")
	if _, err := s.Verify(tok); err == nil {
		t.Fatalf("expected expired-token error")
	}
}

func TestPasswordRoundtrip(t *testing.T) {
	h, err := HashPassword("correct-horse-battery-staple")
	if err != nil {
		t.Fatalf("HashPassword: %v", err)
	}
	if err := VerifyPassword(h, "correct-horse-battery-staple"); err != nil {
		t.Errorf("VerifyPassword good: %v", err)
	}
	if err := VerifyPassword(h, "wrong"); err == nil {
		t.Errorf("VerifyPassword bad: expected error")
	}
}

// A token signed by a different secret must NOT verify.
func TestJWTRejectsWrongSecret(t *testing.T) {
	a := NewSigner("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", time.Hour)
	b := NewSigner("bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb", time.Hour)
	tok, err := a.Sign("u", "n")
	if err != nil {
		t.Fatalf("Sign: %v", err)
	}
	if _, err := b.Verify(tok); err == nil {
		t.Fatalf("expected verify failure with wrong secret")
	}
}

// Verifying garbage input must error, not panic.
func TestJWTVerifyMalformed(t *testing.T) {
	s := NewSigner("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", time.Hour)
	for _, bad := range []string{
		"",
		"not.a.jwt",
		"plain-string",
		"a.b.c",
	} {
		if _, err := s.Verify(bad); err == nil {
			t.Errorf("Verify(%q): expected error", bad)
		}
	}
}

// The "alg confusion" attack: a forged token whose header advertises a
// different algorithm than the server expects must be rejected. We
// hand-craft an `alg: none` token (header + payload, empty signature) and
// confirm Verify refuses it.
func TestJWTRejectsNoneAlg(t *testing.T) {
	s := NewSigner("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", time.Hour)
	// Header `{"alg":"none","typ":"JWT"}` base64-encoded.
	// Payload `{"uid":"u","username":"n"}` base64-encoded.
	// Signature: empty (the "none" algorithm).
	header := "eyJhbGciOiJub25lIiwidHlwIjoiSldUIn0"
	payload := "eyJ1aWQiOiJ1IiwidXNlcm5hbWUiOiJuIn0"
	forged := header + "." + payload + "."
	if _, err := s.Verify(forged); err == nil {
		t.Fatalf("expected Verify to reject alg=none token")
	}
}

// A token signed with the right secret but the wrong signing method (e.g.
// HS384) must be rejected.
func TestJWTRejectsWrongAlgFamily(t *testing.T) {
	secret := []byte("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
	tok := jwt.NewWithClaims(jwt.SigningMethodHS384, Claims{
		UserID:   "u",
		Username: "n",
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(time.Hour)),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
		},
	})
	raw, err := tok.SignedString(secret)
	if err != nil {
		t.Fatalf("sign HS384: %v", err)
	}
	s := NewSigner(string(secret), time.Hour)
	if _, err := s.Verify(raw); err == nil {
		t.Fatalf("expected Verify to reject HS384 token")
	}
}

// Verifying a token whose NotBefore is in the future should fail.
func TestJWTNotBefore(t *testing.T) {
	secret := "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
	tok := jwt.NewWithClaims(jwt.SigningMethodHS256, Claims{
		UserID:   "u",
		Username: "n",
		RegisteredClaims: jwt.RegisteredClaims{
			NotBefore: jwt.NewNumericDate(time.Now().Add(time.Hour)),
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(2 * time.Hour)),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
		},
	})
	raw, err := tok.SignedString([]byte(secret))
	if err != nil {
		t.Fatalf("sign: %v", err)
	}
	s := NewSigner(secret, time.Hour)
	if _, err := s.Verify(raw); err == nil {
		t.Fatalf("expected nbf rejection")
	}
}

// Google verifier without a configured client ID must refuse.
func TestGoogleVerifierUnconfigured(t *testing.T) {
	g := NewGoogleVerifier("")
	if _, err := g.Verify(context.Background(), "any.id.token"); err == nil {
		t.Fatalf("expected error when GOOGLE_CLIENT_ID is empty")
	}
}
