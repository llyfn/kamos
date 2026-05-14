package handlers

import (
	"errors"
	"net/http"
	"time"

	"github.com/kamos/api/internal/apierror"
	"github.com/kamos/api/internal/auth"
	"github.com/kamos/api/internal/domain"
	"github.com/kamos/api/internal/middleware"
	"github.com/kamos/api/internal/repository"
)

// refreshTTL returns the configured refresh TTL, or the package default.
func (h *Handler) refreshTTL() time.Duration {
	if h.Cfg != nil && h.Cfg.RefreshTTL > 0 {
		return h.Cfg.RefreshTTL
	}
	return auth.DefaultRefreshTTL
}

// issueAuthPair generates a fresh access JWT and a new originating refresh
// token (parent_id = nil, family_id = self) for the given user. Used by
// register / login / google login.
func (h *Handler) issueAuthPair(r *http.Request, user *domain.User) (string, string, error) {
	access, err := h.Signer.Sign(user.ID, user.Username)
	if err != nil {
		return "", "", err
	}
	raw, hash, err := auth.NewRefreshSecret()
	if err != nil {
		return "", "", err
	}
	if _, err := h.Repos.RefreshTokens.Insert(
		r.Context(), user.ID, hash, nil, "", h.refreshTTL(),
	); err != nil {
		return "", "", err
	}
	return access, raw, nil
}

// Register implements POST /v1/auth/register.
//   1. Validate the body (username regex, password ≥ 8, etc.)
//   2. Check the username + email aren't held
//   3. Insert user + Inventory/Wishlist collections in a tx
//   4. Issue a verification token (24h) and a JWT
func (h *Handler) Register(w http.ResponseWriter, r *http.Request) {
	var req domain.RegisterRequest
	if err := decodeJSON(r, &req); err != nil {
		h.writeErr(w, "Register decode", err)
		return
	}
	if err := req.Validate(); err != nil {
		h.writeErr(w, "Register validate", err)
		return
	}

	ctx := r.Context()
	state, _, err := h.Repos.Users.CheckUsernameAvailability(ctx, req.Username)
	if err != nil {
		h.writeErr(w, "Register check username", err)
		return
	}
	if state == "live" || state == "held" {
		apierror.WriteError(w, http.StatusConflict, "USERNAME_HELD", "username is not available")
		return
	}
	taken, err := h.Repos.Users.EmailExists(ctx, req.Email)
	if err != nil {
		h.writeErr(w, "Register email check", err)
		return
	}
	if taken {
		apierror.WriteError(w, http.StatusConflict, "EMAIL_TAKEN", "email is already registered")
		return
	}

	hashed, err := auth.HashPassword(req.Password)
	if err != nil {
		h.writeErr(w, "Register hash", err)
		return
	}
	user, err := h.Repos.Users.CreateUserWithDefaults(ctx, repository.CreateUserParams{
		DisplayUsername: req.Username,
		Email:           req.Email,
		EmailVerified:   false,
		PasswordHash:    &hashed,
		DisplayName:     req.DisplayName,
		Bio:             req.Bio,
		Locale:          req.Locale,
	})
	if err != nil {
		h.writeErr(w, "Register insert", err)
		return
	}

	// Verification token (24h). The email send is stubbed — wire up SMTP in
	// integration. The link format is `${APP_BASE_URL}/verify?token=...`.
	token, _ := randomToken(32)
	if err := h.Repos.Users.CreateVerificationToken(ctx, user.ID, token); err != nil {
		h.Log.Error("CreateVerificationToken", "err", err)
	}
	// TODO: wire SMTP sender. For now, log the link so dev environments can
	// click through it manually.
	h.Log.Info("verification link",
		"user_id", user.ID,
		"link", h.Cfg.AppBaseURL+"/verify?token="+token,
	)

	access, refresh, err := h.issueAuthPair(r, user)
	if err != nil {
		h.writeErr(w, "Register issue", err)
		return
	}
	apierror.WriteJSON(w, http.StatusCreated, domain.AuthResponse{
		User:             *user,
		AccessToken:      access,
		RefreshToken:     refresh,
		TokenType:        "Bearer",
		ExpiresIn:        int64(h.Cfg.JWTTTL.Seconds()),
		RefreshExpiresIn: int64(h.refreshTTL().Seconds()),
	})
}

