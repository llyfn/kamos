---
name: kamos-build
description: "KAMOS feature-build orchestrator. Coordinates designer, db-architect, backend-engineer, flutter-engineer, and qa-inspector through a vertical-slice pipeline for one multi-layer feature: design → schema + API (+ admin) → Flutter → final QA. Per-layer QA fires the moment each implementer reports completion. Use when a request touches ≥2 of: design, schema, API, admin, Flutter, i18n. Do NOT use for single-layer work — invoke the relevant per-layer skill (go-api, flutter-feature, db-schema, design-wireframe) directly."
recommended_model: opus
---

# KAMOS Feature-Build Orchestrator

Drives one feature through every layer it touches. Per-layer QA spawns the moment a layer reports done — boundary issues surface in minutes, not at the end.

## When to use this skill

Use when a feature spans ≥2 of: `design/`, `migrations/`, `backend/`, `admin/`, `frontend/`, `frontend/l10n/`.

Do **not** use for: single-file edits, single endpoint, single screen, single migration, a pure refactor confined to one layer, or a code review. For those, invoke the matching per-layer skill (`go-api`, `flutter-feature`, `db-schema`, `design-wireframe`) or `code-review` directly.

## Execution mode: phased agent team

## Agent roster

| Agent | Subagent type | Owns | Skill | Phase |
|---|---|---|---|---|
| designer | `designer` | `design/` + `design/HANDOFF.md` addendum | `design-wireframe` | 1 |
| db-architect | `db-architect` | `migrations/`, `docs/db/` | `db-schema` | 2 |
| backend-engineer | `backend-engineer` | `backend/`, `backend/openapi.yaml`, `admin/` (when in scope) | `go-api` | 2 |
| flutter-engineer | `flutter-engineer` | `frontend/` | `flutter-feature` | 3 |
| qa-inspector | `qa-inspector` | `docs/history/<NN>_<feature>/qa/` | `qa-inspect` | every phase (incremental) + 4 (final) |

## Pipeline

```
Phase 0 — Preflight (orchestrator only) ──► docs/history/<NN>_<feature>/00_brief.md
Phase 1 — Design ─────────► design/* + HANDOFF.md addendum
        └─ QA (incremental, scope: design slice)
Phase 2 — Schema + API (+ Admin) ─► migrations/, backend/, admin/, openapi.yaml
        ├─ db-architect ─────► migrations/ + docs/db/
        ├─ backend-engineer ─► backend/ (Go) + admin/ (React, when in scope)
        └─ QA (incremental, one slice at a time, spawned on each implementer's completion)
Phase 3 — Frontend ─────────► frontend/
        └─ QA (incremental, one slice at a time)
Phase 4 — Final integration QA ► docs/history/<NN>_<feature>/qa/qa_report_final.md
```

Phase gating: a phase begins only after every task in the previous phase is `completed` per `TaskGet`, including its incremental QA tasks.

## Workflow

### Phase 0 — preflight

Orchestrator only. No agent spawned.

1. Read `SPEC.md`, `design/HANDOFF.md`, `design/README.md`, `backend/openapi.yaml`.
2. Confirm the feature's scope with the user — name + one-line description + which layers it touches.
3. Allocate `docs/history/<NN>_<feature>/` (next sequence number under `docs/history/`).
4. Write `docs/history/<NN>_<feature>/00_brief.md`:
   - Feature name and one-line description
   - SPEC reference (if any)
   - Layers in scope: design / schema / API / admin / Flutter / i18n (tick the ones it touches; skipping admin or Flutter is normal)
   - Existing artifacts touched (file paths)
   - New artifacts expected (file paths)
   - Out-of-scope clarifications

### Phase 1 — design

Spawn the designer with the template at [prompts/designer.md](prompts/designer.md). Interpolate `<NN>_<feature>` from Phase 0; pull `model` from the `recommended_model` field in `.claude/skills/design-wireframe/SKILL.md`.

On `designer.complete`: spawn the design-slice QA (see "Incremental QA" below).

### Phase 2 — schema + API (+ admin)

`TeamCreate(team_name: "<feature>-backend-team", ...)` with three members spawned from these templates:

- db-architect — [prompts/db-architect.md](prompts/db-architect.md)
- backend-engineer — [prompts/backend-engineer.md](prompts/backend-engineer.md)
- qa-inspector (modes: `incremental-be`, and `incremental-admin` if scoped) — [prompts/qa-inspector.md](prompts/qa-inspector.md)

Models come from the corresponding SKILL.md `recommended_model` fields (per-mode for `qa-inspect`).

Task IDs (the orchestrator creates these; if admin is out of scope, omit `be-admin`/`qa-admin`):

| ID | Title | Assignee | Depends on |
|---|---|---|---|
| `db-1` | Schema + migration + indexes + query patterns | db-architect | (designer complete) |
| `be-api` | Go API handlers + repository + openapi.yaml | backend-engineer | `db-1` |
| `be-admin` | Admin Go handlers + admin/ React surface | backend-engineer | `be-api` |
| `qa-api` | QA: Go API slice | qa-inspector | `be-api` |
| `qa-admin` | QA: admin slice | qa-inspector | `be-admin` |

Phase 2 ends when all in-scope tasks are `completed`. `TeamDelete("<feature>-backend-team")`. Then sweep MINOR findings (see "End-of-phase MINOR sweep").

### Phase 3 — frontend

`TeamCreate(team_name: "<feature>-frontend-team", ...)` with two members spawned from these templates:

