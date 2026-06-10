---
name: kamos-build
description: "KAMOS feature-build orchestrator. Coordinates designer, db-architect, backend-engineer, flutter-engineer, and qa-inspector through a vertical-slice pipeline for one multi-layer feature: design → schema + API (+ admin) → Flutter → final QA. Per-layer QA fires the moment each implementer reports completion. Use when a request touches ≥2 of: design, schema, API, admin, Flutter, i18n. Do NOT use for single-layer work — invoke the relevant per-layer skill (go-api, flutter-feature, db-schema, design-wireframe) directly."
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

```
Agent(
  name: "designer",
  subagent_type: "designer",
  prompt: "Read docs/history/<NN>_<feature>/00_brief.md, SPEC.md, design/README.md, and design/HANDOFF.md. Use the design-wireframe skill to extend the design system for the named feature: update brand/voice rules only if necessary (the README is authoritative), add or revise JSX screens under design/ui_kits/mobile/components/, add primitive previews if a new primitive is introduced, and append a new section to design/HANDOFF.md listing the screen ↔ data-shape mappings the engineers will consume. Honor non-negotiables: the 5-tab nav (Feed · Lists · Discover · Notifications · Me), the Japanese-blue palette + Koh accent reserved for toast/kanpai only, no emoji in UI, category strings + rating grid from specs/invariants.yaml, cursor pagination. Do not create wireframes.md / design_tokens.md / screen_specs.md / api_contracts.md — the skill forbids them. On completion: SendMessage db-architect and backend-engineer 'Design ready for <feature>'. TaskUpdate to completed."
)
```

On `designer.complete`: spawn the design-slice QA (see "Incremental QA" below).

### Phase 2 — schema + API (+ admin)

```
TeamCreate(
  team_name: "<feature>-backend-team",
  members: [
    {
      name: "db-architect",
      subagent_type: "db-architect",
          prompt: "Read docs/history/<NN>_<feature>/00_brief.md, design/HANDOFF.md (new section), and SPEC.md. Use the db-schema skill. Write a new append-only migration to migrations/NNN_<feature>.sql, extend docs/db/schema.md, docs/db/indexes.md, and docs/db/query_patterns.md with the additions. Encode every cap from specs/invariants.yaml as a CHECK constraint at the column's owning migration; do not paste the value elsewhere. On completion: SendMessage backend-engineer 'DB ready for <feature> — migration NNN, query patterns at docs/db/query_patterns.md'. TaskUpdate to completed."
    },
    {
      name: "backend-engineer",
      subagent_type: "backend-engineer",
          prompt: "Read docs/history/<NN>_<feature>/00_brief.md, design/HANDOFF.md (new section), SPEC.md, and backend/openapi.yaml. Use the go-api skill. Implement Go handlers in backend/internal/handlers/, repository in backend/internal/repository/, any worker jobs in backend/internal/jobs/. Extend backend/openapi.yaml with the new operations. Wait for 'DB ready' from db-architect before implementing the repository layer. If admin scope is set in 00_brief.md: implement the admin Go handlers (admin_*.go) AND extend admin/ React surface (HttpOnly cookie + CSRF auth per ARCHITECTURE.md §5). After the Go API slice is feature-complete: SendMessage qa-inspector 'Backend module <feature> complete' with paths. After the admin slice (if in scope) is feature-complete: SendMessage qa-inspector 'Admin module <feature> complete' with paths. On openapi.yaml updates: SendMessage flutter-engineer 'OpenAPI ready for <feature> at backend/openapi.yaml'. TaskUpdate per slice."
    },
    {
      name: "qa-inspector",
      subagent_type: "qa-inspector",
          prompt: "Use the qa-inspect skill in incremental backend mode. Wait for SendMessage 'Backend module <feature> complete' from backend-engineer. On receipt: cross-check Go handler response shapes against backend/openapi.yaml and design/HANDOFF.md, verify DB column names match Go struct json tags, run the SPEC invariant grep checks. Write docs/history/<NN>_<feature>/qa/qa_report_backend.md. If admin scope is set: also wait for 'Admin module <feature> complete' and cross-check admin handlers against admin/ React calls (CSRF header, cookie auth, /v1/admin/me cookie-authable identity). Write docs/history/<NN>_<feature>/qa/qa_report_admin.md. SendMessage BLOCKER and MAJOR findings to the responsible agent (db-architect or backend-engineer) with file:line and the specific fix; that implementer owns the fix and SendMessages back for re-verification. MINOR findings are filed for the end-of-phase sweep. TaskUpdate per slice."
    }
  ]
)
```

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

