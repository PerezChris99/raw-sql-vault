#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

fail() { echo "FAIL: $*" >&2; exit 1; }

command -v node >/dev/null 2>&1 || fail "Node.js is required for connector checks."
command -v python3 >/dev/null 2>&1 || fail "Python 3 is required for connector checks."

bash -n tools/lint_security.sh

echo "Checking Node.js syntax and mocked connector regression tests..."
node --check _infrastructure/connectors/nodejs/pg-connector.js
node --check tests/connectors/nodejs/pg-connector.test.js
node --test tests/connectors/nodejs/*.test.js

echo "Checking Python connector syntax and mocked regression tests..."
PYTHONPYCACHEPREFIX="${TMPDIR:-/tmp}/raw-sql-vault-pycache" python3 -m py_compile _infrastructure/connectors/python/pg_connector.py
python3 -m unittest discover -s tests/connectors/python -p 'test_*.py'

echo "Checking backup/restore shell syntax..."
bash -n tools/backup_postgres.sh tools/restore_postgres.sh

echo "Checking known-dangerous patterns..."
if grep -Eq "SET app\\.current_(tenant_id|user_id|roles)[[:space:]]*=[[:space:]]*[$%]" _infrastructure/connectors/nodejs/pg-connector.js _infrastructure/connectors/python/pg_connector.py; then
  fail "Found a parameterized SET statement; use transaction-local set_config."
fi
if grep -Eq "PASSWORD[[:space:]]+'CHANGE_IN_PRODUCTION'" _infrastructure/security/01_rbac_roles.sql; then
  fail "Found a known placeholder password in executable RBAC SQL."
fi
if grep -Fxq 'DO 
  fail "Found destructive role cleanup in the reusable RBAC bootstrap."
fi
if grep -Fq "RETURN p_role = ANY(security.current_app_roles())" _infrastructure/security/02_row_level_security.sql; then
  fail "Found authorization based on caller-settable app.current_roles."
fi
if grep -Fq "OR security.has_app_role(''admin'')" _infrastructure/security/02_row_level_security.sql; then
  fail "Found an implicit admin bypass in a generic RLS policy."
fi
if ! grep -Fq "auth_type = scram-sha-256" _infrastructure/performance/pgbouncer.ini; then
  fail "PgBouncer template must use SCRAM-SHA-256."
fi
if ! grep -Fq "client_tls_sslmode = require" _infrastructure/performance/pgbouncer.ini ||
   ! grep -Fq "server_tls_sslmode = verify-full" _infrastructure/performance/pgbouncer.ini; then
  fail "PgBouncer template is missing explicit TLS requirements."
fi
if grep -Eq "_executeWithRetry|_execute_with_retry" _infrastructure/connectors/nodejs/pg-connector.js _infrastructure/connectors/python/pg_connector.py; then
  fail "Found automatic retries of arbitrary SQL statements."
fi

echo "PASS: connector syntax, mocked Node regression, and static security guardrails."
echo "NOTE: this script does not execute SQL, test TLS handshakes, scan Git history, or measure performance."
 _infrastructure/security/01_rbac_roles.sql || grep -Fxq 'END $;' _infrastructure/security/01_rbac_roles.sql; then
  fail "Found malformed dollar quoting in the RBAC role bootstrap."
fi
if grep -Fq "DROP OWNED BY app_user" _infrastructure/security/01_rbac_roles.sql; then
  fail "Found destructive role cleanup in the reusable RBAC bootstrap."
fi
if grep -Fq "RETURN p_role = ANY(security.current_app_roles())" _infrastructure/security/02_row_level_security.sql; then
  fail "Found authorization based on caller-settable app.current_roles."
fi
if grep -Fq "OR security.has_app_role(''admin'')" _infrastructure/security/02_row_level_security.sql; then
  fail "Found an implicit admin bypass in a generic RLS policy."
fi
if ! grep -Fq "auth_type = scram-sha-256" _infrastructure/performance/pgbouncer.ini; then
  fail "PgBouncer template must use SCRAM-SHA-256."
fi
if ! grep -Fq "client_tls_sslmode = require" _infrastructure/performance/pgbouncer.ini ||
   ! grep -Fq "server_tls_sslmode = verify-full" _infrastructure/performance/pgbouncer.ini; then
  fail "PgBouncer template is missing explicit TLS requirements."
fi
if grep -Eq "_executeWithRetry|_execute_with_retry" _infrastructure/connectors/nodejs/pg-connector.js _infrastructure/connectors/python/pg_connector.py; then
  fail "Found automatic retries of arbitrary SQL statements."
fi

echo "PASS: connector syntax, mocked Node regression, and static security guardrails."
echo "NOTE: this script does not execute SQL, test TLS handshakes, scan Git history, or measure performance."
