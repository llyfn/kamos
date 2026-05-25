package domain

import "time"

// ---------------------------------------------------------------------------
// Notifications (SPEC §5.4)
// ---------------------------------------------------------------------------

// Notification type discriminants. Mirror the DB CHECK constraint in
// migration 019.
const (
	NotificationTypeToast          = "toast"
	NotificationTypeComment        = "comment"
	NotificationTypeFollow         = "follow"
	NotificationTypeFollowRequest  = "follow_request"
	NotificationTypeFollowApproved = "follow_approved"
)

// Notification is the wire shape returned by /v1/notifications. `Actor` may
// be nil when the original actor was hard-deleted (FK ON DELETE SET NULL).
// `CheckInID` and `CommentID` are nullable for the same reason and also for
// follow* types that carry no source ref.
type Notification struct {
	ID        string       `json:"id"`
	Type      string       `json:"type"`
	Actor     *CheckinUser `json:"actor"`
	CheckInID *string      `json:"check_in_id,omitempty"`
	CommentID *string      `json:"comment_id,omitempty"`
	ReadAt    *time.Time   `json:"read_at"`
	CreatedAt time.Time    `json:"created_at"`
}

// MarkReadRequest is the body for POST /v1/notifications/read. Exactly one
// of `IDs` or `All` must be set (the handler enforces this).
type MarkReadRequest struct {
	IDs []string `json:"ids,omitempty"`
	All bool     `json:"all,omitempty"`
}

// MarkReadResponse is the body for POST /v1/notifications/read.
type MarkReadResponse struct {
	Marked int `json:"marked"`
}

// UnreadCountResponse is the body for GET /v1/notifications/unread-count.
type UnreadCountResponse struct {
	Count int `json:"count"`
}
