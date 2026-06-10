#!/usr/bin/env bash
# Drift guard for the canonical product invariants in specs/invariants.yaml.
# Scans .claude/skills, .claude/agents, and .claude/CLAUDE.md for prose
# restatements of values that belong to the YAML. Code blocks (```...```)
# are intentionally skipped — the gate is about narrative drift, not about
# pedagogical example snippets.
set -euo pipefail

SKILLS_DIR="${1:-.claude/skills}"
CLAUDE_MD=".claude/CLAUDE.md"
HARNESS_MD=".claude/HARNESS.md"
AGENTS_DIR=".claude/agents"

FORBIDDEN=(
  'NUMERIC\(3,[12]\)'
  '0\.5[- ]step'
  '0\.25[- ]step'
  '0\.5 increments?'
  '0\.25 increments?'
  '\b10 levels\b'
  '\b19 levels\b'
  '\b[0-9]+ photos?\b'
  'max ?[0-9]+ photos?'
  '≤ ?[0-9]+ photos?'
  '500 char(s|acters)?'
  '\b30 days?\b'
  '\b30-day\b'
  '\b32 bytes?\b'
  '≥ ?32 bytes?'
)

scan_targets=("$SKILLS_DIR" "$AGENTS_DIR")
[ -f "$CLAUDE_MD" ] && scan_targets+=("$CLAUDE_MD")
[ -f "$HARNESS_MD" ] && scan_targets+=("$HARNESS_MD")

# Strip fenced code blocks per file so the grep below only sees prose.
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
for target in "${scan_targets[@]}"; do
  [ -e "$target" ] || continue
  if [ -d "$target" ]; then
    files=$(find "$target" -name '*.md')
  else
    files="$target"
  fi
  for f in $files; do
    out="$scratch/${f//\//__}"
    awk 'BEGIN{infence=0} /^```/{infence=!infence; next} !infence{print FILENAME":"NR":"$0}' \
      "$f" > "$out"
  done
done

bad=0
# Use find -exec rather than shell globbing so leading-dot scratch filenames
# (mapped from .claude/...) aren't silently skipped.
for pattern in "${FORBIDDEN[@]}"; do
  hits=$(find "$scratch" -type f -exec grep -hiE "$pattern" {} + 2>/dev/null || true)
  if [ -n "$hits" ]; then
    echo "::error::canonical-invariant drift: literal matching '$pattern' in markdown prose"
    echo "$hits" | sed 's/^/  /'
    bad=1
  fi
done

if [ "$bad" -ne 0 ]; then
  cat <<'EOF'

Drift guard failed. Skill / agent / CLAUDE markdown prose MUST NOT restate a
value that lives in specs/invariants.yaml (rating range / step / levels / db
type, photo cap, review cap, username hold days, etc.). Reference the YAML key
or the generated constants instead — see .claude/HARNESS.md.

EOF
  exit 1
fi

echo "OK: no canonical-invariant drift in $SKILLS_DIR."
