---
name: code-review
description: "Comprehensive code review orchestrator. Runs four parallel reviewer agents (architecture, security, performance, style) and merges all findings into a single prioritized report. Use this skill whenever asked to review code, audit the codebase, check for issues, or run a code review — even for partial scopes like a single file or PR diff."
---

# Code Review Orchestrator

Coordinates four parallel specialist reviewers and synthesizes their findings into one actionable report.

## Execution Mode: Agent Team (Fan-out/Fan-in)

## Agent Roster

| Reviewer | Type | Domain | Skill | Output |
|----------|------|--------|-------|--------|
| arch-reviewer | custom | Architecture & structure | arch-review | `_workspace/review/arch_findings.md` |
| security-reviewer | custom | Security vulnerabilities | security-review | `_workspace/review/security_findings.md` |
| perf-reviewer | custom | Performance bottlenecks | perf-review | `_workspace/review/perf_findings.md` |
| style-reviewer | custom | Style & maintainability | style-review | `_workspace/review/style_findings.md` |

## Workflow

### Phase 1: Scope

1. Determine review scope from the user's request:
   - **Full codebase**: review everything under `backend/`, `frontend/`, `lib/`, `migrations/`
   - **Specific path**: review only the specified directory or file(s)
   - **PR diff**: review only changed files (list provided by user)
2. Create `_workspace/review/` directory
3. Write `_workspace/review/00_scope.md`:
   ```
   Scope: {full | path | diff}
   Target: {path or file list}
   Date: {today}
   Stack: {detected stack — e.g., Go + Flutter + PostgreSQL}
   ```

### Phase 2: Parallel Review — Agent Team

```
TeamCreate(
  team_name: "review-team",
  members: [
    {
      name: "arch-reviewer",
      agent_type: "arch-reviewer",
      model: "opus",
      prompt: "Read _workspace/review/00_scope.md for the review scope. Use the arch-review skill to review the codebase for architectural issues. Write findings to _workspace/review/arch_findings.md. When you find an issue that may also be a security concern, SendMessage to security-reviewer. When done, TaskUpdate your task to completed."
    },
    {
      name: "security-reviewer",
      agent_type: "security-reviewer",
      model: "opus",
      prompt: "Read _workspace/review/00_scope.md for the review scope. Use the security-review skill to audit the codebase for vulnerabilities. Write findings to _workspace/review/security_findings.md. When you find a vulnerability rooted in architecture, SendMessage to arch-reviewer. When done, TaskUpdate your task to completed."
    },
    {
      name: "perf-reviewer",
      agent_type: "perf-reviewer",
      model: "opus",
      prompt: "Read _workspace/review/00_scope.md for the review scope. Use the perf-review skill to find performance bottlenecks. Write findings to _workspace/review/perf_findings.md. If a bottleneck has a security implication (e.g., no rate limiting enabling DoS), SendMessage to security-reviewer. When done, TaskUpdate your task to completed."
    },
    {
      name: "style-reviewer",
      agent_type: "style-reviewer",
      model: "opus",
      prompt: "Read _workspace/review/00_scope.md for the review scope. Use the style-review skill to review code quality and maintainability. Write findings to _workspace/review/style_findings.md. When a style issue masks a deeper structural problem, SendMessage to arch-reviewer. When done, TaskUpdate your task to completed."
    }
  ]
)
```

Register tasks:
```
TaskCreate(tasks: [
  { title: "Architecture review", assignee: "arch-reviewer" },
  { title: "Security review", assignee: "security-reviewer" },
  { title: "Performance review", assignee: "perf-reviewer" },
  { title: "Style review", assignee: "style-reviewer" }
])
```

All four run concurrently. Reviewers communicate directly via SendMessage for cross-domain findings — the leader monitors but does not intermediate.

### Phase 3: Synthesis

After all four tasks complete (monitor via TaskGet):
1. TeamDelete("review-team")
2. Read all four findings files
3. Write the consolidated report

