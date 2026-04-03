---
name: kamos-build
description: "KAMOS full-stack build orchestrator. Coordinates the designer, db-architect, backend-engineer, flutter-engineer, and qa-inspector agents through a wireframe-to-deployment pipeline for the KAMOS beverage tracking app. Use this skill when asked to build, implement, start development, scaffold, or create the KAMOS app end-to-end. This is the primary entry point for any full-stack development work on KAMOS."
---

# KAMOS Build Orchestrator

Coordinates all five KAMOS agents through a pipeline + fan-out workflow from wireframe to deployment-ready code.

## Execution Mode: Agent Team

## Agent Roster

| Agent | Type | Role | Skill | Output |
|-------|------|------|-------|--------|
| designer | custom | Wireframes, design tokens, API contracts | design-wireframe | `_workspace/01_design/` |
| db-architect | custom | PostgreSQL schema + migrations | db-schema | `_workspace/02_backend/db/` |
| backend-engineer | custom | Go REST API + OpenAPI spec | go-api | `_workspace/02_backend/api/` |
| flutter-engineer | custom | Flutter mobile app | flutter-feature | `_workspace/03_frontend/` |
| qa-inspector | custom | Integration + spec QA (incremental) | — | `_workspace/04_qa/` |

## Pipeline Overview

```
Phase 1 ── designer ──────────────────────────────────────────────────────► api_contracts.md
                                                                              screen_specs.md
Phase 2 ── db-architect ──────────────────────────────────────────────────► migrations/ + query_patterns.md
        └─ backend-engineer (parallel, starts on api_contracts) ──────────► openapi.yaml + Go source
                    ↑ db-architect feeds migrations when ready
Phase 3 ── flutter-engineer (starts after screen_specs + openapi.yaml) ──► Flutter app
Phase 4 ── qa-inspector (incremental: runs after each module completes)
Phase 5 ── Final integration check + deployment prep
```

## Workflow

### Phase 1: Preparation

1. Read `README.md` to extract the full feature scope
2. Create workspace: `_workspace/01_design/`, `_workspace/02_backend/db/`, `_workspace/02_backend/api/`, `_workspace/03_frontend/`, `_workspace/04_qa/`
3. Write `_workspace/00_brief.md` with: feature list, MVP scope, tech constraints

### Phase 2: Design Phase — Single Agent

Spawn `designer` as a single-agent (no team yet):

```
Agent(
  name: "designer",
  subagent_type: "designer",
  model: "opus",
  prompt: "Read _workspace/00_brief.md and README.md. Use the design-wireframe skill to produce all four design deliverables in _workspace/01_design/. On completion: SendMessage to orchestrator that design is complete."
)
```

Wait for designer completion.

### Phase 3: Backend Phase — Team (Fan-out)

Spawn a 3-member team: `db-architect`, `backend-engineer`, and `qa-inspector`.

```
TeamCreate(
  team_name: "kamos-backend-team",
  members: [
    {
      name: "db-architect",
      agent_type: "db-architect",
      model: "opus",
      prompt: "Read _workspace/01_design/api_contracts.md and README.md. Use the db-schema skill to design the full PostgreSQL schema and write migrations to _workspace/02_backend/db/. When migrations/ and query_patterns.md are done, SendMessage to backend-engineer with: 'DB ready — migrations and query patterns at _workspace/02_backend/db/'"
    },
    {
      name: "backend-engineer",
      agent_type: "backend-engineer",
      model: "opus",
      prompt: "Read _workspace/01_design/api_contracts.md. Use the go-api skill to implement all Go API endpoints. Wait for a SendMessage from db-architect before implementing repository layer. Write output to _workspace/02_backend/api/. When openapi.yaml is complete, SendMessage to qa-inspector: 'Backend module auth complete' (repeat for each module: auth, beverages, checkins, feed, social, collection)."
    },
    {
      name: "qa-inspector",
      agent_type: "qa-inspector",
      model: "opus",
      prompt: "Monitor for SendMessage notifications from backend-engineer. After each module completion notification, run incremental QA: cross-check Go handler response shapes against api_contracts.md, verify DB column names match Go struct json tags, check index coverage for query patterns. Write qa_report_{module}.md to _workspace/04_qa/. SendMessage issues directly to the responsible agent."
    }
  ]
)
```

Register tasks:
```
TaskCreate(tasks: [
  { title: "DB schema + migrations", assignee: "db-architect" },
  { title: "DB indexes + query patterns", assignee: "db-architect", depends_on: ["DB schema + migrations"] },
  { title: "Go API: auth handlers", assignee: "backend-engineer" },
  { title: "Go API: beverage + brewery handlers", assignee: "backend-engineer" },
  { title: "Go API: check-in handlers", assignee: "backend-engineer" },
  { title: "Go API: feed + social handlers", assignee: "backend-engineer" },
  { title: "Go API: collection handlers", assignee: "backend-engineer" },
  { title: "Go API: openapi.yaml", assignee: "backend-engineer", depends_on: ["Go API: auth handlers", "Go API: check-in handlers"] },
  { title: "QA: backend module checks", assignee: "qa-inspector" }
])
```

Monitor: when both `db-architect` and `backend-engineer` complete (all tasks done), proceed to Phase 4.
TeamDelete("kamos-backend-team").

### Phase 4: Frontend Phase — Team

Spawn a 2-member team: `flutter-engineer` + `qa-inspector`.

