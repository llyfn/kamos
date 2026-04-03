---
name: style-review
description: "Code style and maintainability review skill. Checks naming, dead code, error handling completeness, test coverage gaps, magic values, and consistency. Use when reviewing code quality, readability, or technical debt."
---

# Style Review Skill

Reviews code for long-term maintainability — what linters miss.

## High-Value Grep Patterns

```bash
# Swallowed errors (Go)
grep -rn "_ = err\|_, _ =" . --include="*.go" | grep -v "_test.go"

# Naked returns / missing error propagation
grep -rn "return$\|return nil$" . --include="*.go" | head -30

# TODO/FIXME without issue reference
grep -rn "TODO\|FIXME\|HACK\|XXX" . | grep -v "TODO(#[0-9]"

# Hardcoded magic numbers (Go)
grep -rn "[^a-zA-Z][0-9]\{2,\}[^0-9]" . --include="*.go" | grep -v "test\|_test\|0x\|//\|time\."

# Flutter: hardcoded colors
grep -rn "Color(0x\|Colors\." lib/ | grep -v "theme\|Theme\|AppColors"

# Flutter: print() left in
grep -rn "print(" lib/ --include="*.dart"

# Flutter: null assertions without comment
grep -rn "!\." lib/ --include="*.dart" | grep -v "// safe:"
```

## Error Handling Audit (Go)

For every function that returns `error`:
1. Is the error checked by every caller?
2. Is the error wrapped with context? (`fmt.Errorf("funcName: %w", err)`)
3. Is a useful message logged before swallowing? (logging + returning nil is acceptable if intentional)

**Bad pattern:**
```go
user, _ := repo.GetUser(ctx, id)  // silent failure
```

**Good pattern:**
```go
user, err := repo.GetUser(ctx, id)
if err != nil {
    return fmt.Errorf("GetUser(%s): %w", id, err)
}
```

## Naming Checklist

**Go:**
- Exported types: PascalCase; unexported: camelCase
- Acronyms: `userID` not `userId`; `httpClient` not `httpClient` — consistent throughout
- Receivers: 1-2 letter abbreviation of type name, consistent across all methods of that type
- No `Manager`, `Handler`, `Helper` suffixes without clear justification

**Dart/Flutter:**
- Screens: `*Screen` suffix (e.g., `FeedScreen`)
- Reusable widgets: descriptive noun (e.g., `BeverageCard`, `RatingStarRow`)
- Providers: `*Provider` or `*Notifier` suffix
- Models: plain noun (e.g., `Beverage`, `CheckIn`)

## Test Coverage Gaps

Flag untested cases for:
- Auth boundary: unauthenticated request to protected endpoint
- Empty collection: what happens when a list query returns 0 rows?
- Concurrent writes: does the check-in endpoint handle duplicate submission?
- Validation errors: are 400 responses tested, not just 200?

## Consistency Patterns

Look for the same operation done differently in different files — pick the better pattern, flag both locations, suggest standardizing.

Examples:
- Error response format: `{"error": "..."}` in one handler, `{"message": "..."}` in another
- Config access: direct `os.Getenv()` in some places, `cfg.Field` in others
- Widget error states: custom error widget in some screens, empty `Container()` in others

## Output

Write to `_workspace/review/style_findings.md` with `[STYLE-NNN]` numbering. For findings that appear in many locations, report the pattern once with a representative example rather than listing every instance.
