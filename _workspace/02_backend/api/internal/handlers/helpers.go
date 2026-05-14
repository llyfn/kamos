package handlers

import (
	"net/http"
	"time"

	"github.com/kamos/api/internal/middleware"
)

// mwUser is a typed accessor over the auth context so we can keep handlers
// free of repeated context plumbing.
func mwUser(r *http.Request) *middleware.AuthedUser {
	return middleware.UserFromContext(r.Context())
}

// timeJSON is a re-exported alias to keep the public type name short. We
// might add ISO-8601 marshalling tweaks later.
type timeJSON = time.Time
