// Package foursquare is a thin client over the Foursquare Places API used by
// the KAMOS venue tag (Phase 4). Only one upstream call is needed
// (`GET /v3/places/search`), so the package depends on net/http directly
// instead of an SDK.
//
// Disabled mode: when constructed with an empty API key, Search always
// returns ErrDisabled. The handler maps that to 503 VENUE_SEARCH_DISABLED.
// This mirrors the Phase 3 storage.Disabled / STORAGE_DISABLED pattern: a
// missing vendor credential is a deliberate "feature off at this deployment"
// signal, not a runtime failure.
//
// Caching: 1h TTL, capacity 1000. Foursquare's free tier is heavily
// rate-limited, and our use case (mobile clients searching for a venue at
// the check-in moment) sees the same q+ll combination from many users; even
// a tiny cache cuts upstream load substantially.
package foursquare

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"time"

	"github.com/hashicorp/golang-lru/v2/expirable"
)

// ErrDisabled is returned by Search when the client has no API key.
var ErrDisabled = errors.New("foursquare disabled")

// ErrRateLimited is returned on HTTP 429 from Foursquare. The handler maps
// it to a 503 VENUE_RATE_LIMITED with a Retry-After header.
var ErrRateLimited = errors.New("foursquare rate limited")

const (
	// apiBase is the Places v3 search endpoint.
	apiBase = "https://api.foursquare.com/v3/places/search"

	// httpTimeout caps a single upstream attempt. Combined with one retry
	// on 5xx, the worst-case caller wait is ~2 * httpTimeout + retryBackoff.
	httpTimeout = 5 * time.Second

	// retryBackoff is the wait between the original attempt and the single
	// retry. Short — clients on mobile networks are sensitive to latency.
	retryBackoff = 200 * time.Millisecond

	// cacheTTL is the LRU entry lifetime. 1h is short enough that venue
	// changes (renames, moves) propagate within a day, long enough to
	// absorb the burst that happens when a popular event is happening.
	cacheTTL = time.Hour

	// cacheSize is the maximum number of distinct (q|ll|locale) cache keys
	// held in memory. ~64 bytes per key + a small []Place per entry ≪ 1MB.
	cacheSize = 1000

	// defaultLimit / maxLimit cap the Foursquare response page.
	defaultLimit = 10
	maxLimit     = 50

	// fsqCategories restricts hits to bar / restaurant / cafe / liquor-store
	// categories. KAMOS is a beverage tracker — coffee shops and izakayas
	// are in-scope; museums and laundromats are not. Foursquare's category
	// taxonomy is a forest; these top-level node IDs match the published
	// Foursquare reference (https://docs.foursquare.com/data-products/docs/categories).
	//   13000 = Dining & Drinking (umbrella including bars, restaurants, cafes)
	//   17069 = Liquor Store (Retail > Food & Beverage Retail)
	fsqCategories = "13000,17069"
)

// Place is the KAMOS-facing projection of a Foursquare place. We translate
// the Foursquare payload at the package boundary so neither the repository
// nor handler imports a foursquare-specific response struct.
type Place struct {
	FoursquareID string  `json:"foursquare_id"`
	Name         string  `json:"name"`
	Address      string  `json:"address"`
	Lat          float64 `json:"lat"`
	Lng          float64 `json:"lng"`
	Country      string  `json:"country"`
	Prefecture   string  `json:"prefecture,omitempty"`
	Locality     string  `json:"locality"`
}

// SearchOptions is the input to Search. Lat+Lng are both-or-neither.
type SearchOptions struct {
	Query  string
	Lat    *float64
	Lng    *float64
	Locale string
	Limit  int
}

// Client is the Foursquare client. Zero value is not usable; call New.
type Client struct {
	apiKey string
	http   *http.Client
	cache  *expirable.LRU[string, []Place]
}

// New constructs a client. An empty apiKey returns a Disabled client whose
// Search always returns ErrDisabled — the caller still gets a non-nil *Client
// so handlers can hold a value type without nil-checks.
func New(apiKey string) *Client {
	return &Client{
		apiKey: apiKey,
		http:   &http.Client{Timeout: httpTimeout},
		cache:  expirable.NewLRU[string, []Place](cacheSize, nil, cacheTTL),
	}
}

// Disabled reports whether the feature is OFF at this deployment.
func (c *Client) Disabled() bool { return c.apiKey == "" }

// Search proxies one Foursquare Places query. Results are cached per
// (q, ll-rounded, locale) for cacheTTL.
func (c *Client) Search(ctx context.Context, opts SearchOptions) ([]Place, error) {
	if c.Disabled() {
		return nil, ErrDisabled
	}
	if opts.Limit <= 0 {
		opts.Limit = defaultLimit
	}
	if opts.Limit > maxLimit {
		opts.Limit = maxLimit
	}

	key := cacheKey(opts)
	if cached, ok := c.cache.Get(key); ok {
		return cached, nil
	}

	places, err := c.fetchWithRetry(ctx, opts)
	if err != nil {
		return nil, err
	}
	c.cache.Add(key, places)
	return places, nil
}

