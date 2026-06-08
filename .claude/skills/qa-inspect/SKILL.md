---
name: qa-inspect
description: "KAMOS integration QA skill. Use this to verify boundaries between the Go API, the Flutter app, the PostgreSQL schema, the admin SPA, and the SPEC catalog invariants. Cross-checks API response shapes against Flutter models, ARB key parity across locales, Go Router paths against screen files, schema columns against Go json tags, and every catalog invariant relevant to the mode. Invoke whenever QA, integration check, spec compliance, boundary verification, or pre-merge validation is requested."
recommended_model:
  incremental-design: sonnet
  incremental-be: sonnet
  incremental-admin: sonnet
  incremental-fe: sonnet
  final: opus
---

# QA Inspect Skill

Verifies that the boundaries between layers connect correctly and that every relevant invariant in `.claude/invariants/` is enforced. The job is not to confirm pieces exist — it is to confirm they fit together and match the catalog.

## When to use this skill

- After designer completes a slice → `mode: incremental-design`
- After backend-engineer completes a module → `mode: incremental-be`
- After backend-engineer completes the admin slice → `mode: incremental-admin`
- After flutter-engineer completes a feature → `mode: incremental-fe`
- End-to-end before declaring a multi-layer change done → `mode: final`
- When `SPEC.md` changes → run the affected invariant subset via `spec-sweep`

Single-file or single-layer code-quality issues are not the right scope. Use `code-review` for pure-code review and the layer-specific skills for fixes.

## Modes

The orchestrator passes `mode` as a structured arg. Each mode owns a subset of catalog invariants and a subset of boundaries.

| Mode | Triggered by | Boundaries verified | Catalog invariants run |
|---|---|---|---|
| `incremental-design` | Designer completion in `kamos-build` Phase 1 | `design/HANDOFF.md` addendum internal consistency · JSX previews ↔ design tokens · category strings on screens that show them · rating widget granularity if any | category-strings, rating-scale (if shown) |
| `incremental-be` | [[protocol:BUILD-004]] | DB ↔ Go struct json tags · OpenAPI ↔ handler response · `design/HANDOFF.md` ↔ handler shape | jwt-storage, cursor-pagination, rating-scale, soft-delete, default-collections, i18n-fallback, checkin-caps, sanitize-text, search-bigm, username, pagination-size |
| `incremental-admin` | [[protocol:BUILD-005]] | Admin Go handlers ↔ `admin/src/` calls · CSRF + cookie flow | admin-auth, sanitize-text, soft-delete |
| `incremental-fe` | [[protocol:BUILD-007]] | OpenAPI ↔ Flutter repository parsing · go_router paths ↔ screen files · ARB key parity en/ja/ko | jwt-storage, cursor-pagination, category-strings, rating-scale, i18n-fallback, checkin-caps, username, pagination-size |
| `final` | Phase 4 of `kamos-build` | All of the above end-to-end | Every invariant in `.claude/invariants/` |

## Verification method — read both sides simultaneously

Every check opens both sides of an interface and compares them directly. Never check one side and infer the other.

| Boundary | Left (producer) | Right (consumer) |
|---|---|---|
| API → Flutter model | Go handler JSON response | Dart `fromJson` / `freezed` fields |
| DB → API | PostgreSQL columns + types | Go struct `json:"..."` tags + scan order |
| OpenAPI → Flutter | `openapi.yaml` schema | Dart model fields |
| Router → screen | `go_router` route paths | Screen file existence + `pathParameters` keys |
| i18n keys | `intl_en.arb` keys | `intl_ja.arb`, `intl_ko.arb` keys + widget `l10n.foo` references |
| Admin SPA → Go admin handler | `admin/src/` fetch wrapper | Cookie + CSRF middleware path |
| Catalog → code | `.claude/invariants/<id>.md` "Check" block | The greppable surface in `backend/`, `frontend/`, `admin/`, `migrations/` |

## Catalog-driven invariant checks

Each invariant in `.claude/invariants/` carries its own copy-pasteable `## Check` block. Run those — do not restate the rule here. The mode table above lists which invariants apply per mode.

