#!/usr/bin/env bash
# Stage 7 (ARCH-011) — KAMOS design-token codegen.
#
# Single source of truth: design/tokens.json. This script reads it and
# emits per-platform sinks. The plan covers three targets:
#
#   - admin/src/lib/tokens.ts     (TypeScript export; emitted by THIS pass)
#   - design/colors_and_type.css  (CSS variables; deferred — hand-maintained)
#   - frontend/lib/app/theme.dart (Dart class section between markers; deferred — hand-maintained)
#
# CONTRIBUTING.md documents the partial scope. The admin sink is the
# easiest target (Node already available in the admin toolchain) and
# carries the most drift risk because the React app references colors
# directly. The CSS + Dart sinks land in a follow-up Stage.
#
# Behaviour:
#   - Idempotent — running twice in a row produces no diff.
#   - Exits 0 on success. CI invokes this and then `git diff --exit-code`.
#   - Requires node (>=18) on PATH for the embedded JS.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TOKENS_JSON="${REPO_ROOT}/design/tokens.json"
ADMIN_TS="${REPO_ROOT}/admin/src/lib/tokens.ts"

if [[ ! -f "$TOKENS_JSON" ]]; then
  echo "gen-tokens: $TOKENS_JSON missing" >&2
  exit 1
fi
if ! command -v node >/dev/null 2>&1; then
  echo "gen-tokens: node not on PATH (>=18 required)" >&2
  exit 1
fi

node "${REPO_ROOT}/scripts/gen-tokens.js" "$TOKENS_JSON" "$ADMIN_TS"

echo "gen-tokens: wrote ${ADMIN_TS#$REPO_ROOT/}"
