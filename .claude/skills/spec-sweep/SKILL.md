---
name: spec-sweep
description: "KAMOS cross-layer SPEC propagation orchestrator. Use when a single catalog invariant changes and every layer must adapt in lockstep — e.g. rating step changes from 0.5 to 0.25; photo cap from 4 to 1; a new locale is added. Fans out designer + db-architect + backend-engineer + flutter-engineer + i18n-curator + doc-keeper in parallel; QA verifies each layer as it returns. Do NOT use for new features (that's kamos-build) or for code review (that's code-review). Triggers: SPEC change, invariant update, cross-layer sweep, propagation, catalog change."
recommended_model: opus
---

# SPEC Sweep Orchestrator

For a SPEC invariant change that ripples across every layer. The shape is **fan-out by layer**, not pipeline by phase. Every implementer runs at once; QA fires as each layer returns; doc-keeper syncs prose docs concurrently.

## When to use this skill

- A catalog invariant changed (e.g. `.claude/invariants/rating-scale.md` step value)
- SPEC.md was edited and the change touches more than one layer
- A new locale is added (Phase-9 hypothetical: add `zh-TW`)
- A new admin-auth invariant change (e.g. cookie name, CSRF token name)

## When NOT to use this skill

- Net-new feature work — use `kamos-build`
- Code review — use `code-review`
- Single-layer SPEC change (e.g. a backend-only validation tweak) — use the per-layer skill (`go-api`)
- Deploying the SPEC-sweep result to prod — use `deploy-runbook`

## Inputs

- The catalog invariant file under `.claude/invariants/<id>.md` (already updated to the new wording)
- The corresponding `SPEC.md §` (already updated, user-approved)
- The diff between the old and new wording

## Outputs

- Per-layer updates under `backend/`, `frontend/`, `admin/`, `migrations/`, `design/`
- Per-layer QA reports under `docs/history/spec-sweep/<invariant-id>/qa/`
- Doc-keeper syncs `CLAUDE.md`, `README.md`, `ARCHITECTURE.md`, runbooks as needed
- Final report `docs/history/spec-sweep/<invariant-id>/REPORT.md`

## Agent roster

| Agent | Skill | Role in sweep |
|---|---|---|
| designer | design-wireframe | Update JSX kit + previews if the invariant has a visual surface |
| db-architect | db-schema | Append a new migration if the invariant affects schema (CHECK constraint change, index rename, etc.) |
| backend-engineer | go-api | Update validators, response shapes, OpenAPI |
| flutter-engineer | flutter-feature | Update widgets + repository fields |
| i18n-curator | qa-inspect + flutter-feature | Update ARB strings if the invariant is `category-strings` or i18n-related |
| qa-inspector | qa-inspect | One verification run per layer + final |
| doc-keeper | doc-sync | CLAUDE.md, SPEC.md cross-links, README, runbooks |

## Pipeline

```
phase('Apply')
  └ all implementers (parallel) ─► layer updates
                          │
                          └ qa-inspector per layer ─► per-layer verdict

phase('Sync')
  └ doc-keeper (parallel with implementers) ─► prose doc updates

phase('Final')
  └ qa-inspector mode=final (or scoped to the invariant) ─► REPORT.md
  └ test-runner (verify-gates) as a hard gate
```

Phase gating: `Final` begins only after every layer's QA verdict is `PASS` or `PASS WITH MINOR`.

## Workflow

1. Read `.claude/invariants/<id>.md` to confirm the new wording.
2. Read the SPEC.md section.
3. Decide which layers actually touch the invariant (consult the catalog file's `layers:` frontmatter field).
4. Spawn the relevant implementers in parallel using `[[protocol:SWEEP-001]]`.
5. As each implementer signals done via `[[protocol:SWEEP-002]]`, spawn qa-inspector for that layer.
6. Spawn doc-keeper in parallel with the implementers — they do not block each other.
7. After every layer's `[[protocol:SWEEP-005]]` returns `PASS`/`PASS WITH MINOR`, spawn final qa-inspector and test-runner.
8. Write `REPORT.md` summarizing layer-by-layer status.

## Communication

Every wire string in this orchestrator is in [[protocol:spec-sweep]] (`.claude/protocols/spec-sweep.md`). Cite by ID. Do not restate.

## Error handling

| Situation | Action |
|---|---|
| One layer's QA returns FAIL with unresolved BLOCKER | Halt the sweep; escalate to the user |
| Doc-keeper finishes before implementers and finds drift in CLAUDE.md against the new invariant | Apply the drift fix; do not wait for the layers |
| A layer has nothing to change (invariant doesn't touch it) | Skip that implementer; do not spawn a no-op |
| The invariant change requires a new MINOR sweep across the backlog | Append to `docs/backlog.md`; do not bundle |

## What this skill is not

- **Not for new features** — that's `kamos-build`.
- **Not for code review** — that's `code-review`.
- **Not a deploy step** — schema changes from this sweep still require `deploy-runbook` for the prod migration apply.

## Test scenarios

### Photo cap reduced from 4 to 1

(Real scenario from KAMOS history.) Layers touched:

- migrations: new CHECK constraint capping `array_length(photo_urls, 1) <= 1` on submit
- backend: handler validator + OpenAPI maxItems
- flutter: picker max + form validator
- design: nothing (the picker UI is already single-select)
- docs: CLAUDE.md "Check-in caps" wording

Sweep runs: db + backend + flutter implementers in parallel; doc-keeper updates CLAUDE.md; qa-inspector per layer; final qa-inspector verifies the existing-multi-photo-read path still works.

### Rating step changed from 0.5 to 0.25

(Real scenario.) Layers touched:

- migrations: new CHECK with `(rating * 4) = floor(rating * 4)` and column type change to `NUMERIC(3,2)`
- backend: domain validator + OpenAPI `multipleOf: 0.25`
- flutter: star widget granularity
- design: star widget JSX preview
- docs: CLAUDE.md + SPEC.md §4.2 + the rating-scale invariant catalog file

All five implementers run in parallel; doc-keeper updates the catalog file last (so its content reflects the final wording).
