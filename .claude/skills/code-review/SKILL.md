---
name: code-review
description: "Code review orchestrator. Runs four parallel reviewer agents (architecture, security, performance, style) and merges all findings into a single prioritized report. Use when asked to review code, audit the codebase, or run a code review — including partial scopes like a single file, a directory, or a PR diff. For pure SPEC compliance / boundary checks use the qa-inspect skill instead."
recommended_model: opus
---

# Code Review Orchestrator

Coordinates four parallel specialist reviewers and synthesizes their findings into one actionable report.

## Execution mode: agent team (fan-out / fan-in)

## Agent roster

| Reviewer | Subagent type | Domain | Skill | Output |
|---|---|---|---|---|
| arch-reviewer | `arch-reviewer` | Architecture & structure | `arch-review` | `docs/history/review/arch_findings.md` |
| security-reviewer | `security-reviewer` | OWASP & auth | `security-review` | `docs/history/review/security_findings.md` |
| perf-reviewer | `perf-reviewer` | Performance & scalability | `perf-review` | `docs/history/review/perf_findings.md` |
| style-reviewer | `style-reviewer` | Maintainability | `style-review` | `docs/history/review/style_findings.md` |

## Relationship to qa-inspect

`code-review` and `qa-inspect` have a single clean boundary:

- **qa-inspect owns SPEC catalog invariants** (`.claude/invariants/*.md`). If a layer violates `[[invariant:jwt-storage]]`, `[[invariant:cursor-pagination]]`, or any other catalog rule, the finding lives in a qa-inspect report — not here.
- **code-review owns code-internal quality** beyond the catalog: architecture (layer separation, dependency direction, coupling), OWASP-Top-10 vulnerabilities not codified as invariants (e.g. a new injection vector), performance (N+1, missing index strategies not yet baked into a catalog invariant), and style (naming, error handling, dead code, magic values).

If a reviewer trips on a catalog invariant during code-review, the protocol is to **cross-reference** the qa-inspect concern in the finding (`see [[invariant:<id>]] — owned by qa-inspect`) rather than file a redundant finding here. The cross-reference is a hint to the orchestrator that the qa-inspect path should already have caught it; if it didn't, that's a qa-inspect gap to flag.

In practice: run both for any multi-layer change. They cover disjoint surfaces by design.

## Workflow

### Phase 1 — scope

1. Determine review scope from the user's request:
   - **Full codebase** — everything under `backend/`, `frontend/`, `lib/`, `migrations/`
   - **Specific path** — only the named directory or files
   - **PR diff** — only the changed files (user provides the list or a git ref)
2. Ensure `docs/history/review/` exists.
3. Write `docs/history/review/00_scope.md`:
   ```
   Scope: full | path | diff
   Target: {path or file list}
   Date: {YYYY-MM-DD}
   Stack: Go + Flutter + PostgreSQL
   ```

### Phase 2 — parallel review (team)

`TeamCreate(team_name: "review-team", ...)` with four members spawned from:

- arch-reviewer — [prompts/arch-reviewer.md](prompts/arch-reviewer.md)
- security-reviewer — [prompts/security-reviewer.md](prompts/security-reviewer.md)
- perf-reviewer — [prompts/perf-reviewer.md](prompts/perf-reviewer.md)
- style-reviewer — [prompts/style-reviewer.md](prompts/style-reviewer.md)

Models come from each reviewer's SKILL.md `recommended_model`.

```
TaskCreate(tasks: [
  { title: "Architecture review", assignee: "arch-reviewer" },
  { title: "Security review",     assignee: "security-reviewer" },
  { title: "Performance review",  assignee: "perf-reviewer" },
  { title: "Style review",        assignee: "style-reviewer" }
])
```

All four run concurrently. Reviewers SendMessage each other for cross-domain findings; this skill (the leader) does not intermediate live, but tracks cross-references during synthesis.

### Phase 3 — synthesis

When all four tasks are `completed`:

1. `TeamDelete("review-team")`
2. Read all four findings files.
3. Build a cross-reference map: any finding cited at the same `file:line` by two reviewers is a cross-domain finding.
4. Write `docs/history/review/REVIEW_REPORT.md`.

