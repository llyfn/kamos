package auth

import (
	"testing"
	"time"
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
	// flip last char
	bad := tok[:len(tok)-1] + "X"
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