For the `final` mode, run every invariant's Check block in turn and tally pass/fail in the report.

## Boundary check workflow

For each module under review:

1. **List the inputs and outputs.** What does this module produce, what does it consume?
2. **Open both sides.** For an API endpoint: open the Go handler and the Flutter repository function that calls it.
3. **Compare field-by-field.** Names, types, optional vs required, nesting depth.
4. **Run the catalog Check blocks** for the invariants assigned to the current mode.
5. **Test the unhappy paths.** Does the consumer handle the error responses the producer can return? 401? 404? 422?

## Output format

When invoked by `kamos-build`, the orchestrator scopes the report path to `docs/history/<NN>_<feature>/qa/qa_report_{mode-short}.md`. Direct invocation defaults to `docs/history/qa/qa_report_{module}.md`. Either way:

```markdown
# QA Report — {module or mode}
Date: {YYYY-MM-DD}
Mode: incremental-be | incremental-admin | incremental-fe | final
Scope: {files / endpoints / screens checked}
Status: PASS | PASS WITH MINOR | FAIL

## Catalog invariant pass table

| Invariant ID | Status | Notes |
|---|---|---|
| [[invariant:jwt-storage]] | PASS / FAIL | ... |
| [[invariant:cursor-pagination]] | PASS / FAIL | ... |
| ... | ... | ... |

## Issue: {short title}
- ID: QA-NNN (assigned by this report, used in [[protocol:BUILD-008]] / BUILD-009)
- Severity: BLOCKER | MAJOR | MINOR
- Invariant: [[invariant:<id>]] (if applicable)
- Boundary: {left file:line} ↔ {right file:line}
- Problem: {what is wrong, observably}
- Fix: {specific action — name the responsible agent}

## Issue: ...
```

For the `final` mode, the report must include a PASS/FAIL summary at the top before the invariant table.

## Severity + routing

See [[protocol:build-pipeline]] "Severity → routing". Summary:

| Severity | Routing | Phase impact |
|---|---|---|
| BLOCKER | [[protocol:BUILD-008]] to implementer; QA re-verifies | Halts dependent task |
| MAJOR | [[protocol:BUILD-008]] to implementer; QA re-verifies | Does not halt; before phase end |
| MINOR | File in report; append to `docs/backlog.md` | Swept at end of phase |

Responsible-agent map:

| Boundary or invariant | Owner |
|---|---|
| API response shape | backend-engineer |
| Schema column type / constraint | db-architect |
| Flutter model parsing / ARB key | flutter-engineer |
| Wireframe / spec ambiguity | designer |
| Admin React surface / CSRF flow | backend-engineer (admin slice) |
| Two layers disagree, SPEC silent | flag orchestrator per [[protocol:BUILD-012]]; do not pick a side |

When SendMessage-ing fixes, follow [[protocol:BUILD-008]] payload format: severity, finding ID, file:line, exact change. No vague "fix the rating field" — write `backend/internal/handlers/checkins.go:142: change rating type from int to float64 to match [[invariant:rating-scale]]`.

## Re-verification

On [[protocol:BUILD-009]] from the implementer:

1. Re-read the cited file:line.
2. Confirm the fix matches what was requested in BUILD-008.
3. Re-run the relevant catalog Check block.
4. Mark resolved in the report only after re-verification passes.

## Relationship to code-review

This skill owns catalog invariants. `code-review` owns code-internal quality (architecture, OWASP-beyond-catalog, perf-beyond-catalog, style). They do not overlap on catalog invariants — if security-review trips on `[[invariant:jwt-storage]]`, it cross-references this skill instead of issuing a fresh CRITICAL.

## What this skill is not

- **Not unit testing.** Unit tests are the engineer's job. This skill checks that the layers agree, not that any one layer is correct in isolation.
- **Not a free code review.** Use `code-review` for that — see "Relationship to code-review".
- **Not deploy verification.** Use `verify-gates` to run the verification matrix from CLAUDE.md (Go build, flutter analyze, smoke, etc.) at end of phase.