## Consolidated Report Format

Output: `_workspace/review/REVIEW_REPORT.md`

```markdown
# Code Review Report
Date: {date}
Scope: {scope}
Reviewers: arch-reviewer · security-reviewer · perf-reviewer · style-reviewer

---

## Executive Summary

| Domain | CRITICAL | HIGH | MEDIUM | LOW |
|--------|----------|------|--------|-----|
| Architecture | N | N | N | N |
| Security | N | N | N | N |
| Performance | N | N | N | N |
| Style | N | N | N | N |
| **Total** | **N** | **N** | **N** | **N** |

**Must-fix before merge:** {list CRITICAL + HIGH finding IDs}

---

## Critical & High Priority Findings

{All CRITICAL and HIGH findings from all four reviewers, sorted by severity.
 Cross-domain findings (where reviewers flagged each other) are annotated with "[Cross-domain]".}

---

## Medium Priority Findings

{All MEDIUM findings, grouped by domain.}

---

## Low Priority & Suggestions

{All LOW and SUGGESTION findings, grouped by domain.}

---

## Cross-Domain Findings

{Findings where two reviewers identified the same root cause from different angles.
 List the finding IDs and explain the connection.}

---

## Recommended Fix Order

1. {CRITICAL items — specific file:line}
2. {HIGH security items}
3. {HIGH architecture items that block other fixes}
4. {HIGH performance items}
5. {MEDIUM items by effort/impact ratio}

---

## Full Findings Reference

- Architecture: see `_workspace/review/arch_findings.md`
- Security: see `_workspace/review/security_findings.md`
- Performance: see `_workspace/review/perf_findings.md`
- Style: see `_workspace/review/style_findings.md`
```

## Cross-Domain Deduplication

Before writing the consolidated report, identify findings from different reviewers that describe the same root cause:
- Same file + line cited by two reviewers → merge into one cross-domain finding
- SendMessage pattern between reviewers recorded in `_workspace/review/00_scope.md` → include in Cross-Domain section

## Data Flow

```
_workspace/review/00_scope.md
         │
         ▼
┌─────────────────────────────────────────┐
│         review-team (parallel)          │
│  arch ←─SendMessage─→ security          │
│   ↕                       ↕             │
│  perf ←─SendMessage─→ style             │
└─────────────────────────────────────────┘
         │        │        │        │
         ▼        ▼        ▼        ▼
      arch_    security_ perf_   style_
    findings  findings findings findings
         │        │        │        │
         └────────┴────────┴────────┘
                       │
                       ▼
               REVIEW_REPORT.md
```

## Error Handling

| Situation | Action |
|-----------|--------|
| One reviewer produces empty findings | Include "No findings in this domain" section; do not skip the domain |
| One reviewer fails to complete | Note in report: "{domain} review incomplete — re-run with `/code-review {path}`" |
| Two reviewers report conflicting severity for same finding | Use the higher severity; note the discrepancy |
| Scope is very large (>100 files) | Each reviewer focuses on files most relevant to their domain: security→auth/handlers, perf→queries/lists, arch→entry points + interfaces, style→most-called modules |

## Test Scenarios

### Normal Flow
1. User: "review the backend code"
2. Scope written: `backend/` directory, Go stack detected
3. 4 reviewers run in parallel; security flags auth handler to arch; arch confirms layer violation
4. All 4 complete; leader reads findings, cross-references the shared finding
5. `REVIEW_REPORT.md` produced with 1 CRITICAL (IDOR), 2 HIGH, 5 MEDIUM, 8 LOW
6. Recommended fix order presented

### Error Flow
1. `perf-reviewer` fails mid-run due to large codebase
2. Leader detects task stuck (TaskGet shows in-progress after others complete)
3. SendMessage to perf-reviewer: status check
4. No response after 2 rounds → note in report: "Performance review incomplete for `internal/handler/feed.go` and downstream — re-run scoped review"
5. Report generated with 3 complete domains
