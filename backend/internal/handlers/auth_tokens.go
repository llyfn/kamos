package handlers

import (
	"errors"
	"net/http"
	"time"

	"github.com/kamos/api/internal/apierror"
	"github.com/kamos/api/internal/auth"
	"github.com/kamos/api/internal/domain"
)

// RefreshToken implements POST /v1/auth/refresh.
//
// Rotating refresh tokens with re-use detection:
//
//  1. Hash the presented secret; look up by hash.
//  2. Miss → 401 + token_invalid. No family revocation (nothing to revoke).
//  3. Hit AND already revoked → 401 + token_invalid AND revoke the entire
//     family. A revoked token being presented means somewhere a stolen copy
//     escaped; treat every sibling as compromised.
//  4. Hit, not revoked, but expired → 401 + token_expired. No family revoke
//     (expiry is benign).
//  5. Hit, not revoked, owner soft-deleted → 401 + token_invalid.
//  6. Otherwise: revoke the presented token, insert a successor (parent_id
//     = old.id, family_id = old.family_id), issue a new access JWT, return
//     the standard AuthResponse.
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

	// Rotate atomically — revoke the predecessor + insert the successor in
	// one transaction. SEC-010: previously this was Insert(successor) then
	// MarkRevoked(predecessor) outside a tx; N concurrent refreshes of the
	// same predecessor could each land a separate successor. RotateAtomic
	// uses UPDATE … WHERE revoked_at IS NULL RETURNING id — only one
	// caller's row-level lock wins, and the rest get ErrRefreshTokenRaceLost
	// which we surface as TOKEN_INVALID.
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
	if _, err := h.Repos.RefreshTokens.RotateAtomic(
		ctx, row.ID, user.ID, newHash, row.FamilyID, h.refreshTTL(),
	); err != nil {
		if errors.Is(err, apierror.ErrRefreshTokenRaceLost) {
			apierror.WriteError(w, http.StatusUnauthorized, "TOKEN_INVALID", "invalid refresh token")
			return
		}
		h.writeErr(w, "RefreshToken rotate", err)
		return
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
//   - Present → revoke that one token only (mobile single-device sign-out).
//   - Absent  → revoke EVERY active refresh token for the authed user
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
