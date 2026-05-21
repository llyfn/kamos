# QA history

The active reports are kept at the top level of this directory. Older
phase-by-phase reports live under `archive/`.

## Active

- `qa_report_phase7_final.md` — Phase 7 cross-layer drift final, the
  current QA pin.
- `qa_report_phase7_flutter.md` — Phase 7 frontend-specific findings.
- `qa_report_phase7a_backend_qa.md` — the most recent integration
  check, run after Phase 7's backend slice (M-8 series).
- `qa_phase7_grafana_panel.json` — the observability dashboard
  artifact pinned to the Phase 7 panel layout.

## Archive

`archive/` holds the phase-by-phase QA snapshots from Phase 0 through
Phase 6a (plus the original `qa_report_backend.md` baseline). These are
kept for historical context; the active reports above supersede them.
Do not edit archived reports — file a fresh report at the top level if
new findings emerge.

When you ship a new phase, move the prior phase's pinned report under
`archive/` and update this README's "Active" list.
