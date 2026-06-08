---
name: qa-inspect
description: "KAMOS integration QA skill. Use this to verify boundaries between the Go API, the Flutter app, the PostgreSQL schema, and the SPEC. Cross-checks API response shapes against Flutter models, ARB key parity across locales, Go Router paths against screen files, schema columns against Go json tags, and SPEC invariants (category strings, rating scale, cursor pagination, secure JWT storage). Invoke whenever QA, integration check, spec compliance, boundary verification, or pre-merge validation is requested."
recommended_model:
  incremental-be: sonnet
  incremental-admin: sonnet
  incremental-fe: sonnet
  final: opus
---

# QA Inspect Skill

Verifies that the boundaries between layers connect correctly. The job is not to confirm pieces exist — it is to confirm they fit together and match `SPEC.md`.

## When to use this skill

Use this skill when a layer or feature is complete and needs cross-layer verification:

- After backend-engineer completes a module → check API response shapes vs. `backend/openapi.yaml` and DB columns
- After flutter-engineer completes a feature → check Flutter models vs. `openapi.yaml`, router paths vs. screen files, ARB key parity
- Before merging multi-layer changes → run all checks below
- When `SPEC.md` is updated → audit every layer against the new invariants

Single-file or single-layer bugs are not the right scope for this skill. Use `code-review` for pure-code review and the layer-specific skills for fixes.

## Verification method — read both sides simultaneously

Every check opens both sides of an interface and compares them directly. Never check one side and infer the other.

| Boundary | Left (producer) | Right (consumer) |
|---|---|---|
| API → Flutter model | Go handler JSON response | Dart `fromJson` / `freezed` fields |
| DB → API | PostgreSQL columns + types | Go struct `json:"..."` tags + scan order |
| OpenAPI → Flutter | `openapi.yaml` schema | Dart model fields |
| Router → screen | `go_router` route paths | Screen file existence + `pathParameters` keys |
| i18n keys | `app_en.arb` keys | `app_ja.arb`, `app_ko.arb` keys + widget `l10n.foo` references |
| SPEC → impl | `SPEC.md` invariant | Code that should reflect it |

## SPEC invariant checks

These are the most common breakage points. Verify each one explicitly per session, not by sampling:

### Category terminology (`SPEC §2.1`, `§8`)

The strings in UI must match these exactly. Grep across all three ARB files and any hardcoded UI strings:

```bash
grep -rn "Nihonshu\|Shochu\|Liqueur\|Sake" lib/ | grep -v ".arb"
grep -rn "日本酒\|焼酎\|リキュール" lib/ | grep -v ".arb"
grep -rn "니혼슈\|쇼츄\|리큐어" lib/ | grep -v ".arb"
```

Any hardcoded match outside ARB files → BLOCKER.

In `app_en.arb`, `Sake` alone (without `Nihonshu (Sake)`) → BLOCKER.

### Rating scale (`SPEC §4.2`)

- DB: column type is `NUMERIC(3,1)` with `CHECK (rating >= 0.5 AND rating <= 5.0)`
- Go: model field type is a numeric type that preserves one decimal (e.g., `decimal.Decimal` or `float64`); JSON tag emits the value with one decimal place
- OpenAPI: `format: float` or `type: number, multipleOf: 0.5`
- Flutter: model field is `double`; star widget renders 0.5 increments (10 levels), not 0.25 (Untappd) and not integer

### Cursor pagination (`SPEC §5.2`)

Every list endpoint:

```bash
# Go: response shape
grep -rn "next_cursor\|NextCursor" backend/internal/handlers/
# Should appear for: /feed, /beverages, /producers (list), /checkins/by-user, etc.

# OpenAPI
grep -n "next_cursor\|has_more" openapi.yaml

# Flutter
grep -rn "nextCursor\|next_cursor" frontend/lib/ | grep repository
```

Any list endpoint missing `next_cursor` and `has_more` in the response → BLOCKER.

Any Flutter repository using `offset` / `page` parameters → BLOCKER.

### JWT storage (`SPEC §3.1`, security policy)

```bash
grep -rn "SharedPreferences" frontend/lib/ | grep -i "token\|jwt\|auth"
```

Any match → CRITICAL. JWT must use `flutter_secure_storage`.

