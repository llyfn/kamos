package handlers

import (
	"bytes"
	"net/http"
	"time"

	"github.com/kamos/api/internal/middleware"
)

// mwUser is a typed accessor over the auth context so we can keep handlers
// free of repeated context plumbing.
func mwUser(r *http.Request) *middleware.AuthedUser {
	return middleware.UserFromContext(r.Context())
}

// bytesReader returns an io.Reader for an in-memory slice. We use it to
// double-decode JSON bodies for fields that need null-vs-omitted treatment.
func bytesReader(b []byte) *bytes.Reader { return bytes.NewReader(b) }

// timeJSON is a re-exported alias to keep the public type name short. We
// might add ISO-8601 marshalling tweaks later.
type timeJSON = time.Time