```
TeamCreate(
  team_name: "<feature>-frontend-team",
  members: [
    {
      name: "flutter-engineer",
      subagent_type: "flutter-engineer",
          prompt: "Read docs/history/<NN>_<feature>/00_brief.md, design/README.md, design/colors_and_type.css, design/ui_kits/mobile/, design/HANDOFF.md (new section), backend/openapi.yaml, and SPEC.md. Use the flutter-feature skill. Implement screens, Riverpod providers, repositories, and ARB keys (all three locales together) under frontend/lib/features/<feature>/. Wire navigation in frontend/lib/app/router.dart. Required invariants: JWT in flutter_secure_storage (never SharedPreferences); all numeric/regex/enum values from KamosSpec (frontend/lib/core/spec/spec.dart), backed by specs/invariants.yaml; cursor pagination via next_cursor + has_more; ARB key parity across en/ja/ko. After the feature is implemented: SendMessage qa-inspector 'Flutter feature <feature> complete' with paths. TaskUpdate to completed."
    },
    {
      name: "qa-inspector",
      subagent_type: "qa-inspector",
          prompt: "Use the qa-inspect skill in incremental frontend mode. Wait for SendMessage 'Flutter feature <feature> complete' from flutter-engineer. On receipt: cross-check Flutter repository response parsing against backend/openapi.yaml, verify go_router paths correspond to real screen files, verify all three ARB files have matching keys, run the SPEC invariant grep checks (especially category strings, SharedPreferences, cursor pagination). Write docs/history/<NN>_<feature>/qa/qa_report_frontend.md. SendMessage BLOCKER and MAJOR findings to flutter-engineer with file:line and the specific fix; that implementer owns the fix and SendMessages back for re-verification. MINOR findings are filed for the end-of-phase sweep. TaskUpdate to completed."
    }
  ]
)
```

Phase 3 ends when `fe-feature` and `qa-frontend` are `completed`. `TeamDelete`. Sweep MINOR findings.

### Phase 4 — final integration QA

```
Agent(
  name: "qa-inspector-final",
  subagent_type: "qa-inspector",
  prompt: "Use the qa-inspect skill in 'final' mode for the <feature> feature. Read backend/, frontend/, admin/ (if in scope), migrations/, design/, docs/db/, and SPEC.md. Verify end-to-end: (1) every new endpoint in backend/openapi.yaml is consumed by Flutter (and admin if in scope); (2) every new go_router path corresponds to a real screen file; (3) all three ARB files are consistent and complete for the feature; (4) category terminology in all three locales matches SPEC §2.1 exactly; (5) JWT storage uses flutter_secure_storage; (6) cursor pagination is end-to-end (handler → openapi → repository → UI); (7) admin auth uses HttpOnly cookies + CSRF (when in scope); (8) soft-delete columns and filters are present per SPEC where the feature touches them; (9) all SPEC caps enforced both client-side and server-side; (10) no SPEC invariant violated. Write docs/history/<NN>_<feature>/qa/qa_report_final.md with PASS/FAIL summary at the top, then per-category findings."
)
```

Halt if final report is `FAIL`. Do not call the feature done until BLOCKERs are resolved.

## Incremental QA (the per-layer trigger)

Every implementer slice ends with a SendMessage to qa-inspector and a TaskUpdate. The orchestrator spawns no new agent for QA — the qa-inspector member of the running team picks it up. Time from "slice complete" to "QA findings filed" should be minutes, not phase-end.

QA prompts include architecture + coding conventions + security/perf spot-checks in addition to integration boundaries — not just boundary verification.

## BLOCKER / MAJOR / MINOR routing

| Severity | Routing | Phase impact |
|---|---|---|
| BLOCKER | SendMessage implementer; that agent owns the fix; QA re-verifies before marking resolved | Halts the dependent task; if unresolved in 2 SendMessage rounds, halt the phase and escalate to user |
| MAJOR | SendMessage implementer; implementer owns the fix; QA re-verifies | Does not halt; resolves before phase end |
| MINOR | Filed in the QA report; not routed live | Swept at end of phase |

## End-of-phase MINOR sweep

After every phase's final `PASS` (or `PASS WITH MINOR`), before tearing down the team:

1. Read the cumulative QA reports for the phase.
2. Apply all MINOR fixes that are low-effort, low-risk, and a clear win (typos in error messages, missing comments, redundant null checks, etc.).
3. Explicitly defer judgment-call MINORs to backlog with a note in the phase's brief.

This is a memory-driven preference — do not skip it.

## Path rule

Implementer agents write production code to `backend/`, `frontend/`, `admin/`, `migrations/`, and `design/` at the repo root; doc artifacts go to `docs/db/` and `docs/history/<NN>_<feature>/`. No workspace fallback.

## Communication contract

Inter-agent messages, in order:

- `designer` → `db-architect`, `backend-engineer`: "Design ready for `<feature>`"
- `db-architect` → `backend-engineer`: "DB ready for `<feature>` — migration NNN"
- `backend-engineer` (Go slice) → `qa-inspector`: "Backend module `<feature>` complete"
- `backend-engineer` (admin slice, if in scope) → `qa-inspector`: "Admin module `<feature>` complete"
- `backend-engineer` → `flutter-engineer`: "OpenAPI ready for `<feature>`"
- `flutter-engineer` → `qa-inspector`: "Flutter feature `<feature>` complete"
- `qa-inspector` → responsible agent: BLOCKER / MAJOR with file:line and exact fix
- All agents → `TaskUpdate` after each meaningful state change

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
