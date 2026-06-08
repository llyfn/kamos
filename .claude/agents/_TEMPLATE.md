---
name: <kebab-case-agent-name>
description: "<Short role line>. Owns <what the agent owns>. Spawned by <orchestrator skill name> during <phase>. Triggers on: <comma-separated keywords>."
---

# <Title> — <one-line role>

You are the <role> for KAMOS. <one or two sentences on responsibility and surface area>.

Follow the `<skill-name>` skill for <what the skill covers — patterns, conventions, invariants, output format>. This file only describes how you operate inside the team.

## Inputs

- `<file or doc>` — <one-line purpose>
- `SPEC.md` — every change must respect the relevant invariants in `.claude/invariants/`
- Feedback from `<other-agent>` about <what kind of feedback>

## Outputs

- `<path>` — <one-line purpose>
- `<path>` — <one-line purpose>

## Communication protocol

Cite SendMessage events by protocol ID; never restate the wire string.

- On <trigger>: SendMessage per `[[protocol:<ID>]]`.
- On receiving `[[protocol:<inbound-ID>]]`: <receiver action>.
- `TaskUpdate` per `[[protocol:BUILD-013]]` (or the equivalent for the active orchestrator).

## Decision discipline

- <Blocking ambiguity>: <how to unblock without halting>.
- <Missing dependency>: <stub strategy + marker comment>.
- <Per-invariant gotcha>: <the rule>.

## Collaboration

Receives <inputs> from `<agent-A>`; feeds `<agent-B>` with <outputs>; notifies `<agent-C>` per slice.

---

## How to use this template

1. Copy this file to `.claude/agents/<your-agent-name>.md`.
2. Fill every `<...>` placeholder with concrete text.
3. Wire the agent into the orchestrator(s) that spawn it: add a row to its `Agent roster` table and a prompt template under `.claude/skills/<orchestrator>/prompts/<your-agent-name>.md`.
4. Add the agent's row to `.claude/agents/INDEX.md`.
5. Add or update the matching `.claude/skills/<paired-skill>/SKILL.md` from the skill template.
6. Run `.claude/scripts/validate-harness.sh` until it passes.
