#!/usr/bin/env bash
# Regenerate Go + Dart constants from specs/invariants.yaml.
#
# Single source of truth: specs/invariants.yaml. Emits:
#   backend/internal/spec/spec.go
#   frontend/lib/core/spec/spec.dart
#
# CI invokes this then `git diff --exit-code` to catch drift.
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
exec python3 "${REPO_ROOT}/scripts/gen-spec.py"
