package domain

import (
	"strings"
	"time"

	"github.com/kamos/api/internal/spec"
)

// ---------------------------------------------------------------------------
// Comments (— flat, on check-ins)
// ---------------------------------------------------------------------------

// Comment is the wire shape returned by /v1/check-ins/{id}/comments and the
// soft-delete endpoint. `User` embeds CheckinUser (a strict subset of
// PublicUser — id, username, display_username, display_name, avatar_url)
// so email + email_verified can never leak. The shape mirrors the existing
// FeedItem.User shape so the Flutter client uses one renderer for both.
//
// `User` is a pointer because comments.user_id is ON DELETE SET NULL.
// When the original author has been hard-purged by the username-hold
// sweep, the comment row remains but the user pointer is nil; Flutter
// renders the localized `commentAuthorDeleted` placeholder.
type Comment struct {
	ID        string       `json:"id"`
	CheckInID string       `json:"check_in_id"`
	User      *CheckinUser `json:"user"`
	Body      string       `json:"body"`
	CreatedAt time.Time    `json:"created_at"`
	// EditedAt is non-nil when the author has edited the body after creation
	// (SPEC §5.4 / migration 004). Rendering-only.
	EditedAt *time.Time `json:"edited_at,omitempty"`
	// DeletedAt is exposed for completeness; List queries filter
	// soft-deleted rows server-side so clients never see one here.
	DeletedAt *time.Time `json:"deleted_at,omitempty"`
}

// CreateCommentRequest is the body for POST /v1/check-ins/{id}/comments.
type CreateCommentRequest struct {
	Body string `json:"body"`
}

// UpdateCommentRequest is the body for PATCH /v1/comments/{id}. Body is the
// only mutable field per SPEC §5.4.
type UpdateCommentRequest struct {
	Body string `json:"body"`
}

// Validate mirrors CreateCommentRequest.Validate so an edit cannot bypass
// the same sanitization a create runs through.
func (r *UpdateCommentRequest) Validate() error {
	r.Body = strings.TrimSpace(r.Body)
	if r.Body == "" {
		return wrapValidation("body must be 1-500 characters")
	}
	clean, err := SanitizeText("body", r.Body, true, spec.CommentMaxChars)
	if err != nil {
		return err
	}
	if len([]rune(clean)) < spec.CommentMinChars {
		return wrapValidation("body must be 1-500 characters")
	}
	r.Body = clean
	return nil
}

// Validate enforces the comment text cap (specs/invariants.yaml comment_text)
// plus a control-character guard mirroring the venue-name pattern; rejects
// Unicode bidi-override codepoints.
func (r *CreateCommentRequest) Validate() error {
	r.Body = strings.TrimSpace(r.Body)
	if r.Body == "" {
		return wrapValidation("body must be 1-500 characters")
	}
	clean, err := SanitizeText("body", r.Body, true, spec.CommentMaxChars)
	if err != nil {
		return err
	}
	if len([]rune(clean)) < spec.CommentMinChars {
		return wrapValidation("body must be 1-500 characters")
	}
	r.Body = clean
	return nil
}
