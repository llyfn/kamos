# Skills — index

Every skill in `.claude/skills/`. Each row maps the skill to its paired agent (when any), the orchestrator (if it is itself an orchestrator or is invoked by one), and the recommended model from frontmatter.

To add a skill: copy `_TEMPLATE.md`, then add a row here and run `.claude/scripts/validate-harness.sh`.

## Orchestrators

| Skill | Paired agent | Spawns | Output | Model |
|---|---|---|---|---|
| [kamos-build](kamos-build/SKILL.md) | (orchestrator) | designer, db-architect, backend-engineer, flutter-engineer, qa-inspector, test-runner, doc-keeper | feature implementation across all relevant layers + per-slice QA reports + final report | opus |
| [code-review](code-review/SKILL.md) | (orchestrator) | arch-reviewer, security-reviewer, perf-reviewer, style-reviewer | `docs/history/review/REVIEW_REPORT.md` | opus |
| [spec-sweep](spec-sweep/SKILL.md) | (orchestrator) | all implementers + qa-inspector + doc-keeper | per-layer SPEC propagation reports | opus |

## Implementation skills

| Skill | Paired agent | Used by | Outputs | Model |
|---|---|---|---|---|
| [design-wireframe](design-wireframe/SKILL.md) | [designer](../agents/designer.md) | kamos-build, spec-sweep, direct | `design/*` + `design/HANDOFF.md` | opus |
| [db-schema](db-schema/SKILL.md) | [db-architect](../agents/db-architect.md) | kamos-build, spec-sweep, direct | `migrations/NNN_*.sql`, `docs/db/*` | opus |
| [go-api](go-api/SKILL.md) | [backend-engineer](../agents/backend-engineer.md) | kamos-build, spec-sweep, direct | `backend/*`, `backend/openapi.yaml`, `admin/*` (admin slice) | opus |
| [flutter-feature](flutter-feature/SKILL.md) | [flutter-engineer](../agents/flutter-engineer.md) | kamos-build, spec-sweep, direct | `frontend/*` | opus |

## Review skills

| Skill | Paired agent | Used by | Outputs | Model |
|---|---|---|---|---|
| [arch-review](arch-review/SKILL.md) | [arch-reviewer](../agents/arch-reviewer.md) | code-review, direct | `docs/history/review/arch_findings.md` | opus |
| [security-review](security-review/SKILL.md) | [security-reviewer](../agents/security-reviewer.md) | code-review, direct | `docs/history/review/security_findings.md` | opus |
| [perf-review](perf-review/SKILL.md) | [perf-reviewer](../agents/perf-reviewer.md) | code-review, direct | `docs/history/review/perf_findings.md` | sonnet |
| [style-review](style-review/SKILL.md) | [style-reviewer](../agents/style-reviewer.md) | code-review, direct | `docs/history/review/style_findings.md` | sonnet |

## QA + ops skills

| Skill | Paired agent | Used by | Outputs | Model |
|---|---|---|---|---|
| [qa-inspect](qa-inspect/SKILL.md) | [qa-inspector](../agents/qa-inspector.md) | kamos-build, spec-sweep, direct | `docs/history/<feature>/qa/qa_report_*.md`, `docs/history/backlog.md` (MINOR sweep) | sonnet (incremental) / opus (final) |
| [verify-gates](verify-gates/SKILL.md) | [test-runner](../agents/test-runner.md) | kamos-build (phase 4), code-review (final), direct | `docs/history/<context>/verify_report.md` | sonnet |
| [deploy-runbook](deploy-runbook/SKILL.md) | [release-engineer](../agents/release-engineer.md) | direct | runs the deploy runbook step-by-step; no file output unless asked | opus |
| [doc-sync](doc-sync/SKILL.md) | [doc-keeper](../agents/doc-keeper.md) | kamos-build (end-of-phase), spec-sweep, direct | edits to `CLAUDE.md`, `SPEC.md`, `README.md`, `docs/runbooks/*` | sonnet |

## Conventions

- Every skill carries `recommended_model:` in frontmatter; orchestrators read from there.
- Every skill cites SPEC rules by `[[invariant:<id>]]`, never restating.
- Every skill cites inter-agent messages by `[[protocol:<id>]]`, never restating.
- Skill files are short (When-to-use / When-not-to-use / Workflow / Conventions / Invariants-by-ref / Output format). Method lives here; persona lives in the paired agent file.
