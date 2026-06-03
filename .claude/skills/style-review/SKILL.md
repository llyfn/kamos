---
name: style-review
description: "Code style and maintainability review skill for KAMOS. Checks naming, dead code, error handling completeness, test coverage gaps, magic values, and consistency. Use when reviewing readability, technical debt, or maintainability. Triggers: style review, maintainability, naming, error handling, code smell, refactor candidate."
---

# Style Review Skill

Reviews code for long-term maintainability — what linters miss. Focus on patterns that confuse the next engineer or hide bugs.

## High-value greps

```bash
# Swallowed errors (Go)
grep -rn "_\s*=\s*err\|_,\s*_\s*=" backend/ --include="*.go" | grep -v "_test.go"

# Bare returns / unreturned errors
grep -rn "return$\|return nil$" backend/ --include="*.go" | head -50

# TODO / FIXME without an issue link
grep -rn "TODO\|FIXME\|HACK\|XXX" . | grep -v "TODO(#[0-9]\|TODO: SPEC §"

# Hardcoded magic numbers (Go) — exclude obvious time / hex / 0 / 1
grep -rn "[^a-zA-Z_][0-9]\{2,\}[^0-9]" backend/ --include="*.go" | grep -v "_test.go\|0x\|//\|time\."

# Flutter: hardcoded colors / sizes
grep -rn "Color(0x\|Colors\." frontend/lib/ | grep -v "theme\|Theme\|AppColors"
grep -rn "fontSize:\s*[0-9]" frontend/lib/ | grep -v "theme"

# Flutter: print() left in
grep -rn "print(" frontend/lib/ --include="*.dart"

# Flutter: null assertion without justification
grep -rn "!\." frontend/lib/ --include="*.dart" | grep -v "// safe:\|// l10n:"

# Hardcoded display strings (Flutter) — should be l10n
grep -rn "Text(['\"]" frontend/lib/ --include="*.dart" | grep -v "l10n\.\|AppLocalizations"
```

## Error handling audit (Go)

For every function that returns `error`:

1. Every caller checks the error
2. Errors are wrapped with context: `fmt.Errorf("FuncName: %w", err)`
3. Sentinel errors used for known cases (`apierror.ErrNotFound`, etc.)
4. Errors are not double-logged (logged once at the boundary that handles them)

Bad pattern:

```go
user, _ := repo.GetUser(ctx, id)  // silent failure
```

Good pattern:

```go
user, err := repo.GetUser(ctx, id)
if err != nil {
    if errors.Is(err, apierror.ErrNotFound) {
        respondError(w, 404, "user not found")
        return
    }
    return fmt.Errorf("GetUser(%s): %w", id, err)
}
```

## Naming

**Go:**
- Exported: `PascalCase`; unexported: `camelCase`
- Acronyms keep case: `userID` not `userId`; `httpClient` not `HttpClient`; consistency across the codebase
- Receivers: 1–2 letter abbreviation matching the type, consistent across all methods of that type (if `(r *CheckinRepo)` somewhere, never `(repo *CheckinRepo)` elsewhere)
- Avoid `Manager`, `Helper`, `Util` suffixes without specific justification

**Dart / Flutter:**
- Screens: `*Screen` suffix (`FeedScreen`)
- Reusable widgets: descriptive noun (`BeverageCard`, `RatingStarRow`) — not `*Widget`
- Providers: `*Provider` (function/value) or `*Controller`/`*Notifier` (class)
- Models: plain noun (`Beverage`, `Checkin`) — not `*Model` or `*Dto`
- Files: snake_case to match lib convention

## KAMOS-specific consistency

Look for the same operation done differently in different files:

- Error response shape: should always be `{ "error": "...", "code": "..." }` — flag any handler returning a different shape
- Cursor encoding: should always go through `pkg/cursor` — flag any handler that builds a cursor inline
- i18n fallback: should always go through one helper — flag inline fallback logic
- Star rating widget: should be one widget — flag any screen rolling its own
- Default Inventory + Wishlist creation: must be one service function — flag duplicated logic between email and Google registration handlers

## Test coverage gaps

Flag untested:

- Auth boundary — request to a protected endpoint without `Authorization` header
- IDOR — request to another user's resource as an authenticated non-owner
- Empty list — does the handler return `{ items: [], next_cursor: null, has_more: false }` not `null` or `[]`
- Validation — does each `422` path have a test
- Concurrent: duplicate check-in submission, duplicate follow request, duplicate toast
- i18n fallback: beverage with `name_i18n.ko = null` rendered with `ko` locale

## Documentation

- Every exported Go function has a doc comment starting with the function name
- Every public Dart class member has a `///` doc comment
- Complex algorithms (cursor decode, star tap mapping, follow request approval) have an explanatory comment block
- `TODO` comments include either an issue link `TODO(#42)` or a SPEC reference `TODO: SPEC §5.4`

## Magic values

- Numbers: `20` (page size), `4` (photo cap), `500` (review cap), `30` (username hold days), `24` (verification ttl hours) — should be named constants in a `const` block or `Config` field
- Strings: enum-like values (`'inventory'`, `'wishlist'`, `'on_premise'`, etc.) — should be defined as constants once

## Severity guide

| Severity | Meaning |
|---|---|
| MEDIUM | Causes maintenance friction or hides real bugs |
| LOW | Cosmetic |
| SUGGESTION | Pattern that could be standardized; no urgency |

Style reviewer does **not** issue HIGH or CRITICAL — those severities are reserved for arch / security / perf.

## Output format

Write to `docs/history/review/style_findings.md` with `[STYLE-NNN]` numbering. For findings that recur in many locations, report the pattern once with one representative example, then list the remaining locations as a bullet list — don't write a full entry per occurrence.

```markdown
## [STYLE-NNN] Short title
- Severity: MEDIUM | LOW | SUGGESTION
- Location: file:line (or "pattern across files — see list below")
- Finding: what the issue is
- Fix: specific change or pattern to apply consistently

(If pattern across files:)
Affected locations:
- backend/internal/handlers/auth.go:42
- backend/internal/handlers/users.go:108
- ...
```

## Cross-domain SendMessage

- If a style issue indicates a structural problem (e.g., duplicated error handling because there's no central error helper) → SendMessage `arch-reviewer`
- If an error-handling gap could mask a security issue (swallowed auth error, ignored validation error on a sensitive endpoint) → SendMessage `security-reviewer`
- Receive incoming SendMessage from other reviewers about style issues they noticed in passing

## Prioritization

When the codebase is large, prioritize:

1. Files in auth / user / check-in flows (most-touched, most-sensitive)
2. Handler and repository files (most callsites)
3. Everything else

Report patterns first, individual instances second.
