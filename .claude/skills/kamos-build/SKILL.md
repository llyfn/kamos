---
name: kamos-build
description: "KAMOS full-stack build orchestrator. Coordinates the designer, db-architect, backend-engineer, flutter-engineer, and qa-inspector agents through a wireframe-to-deployment pipeline for the KAMOS beverage tracking app. Use this skill when asked to build, implement, start development, scaffold, or create the KAMOS app end-to-end. Do NOT use this for single-file fixes, single-screen work, or single-endpoint changes — invoke the relevant skill (go-api, flutter-feature, db-schema, design-wireframe) directly instead."
---

# KAMOS Build Orchestrator

Coordinates the five KAMOS agents through a phased pipeline (single-agent → fan-out team → fan-out team → final QA) from spec to deployable code.

## Execution mode: agent team (phased fan-out / fan-in)

## Agent roster

| Agent | Subagent type | Role | Skill | Output |
|---|---|---|---|---|
| designer | `designer` | Wireframes (JSX), design tokens (CSS), screen ↔ data handoff | `design-wireframe` | `design/` (incl. `HANDOFF.md`) |
| db-architect | `db-architect` | PostgreSQL schema + migrations | `db-schema` | `migrations/` + `docs/db/` |
| backend-engineer | `backend-engineer` | Go REST API + OpenAPI spec | `go-api` | `backend/` |
| flutter-engineer | `flutter-engineer` | Flutter mobile app | `flutter-feature` | `frontend/` |
| qa-inspector | `qa-inspector` | Cross-layer integration QA | `qa-inspect` | `docs/history/qa/` |

## Pipeline overview

```
Phase 1 ── designer ─────────────────────────────────────► design/{README.md, colors_and_type.css, ui_kits/mobile/, HANDOFF.md}
Phase 2 ── db-architect ─────────────────────────────────► migrations/, query_patterns.md
        ── backend-engineer (waits for db) ──────────────► openapi.yaml, Go source
        ── qa-inspector (incremental per module) ────────► qa_report_{module}.md
Phase 3 ── flutter-engineer (waits for openapi.yaml) ────► Flutter app
        ── qa-inspector (incremental per feature) ───────► qa_report_{feature}.md
Phase 4 ── qa-inspector (final, single-agent) ───────────► qa_report_final.md
Phase 5 ── deployment artifacts (DEPLOYMENT.md, etc.)
```

**Phase gating:** each phase begins only after the previous phase's tasks (including its incremental QA) are all `completed` per `TaskGet`.

## Workflow

### Phase 1 — preparation

1. Read `README.md` and `SPEC.md` to extract MVP scope.
2. Ensure the production directories exist: `design/`, `migrations/`, `docs/db/`, `backend/`, `frontend/`, `docs/history/qa/`.
3. Write `docs/history/00_brief.md` with: feature list, MVP scope, out-of-scope items (mirror `SPEC §9`), tech constraints.

### Phase 2 — design (single agent)

```
Agent(
  name: "designer",
  subagent_type: "designer",
  model: "opus",
  prompt: "Read docs/history/00_brief.md, SPEC.md, and README.md. Use the design-wireframe skill to maintain and extend the design system under design/: brand + foundations in README.md, tokens in colors_and_type.css, primitive previews under preview/, and the runnable mobile UI kit under ui_kits/mobile/. Update design/HANDOFF.md with the screen ↔ data-shape index that db-architect and backend-engineer consume. Honor the SPEC invariants: category terminology per §2.1, rating in 0.5 steps per §4.2, cursor pagination per §5.2, default collections (Inventory, Wishlist) per §6.1. Do not create wireframes.md / design_tokens.md / screen_specs.md / api_contracts.md — the skill forbids them. On completion: TaskUpdate to completed."
)
```

Wait for designer task to complete before Phase 3.

### Phase 3 — backend + incremental QA (team)

