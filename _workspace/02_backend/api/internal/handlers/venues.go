package handlers

import (
	"errors"
	"net/http"
	"strconv"
	"strings"

	"github.com/kamos/api/internal/apierror"
	"github.com/kamos/api/internal/foursquare"
)

// venueSearchLimit caps the result page exposed to the client. Foursquare
// itself caps at 50 (see foursquare.maxLimit); we mirror that here so clients
// can't ask for more.
const venueSearchLimit = 50

// venueSearchResponse is the flat envelope returned by GET /v1/venues/search.
// NOT cursor-paginated — Foursquare's own response is bounded by `limit`,
// and stitching a cursor across upstream pagination adds complexity for no
// real value at this phase.
type venueSearchResponse struct {
	Items []foursquare.Place `json:"items"`
}

// VenueSearch — GET /v1/venues/search?q=&lat=&lng=&locale=&limit=
//
// Authed. Proxies the Foursquare Places search.
//
// Errors:
//   - 422 VALIDATION on missing q or lat/lng mismatch.
//   - 503 VENUE_SEARCH_DISABLED when FOURSQUARE_API_KEY is unset.
//   - 503 VENUE_RATE_LIMITED on upstream 429 (with Retry-After: 1).
//   - 502/500 on other upstream errors (mapped via writeErr → INTERNAL).
func (h *Handler) VenueSearch(w http.ResponseWriter, r *http.Request) {
	if _, ok := h.authedID(w, r); !ok {
		return
	}

	q := strings.TrimSpace(r.URL.Query().Get("q"))
	if q == "" {
		apierror.WriteError(w, http.StatusUnprocessableEntity, "VALIDATION",
			"q is required")
		return
	}

	opts := foursquare.SearchOptions{
		Query:  q,
		Locale: resolveLocale(r),
		Limit:  parseLimit(r, 10, venueSearchLimit),
	}

	latStr := strings.TrimSpace(r.URL.Query().Get("lat"))
	lngStr := strings.TrimSpace(r.URL.Query().Get("lng"))
	if (latStr == "") != (lngStr == "") {
		apierror.WriteError(w, http.StatusUnprocessableEntity, "VALIDATION",
			"lat and lng must be provided together")
		return
	}
	if latStr != "" {
		lat, err := strconv.ParseFloat(latStr, 64)
		if err != nil || lat < -90 || lat > 90 {
			apierror.WriteError(w, http.StatusUnprocessableEntity, "VALIDATION",
				"lat must be a number in [-90, 90]")
			return
		}
		lng, err := strconv.ParseFloat(lngStr, 64)
		if err != nil || lng < -180 || lng > 180 {
			apierror.WriteError(w, http.StatusUnprocessableEntity, "VALIDATION",
				"lng must be a number in [-180, 180]")
			return
		}
		opts.Lat = &lat
		opts.Lng = &lng
	}

	places, err := h.Foursquare.Search(r.Context(), opts)
	if err != nil {
		switch {
		case errors.Is(err, foursquare.ErrDisabled):
			apierror.WriteError(w, http.StatusServiceUnavailable,
				"VENUE_SEARCH_DISABLED",
				"venue search not configured on this server")
		case errors.Is(err, foursquare.ErrRateLimited):
			// Mirror the global rate-limit middleware's Retry-After signal.
			w.Header().Set("Retry-After", "1")
			apierror.WriteError(w, http.StatusServiceUnavailable,
				"VENUE_RATE_LIMITED",
				"venue search is rate limited; retry shortly")
		default:
			h.writeErr(w, "VenueSearch", err)
		}
		return
	}
	if places == nil {
		places = []foursquare.Place{}
	}
	apierror.WriteJSON(w, http.StatusOK, venueSearchResponse{Items: places})
}

// resolveLocale picks the locale for the Foursquare Accept-Language header,
// preferring an explicit ?locale= over the request's Accept-Language tag,
// falling back to "en". The AuthedUser context value doesn't carry the
// stored locale, so we don't consult it here.
func resolveLocale(r *http.Request) string {
	if v := strings.TrimSpace(r.URL.Query().Get("locale")); v != "" {
		v = strings.ToLower(v)
		if v == "en" || v == "ja" || v == "ko" {
			return v
		}
	}
	if h := r.Header.Get("Accept-Language"); h != "" {
		// Just the primary tag — Foursquare doesn't grade quality.
		if i := strings.IndexAny(h, ",;"); i > 0 {
			h = h[:i]
		}
		h = strings.ToLower(strings.TrimSpace(h))
		if i := strings.Index(h, "-"); i > 0 {
			h = h[:i]
		}
		if h == "en" || h == "ja" || h == "ko" {
			return h
		}
	}
	return "en"
}