- flutter-engineer — [prompts/flutter-engineer.md](prompts/flutter-engineer.md)
- qa-inspector (mode: `incremental-fe`) — [prompts/qa-inspector.md](prompts/qa-inspector.md)

Models come from the corresponding SKILL.md `recommended_model` fields.

Phase 3 ends when `fe-feature` and `qa-frontend` are `completed`. `TeamDelete`. Sweep MINOR findings.

### Phase 4 — final integration QA

Spawn qa-inspector with `mode: final` using [prompts/qa-inspector.md](prompts/qa-inspector.md). The final mode runs every catalog invariant grep across `backend/`, `frontend/`, `admin/` (if in scope), `migrations/`, and `design/`. Output: `docs/history/<NN>_<feature>/qa/qa_report_final.md`.

Halt if final report is `FAIL`. Do not call the feature done until BLOCKERs are resolved.

Optionally chain a `test-runner` (D1) at the end of Phase 4 to run the verification matrix from CLAUDE.md as a hard gate.

## Incremental QA (the per-layer trigger)

Every implementer slice ends with a SendMessage to qa-inspector and a TaskUpdate. The orchestrator spawns no new agent for QA — the qa-inspector member of the running team picks it up. Time from "slice complete" to "QA findings filed" should be minutes, not phase-end.

QA prompts include architecture + coding conventions + security/perf spot-checks in addition to integration boundaries — not just boundary verification.

## BLOCKER / MAJOR / MINOR routing

See [[protocol:build-pipeline]] "Severity → routing" section. Summary: BLOCKER + MAJOR route to the implementer (per `feedback_implementer_owns_qa_fixes` memory); MINOR files into `docs/history/backlog.md` for the end-of-phase sweep.

## End-of-phase MINOR sweep

After every phase's final `PASS` (or `PASS WITH MINOR`), before tearing down the team:

1. Read the cumulative QA reports for the phase.
2. Apply all MINOR fixes that are low-effort, low-risk, and a clear win (typos in error messages, missing comments, redundant null checks, etc.).
3. Explicitly defer judgment-call MINORs to backlog with a note in the phase's brief.

This is a memory-driven preference — do not skip it.

## Path rule

Implementer agents write production code to `backend/`, `frontend/`, `admin/`, `migrations/`, and `design/` at the repo root; doc artifacts go to `docs/db/` and `docs/history/<NN>_<feature>/`. No workspace fallback.

## Communication contract

Every SendMessage in this pipeline is defined in [[protocol:build-pipeline]] (`.claude/protocols/build-pipeline.md`). The contract names sender, receiver, literal wire string, payload, trigger, and receiver action for IDs `BUILD-001` through `BUILD-013`. Cite by ID; do not restate.

## Error handling

| Situation | Action |
|---|---|
| Designer's HANDOFF.md addendum is incomplete | Continue; QA flags missing data shapes; designer fills in during incremental round-trip |
| db-architect and backend-engineer disagree on schema | db-architect's migration is authoritative; backend-engineer adapts the repository layer |
| Flutter blocked by missing API operation | flutter-engineer stubs with mock data + `// STUB:` comment; resumes when OpenAPI updates land |
| QA reports BLOCKER | Halt the dependent task; SendMessage implementer; if no fix in 2 rounds, halt the phase and escalate to user |
| Agent unresponsive past 2 SendMessage rounds | Status check; if still no response, note the gap in the brief, proceed with what exists, surface in final report |
| User asks a single-layer question mid-build | Pause the orchestrator; answer; resume on confirmation |

## What this skill is not

- **Not a from-scratch build orchestrator.** The repo already ships. For a green-field rebuild, you would walk the per-layer skills with a brief written by hand.
- **Not a code review.** Use `code-review` for that.
- **Not a single-layer skill.** Use `go-api`, `flutter-feature`, `db-schema`, `design-wireframe` for one-layer scope.

## Test scenarios

### Adding a feature that touches every layer (e.g., a new "tasting flight" check-in mode)

1. Phase 0: brief written; layers = design + schema + API + admin (moderation flag) + Flutter + i18n.
2. Phase 1: designer adds `TastingFlightScreen.jsx`, updates `HANDOFF.md` with the data shape. QA verifies the HANDOFF addendum is internally consistent.
3. Phase 2: db-architect ships migration `021_tasting_flights.sql`; backend-engineer adds `/checkins/flights` handlers, extends `openapi.yaml`, adds admin moderation endpoint + admin React row. QA fires per slice; BLOCKER on a missing IDOR check round-trips to backend-engineer.
4. Phase 3: flutter-engineer implements the flight screen + provider + repository + ARB keys for en/ja/ko. QA verifies boundaries.
5. Phase 4: final QA — PASS.

### Adding a feature with no admin scope (e.g., flat comments on check-ins)

Phase 0 ticks design + schema + API + Flutter + i18n; admin = no. The `be-admin` and `qa-admin` tasks are not created. Otherwise identical.

### Late SPEC violation mid-phase

1. Phase 3 underway. flutter-engineer implements paging with `offset` because OpenAPI was momentarily ambiguous.
2. QA detects: repository consumes `offset`, openapi.yaml defines `next_cursor`. SPEC §5.2 mandates cursor.
3. SendMessage flutter-engineer: BLOCKER, file:line, fix.
4. flutter-engineer fixes; SendMessage qa-inspector for re-verify.
5. QA re-reads, confirms fix, marks resolved.
6. Phase 3 continues.