// Login implements POST /v1/auth/login.
func (h *Handler) Login(w http.ResponseWriter, r *http.Request) {
	var req domain.LoginRequest
	if err := decodeJSON(r, &req); err != nil {
		h.writeErr(w, "Login decode", err)
		return
	}
	if err := req.Validate(); err != nil {
		h.writeErr(w, "Login validate", err)
		return
	}

	row, err := h.Repos.Users.FindByEmail(r.Context(), req.Email)
	if err != nil {
		if errors.Is(err, apierror.ErrNotFound) {
			apierror.WriteError(w, http.StatusUnauthorized, "INVALID_CREDENTIAL", "invalid email or password")
			return
		}
		h.writeErr(w, "Login find", err)
		return
	}
	if row.PasswordHash == nil {
		apierror.WriteError(w, http.StatusUnauthorized, "INVALID_CREDENTIAL", "invalid email or password")
		return
	}
	if err := auth.VerifyPassword(*row.PasswordHash, req.Password); err != nil {
		apierror.WriteError(w, http.StatusUnauthorized, "INVALID_CREDENTIAL", "invalid email or password")
		return
	}
	access, refresh, err := h.issueAuthPair(r, &row.User)
	if err != nil {
		h.writeErr(w, "Login issue", err)
		return
	}
	apierror.WriteJSON(w, http.StatusOK, domain.AuthResponse{
		User:             row.User,
		AccessToken:      access,
		RefreshToken:     refresh,
		TokenType:        "Bearer",
		ExpiresIn:        int64(h.Cfg.JWTTTL.Seconds()),
		RefreshExpiresIn: int64(h.refreshTTL().Seconds()),
	})
}

// GoogleLogin implements POST /v1/auth/google.
// The Flutter client sends the Google ID token; we verify against Google
// (using the configured client ID as `aud`), then upsert by `google_sub`.
//
// For first-login the client may provide a `username` to claim, or we derive
// one from the email local part. If the derived username clashes, we 409.
func (h *Handler) GoogleLogin(w http.ResponseWriter, r *http.Request) {
	var req domain.GoogleLoginRequest
	if err := decodeJSON(r, &req); err != nil {
		h.writeErr(w, "GoogleLogin decode", err)
		return
	}
	if err := req.Validate(); err != nil {
		h.writeErr(w, "GoogleLogin validate", err)
		return
	}

	ctx := r.Context()
	payload, err := h.Google.Verify(ctx, req.IDToken)
	if err != nil {
		h.Log.Warn("GoogleLogin verify failed", "err", err)
		apierror.WriteError(w, http.StatusUnauthorized, "INVALID_CREDENTIAL", "invalid id token")
		return
	}

	existing, err := h.Repos.Users.FindByGoogleSub(ctx, payload.Sub)
	if err != nil && !errors.Is(err, apierror.ErrNotFound) {
		h.writeErr(w, "GoogleLogin lookup", err)
		return
	}

	var user *domain.User
	if existing != nil {
		user = existing
	} else {
		// First login: pick a username. If the client sent one, use it; else
		// derive from email local-part. We do NOT auto-merge with an existing
		// email-only account; that's a 409.
		uname := ""
		if req.Username != nil && *req.Username != "" {
			uname = *req.Username
		} else if payload.Email != "" {
			at := -1
			for i, ch := range payload.Email {
				if ch == '@' {
					at = i
					break
				}
			}
			if at > 0 {
				uname = payload.Email[:at]
			}
		}
		// Sanitize candidate username.
		cand := sanitizeUsernameCandidate(uname)
		if cand == "" {
			apierror.WriteError(w, http.StatusUnprocessableEntity, "USERNAME_REQUIRED", "please choose a username")
			return
		}
		state, _, err := h.Repos.Users.CheckUsernameAvailability(ctx, cand)
		if err != nil {
			h.writeErr(w, "GoogleLogin avail", err)
			return
		}
		if state == "live" || state == "held" {
			apierror.WriteError(w, http.StatusConflict, "USERNAME_HELD", "username is not available; please pick another")
			return
		}
		if payload.Email != "" {
			taken, err := h.Repos.Users.EmailExists(ctx, payload.Email)
			if err != nil {
				h.writeErr(w, "GoogleLogin email", err)
				return
			}
			if taken {
				apierror.WriteError(w, http.StatusConflict, "EMAIL_TAKEN", "this email is linked to another account")
				return
			}
		}
		locale := "en"
		if req.Locale != nil {
			l := *req.Locale
			if l == "en" || l == "ja" || l == "ko" {
				locale = l
			}
		}
		dispName := payload.Name
		if dispName == "" {
			dispName = cand
		}
		var avatar *string
		if payload.Picture != "" {
			a := payload.Picture
			avatar = &a
		}
		newUser, err := h.Repos.Users.CreateUserWithDefaults(ctx, repository.CreateUserParams{
			DisplayUsername: cand,
			Email:           payload.Email,
			EmailVerified:   payload.EmailVerified,
			GoogleSub:       &payload.Sub,
			DisplayName:     dispName,
			AvatarURL:       avatar,
			Locale:          locale,
		})
		if err != nil {
			h.writeErr(w, "GoogleLogin create", err)
			return
		}
		user = newUser
	}

	access, refresh, err := h.issueAuthPair(r, user)
	if err != nil {
		h.writeErr(w, "GoogleLogin issue", err)
		return
	}
	apierror.WriteJSON(w, http.StatusOK, domain.AuthResponse{
		User:             *user,
		AccessToken:      access,
		RefreshToken:     refresh,
		TokenType:        "Bearer",
		ExpiresIn:        int64(h.Cfg.JWTTTL.Seconds()),
		RefreshExpiresIn: int64(h.refreshTTL().Seconds()),
	})
}

