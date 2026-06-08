---
name: <kebab-case-skill-name>
description: "<What the skill does in one sentence>. Use this to <triggering condition>. Invoke whenever <list of trigger phrases>. Triggers: <comma-separated keywords>."
recommended_model: opus | sonnet | haiku
# For multi-mode skills (e.g. qa-inspect), use a mapping:
# recommended_model:
#   mode-a: sonnet
#   mode-b: opus
---

# <Title> Skill

<One paragraph stating what the skill produces and the domain it covers.>

## When to use this skill

- <Trigger 1>
- <Trigger 2>
- <Trigger 3>

## When NOT to use this skill

- <Adjacent scope that belongs to a different skill — name it>
- <Adjacent scope that belongs to a different skill — name it>

## Project structure

```
<authoritative output paths the skill writes to>
```

<One paragraph naming the source of truth and the path rule (no workspace fallback, etc.).>

## Conventions

- <Convention 1>
- <Convention 2>

## SPEC invariants this skill enforces

Cite by ID. Do NOT restate the rule; the catalog is canonical.

- [[invariant:<id-1>]] — <one-line how this skill enforces it>
- [[invariant:<id-2>]] — <one-line how this skill enforces it>

## Workflow

1. <Step 1>
2. <Step 2>
3. <Step 3>

## Output format

```
<concrete output template — file contents, response shape, etc.>
```

## Communication

If this skill is invoked inside an orchestrator team, follow the relevant protocol:

- `[[protocol:<protocol-id>]]` — <one-line which protocol applies>

For direct invocation outside a team, write outputs to the paths above; no SendMessage required.

## What this skill is not

- **Not <adjacent thing>** — that's <other skill>.
- **Not <another adjacent thing>** — that's <other skill>.

---

## How to use this template

1. Copy this file to `.claude/skills/<your-skill-name>/SKILL.md`.
2. Fill every `<...>` placeholder.
3. List the SPEC invariants this skill enforces by ID. Add new ones to `.claude/invariants/` if needed.
4. Add the skill's row to `.claude/skills/INDEX.md`.
5. If the skill pairs with an agent, create or update the matching `.claude/agents/<agent-name>.md` from the agent template.
6. Run `.claude/scripts/validate-harness.sh` until it passes.
