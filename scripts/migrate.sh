#!/bin/sh
# Idempotent migration runner.
#
# Applies migrations/*.sql in lexical order, recording each in a
# schema_migrations table so re-runs (every CD deploy) only apply what's
# new. Safe to run repeatedly against the same database.
#
# POSIX sh (runs inside postgres:18-alpine, which has busybox sh, not bash).
#
# Usage:
#   PSQL_URL=postgres://user:pass@host:5432/db?sslmode=require scripts/migrate.sh [migrations_dir]
set -eu

: "${PSQL_URL:?PSQL_URL is required}"
DIR="${1:-migrations}"

psql "$PSQL_URL" -v ON_ERROR_STOP=1 -q -c \
  "CREATE TABLE IF NOT EXISTS schema_migrations (filename text PRIMARY KEY, applied_at timestamptz NOT NULL DEFAULT now());"

# Migration filenames are repo-controlled (NNN_name.sql), so direct
# interpolation is safe — no user input reaches this SQL.
for f in "$DIR"/*.sql; do
  base="$(basename "$f")"
  applied="$(psql "$PSQL_URL" -tA -c "SELECT 1 FROM schema_migrations WHERE filename = '$base'")"
  if [ "$applied" = "1" ]; then
    echo "✓ $base (already applied)"
    continue
  fi
  echo "→ $base"
  psql "$PSQL_URL" -v ON_ERROR_STOP=1 -q -f "$f"
  psql "$PSQL_URL" -v ON_ERROR_STOP=1 -q -c \
    "INSERT INTO schema_migrations (filename) VALUES ('$base')"
done
echo "migrations up to date"
