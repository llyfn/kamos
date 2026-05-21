package handlers

import (
	"net/http"

	"github.com/kamos/api/internal/middleware"
)

// mwUser is a typed accessor over the auth context so we can keep handlers
// free of repeated context plumbing.
func mwUser(r *http.Request) *middleware.AuthedUser {
	return middleware.UserFromContext(r.Context())
}