// VerifyEmail consumes a verification token.
func (h *Handler) VerifyEmail(w http.ResponseWriter, r *http.Request) {
	var req domain.VerifyEmailRequest
	if err := decodeJSON(r, &req); err != nil {
		h.writeErr(w, "VerifyEmail decode", err)
		return
	}
	if err := req.Validate(); err != nil {
		h.writeErr(w, "VerifyEmail validate", err)
		return
	}
	userID, err := h.Repos.Users.FindUserByVerificationToken(r.Context(), req.Token)
	if err != nil {
		h.writeErr(w, "VerifyEmail find", err)
		return
	}
	if err := h.Repos.Users.MarkEmailVerified(r.Context(), userID, req.Token); err != nil {
		h.writeErr(w, "VerifyEmail mark", err)
		return
	}
	apierror.WriteJSON(w, http.StatusOK, map[string]bool{"verified": true})
}

// ResendVerification issues a fresh 24h token (authed).
func (h *Handler) ResendVerification(w http.ResponseWriter, r *http.Request) {
	uid, ok := h.authedID(w, r)
	if !ok {
		return
	}
	token, _ := randomToken(32)
	if err := h.Repos.Users.CreateVerificationToken(r.Context(), uid, token); err != nil {
		h.writeErr(w, "ResendVerification", err)
		return
	}
	h.Log.Info("verification link",
		"user_id", uid,
		"link", h.Cfg.AppBaseURL+"/verify?token="+token,
	)
	apierror.WriteJSON(w, http.StatusAccepted, map[string]bool{"sent": true})
}

