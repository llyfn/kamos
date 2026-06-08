#!/usr/bin/env bash
# Validate the .claude/ harness: every cited invariant/protocol exists,
# every agent has a matching skill pointer, every skill has frontmatter.
#
# Exits 0 on success, 1 on any failure. Intended for CI.

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CLAUDE_DIR="$ROOT/.claude"
ERRORS=0
WARNINGS=0

red() { printf '\033[31m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
fail() { red "FAIL  $*"; ERRORS=$((ERRORS+1)); }
warn() { yellow "WARN  $*"; WARNINGS=$((WARNINGS+1)); }
ok()   { green "OK    $*"; }

# ---------------------------------------------------------------------------
# 1. Every cited [[invariant:<id>]] resolves to a file in .claude/invariants/
# ---------------------------------------------------------------------------
echo "▸ Verifying invariant references"
INVARIANT_IDS=$(ls "$CLAUDE_DIR/invariants" 2>/dev/null \
  | grep -E '^[a-z0-9-]+\.md$' \
  | sed 's/\.md$//' \
  | grep -v '^README$' \
  | sort -u)

if [ -z "$INVARIANT_IDS" ]; then
  fail "no invariant files found under .claude/invariants/"
fi

CITED_INVARIANTS=$(grep -rho '\[\[invariant:[a-z0-9-]\+\]\]' "$CLAUDE_DIR" 2>/dev/null \
  | sed 's/\[\[invariant://;s/\]\]//' \
  | sort -u)

for cited in $CITED_INVARIANTS; do
  if ! printf '%s\n' "$INVARIANT_IDS" | grep -qx "$cited"; then
    fail "[[invariant:$cited]] cited but file .claude/invariants/$cited.md does not exist"
  fi
done

# Unused invariants are a warning, not a failure (catalog can predate adoption)
for id in $INVARIANT_IDS; do
  if ! printf '%s\n' "$CITED_INVARIANTS" | grep -qx "$id"; then
    warn "invariant '$id' is in the catalog but never cited"
  fi
done

[ "$ERRORS" -eq 0 ] && ok "all invariant references resolve"

# ---------------------------------------------------------------------------
# 2. Every cited [[protocol:<ID>]] resolves to a row in .claude/protocols/
# ---------------------------------------------------------------------------
echo "▸ Verifying protocol references"
PROTOCOL_IDS=""
PROTOCOL_SCOPES=""
for f in "$CLAUDE_DIR/protocols"/*.md; do
  [ -f "$f" ] || continue
  base=$(basename "$f")
  [ "$base" = "README.md" ] && continue
  IDS_HERE=$(grep -oE '\|[[:space:]]+(BUILD|REVIEW|SWEEP)-[0-9]+[[:space:]]+\|' "$f" \
    | sed 's/|//g;s/[[:space:]]//g' | sort -u)
  PROTOCOL_IDS="$PROTOCOL_IDS $IDS_HERE"
  SCOPE_HERE=$(grep -oE '^id: protocol:[a-z-]+' "$f" | sed 's/id: protocol://')
  PROTOCOL_SCOPES="$PROTOCOL_SCOPES $SCOPE_HERE"
done

CITED_PROTOCOLS=$(grep -rho '\[\[protocol:[A-Za-z0-9-]\+\]\]' "$CLAUDE_DIR" 2>/dev/null \
  | sed 's/\[\[protocol://;s/\]\]//' \
  | sort -u)

for cited in $CITED_PROTOCOLS; do
  # Accept either a specific message id (BUILD-004) or a protocol-file scope (build-pipeline)
  if ! printf '%s ' $PROTOCOL_IDS | grep -qw -- "$cited" \
     && ! printf '%s ' $PROTOCOL_SCOPES | grep -qw -- "$cited"; then
    fail "[[protocol:$cited]] cited but not defined in any .claude/protocols/*.md"
  fi
done
[ "$ERRORS" -eq 0 ] && ok "all protocol references resolve"

# ---------------------------------------------------------------------------
# 3. Every agent file points at an existing skill
# ---------------------------------------------------------------------------
echo "▸ Verifying agent ↔ skill pairings"
SKILL_NAMES=$(ls -d "$CLAUDE_DIR/skills"/*/ 2>/dev/null \
  | sed 's|.*/skills/||;s|/$||' | sort -u)

for agent_file in "$CLAUDE_DIR/agents"/*.md; do
  base=$(basename "$agent_file")
  [ "$base" = "_TEMPLATE.md" ] && continue
  [ "$base" = "INDEX.md" ] && continue
  # "Follow the `<skill>` skill" — extract referenced skill names
  cited_skills=$(grep -oE 'Follow the `[a-z0-9-]+` skill' "$agent_file" \
    | sed 's/Follow the `//;s/` skill//' | sort -u)
  if [ -z "$cited_skills" ]; then
    warn "agent file $base does not cite a skill"
    continue
  fi
  for skill in $cited_skills; do
    if ! printf '%s\n' "$SKILL_NAMES" | grep -qx "$skill"; then
      fail "agent $base points at skill '$skill' which does not exist under .claude/skills/"
    fi
  done
done
[ "$ERRORS" -eq 0 ] && ok "every agent's skill citation resolves"

# ---------------------------------------------------------------------------
# 4. Every skill has the required frontmatter fields
# ---------------------------------------------------------------------------
echo "▸ Verifying skill frontmatter"
for skill_file in "$CLAUDE_DIR/skills"/*/SKILL.md; do
  base=$(dirname "$skill_file" | sed 's|.*/||')
  for field in name description recommended_model; do
    if ! awk '/^---$/{f++;next} f==1' "$skill_file" | grep -q "^$field:"; then
      fail "skill $base missing frontmatter field: $field"
    fi
  done
done
[ "$ERRORS" -eq 0 ] && ok "all skills carry required frontmatter"

# ---------------------------------------------------------------------------
# 5. Sanity: no skill's SPEC invariants section restates a catalog rule
#    (heuristic: if a skill mentions "0.25" or "SharedPreferences" outside a
#    fenced code block while also citing the invariant, that's fine; we only
#    fail on a known-wrong literal like the old "0.5 steps" drift.)
# ---------------------------------------------------------------------------
echo "▸ Sanity checks for known drifts"
for skill_file in "$CLAUDE_DIR/skills"/*/SKILL.md; do
  if grep -q "0.5 increments\|0.5 steps\|10 levels" "$skill_file" 2>/dev/null; then
    fail "skill $(dirname "$skill_file" | sed 's|.*/||') still says '0.5 increments / 10 levels' — rating is 0.25 in 19 levels per [[invariant:rating-scale]]"
  fi
  if grep -q "4 photos\|four photos\|up to 4 photo" "$skill_file" 2>/dev/null; then
    fail "skill $(dirname "$skill_file" | sed 's|.*/||') still says '4 photos' — cap is 1 per [[invariant:checkin-caps]]"
  fi
done
[ "$ERRORS" -eq 0 ] && ok "no known drifts present"

# ---------------------------------------------------------------------------
echo
echo "Summary: $ERRORS error(s), $WARNINGS warning(s)"
[ "$ERRORS" -eq 0 ] || exit 1
exit 0
