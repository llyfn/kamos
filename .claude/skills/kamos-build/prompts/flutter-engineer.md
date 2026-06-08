# Spawn prompt — flutter-engineer (kamos-build phase 3)

```
subagent_type: flutter-engineer
model: <recommended_model from flutter-feature SKILL.md>
prompt:
Read docs/history/<NN>_<feature>/00_brief.md, design/README.md,
design/colors_and_type.css, design/ui_kits/mobile/, design/HANDOFF.md
(new section), backend/openapi.yaml, and SPEC.md.

Use the flutter-feature skill. Implement screens, Riverpod providers,
repositories, and ARB keys (all three locales together) under
frontend/lib/features/<feature>/. Wire navigation in
frontend/lib/app/router.dart.

Required invariants (cite by ID, do not restate):
- [[invariant:jwt-storage]] — never SharedPreferences
- [[invariant:category-strings]] exact strings per SPEC §2.1
- [[invariant:rating-scale]] 0.25-step star widget (19 levels)
- [[invariant:cursor-pagination]] via next_cursor + has_more
- [[invariant:checkin-caps]] client-side maxLength + 1-photo cap on submit
- [[invariant:i18n-fallback]] consumed from API; do not re-resolve

ARB key parity across en/ja/ko: add to ALL THREE files in the same change.
Stub Dio calls with `// STUB:` mock data until [[protocol:BUILD-006]] from
backend-engineer lands.

Communication: [[protocol:BUILD-007]] after slice complete. BUILD-009 on
every QA-routed fix. TaskUpdate per [[protocol:BUILD-013]].
```
