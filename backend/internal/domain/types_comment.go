package domain

import (
	"strings"
	"time"
)

// ---------------------------------------------------------------------------
// Comments (Phase 6a — flat, on check-ins)
// ---------------------------------------------------------------------------

// Comment is the wire shape returned by /v1/check-ins/{id}/comments and the
// soft-delete endpoint. `User` embeds CheckinUser (a strict subset of
// PublicUser — id, username, display_username, display_name, avatar_url)
// so email + email_verified can never leak. The shape mirrors the existing
// FeedItem.User shape so the Flutter client uses one renderer for both.
type Comment struct {
	ID        string      `json:"id"`
	CheckInID string      `json:"check_in_id"`
	User      CheckinUser `json:"user"`
	Body      string      `json:"body"`
	CreatedAt time.Time   `json:"created_at"`
	// DeletedAt is exposed for completeness; List queries filter
	// soft-deleted rows server-side so clients never see one here.
	DeletedAt *time.Time `json:"deleted_at,omitempty"`
}

// CreateCommentRequest is the body for POST /v1/check-ins/{id}/comments.
type CreateCommentRequest struct {
	Body string `json:"body"`
}

// Validate enforces SPEC §6.7's "≤ 500 chars" cap plus a control-character
// guard mirroring the venue-name pattern from migration 006 (defense in
// depth on a shared user-content surface). SEC-006 extends the guard to
// reject Unicode bidi-override codepoints.
func (r *CreateCommentRequest) Validate() error {
	r.Body = strings.TrimSpace(r.Body)
	if r.Body == "" {
		return wrapValidation("body must be 1-500 characters")
	}
	clean, err := SanitizeText("body", r.Body, true, 500)
	if err != nil {
		return err
	}
	if len([]rune(clean)) < 1 {
		return wrapValidation("body must be 1-500 characters")
	}
	r.Body = clean
	return nil
}
