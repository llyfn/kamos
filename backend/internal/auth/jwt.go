// Package auth handles JWT signing/verification and Google OAuth ID-token
// verification. Secrets are passed in by Config — auth never touches env.
package auth

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"google.golang.org/api/idtoken"
)

// Claims is the JWT body. UserID is the canonical id; Username is included
// for nice logging and client-side guarding, never trusted server-side.
type Claims struct {
	UserID   string `json:"uid"`
	Username string `json:"username"`
	jwt.RegisteredClaims
}

// Signer issues JWTs.
type Signer struct {
	secret []byte
	ttl    time.Duration
}

// NewSigner constructs a signer. Secret must be ≥ 32 bytes for HS256 safety.
func NewSigner(secret string, ttl time.Duration) *Signer {
	return &Signer{secret: []byte(secret), ttl: ttl}
}

// Sign issues a new token for the given user.
func (s *Signer) Sign(userID, username string) (string, error) {
	now := time.Now()
	tok := jwt.NewWithClaims(jwt.SigningMethodHS256, Claims{
		UserID:   userID,
		Username: username,
		RegisteredClaims: jwt.RegisteredClaims{
			Subject:   userID,
			IssuedAt:  jwt.NewNumericDate(now),
			ExpiresAt: jwt.NewNumericDate(now.Add(s.ttl)),
			NotBefore: jwt.NewNumericDate(now),
		},
	})
	out, err := tok.SignedString(s.secret)
	if err != nil {
		return "", fmt.Errorf("Sign: %w", err)
	}
	return out, nil
}

// Verify parses a token and returns its claims. It rejects "none" and any
// non-HS256 algorithm explicitly to avoid the alg-confusion vulnerability.
func (s *Signer) Verify(tokenStr string) (*Claims, error) {
	var c Claims
	tok, err := jwt.ParseWithClaims(tokenStr, &c, func(t *jwt.Token) (any, error) {
		if t.Method.Alg() != jwt.SigningMethodHS256.Alg() {
			return nil, fmt.Errorf("unexpected signing method: %s", t.Method.Alg())
		}
		return s.secret, nil
	})
	if err != nil {
		return nil, fmt.Errorf("Verify: %w", err)
	}
	if !tok.Valid {
		return nil, errors.New("Verify: token invalid")
	}
	return &c, nil
}

// GooglePayload is the trusted subset of a Google ID token we use.
type GooglePayload struct {
	Sub           string
	Email         string
	EmailVerified bool
	Name          string
	Picture       string
}

// GoogleVerifier validates ID tokens against Google's published keys.
type GoogleVerifier struct {
	audience string
}

// NewGoogleVerifier constructs a verifier bound to a single client ID.
func NewGoogleVerifier(clientID string) *GoogleVerifier {
	return &GoogleVerifier{audience: clientID}
}

// Verify checks the signature, issuer, audience and expiry of an ID token.
// The Google client *secret* is NOT used here — ID-token verification only
// requires the public client ID as audience and Google's published JWKS, which
// idtoken.Validate fetches.
func (g *GoogleVerifier) Verify(ctx context.Context, idTokenStr string) (*GooglePayload, error) {
	if g.audience == "" {
		// CONFIGURE: set GOOGLE_CLIENT_ID before enabling Google OAuth.
		return nil, errors.New("GoogleVerifier: GOOGLE_CLIENT_ID not configured")
	}
	p, err := idtoken.Validate(ctx, idTokenStr, g.audience)
	if err != nil {
		return nil, fmt.Errorf("GoogleVerifier.Verify: %w", err)
	}
	out := &GooglePayload{}
	out.Sub = p.Subject
	if v, ok := p.Claims["email"].(string); ok {
		out.Email = v
	}
	if v, ok := p.Claims["email_verified"].(bool); ok {
		out.EmailVerified = v
	}
	if v, ok := p.Claims["name"].(string); ok {
		out.Name = v
	}
	if v, ok := p.Claims["picture"].(string); ok {
		out.Picture = v
	}
	return out, nil
}
