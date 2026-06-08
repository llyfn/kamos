# Agents — index

Every agent in `.claude/agents/`. Each row maps the agent to its paired skill, the orchestrator that spawns it, the trigger keywords, and the recommended model (resolved from the paired skill's frontmatter).

To add an agent: copy `_TEMPLATE.md`, then add a row here and run `.claude/scripts/validate-harness.sh`.

## Implementers

| Agent | Paired skill | Spawned by | Triggers on | Model |
|---|---|---|---|---|
| [designer](designer.md) | [design-wireframe](../skills/design-wireframe/SKILL.md) | kamos-build (phase 1), direct | wireframe, design, UX, UI, screen spec, design system, tokens, typography | opus |
| [db-architect](db-architect.md) | [db-schema](../skills/db-schema/SKILL.md) | kamos-build (phase 2), direct | schema, database, PostgreSQL, migration, index | opus |
| [backend-engineer](backend-engineer.md) | [go-api](../skills/go-api/SKILL.md) | kamos-build (phase 2), direct | Go, backend, API, handler, JWT, OAuth, repository, openapi, admin | opus |
| [flutter-engineer](flutter-engineer.md) | [flutter-feature](../skills/flutter-feature/SKILL.md) | kamos-build (phase 3), direct | Flutter, Dart, widget, screen, Riverpod, go_router, ARB, i18n | opus |

## Reviewers

| Agent | Paired skill | Spawned by | Triggers on | Model |
|---|---|---|---|---|
| [arch-reviewer](arch-reviewer.md) | [arch-review](../skills/arch-review/SKILL.md) | code-review (fan-out) | architecture review, structure, layer separation, coupling | opus |
| [security-reviewer](security-reviewer.md) | [security-review](../skills/security-review/SKILL.md) | code-review (fan-out) | security review, OWASP, IDOR, auth review | opus |
| [perf-reviewer](perf-reviewer.md) | [perf-review](../skills/perf-review/SKILL.md) | code-review (fan-out) | perf review, scalability, N+1, indexing, latency | sonnet |
| [style-reviewer](style-reviewer.md) | [style-review](../skills/style-review/SKILL.md) | code-review (fan-out) | style review, maintainability, naming, code smell | sonnet |

## QA + ops

| Agent | Paired skill | Spawned by | Triggers on | Model |
|---|---|---|---|---|
| [qa-inspector](qa-inspector.md) | [qa-inspect](../skills/qa-inspect/SKILL.md) | kamos-build (every phase), spec-sweep, direct | QA, integration check, spec compliance, boundary verification | sonnet (incremental) / opus (final) |
| [test-runner](test-runner.md) | [verify-gates](../skills/verify-gates/SKILL.md) | kamos-build (phase 4), code-review (final), direct | verification, gate, smoke test, CI, integration test | sonnet |
| [release-engineer](release-engineer.md) | [deploy-runbook](../skills/deploy-runbook/SKILL.md) | direct | deploy, release, migration apply, secret rotation, smoke | opus |
| [doc-keeper](doc-keeper.md) | [doc-sync](../skills/doc-sync/SKILL.md) | kamos-build (end-of-phase), spec-sweep, direct | docs sync, CLAUDE.md, SPEC.md, README, runbook | sonnet |
| [i18n-curator](i18n-curator.md) | (paired with [qa-inspect](../skills/qa-inspect/SKILL.md) + [flutter-feature](../skills/flutter-feature/SKILL.md)) | kamos-build (phase 3), spec-sweep | i18n, ARB parity, locale fallback, category strings | sonnet |

## Conventions

- Implementer agents write production code; QA + reviewer agents write reports only.
- Agent files are short (Inputs / Outputs / Communication / Decision discipline / Collaboration). Method lives in the paired skill.
- Every agent cites SendMessage events by protocol ID — see `.claude/protocols/`.
- Every agent cites SPEC rules by invariant ID — see `.claude/invariants/`.
