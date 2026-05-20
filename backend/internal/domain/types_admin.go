package domain

// ---------------------------------------------------------------------------
// RBAC roles (Phase 5a)
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