```
TeamCreate(
  team_name: "kamos-backend-team",
  members: [
    {
      name: "db-architect",
      subagent_type: "db-architect",
      model: "opus",
      prompt: "Read design/HANDOFF.md and SPEC.md. Use the db-schema skill to design the full PostgreSQL schema, write migrations to migrations/, and write schema/index/query-pattern docs to docs/db/. Required invariants: rating NUMERIC(3,1) with CHECK 0.5..5.0; deleted_at TIMESTAMPTZ on users, check_ins, collections; default Inventory + Wishlist on user creation (handle in service layer or via trigger — document the choice). When migrations/ and docs/db/query_patterns.md are ready: SendMessage to backend-engineer 'DB ready'."
    },
    {
      name: "backend-engineer",
      subagent_type: "backend-engineer",
      model: "opus",
      prompt: "Read design/HANDOFF.md and SPEC.md. Use the go-api skill to implement Go API endpoints in backend/ and own backend/openapi.yaml as the canonical API contract. Wait for SendMessage 'DB ready' from db-architect before implementing repository layer. Required invariants: cursor pagination on all list endpoints (next_cursor + has_more); JWT middleware applied to all non-public routes; rating field as numeric with one decimal. After each module is feature-complete (auth, beverages, checkins, feed, social, collection): SendMessage to qa-inspector 'Backend module {name} complete' with paths to changed files. On openapi.yaml completion: SendMessage flutter-engineer 'OpenAPI ready at backend/openapi.yaml'."
    },
    {
      name: "qa-inspector",
      subagent_type: "qa-inspector",
      model: "opus",
      prompt: "Use the qa-inspect skill. Monitor for SendMessage 'Backend module {name} complete' from backend-engineer. For each notification: read the named files, cross-check Go handler response shapes against backend/openapi.yaml and design/HANDOFF.md, verify DB column names match Go struct json tags, check index coverage for the module's query patterns, run the SPEC invariant grep checks. Write qa_report_{module}.md to docs/history/qa/. SendMessage BLOCKER and MAJOR issues to the responsible agent (db-architect or backend-engineer) with file:line and the specific fix. After re-verification of fixes, mark issues resolved."
    }
  ]
)

TaskCreate(tasks: [
  { id: "db-1", title: "DB schema + migrations", assignee: "db-architect" },
  { id: "db-2", title: "DB indexes + query patterns", assignee: "db-architect", depends_on: ["db-1"] },
  { id: "be-auth",  title: "Go API: auth handlers",            assignee: "backend-engineer", depends_on: ["db-1"] },
  { id: "be-bev",   title: "Go API: beverage + producer",      assignee: "backend-engineer", depends_on: ["db-1"] },
  { id: "be-ci",    title: "Go API: check-in handlers",        assignee: "backend-engineer", depends_on: ["db-1"] },
  { id: "be-feed",  title: "Go API: feed + social handlers",   assignee: "backend-engineer", depends_on: ["db-1"] },
  { id: "be-coll",  title: "Go API: collection handlers",      assignee: "backend-engineer", depends_on: ["db-1"] },
  { id: "be-spec",  title: "Go API: openapi.yaml",             assignee: "backend-engineer", depends_on: ["be-auth", "be-bev", "be-ci", "be-feed", "be-coll"] },
  { id: "qa-auth",  title: "QA: auth module",                  assignee: "qa-inspector",     depends_on: ["be-auth"] },
  { id: "qa-bev",   title: "QA: beverage module",              assignee: "qa-inspector",     depends_on: ["be-bev"] },
  { id: "qa-ci",    title: "QA: check-in module",              assignee: "qa-inspector",     depends_on: ["be-ci"] },
  { id: "qa-feed",  title: "QA: feed + social module",         assignee: "qa-inspector",     depends_on: ["be-feed"] },
  { id: "qa-coll",  title: "QA: collection module",            assignee: "qa-inspector",     depends_on: ["be-coll"] },
  { id: "qa-spec",  title: "QA: openapi.yaml vs handlers",     assignee: "qa-inspector",     depends_on: ["be-spec"] }
])
```

Phase 3 ends when **all** tasks above are `completed` (including every `qa-*`). Then `TeamDelete("kamos-backend-team")`.

If any QA report is `FAIL` and the fix is not made within 2 SendMessage rounds, halt the phase and flag the user.

### Phase 4 — frontend + incremental QA (team)