### Soft-delete (`SPEC §3.3`, `§4.4`)

- Tables that need `deleted_at TIMESTAMPTZ`: `users`, `check_ins`, `collections`
- Every list query against these tables must filter `WHERE deleted_at IS NULL`
- Account deletion must hold the username for 30 days before release — verify via the deletion handler logic, not just the schema

### Default collections (`SPEC §6.1`)

User registration must create `Inventory` and `Wishlist` collections atomically with the user record. Verify in the registration handler — both for email/password and Google OAuth paths.

### i18n fallback (`SPEC §8`)

When a beverage's `name_i18n` is missing the user's locale, the API or the Flutter rendering layer must fall back to `en`. Verify the fallback exists at exactly one layer (preferably API), not zero and not both.

### Photos cap (`SPEC §4.1`)

Check-in handler must reject more than 4 photos. Flutter check-in form must prevent selecting more than 4. Both sides → MAJOR if either is missing.

### Review text cap (`SPEC §4.1`)

Check-in `review_text` ≤ 500 chars. DB constraint, Go validation, Flutter `maxLength` — all three.

## Boundary check workflow

For each module under review:

1. **List the inputs and outputs.** What does this module produce, what does it consume?
2. **Open both sides.** For an API endpoint: open the Go handler and the Flutter repository function that calls it.
3. **Compare field-by-field.** Names, types, optional vs required, nesting depth.
4. **Run the SPEC invariant grep.** Spot-check the most-violated invariants.
5. **Test the unhappy paths.** Does the consumer handle the error responses the producer can return? 401? 404? 422?

## Output format

Default path: `docs/history/qa/qa_report_{module}.md`. When invoked by `kamos-build`, the orchestrator overrides this to `docs/history/<NN>_<feature>/qa/qa_report_{slice}.md` so each feature's QA reports group together. Either way, the file template is:

```markdown
# QA Report — {module}
Date: {YYYY-MM-DD}
Scope: {files / endpoints / screens checked}
Status: PASS | PASS WITH MINOR | FAIL

## Issue: {short title}
- Severity: BLOCKER | MAJOR | MINOR
- Boundary: {left file:line} ↔ {right file:line}
- SPEC reference: §{N} (if applicable)
- Problem: {what is wrong, observably}
- Fix: {specific action — name the responsible agent}

## Issue: ...
```

Final consolidated report goes to `docs/history/qa/qa_report_final.md` and must include a PASS/FAIL summary at the top.

## Severity guide

| Severity | Meaning |
|---|---|
| BLOCKER | SPEC invariant violated, or layer-to-layer mismatch that breaks the feature. Cannot ship. |
| MAJOR | Feature works but is incorrect for some inputs / locales. Must fix before merge. |
| MINOR | Cosmetic, edge case, or doc gap. File and continue. |

## Routing the fix

For each finding, name the agent who owns the fix:

- API response shape wrong → `backend-engineer`
- Schema column type wrong → `db-architect`
- Flutter model parsing wrong → `flutter-engineer`
- ARB key missing in one locale → `flutter-engineer`
- Wireframe/spec ambiguity → `designer`
- Two layers disagree on the contract and the spec is silent → flag to orchestrator; do not pick a side

When SendMessage-ing fixes, include the file path, line number, and exact change. Do not say "fix the rating field" — say `backend/internal/handlers/checkins.go:142: change rating type from int to float64 to match SPEC §4.2`.

## Re-verification

After a fix is reported:

1. Re-read the specific file:line from the original finding.
2. Confirm the fix matches what was requested.
3. Run the relevant grep/check from this skill again to ensure no regression.
4. Mark the issue resolved in the report only after re-verification.

## What this skill is not

- **Not unit testing.** Unit tests are the engineer's job. This skill checks that the layers agree, not that any one layer is correct in isolation.
- **Not code style.** Use `code-review` for that. A handler can be ugly Go code and still pass QA if the boundary is correct.
- **Not security audit.** Use `security-review` for OWASP-level vulnerabilities. The only security check here is JWT storage, because it's a SPEC-level invariant.
- **Not performance.** Use `perf-review`. The only perf check here is cursor pagination, again because it's a SPEC-level invariant.