## Consolidated report format

```markdown
# Code Review Report
Date: {date}
Scope: {scope}
Reviewers: arch · security · perf · style

## Executive Summary

| Domain | CRITICAL | HIGH | MEDIUM | LOW |
|---|---|---|---|---|
| Architecture | N | N | N | N |
| Security | N | N | N | N |
| Performance | N | N | N | N |
| Style | — | N | N | N |
| **Total** | **N** | **N** | **N** | **N** |

**Must-fix before merge:** {list of CRITICAL + HIGH finding IDs}

## Critical & High Priority

(All CRITICAL and HIGH findings, sorted by severity. Cross-domain findings annotated `[Cross-domain: SEC-NNN ↔ ARCH-NNN]`.)

## Medium Priority

(All MEDIUM findings, grouped by domain.)

## Low Priority & Suggestions

(All LOW and SUGGESTION findings, grouped by domain.)

## Cross-Domain Findings

(One section per file:line cited by two or more reviewers. Explain how the angles connect.)

## Recommended Fix Order

1. {CRITICAL items — file:line}
2. {HIGH security items}
3. {HIGH architecture items that block other fixes}
4. {HIGH perf items}
5. {MEDIUM items by effort/impact ratio}

## Full Findings

- Architecture: `docs/history/review/arch_findings.md`
- Security: `docs/history/review/security_findings.md`
- Performance: `docs/history/review/perf_findings.md`
- Style: `docs/history/review/style_findings.md`
```

## Severity normalization

See [[protocol:review-fanout]] "Severity normalization" — the contract defines per-domain severity caps and the cross-domain dedup rule. Summary: style is capped at MEDIUM, only security may issue CRITICAL, higher severity wins on disagreement.

## Cross-domain dedup

A finding is "cross-domain" when:

- Two reviewers cite the same `file:line` (or the same function/struct), OR
- A SendMessage between reviewers references the same finding ID (record this from the findings files — reviewers should mention the cross-reference in their own write-up)

Merge into one entry in the report; don't double-count in the executive summary table (count it once under the higher-severity domain).

## Data flow

```
00_scope.md
    │
    ▼
┌────────────────────────────────────┐
│       review-team (parallel)       │
│  arch ←─SendMessage─→ security     │
│   ↕                       ↕        │
│  perf ←─SendMessage─→ style        │
└────────────────────────────────────┘
    │       │       │       │
    ▼       ▼       ▼       ▼
  arch_  security_ perf_  style_
findings findings findings findings
    │       │       │       │
    └───────┴───────┴───────┘
              │
              ▼
       REVIEW_REPORT.md
```

## Error handling

| Situation | Action |
|---|---|
| One reviewer produces empty findings | Include "No findings in this domain" section; don't skip the domain |
| One reviewer fails to complete | Note in report: "{domain} review incomplete — re-run with `/code-review {path}`" |
| Two reviewers report conflicting severity | Use higher severity, note discrepancy |
| Scope very large (>100 files) | Each reviewer narrows: security → auth/handlers, perf → queries/lists, arch → entry points + interfaces, style → most-called modules. Document the narrowing in `00_scope.md`. |
| User wants quick review only | Skip team mode; run a single reviewer chosen by the user request (`security-review`, etc.) directly without spawning a team |

## Test scenarios

### Normal flow

1. User: "review the backend code"
2. Scope written: `backend/`, Go stack
3. 4 reviewers run; security flags an auth-handler issue and SendMessages arch-reviewer; arch confirms a layer violation at the same file:line
4. All 4 complete; leader cross-references the shared finding
5. `REVIEW_REPORT.md` produced: 1 CRITICAL (IDOR), 2 HIGH, 5 MEDIUM, 8 LOW
6. Recommended fix order presented

### Error flow

1. perf-reviewer fails partway through a large codebase
2. Leader detects via `TaskGet` (others completed, perf in-progress past timeout)
3. SendMessage perf-reviewer for status; no response in 2 rounds
4. Leader writes report with 3 complete domains and a perf section saying "Performance review incomplete for `internal/handlers/feed.go` and downstream — re-run scoped review"
