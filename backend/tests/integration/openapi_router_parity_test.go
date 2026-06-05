//go:build integration
// +build integration

// Drift check between backend/openapi.yaml and the chi router.
//
// The Flutter typed client and the React admin client are both code-
// generated from openapi.yaml; if a backend endpoint is removed but the
// spec still advertises it, the Flutter app calls a phantom route. This
// test walks both surfaces and reports the symmetric difference.
//
// It is intentionally a structural check — we compare {method, path
// template} pairs only, not request / response shapes (those drift
// surfaces are caught by handler tests and the openapi-mocked Flutter
// repository tests).

package integration

import (
	"net/http"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"testing"

	"github.com/go-chi/chi/v5"
)

// TestOpenAPIRouterParity asserts:
//
//   - every path:method mounted on the chi router is documented in
//     backend/openapi.yaml, and
//   - every path:method documented in openapi.yaml is mounted on the chi
//     router.
//
// A failure means one of the two sides drifted; reconcile by either
// adding the spec entry or removing the dead route.
func TestOpenAPIRouterParity(t *testing.T) {
	srv := newServer(t)
	defer srv.Close()

	// Walk the chi router. `srv.Config.Handler` returns the http.Handler
	// we mounted in newServer; the type assertion lets chi.Walk see it.
	r, ok := srv.Config.Handler.(chi.Router)
	if !ok {
		t.Fatalf("server handler is not a chi.Router (got %T)", srv.Config.Handler)
	}

	live := map[string]struct{}{}
	walkErr := chi.Walk(r, func(method, route string, _ http.Handler, _ ...func(http.Handler) http.Handler) error {
		// Restrict to /v1 — health / metrics / OPTIONS / static are out
		// of openapi scope by design.
		if !strings.HasPrefix(route, "/v1/") {
			return nil
		}
		// Skip CORS preflight and HEAD shadows — openapi documents the
		// concrete verbs only.
		if method == http.MethodOptions || method == http.MethodHead {
			return nil
		}
		live[method+" "+normalizePath(route)] = struct{}{}
		return nil
	})
	if walkErr != nil {
		t.Fatalf("chi.Walk: %v", walkErr)
	}

	// Parse openapi.yaml structurally with a tiny indentation-aware
	// scanner — yaml.v3 is not in the test build's direct deps, and we
	// only need the {path, methods} pairs. The file is small enough
	// (~3K lines) that the regex pass is cheap.
	specPaths, err := parseOpenAPIPaths()
	if err != nil {
		t.Fatalf("parse openapi: %v", err)
	}
	spec := map[string]struct{}{}
	for p, methods := range specPaths {
		for _, m := range methods {
			spec[strings.ToUpper(m)+" "+normalizePath(p)] = struct{}{}
		}
	}

	missingFromSpec := diff(live, spec)
	missingFromRouter := diff(spec, live)

	// Allow-list: endpoints that are intentionally undocumented (health,
	// metrics) shouldn't be in live anyway because we filtered on /v1,
	// but if a future PR mounts a /v1/internal/* probe and we choose not
	// to document it, add the {method, path} string to this list.
	for k := range missingFromSpec {
		t.Errorf("router endpoint not in openapi.yaml: %s", k)
	}
	for k := range missingFromRouter {
		t.Errorf("openapi.yaml endpoint not mounted in router: %s", k)
	}

	if t.Failed() {
		t.Logf("live routes: %d, spec routes: %d", len(live), len(spec))
	}
}

// normalizePath collapses chi's `{id}` syntax and openapi's `{id}` form
// so the maps compare cleanly. Trailing slashes are stripped.
func normalizePath(p string) string {
	p = strings.TrimSuffix(p, "/")
	return p
}

// parseOpenAPIPaths walks backend/openapi.yaml and returns a map of
// path-template → list of HTTP methods declared under that path. The
// scanner is whitespace-aware: a `/v1/...` line at column 2 starts a
// path, and any of GET/POST/...:` at column 4 is a method.
func parseOpenAPIPaths() (map[string][]string, error) {
	wd, err := os.Getwd()
	if err != nil {
		return nil, err
	}
	// helpers_test.go runs from backend/tests/integration; backtrack
	// two levels to reach backend/.
	yamlPath := filepath.Join(wd, "..", "..", "openapi.yaml")
	data, err := os.ReadFile(yamlPath)
	if err != nil {
		return nil, err
	}
	// Any top-level path entry acts as a section boundary so methods
	// belonging to non-/v1 paths (e.g. the public /verify HTML route) do
	// not get wrongly attributed to the previous /v1 path's slot.
	anyPathRe := regexp.MustCompile(`^  (/[^:]+):\s*$`)
	versionedPathRe := regexp.MustCompile(`^/v[0-9]`)
	methodRe := regexp.MustCompile(`^    (get|put|post|delete|patch):`)
	out := map[string][]string{}
	var current string
	for _, line := range strings.Split(string(data), "\n") {
		if m := anyPathRe.FindStringSubmatch(line); m != nil {
			if versionedPathRe.MatchString(m[1]) {
				current = m[1]
				out[current] = nil
			} else {
				current = "" // non-versioned path: ignore its methods.
			}
			continue
		}
		if current == "" {
			continue
		}
		if m := methodRe.FindStringSubmatch(line); m != nil {
			out[current] = append(out[current], m[1])
		}
	}
	// Stable order for reproducibility (the test doesn't depend on it,
	// but the log line does).
	for p := range out {
		sort.Strings(out[p])
	}
	return out, nil
}

// diff returns keys in a that are not in b.
func diff(a, b map[string]struct{}) map[string]struct{} {
	out := map[string]struct{}{}
	for k := range a {
		if _, ok := b[k]; !ok {
			out[k] = struct{}{}
		}
	}
	return out
}