```
TeamCreate(
  team_name: "kamos-frontend-team",
  members: [
    {
      name: "flutter-engineer",
      subagent_type: "flutter-engineer",
      model: "opus",
      prompt: "Read design/README.md, design/colors_and_type.css, design/ui_kits/mobile/, design/HANDOFF.md, backend/openapi.yaml, and SPEC.md. Use the flutter-feature skill to implement the Flutter app in frontend/. Implement in this order: 1) app scaffold + router + theme, 2) auth, 3) beverage browse + detail, 4) check-in flow, 5) feed, 6) profile + follow, 7) collection, 8) notifications. Required invariants: JWT in flutter_secure_storage (NEVER SharedPreferences); category strings exactly as SPEC §2.1; 0.5-step rating widget; cursor pagination consuming next_cursor; all three ARB files updated together. After each feature group: SendMessage to qa-inspector 'Flutter feature {name} complete' with paths."
    },
    {
      name: "qa-inspector",
      subagent_type: "qa-inspector",
      model: "opus",
      prompt: "Use the qa-inspect skill. Monitor for SendMessage 'Flutter feature {name} complete' from flutter-engineer. For each notification: read the named files, cross-check Flutter repository response parsing against openapi.yaml, verify go_router paths correspond to real screen files, verify all three ARB files have matching keys for the feature, run SPEC invariant grep checks (especially category strings and SharedPreferences). Write qa_report_{feature}.md to docs/history/qa/. SendMessage BLOCKER and MAJOR issues to flutter-engineer with file:line and specific fix."
    }
  ]
)

TaskCreate(tasks: [
  { id: "fe-shell",  title: "Flutter: app scaffold + router + theme", assignee: "flutter-engineer" },
  { id: "fe-auth",   title: "Flutter: auth screens",                  assignee: "flutter-engineer", depends_on: ["fe-shell"] },
  { id: "fe-bev",    title: "Flutter: beverage browse + detail",      assignee: "flutter-engineer", depends_on: ["fe-shell"] },
  { id: "fe-ci",     title: "Flutter: check-in flow",                 assignee: "flutter-engineer", depends_on: ["fe-bev"] },
  { id: "fe-feed",   title: "Flutter: feed",                          assignee: "flutter-engineer", depends_on: ["fe-shell"] },
  { id: "fe-prof",   title: "Flutter: profile + follow",              assignee: "flutter-engineer", depends_on: ["fe-shell"] },
  { id: "fe-coll",   title: "Flutter: collection",                    assignee: "flutter-engineer", depends_on: ["fe-shell"] },
  { id: "qa-shell",  title: "QA: Flutter shell",                      assignee: "qa-inspector",     depends_on: ["fe-shell"] },
  { id: "qa-feauth", title: "QA: Flutter auth",                       assignee: "qa-inspector",     depends_on: ["fe-auth"] },
  { id: "qa-febev",  title: "QA: Flutter beverage",                   assignee: "qa-inspector",     depends_on: ["fe-bev"] },
  { id: "qa-feci",   title: "QA: Flutter check-in",                   assignee: "qa-inspector",     depends_on: ["fe-ci"] },
  { id: "qa-fefeed", title: "QA: Flutter feed",                       assignee: "qa-inspector",     depends_on: ["fe-feed"] },
  { id: "qa-feprof", title: "QA: Flutter profile",                    assignee: "qa-inspector",     depends_on: ["fe-prof"] },
  { id: "qa-fecoll", title: "QA: Flutter collection",                 assignee: "qa-inspector",     depends_on: ["fe-coll"] }
])
```

Phase 4 ends when all tasks are `completed`. `TeamDelete("kamos-frontend-team")`.

### Phase 5 — final integration QA (single agent)

