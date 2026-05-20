package handlers

import (
	"errors"
	"net/http"

	"github.com/kamos/api/internal/auth"
	"github.com/kamos/api/internal/domain"
	"github.com/kamos/api/internal/httperr"
	"github.com/kamos/api/internal/repository"
)

// Register implements POST /v1/auth/register.
//
// Stage 3: the orchestration (availability + email-uniqueness + insert +
// default-collections + verify-token + verify-mail + auth-pair issue) lives
// in AuthService.Register.
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
	if h.Services != nil && h.Services.Auth != nil {
		res, err := h.Services.Auth.Register(r.Context(), req, randomToken)
		if err != nil {
			h.writeErr(w, "Register", err)
			return
		}
		httperr.WriteJSON(w, http.StatusCreated, domain.AuthResponse{
			User:             res.User,
			AccessToken:      res.AccessToken,
			RefreshToken:     res.RefreshToken,
			TokenType:        "Bearer",
			ExpiresIn:        int64(h.Cfg.JWTTTL.Seconds()),
			RefreshExpiresIn: res.RefreshExpiresIn,
		})
		return
	}
	// Legacy fallback (tests that don't construct services).
	ctx := r.Context()
	state, _, err := h.Repos.Users.CheckUsernameAvailability(ctx, req.Username)
	if err != nil {
		h.writeErr(w, "Register check username", err)
		return
	}
	if state == "live" || state == "held" {
		httperr.WriteError(w, http.StatusConflict, "USERNAME_HELD", "username is not available")
		return
	}
	taken, err := h.Repos.Users.EmailExists(ctx, req.Email)
	if err != nil {
		h.writeErr(w, "Register email check", err)
		return
	}
	if taken {
		httperr.WriteError(w, http.StatusConflict, "EMAIL_TAKEN", "email is already registered")
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
	token, _ := randomToken(32)
	if err := h.Repos.Users.CreateVerificationToken(ctx, user.ID, token); err != nil {
		h.Log.Error("CreateVerificationToken", "err", err)
	}
	h.sendVerificationEmail(r, user, token)
	access, refresh, err := h.issueAuthPair(r, user)
	if err != nil {
		h.writeErr(w, "Register issue", err)
		return
	}
	httperr.WriteJSON(w, http.StatusCreated, domain.AuthResponse{
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
		if errors.Is(err, domain.ErrNotFound) {
			// SEC-018: equalize wall-clock time vs the "wrong password"
			// branch by running an equivalent bcrypt compare against a
			// precomputed dummy hash. Result is discarded.
			auth.VerifyDummyPassword(req.Password)
			httperr.WriteError(w, http.StatusUnauthorized, "INVALID_CREDENTIAL", "invalid email or password")
			return
		}
		h.writeErr(w, "Login find", err)
		return
	}
	if row.PasswordHash == nil {
		// Google-only account — also run the dummy compare so a probe
		// can't distinguish "no local password" from "wrong password".
		auth.VerifyDummyPassword(req.Password)
		httperr.WriteError(w, http.StatusUnauthorized, "INVALID_CREDENTIAL", "invalid email or password")
		return
	}
	if err := auth.VerifyPassword(*row.PasswordHash, req.Password); err != nil {
		httperr.WriteError(w, http.StatusUnauthorized, "INVALID_CREDENTIAL", "invalid email or password")
		return
	}
	access, refresh, err := h.issueAuthPair(r, &row.User)
	if err != nil {
		h.writeErr(w, "Login issue", err)
		return
	}
	httperr.WriteJSON(w, http.StatusOK, domain.AuthResponse{
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
		httperr.WriteError(w, http.StatusUnauthorized, "INVALID_CREDENTIAL", "invalid id token")
		return
	}

	existing, err := h.Repos.Users.FindByGoogleSub(ctx, payload.Sub)
	if err != nil && !errors.Is(err, domain.ErrNotFound) {
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
			httperr.WriteError(w, http.StatusUnprocessableEntity, "USERNAME_REQUIRED", "please choose a username")
			return
		}
		state, _, err := h.Repos.Users.CheckUsernameAvailability(ctx, cand)
		if err != nil {
			h.writeErr(w, "GoogleLogin avail", err)
			return
		}
		if state == "live" || state == "held" {
			httperr.WriteError(w, http.StatusConflict, "USERNAME_HELD", "username is not available; please pick another")
			return
		}
		if payload.Email != "" {
			taken, err := h.Repos.Users.EmailExists(ctx, payload.Email)
			if err != nil {
				h.writeErr(w, "GoogleLogin email", err)
				return
			}
			if taken {
				httperr.WriteError(w, http.StatusConflict, "EMAIL_TAKEN", "this email is linked to another account")
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
		// SEC-006: Google may return a display name containing arbitrary
		// Unicode including bidi-override codepoints; sanitize before
		// insert. Fallback to the candidate username on any error so the
		// flow still completes for legitimate users.
		dispName := payload.Name
		if dispName != "" {
			if clean, err := domain.SanitizeText("display_name", dispName, false, 50); err == nil {
				dispName = clean
			} else {
				dispName = ""
			}
		}
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
	httperr.WriteJSON(w, http.StatusOK, domain.AuthResponse{
		User:             *user,
		AccessToken:      access,
		RefreshToken:     refresh,
		TokenType:        "Bearer",
		ExpiresIn:        int64(h.Cfg.JWTTTL.Seconds()),
		RefreshExpiresIn: int64(h.refreshTTL().Seconds()),
	})
}

// sanitizeUsernameCandidate strips disallowed characters and trims to the
// SPEC 3-30 range. Returns "" if the resulting string is too short.
// Used by GoogleLogin to derive a username from an email local-part.
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