// fetchWithRetry performs the upstream call with one retry on 5xx. Auth
// failures (401/403) do NOT retry — they're config bugs, retrying just
// burns the rate-limit budget.
func (c *Client) fetchWithRetry(ctx context.Context, opts SearchOptions) ([]Place, error) {
	places, err := c.fetchOnce(ctx, opts)
	if err == nil {
		return places, nil
	}
	var serverErr *upstreamServerError
	if !errors.As(err, &serverErr) {
		return nil, err
	}
	select {
	case <-ctx.Done():
		return nil, ctx.Err()
	case <-time.After(retryBackoff):
	}
	return c.fetchOnce(ctx, opts)
}

// upstreamServerError signals a retryable 5xx. Kept internal so callers
// only ever see the wrapped error from fetchWithRetry.
type upstreamServerError struct{ status int }

func (e *upstreamServerError) Error() string {
	return fmt.Sprintf("foursquare upstream %d", e.status)
}

// fetchOnce does one HTTP call.
func (c *Client) fetchOnce(ctx context.Context, opts SearchOptions) ([]Place, error) {
	u, err := url.Parse(apiBase)
	if err != nil {
		return nil, fmt.Errorf("fetchOnce: parse base: %w", err)
	}
	q := u.Query()
	q.Set("query", opts.Query)
	q.Set("limit", strconv.Itoa(opts.Limit))
	q.Set("categories", fsqCategories)
	if opts.Lat != nil && opts.Lng != nil {
		q.Set("ll", fmt.Sprintf("%.6f,%.6f", *opts.Lat, *opts.Lng))
	}
	u.RawQuery = q.Encode()

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, u.String(), nil)
	if err != nil {
		return nil, fmt.Errorf("fetchOnce: new request: %w", err)
	}
	// Foursquare uses the raw API key in Authorization, NOT a Bearer prefix.
	req.Header.Set("Authorization", c.apiKey)
	req.Header.Set("Accept", "application/json")
	if opts.Locale != "" {
		req.Header.Set("Accept-Language", opts.Locale)
	}

	resp, err := c.http.Do(req)
	if err != nil {
		return nil, fmt.Errorf("fetchOnce: http do: %w", err)
	}
	defer resp.Body.Close()

	switch {
	case resp.StatusCode == http.StatusOK:
		// Decode below.
	case resp.StatusCode == http.StatusUnauthorized, resp.StatusCode == http.StatusForbidden:
		// Config bug — do not page Sentry, do not retry.
		return nil, fmt.Errorf("fetchOnce: auth failed (%d)", resp.StatusCode)
	case resp.StatusCode == http.StatusTooManyRequests:
		return nil, ErrRateLimited
	case resp.StatusCode >= 500:
		return nil, &upstreamServerError{status: resp.StatusCode}
	default:
		return nil, fmt.Errorf("fetchOnce: unexpected status %d", resp.StatusCode)
	}

	var payload struct {
		Results []struct {
			FsqID    string `json:"fsq_id"`
			Name     string `json:"name"`
			Geocodes struct {
				Main struct {
					Latitude  float64 `json:"latitude"`
					Longitude float64 `json:"longitude"`
				} `json:"main"`
			} `json:"geocodes"`
			Location struct {
				Address    string `json:"address"`
				Country    string `json:"country"`
				Region     string `json:"region"`
				Locality   string `json:"locality"`
				FormattedAddress string `json:"formatted_address"`
			} `json:"location"`
		} `json:"results"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&payload); err != nil {
		return nil, fmt.Errorf("fetchOnce: decode: %w", err)
	}

	places := make([]Place, 0, len(payload.Results))
	for _, r := range payload.Results {
		addr := r.Location.Address
		if addr == "" {
			addr = r.Location.FormattedAddress
		}
		places = append(places, Place{
			FoursquareID: r.FsqID,
			Name:         r.Name,
			Address:      addr,
			Lat:          r.Geocodes.Main.Latitude,
			Lng:          r.Geocodes.Main.Longitude,
			Country:      r.Location.Country,
			Prefecture:   r.Location.Region,
			Locality:     r.Location.Locality,
		})
	}
	return places, nil
}

// cacheKey builds the LRU key. Lat/lng rounded to 3 decimals (~100m) so
// nearby callers share a cache entry.
func cacheKey(opts SearchOptions) string {
	var sb strings.Builder
	sb.WriteString(strings.ToLower(strings.TrimSpace(opts.Query)))
	sb.WriteByte('|')
	if opts.Lat != nil && opts.Lng != nil {
		sb.WriteString(fmt.Sprintf("%.3f,%.3f", *opts.Lat, *opts.Lng))
	}
	sb.WriteByte('|')
	sb.WriteString(opts.Locale)
	sb.WriteByte('|')
	sb.WriteString(strconv.Itoa(opts.Limit))
	return sb.String()
}
