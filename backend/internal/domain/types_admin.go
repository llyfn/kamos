package domain

import "time"

// ---------------------------------------------------------------------------
// RBAC roles
// ---------------------------------------------------------------------------

// UserRole mirrors the postgres user_role enum (migration 007). Three values
// only: user (default), moderator (can triage), admin (full access). The
// column lives on `users.role` and is read on every admin-scoped request
// (no JWT claim) so a demotion takes effect within one indexed PK lookup
// rather than waiting for the access-token TTL.
type UserRole string

const (
	RoleUser      UserRole = "user"
	RoleModerator UserRole = "moderator"
	RoleAdmin     UserRole = "admin"
)

// Valid reports whether s is one of the three accepted role strings.
func (r UserRole) Valid() bool {
	switch r {
	case RoleUser, RoleModerator, RoleAdmin:
		return true
	}
	return false
}

// ---------------------------------------------------------------------------
// Moderation log audit entry
// ---------------------------------------------------------------------------

// ModerationLogEntry is one row of the audit trail backing
// `GET /v1/admin/moderation-log`. Column shape matches migration 008
// (moderation_log). `notes` is the SQL column name; the JSON tag stays
// `notes` for consistency with the request bodies on
// admin/{approve,reject,moderate,comments/moderate} endpoints that take
// notes alongside their state-change writes.
type ModerationLogEntry struct {
	ID          string         `json:"id"`
	ModeratorID *string        `json:"moderator_id"`
	Action      string         `json:"action"`
	TargetType  string         `json:"target_type"`
	TargetID    string         `json:"target_id"`
	Notes       *string        `json:"notes,omitempty"`
	Metadata    map[string]any `json:"metadata,omitempty"`
	CreatedAt   time.Time      `json:"created_at"`
}
