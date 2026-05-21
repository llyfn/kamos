# Code-review history

The latest per-phase sweep reports live at the top level; the original
Phase 4 deep-dive reviews (arch / security / perf / style + the
synthesized REVIEW_REPORT) are archived under `phase4/`.

## Active

- `post_phase5_sweep.md` — sweep after Stage 5 (DB & query performance).
- `post_phase6_sweep.md` — sweep after Stage 6 (Flutter typed API
  client).
- `post_phase7_sweep.md` — sweep after Stage 7 (cross-layer drift
  cleanup); the current pinned review.

## Archive

`phase4/` holds:

- `00_scope.md` — the scope the four reviewer agents ran against.
- `arch_findings.md`, `security_findings.md`, `perf_findings.md`,
  `style_findings.md` — per-reviewer raw output.
- `REVIEW_REPORT.md` — the orchestrator's merged + prioritized synthesis.
- `applied.md` — the diff between what was filed and what was actually
  fixed across Stages 5–7.

These are kept verbatim; do not edit them. New review output lands at
the top level via `post_phaseN_sweep.md`.
