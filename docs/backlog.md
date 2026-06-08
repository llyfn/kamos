# Backlog — deferred MINOR findings

Single, append-only list of MINOR findings that QA or code-review deferred during a phase. Items here are picked up at end-of-phase MINOR sweep (kamos-build) or whenever a follow-up touches the affected file.

## Format

Each line is one finding:

```
- [MINOR-NNN] <YYYY-MM-DD> <file:line> — <one-line title>
  Source: <feature dir or review report path>
  Owner: <agent name>
  Notes: <optional context>
```

Numbering: `MINOR-001`, `MINOR-002`, etc. Never reuse a number, even after the finding is resolved — strike-through resolved lines and keep them for history.

## Resolution

When applied:

1. Strike-through the line: `- ~~[MINOR-NNN] ...~~ resolved YYYY-MM-DD in <commit>`.
2. If the resolution required new MINOR findings, add them with new numbers.
3. Do not delete entries. The backlog is the historical record.

## Sweep policy

Per the `feedback_post_phase_minor_sweep` memory:

- After every phase's final `PASS` (or `PASS WITH MINOR`), review the cumulative QA reports and this backlog.
- Apply MINOR fixes that are low-effort, low-risk, and a clear win (typos in error messages, missing comments per CLAUDE.md policy, redundant null checks, etc.).
- Explicitly defer judgment-call MINORs to the next sweep with a note in the phase's brief.

This is a memory-driven preference. Do not skip it.

## Open

<!-- New MINOR findings get appended here. The validator does NOT fail on an empty backlog. -->
