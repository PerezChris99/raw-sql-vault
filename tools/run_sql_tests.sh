#!/usr/bin/env bash
set -euo pipefail

if ! command -v psql >/dev/null 2>&1; then
  echo "ERROR: psql is required (PostgreSQL 15+ client)." >&2
  exit 127
fi

if [[ -z "${DATABASE_URL:-}" ]]; then
  echo "ERROR: Set DATABASE_URL to a dedicated disposable PostgreSQL/PostGIS test database." >&2
  echo "Example: DATABASE_URL=postgresql://postgres:postgres@localhost:5432/vault_test $0" >&2
  exit 2
fi

case "$DATABASE_URL" in
  *production*|*prod*) echo "ERROR: refusing an ambiguous production-like DATABASE_URL." >&2; exit 2 ;;
esac

echo "Running Raw SQL Vault regression tests against the explicitly configured database."
psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -f sql/tests/run_all.sql