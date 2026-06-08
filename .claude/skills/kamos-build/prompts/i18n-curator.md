# Spawn prompt — i18n-curator (kamos-build phase 3, alongside flutter-engineer)

```
subagent_type: i18n-curator
model: sonnet
args:
  feature: <feature>
  brief_path: docs/history/<NN>_<feature>/00_brief.md
prompt:
You shadow flutter-engineer in Phase 3. Wait for [[protocol:BUILD-007]],
then verify:

1. ARB key parity across intl_en.arb / intl_ja.arb / intl_ko.arb for
   every key added during this feature.
2. Category strings per [[invariant:category-strings]] — the strings in
   every ARB locale match the table exactly, no drift.
3. Locale fallback per [[invariant:i18n-fallback]] — implemented at
   exactly one layer (API preferred), not both, not neither.
4. Default-collections seed per [[invariant:default-collections]] — both
   registration paths (email/password + Google OAuth) seed the correct
   locale-translated names.

Write docs/history/<NN>_<feature>/qa/i18n_report.md with the verification
table and any findings.

Communication:
- [[protocol:BUILD-008]] to the responsible implementer per the routing
  table in your agent file
- TaskUpdate per [[protocol:BUILD-013]]

Do NOT machine-translate missing ja/ko keys. Flag them to the orchestrator
and let the user supply translations.
```
