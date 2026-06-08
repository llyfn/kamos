---
name: doc-sync
description: "KAMOS doc sync skill. Use this to keep CLAUDE.md, SPEC.md, README.md, runbooks, and the .claude/ harness files in sync after a feature ships or a SPEC invariant changes. Codifies the feedback_capture_plan_changes memory: any plan-changing decision must land in both memory and the relevant repo doc the same turn. Invoke whenever doc sync, CLAUDE.md update, SPEC update, runbook drift, or plan-change codification is requested. Triggers: doc sync, docs, CLAUDE, SPEC, README, runbook, plan change, codify."
recommended_model: sonnet
---

# Doc Sync Skill

Keeps the project's prose documentation in lockstep with the implementation. Used at end-of-phase by `kamos-build`, in parallel by `spec-sweep`, and directly when a plan-changing decision needs to be codified.

## When to use this skill

- End of every `kamos-build` phase — sync CLAUDE.md, SPEC.md, README, and any affected runbook against the feature's changes
- Inside `spec-sweep` — concurrent with implementer work, doc-keeper updates the prose docs while implementers update the code
- After any plan-changing decision (mine, user's, or joint) — `feedback_capture_plan_changes` memory: same turn, both memory and the relevant repo doc
- After a new agent, skill, or invariant lands in `.claude/` — sync CLAUDE.md's "how this project uses agents and skills" section and the relevant INDEX

## When NOT to use this skill

- Writing new feature docs (use the layer skill that produced the feature)
- Authoring SPEC sections from scratch (SPEC is the source of truth; doc-keeper only syncs derived prose)
- Editing memory files (those are managed by the auto-memory system per the user's global instructions)

## What is in scope

| Doc | Sync trigger |
|---|---|
| `CLAUDE.md` (project) | New invariant, new agent, new skill, new orchestration mode, changed "UI consistency baseline" item, changed verification matrix |
| `SPEC.md` | The user explicitly approves a SPEC change — doc-keeper reflects the approved wording, never authors silently |
| `README.md` | New tab, new top-level capability, changed stack version, new env var |
| `ARCHITECTURE.md` | New layer, new replica, changed cache invalidation path, changed auth topology |
| `DEPLOYMENT.md` | New env var, new vendor flag, new region |
| `CONTRIBUTING.md` | New verification gate, changed commit convention |
| `docs/runbooks/*.md` | A runbook step that did not match current state during a `deploy-runbook` execution |
| `docs/db/*.md` | New column / index / query pattern — `db-architect` writes the primary entries; doc-keeper makes sure they're cross-linked |
| `.claude/agents/INDEX.md` and `.claude/skills/INDEX.md` | New agent or skill added |
| `.claude/invariants/README.md` | New invariant file added |

## What is out of scope

- Inline code comments (CLAUDE.md "Code comments — strict policy" governs those)
- Per-feature design docs in `docs/history/<NN>_<feature>/` (the orchestrator writes those)

## Workflow

1. Read the trigger: feature brief / SPEC delta / runbook drift / harness change.
2. Build a sync checklist: which docs above should be touched?
3. Open each doc and propose the minimal edit. Match the existing voice. Do not bundle refactors.
4. For CLAUDE.md edits, keep the "Project invariants" section pointing at `.claude/invariants/` IDs — do not restate.
5. For SPEC.md edits, require explicit user approval before changing; reflect approved wording verbatim.
6. Run `.claude/scripts/validate-harness.sh` if the edit touches `.claude/` files.

## Output format

Doc-sync does not produce a report file by default — it produces diffs. When invoked inside an orchestrator, emit a one-paragraph summary of edits to the orchestrator via TaskUpdate.

For the end-of-phase invocation in `kamos-build`, write a single-line entry to `docs/history/<NN>_<feature>/05_doc_sync.md`:

```markdown
# Doc sync — {feature}
Date: {YYYY-MM-DD}

Files touched:
- {path} — {one-line reason}
- {path} — {one-line reason}
```

## Communication

- Inside `kamos-build` end-of-phase: SendMessage orchestrator + TaskUpdate per `[[protocol:BUILD-013]]`.
- Inside `spec-sweep`: SendMessage orchestrator per `[[protocol:SWEEP-006]]` when prose docs are caught up.

## Decision discipline

- Never silently change SPEC.md. SPEC is the source of truth and changes require user approval.
- Match the existing voice + structure. CLAUDE.md is terse and prescriptive; SPEC.md is descriptive; README.md is friendly.
- Do not delete content unless it is now wrong or duplicated by a `.claude/` reference.
- Cross-link, do not duplicate. When in doubt, link to the catalog / protocol / index.

## What this skill is not

- **Not a free pass to refactor docs.** Touch only what the trigger requires.
- **Not a SPEC author.** SPEC.md changes require explicit user approval.
- **Not a comment-writing helper.** Comments policy is in CLAUDE.md and applies to code, not docs.