```
TeamCreate(
  team_name: "kamos-frontend-team",
  members: [
    {
      name: "flutter-engineer",
      agent_type: "flutter-engineer",
      model: "opus",
      prompt: "Read _workspace/01_design/screen_specs.md, design_tokens.md, and _workspace/02_backend/api/openapi.yaml. Use the flutter-feature skill to implement the full Flutter app in _workspace/03_frontend/. Implement in this order: 1) app scaffold + router + theme, 2) auth screens, 3) beverage browse/detail, 4) check-in flow, 5) feed, 6) profile + social, 7) collection. After each feature group is done, SendMessage to qa-inspector: 'Flutter feature complete: {name}'."
    },
    {
      name: "qa-inspector",
      agent_type: "qa-inspector",
      model: "opus",
      prompt: "Monitor for SendMessage from flutter-engineer. After each feature notification, run incremental QA: compare Flutter repository response parsing with Go handler JSON output (from openapi.yaml), check all go_router paths match screen files, verify all three ARB files have matching keys, verify category terminology matches README. Write qa_report_{feature}.md to _workspace/04_qa/. SendMessage fix requests directly to flutter-engineer with file + line."
    }
  ]
)
```

Register tasks:
```
TaskCreate(tasks: [
  { title: "Flutter: app scaffold + router", assignee: "flutter-engineer" },
  { title: "Flutter: auth screens", assignee: "flutter-engineer", depends_on: ["Flutter: app scaffold + router"] },
  { title: "Flutter: beverage browse + detail", assignee: "flutter-engineer" },
  { title: "Flutter: check-in flow", assignee: "flutter-engineer" },
  { title: "Flutter: feed screen", assignee: "flutter-engineer" },
  { title: "Flutter: profile + follow", assignee: "flutter-engineer" },
  { title: "Flutter: collection screen", assignee: "flutter-engineer" },
  { title: "QA: Flutter feature checks", assignee: "qa-inspector" }
])
```

Wait for completion. TeamDelete("kamos-frontend-team").

### Phase 5: Final Integration Check

Spawn `qa-inspector` as a single agent for the final end-to-end check:

```
Agent(
  name: "qa-inspector-final",
  subagent_type: "qa-inspector",
  model: "opus",
  prompt: "Perform final integration QA. Read all files in _workspace/. Cross-check: (1) every API endpoint in openapi.yaml is consumed in Flutter repositories, (2) all Flutter go_router routes correspond to real screen files, (3) all ARB files are complete and consistent, (4) KAMOS category terminology is correct in all three locales, (5) JWT storage uses flutter_secure_storage not SharedPreferences, (6) cursor pagination is implemented end-to-end. Write qa_report_final.md to _workspace/04_qa/ with PASS/FAIL summary."
)
```

### Phase 6: Deployment Prep

After QA passes (no BLOCKERs):
1. Write `DEPLOYMENT.md` with: prerequisites, environment variables, DB migration steps, Go build command, Flutter build command, notes on Google OAuth setup
2. Write `docker-compose.yml` for local development (PostgreSQL + Go API)
3. Write `Makefile` with targets: `db-migrate`, `api-run`, `flutter-run`, `test`

## Data Flow

```
README.md ──► designer ──► api_contracts.md ──► db-architect ──► migrations/
                                              └──► backend-engineer ──► openapi.yaml
                        └──► screen_specs.md ──► flutter-engineer ──► Flutter app
                                                       ↑
                                               openapi.yaml (from backend)
All modules ──► qa-inspector (incremental) ──► qa_reports/
```

## Error Handling

| Situation | Action |
|-----------|--------|
| Designer produces incomplete API contracts | Continue with what exists; qa-inspector will flag missing endpoints |
| db-architect and backend-engineer schema conflict | SendMessage to both; db-architect's migration is authoritative |
| Flutter feature blocked by missing API | Flutter engineer stubs with mock data; marks with `// STUB:` comment |
| QA BLOCKER found | Halt dependent phase; SendMessage responsible agent; wait for fix |
| Agent unresponsive | SendMessage with status check; if no response in 2 rounds, proceed with available output and note gap in final report |

## Team Communication Rules

- `db-architect` → `backend-engineer`: migration readiness
- `backend-engineer` → `qa-inspector`: module complete notifications
- `flutter-engineer` → `qa-inspector`: feature complete notifications
- `qa-inspector` → any agent: fix requests with file:line references
- All agents → TaskUpdate: keep task list current

## Test Scenarios

### Normal Flow
1. User requests "build the KAMOS app"
2. Phase 1: brief created
3. Phase 2: designer produces all 4 deliverables in ~1 pass
4. Phase 3: db-architect and backend-engineer run in parallel; qa-inspector checks each module
5. Phase 4: flutter-engineer implements features; qa-inspector checks each feature
6. Phase 5: final QA passes with no BLOCKERs
7. Phase 6: `DEPLOYMENT.md`, `docker-compose.yml`, `Makefile` generated
8. Expected: full project in `_workspace/` with all files present

### Error Flow
1. In Phase 3, backend-engineer implements `/feed` endpoint with offset pagination instead of cursor
2. qa-inspector sends BLOCKER to backend-engineer: "`GET /feed` returns `{ offset, limit }` but Flutter expects `{ next_cursor, has_more }` — fix handler and openapi.yaml"
3. backend-engineer fixes and notifies qa-inspector
4. qa-inspector re-verifies and marks resolved
5. Flutter phase proceeds with correct contract