// PasswordChange implements POST /v1/auth/password-change.
func (h *Handler) PasswordChange(w http.ResponseWriter, r *http.Request) {
	uid, ok := h.authedID(w, r)
	if !ok {
		return
	}
	var req domain.PasswordChangeRequest
	if err := decodeJSON(r, &req); err != nil {
		h.writeErr(w, "PasswordChange decode", err)
		return
	}
	if err := req.Validate(); err != nil {
		h.writeErr(w, "PasswordChange validate", err)
		return
	}
	currentHash, err := h.Repos.Users.LoadPasswordHash(r.Context(), uid)
	if err != nil {
		h.writeErr(w, "PasswordChange load", err)
		return
	}
	if err := auth.VerifyPassword(currentHash, req.CurrentPassword); err != nil {
		apierror.WriteError(w, http.StatusUnauthorized, "INVALID_CREDENTIAL", "current password is incorrect")
		return
	}
	newHash, err := auth.HashPassword(req.NewPassword)
	if err != nil {
		h.writeErr(w, "PasswordChange hash", err)
		return
	}
	if err := h.Repos.Users.UpdatePasswordHash(r.Context(), uid, newHash); err != nil {
		h.writeErr(w, "PasswordChange update", err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// EmailChange implements POST /v1/auth/email-change. Triggers re-verification.
func (h *Handler) EmailChange(w http.ResponseWriter, r *http.Request) {
	uid, ok := h.authedID(w, r)
	if !ok {
		return
	}
	var req domain.EmailChangeRequest
	if err := decodeJSON(r, &req); err != nil {
		h.writeErr(w, "EmailChange decode", err)
		return
	}
	if err := req.Validate(); err != nil {
		h.writeErr(w, "EmailChange validate", err)
		return
	}
	taken, err := h.Repos.Users.EmailExists(r.Context(), req.NewEmail)
	if err != nil {
		h.writeErr(w, "EmailChange exists", err)
		return
	}
	if taken {
		apierror.WriteError(w, http.StatusConflict, "EMAIL_TAKEN", "email is already registered")
		return
	}
	if err := h.Repos.Users.UpdateEmail(r.Context(), uid, req.NewEmail); err != nil {
		h.writeErr(w, "EmailChange update", err)
		return
	}
	token, _ := randomToken(32)
	if err := h.Repos.Users.CreateVerificationToken(r.Context(), uid, token); err != nil {
		h.Log.Error("EmailChange token", "err", err)
	}
	h.Log.Info("verification link",
		"user_id", uid,
		"link", h.Cfg.AppBaseURL+"/verify?token="+token,
	)
	apierror.WriteJSON(w, http.StatusAccepted, map[string]bool{"re_verification_sent": true})
}

// RefreshToken implements POST /v1/auth/refresh.
//
// Rotating refresh tokens with re-use detection:
//
//   1. Hash the presented secret; look up by hash.
//   2. Miss → 401 + token_invalid. No family revocation (nothing to revoke).
//   3. Hit AND already revoked → 401 + token_invalid AND revoke the entire
//      family. A revoked token being presented means somewhere a stolen copy
//      escaped; treat every sibling as compromised.
//   4. Hit, not revoked, but expired → 401 + token_expired. No family revoke
//      (expiry is benign).
//   5. Hit, not revoked, owner soft-deleted → 401 + token_invalid.
//   6. Otherwise: revoke the presented token, insert a successor (parent_id
//      = old.id, family_id = old.family_id), issue a new access JWT, return
//      the standard AuthResponse.
//
// The endpoint is public (no Auth middleware) — possession of a valid raw
// refresh secret IS the authentication. The `/v1/auth/*` rate-limit applies.
func (h *Handler) RefreshToken(w http.ResponseWriter, r *http.Request) {
	var req domain.RefreshTokenRequest
	if err := decodeJSON(r, &req); err != nil {
		h.writeErr(w, "RefreshToken decode", err)
		return
	}
	if err := req.Validate(); err != nil {
		h.writeErr(w, "RefreshToken validate", err)
		return
	}

	ctx := r.Context()
	hash := auth.HashRefreshToken(req.RefreshToken)
	row, err := h.Repos.RefreshTokens.LookupByHash(ctx, hash)
	if err != nil {
		if errors.Is(err, apierror.ErrNotFound) {
			apierror.WriteError(w, http.StatusUnauthorized, "TOKEN_INVALID", "invalid refresh token")
			return
		}
		h.writeErr(w, "RefreshToken lookup", err)
		return
	}

	// Re-use detection: the presented token is in the DB but already revoked.
	// Burn the whole family.
	if row.RevokedAt != nil {
		n, ferr := h.Repos.RefreshTokens.RevokeFamily(ctx, row.FamilyID)
		if ferr != nil {
			h.Log.Error("RefreshToken family revoke", "err", ferr,
				"user_id", row.UserID, "family_id", row.FamilyID)
		}
		h.Log.Warn("refresh_token_reuse_detected",
			"user_id", row.UserID,
			"family_id", row.FamilyID,
			"revoked_count", n,
		)
		apierror.WriteError(w, http.StatusUnauthorized, "TOKEN_INVALID", "invalid refresh token")
		return
	}

	if time.Now().After(row.ExpiresAt) {
		apierror.WriteError(w, http.StatusUnauthorized, "TOKEN_EXPIRED", "refresh token expired")
		return
	}

	// Owner must still be alive.
	user, err := h.Repos.Users.FindByID(ctx, row.UserID)
	if err != nil {
		if errors.Is(err, apierror.ErrNotFound) {
			apierror.WriteError(w, http.StatusUnauthorized, "TOKEN_INVALID", "invalid refresh token")
			return
		}
		h.writeErr(w, "RefreshToken find user", err)
		return
	}

	// Rotate: revoke the presented token, insert a successor in the same
	// family. The order matters — if the insert fails we still want the
	// caller's token to be valid so a retry doesn't bury them.
	access, err := h.Signer.Sign(user.ID, user.Username)
	if err != nil {
		h.writeErr(w, "RefreshToken sign", err)
		return
	}
	raw, newHash, err := auth.NewRefreshSecret()
	if err != nil {
		h.writeErr(w, "RefreshToken new secret", err)
		return
	}
	parentID := row.ID
	if _, err := h.Repos.RefreshTokens.Insert(
		ctx, user.ID, newHash, &parentID, row.FamilyID, h.refreshTTL(),
	); err != nil {
		h.writeErr(w, "RefreshToken insert successor", err)
		return
	}
	if err := h.Repos.RefreshTokens.MarkRevoked(ctx, row.ID); err != nil {
		// The successor is already issued; we log but do not error out the
		// caller — leaving the predecessor live for a moment is the lesser
		// evil. The successor is what the client will use next.
		h.Log.Error("RefreshToken revoke predecessor", "err", err,
			"user_id", user.ID, "token_id", row.ID)
	}

	apierror.WriteJSON(w, http.StatusOK, domain.AuthResponse{
		User:             *user,
		AccessToken:      access,
		RefreshToken:     raw,
		TokenType:        "Bearer",
		ExpiresIn:        int64(h.Cfg.JWTTTL.Seconds()),
		RefreshExpiresIn: int64(h.refreshTTL().Seconds()),
	})
}

// Logout implements POST /v1/auth/logout (authed).
//
// Optional body: { "refresh_token": "..." }
//   * Present → revoke that one token only (mobile single-device sign-out).
//   * Absent  → revoke EVERY active refresh token for the authed user
//     (web-style "sign out everywhere" / no-refresh-token fallback).
//
// The endpoint always returns 204 — silent success even if the refresh
// token presented does not belong to the authed user (we don't 403 there
// because clients commonly retry on flakes and a 403 there leaks
// ownership). When the token belongs to a different user, we still log
// the mismatch.
func (h *Handler) Logout(w http.ResponseWriter, r *http.Request) {
	uid, ok := h.authedID(w, r)
	if !ok {
		return
	}
	// Tolerate a missing/empty body — both common (no Content-Length, or
	// {}).
	var req domain.LogoutRequest
	if r.ContentLength > 0 {
		if err := decodeJSON(r, &req); err != nil {
			h.writeErr(w, "Logout decode", err)
			return
		}
	}

	ctx := r.Context()
	if req.RefreshToken != "" {
		hash := auth.HashRefreshToken(req.RefreshToken)
		row, err := h.Repos.RefreshTokens.LookupByHash(ctx, hash)
		if err != nil {
			if !errors.Is(err, apierror.ErrNotFound) {
				h.writeErr(w, "Logout lookup", err)
				return
			}
			// Unknown token → succeed silently. Best-effort cleanup.
			w.WriteHeader(http.StatusNoContent)
			return
		}
		if row.UserID != uid {
			h.Log.Warn("logout_token_owner_mismatch",
				"authed_user_id", uid, "token_user_id", row.UserID)
			w.WriteHeader(http.StatusNoContent)
			return
		}
		if err := h.Repos.RefreshTokens.MarkRevoked(ctx, row.ID); err != nil {
			h.writeErr(w, "Logout revoke", err)
			return
		}
		w.WriteHeader(http.StatusNoContent)
		return
	}

	// Revoke every active refresh token for this user.
	if _, err := h.Repos.RefreshTokens.RevokeAllForUser(ctx, uid); err != nil {
		h.writeErr(w, "Logout revoke all", err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// sanitizeUsernameCandidate strips disallowed characters and trims to the
// SPEC 3-30 range. Returns "" if the resulting string is too short.
func sanitizeUsernameCandidate(s string) string {
	var b []rune
	for _, ch := range s {
		switch {
		case ch >= 'a' && ch <= 'z',
			ch >= 'A' && ch <= 'Z',
			ch >= '0' && ch <= '9',
			ch == '_':
			b = append(b, ch)
		}
		if len(b) >= 30 {
			break
		}
	}
	if len(b) < 3 {
		return ""
	}
	return string(b)
}

// Compile-time ref to keep middleware import alive across files.
var _ = middleware.UserFromContext
