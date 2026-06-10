# KAMOS Harness Topology

Single source of truth for how agents, skills, and the orchestrators fit together. CLAUDE.md and the skill files cite this doc instead of restating.

## Source of truth for product invariants

| Layer | Where the values live |
|---|---|
| **Canonical** | `specs/invariants.yaml` |
| Go constants | `backend/internal/spec/spec.go` (generated) |
| Dart constants | `frontend/lib/core/spec/spec.dart` (generated; `KamosSpec`) |
| Regenerate | `scripts/gen-spec.sh` |
| CI drift gate | `.github/workflows/ci.yml::spec-codegen` |

Spec change process: edit YAML → run `gen-spec.sh` → commit both files → CI fails on drift. Do **not** restate numeric / regex / enum values in skills, agents, code, docs, or copy. Behavioral rules that don't fit a constant (private-profile gating, soft-delete window, "PATCH check-ins rejects beverage_id") live in `SPEC.md`.

## Models

- **Orchestrator skills** (`kamos-build`, `code-review`) run in the main loop — Opus by default. Do not set `model:` overrides on their `Agent()` calls.
- **Spawned agents** (everything in `.claude/agents/`) pin `model: sonnet` in frontmatter. Each Agent invocation inherits Sonnet from frontmatter; no per-call override needed.

If a spawned agent ever needs Opus for a specific task, override at the spawn call site (`Agent({..., model: "opus"})`); do not change frontmatter.

## Agent ↔ skill pairs

Each implementer / reviewer agent has a 1:1 skill counterpart. The agent file holds team protocol (inputs / outputs / SendMessage contracts). The skill file holds how-to (procedures / templates / patterns). Neither restates SPEC values.

| Agent | Skill | Spawned by | Role |
|---|---|---|---|
| `designer` | `design-wireframe` | `kamos-build` Phase 1 | Design system extension |
| `db-architect` | `db-schema` | `kamos-build` Phase 2 | Migrations + indexes |
| `backend-engineer` | `go-api` | `kamos-build` Phase 2 | Go API + admin React |
| `flutter-engineer` | `flutter-feature` | `kamos-build` Phase 3 | Flutter app |
| `qa-inspector` | `qa-inspect` | `kamos-build` (incremental + Phase 4) | Integration / SPEC checks |
| `arch-reviewer` | `arch-review` | `code-review` fan-out | Architecture review |
| `security-reviewer` | `security-review` | `code-review` fan-out | Adversarial security |
| `perf-reviewer` | `perf-review` | `code-review` fan-out | Performance review |
| `style-reviewer` | `style-review` | `code-review` fan-out | Style / maintainability |

## Orchestrator topology

```
kamos-build (main-loop Opus)
  Phase 0 — preflight
  Phase 1 — designer ─────────────────── qa-inspector (design slice)
  Phase 2 — db-architect → backend-engineer ── qa-inspector (API + admin slices)
  Phase 3 — flutter-engineer ─────────── qa-inspector (frontend slice)
  Phase 4 — qa-inspector (final)

code-review (main-loop Opus)
  Phase 1 — scope
  Phase 2 — arch-reviewer · security-reviewer · perf-reviewer · style-reviewer (parallel)
  Phase 3 — synthesis → REVIEW_REPORT.md
```

Per-layer skills (`go-api`, `flutter-feature`, `db-schema`, `design-wireframe`, `qa-inspect`, four `*-review` skills) can also be invoked directly by the user as `/<skill>` — same procedures, no team protocol.

## Sustainment rules

- **One value, one place.** A new numeric / regex / enum invariant goes into `specs/invariants.yaml` first; everything else references the generated constants.
- **Skills do not restate values.** They reference `specs/invariants.yaml` (and the generated constants for code examples).
- **Agents are team protocol.** They reference their skill for the how-to.
- **CLAUDE.md is a pointer.** It cites this doc + `specs/invariants.yaml` + `SPEC.md` rather than duplicating their content.
