# Spawn prompt — designer (kamos-build phase 1)

```
subagent_type: designer
model: <recommended_model from design-wireframe SKILL.md>
prompt:
Read docs/history/<NN>_<feature>/00_brief.md, SPEC.md, design/README.md, and
design/HANDOFF.md.

Use the design-wireframe skill. Extend the design system for <feature>:
update brand/voice rules only if necessary (README authoritative), add or
revise JSX screens under design/ui_kits/mobile/components/, add primitive
previews if a new primitive is introduced, append a new section to
design/HANDOFF.md listing the screen ↔ data-shape mappings the engineers
will consume.

Honor these invariants (cite by ID, do not restate):
- [[invariant:category-strings]] in all three locales
- [[invariant:rating-scale]] for any rating widget
- [[invariant:cursor-pagination]] for any list shape exposed in design
- KAMOS UI baseline from CLAUDE.md "UI consistency baseline"

Do NOT create wireframes.md / design_tokens.md / screen_specs.md /
api_contracts.md — the skill forbids them.

Communication: per [[protocol:BUILD-001]] and [[protocol:BUILD-002]] on
completion. TaskUpdate per [[protocol:BUILD-013]].
```