```
Agent(
  name: "qa-inspector-final",
  subagent_type: "qa-inspector",
  model: "opus",
  prompt: "Use the qa-inspect skill in 'final' mode. Read backend/, frontend/, migrations/, design/, docs/db/, and SPEC.md. Verify end-to-end: (1) every endpoint in openapi.yaml is consumed in Flutter repositories; (2) every go_router path corresponds to a real screen file; (3) all three ARB files are consistent and complete; (4) category terminology in all three locales matches SPEC §2.1 exactly; (5) JWT storage uses flutter_secure_storage; (6) cursor pagination is end-to-end (handler → openapi → repository → UI); (7) soft-delete columns and filters are present per SPEC; (8) default collections are created on user registration; (9) photo cap of 4 enforced both client and server; (10) review text 500-char cap enforced both sides. Write docs/history/qa/qa_report_final.md with PASS/FAIL summary at the top, then per-category findings."
)
```

Halt if final report is FAIL. Do not proceed to Phase 6 until BLOCKERs are resolved.

### Phase 6 — deployment prep

After final QA passes:

1. `DEPLOYMENT.md` — prerequisites, env vars, DB migration steps, build commands, Google OAuth setup, Flutter signing notes
2. `docker-compose.yml` — local PostgreSQL + Go API
3. `Makefile` — targets: `db-migrate`, `api-run`, `api-test`, `flutter-run`, `flutter-test`, `check` (runs all tests + analyze)

## Path rule

Agents write production code to `backend/`, `frontend/`, `migrations/`, `design/`, and `admin/` at the repo root; doc artifacts go to `docs/db/` and `docs/history/`. There is no workspace fallback.

## Communication rules

- `db-architect` → `backend-engineer`: "DB ready"
- `backend-engineer` → `qa-inspector`: "Backend module {name} complete"
- `flutter-engineer` → `qa-inspector`: "Flutter feature {name} complete"
- `qa-inspector` → responsible agent: BLOCKER / MAJOR fix request with file:line
- All agents → `TaskUpdate` after each meaningful state change

## Error handling

| Situation | Action |
|---|---|
| Designer's `HANDOFF.md` is incomplete | Continue; qa-inspector flags missing endpoints in module reports |
| `db-architect` and `backend-engineer` disagree on schema | db-architect's migrations are authoritative; backend-engineer adapts |
| Flutter blocked by missing API | flutter-engineer stubs with mock data and a `// STUB:` comment; resumes when OpenAPI updates |
| QA reports BLOCKER | Halt the dependent task; SendMessage responsible agent; if no fix in 2 rounds, halt the phase and escalate to user |
| Agent unresponsive | SendMessage status check; if no response in 2 rounds, log the gap, proceed with what exists, note in final report |
| User asks a single-file scope question mid-build | Pause the orchestrator; answer the question; resume on confirmation |

## When NOT to use this skill

- Single-file edits → just edit the file
- One screen, one endpoint, one migration → use the layer-specific skill directly
- Code review only → use the `code-review` skill
- Design exploration without implementation → use `design-wireframe` directly

Spawning a 3-agent team for a one-line fix wastes context and time.

## Test scenarios

### Normal flow

1. User: "build the KAMOS app"
2. Phase 1: brief written from `SPEC.md`
3. Phase 2: designer produces 4 deliverables
4. Phase 3: db-architect + backend-engineer run; qa-inspector incrementally QAs each module; all tasks complete
5. Phase 4: flutter-engineer implements 7 features; qa-inspector incrementally QAs each; all tasks complete
6. Phase 5: final QA — PASS
7. Phase 6: deployment artifacts generated

### Error flow — late SPEC violation

1. Phase 4 underway. flutter-engineer implements feed using `offset` pagination because OpenAPI was momentarily ambiguous.
2. qa-inspector detects: `feed_repository.dart` consumes `offset`, `openapi.yaml` defines `next_cursor`. SPEC §5.2 mandates cursor.
3. SendMessage to flutter-engineer: BLOCKER, file:line, fix.
4. flutter-engineer fixes; SendMessage qa-inspector for re-verify.
5. qa-inspector re-reads, confirms fix, marks resolved.
6. Phase 4 continues.

### Error flow — agent stuck

1. Phase 3, `be-feed` task in progress for unusually long.
2. Orchestrator (you) detects via `TaskGet`. SendMessage backend-engineer for status.
3. No response in 2 rounds.
4. Orchestrator notes "be-feed incomplete" in final report, marks task blocked, asks user how to proceed.
