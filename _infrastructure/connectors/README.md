# Shared PostgreSQL Connectors: Safe Use and Verification

## What the connector does

The Node.js and Python examples provide a starting point for pooled PostgreSQL access. They parameterize query values, apply bounded statement timeouts, and can attach trusted request context to a transaction. They are not a complete authorization system, distributed rate limiter, secrets manager, or production SRE service.

## The key safety rules

- **Use a trusted application backend.** Tenant/user context stored in custom PostgreSQL settings is caller-settable. It is useful as defense in depth against application mistakes, but it does not prove identity against a caller who can issue arbitrary SQL using the same database role. Do not expose a shared app_service login directly to end users.
- **Use transaction-local context.** The connector calls set_config(name, value, true) inside a transaction. The third argument makes the value local to the current transaction, so it is reset at commit/rollback rather than leaking to the next pool borrower.
- **Do not blindly retry arbitrary statements.** If the network drops after a write, the client may not know whether PostgreSQL committed it. Retrying can double-book an appointment or repeat a payment. These connectors execute each statement once; applications needing retries must classify retryable errors and retry the entire transaction only when all side effects are idempotent.
- **Use verified TLS in production.** Node.js production mode requires DB_SSL=true and certificate verification. Python defaults to sslmode=verify-full; production accepts only verify-ca or verify-full. Use an explicit local-development setting only for a local disposable database.
- **Keep credentials out of source.** The Python connector passes structured connection parameters to libpq, so quotes and spaces in a password remain values instead of breaking an interpolated DSN.
- **Bound resource usage.** Pool bounds, connection timeouts, statement timeouts, and in-memory rate-limit state reduce common failure modes. In-memory limits are per process and are not a distributed security control.

## Example: a payment or booking request

```js
const result = await db.transaction(async (client) => {
  // Lock and idempotency constraints belong in domain SQL as well.
  const account = await client.query(
    'SELECT id, balance FROM accounts WHERE id = $1 FOR UPDATE',
    [accountId]
  );
  // Validate domain invariants before writing.
  await client.query(
    'INSERT INTO ledger_entries (account_id, amount, request_id) VALUES ($1, $2, $3)',
    [accountId, amount, requestId]
  );
  return account.rows[0];
}, { tenantId, userId, requestId });
```

**Plain language:** the transaction keeps the checks and writes together. If one step fails, the database rolls back the transaction. A transaction does not automatically protect against duplicate requests; domain-level idempotency constraints are still required.

**Technical detail:** never interpolate user input into SQL identifiers or query text. Parameters are for values; dynamic identifiers require a strict allow-list and identifier quoting. A caller-supplied tenant value is not a substitute for authenticating the caller.

## Run checks

From the repository root:

```bash
node --test tests/connectors/nodejs/*.test.js
node --check _infrastructure/connectors/nodejs/pg-connector.js
python -m py_compile _infrastructure/connectors/python/pg_connector.py
bash tools/lint_sql.sh
```

The Node tests mock the pg client and validate connector control flow only. They do **not** prove PostgreSQL RLS semantics, TLS handshake correctness, PgBouncer compatibility, Python driver behaviour, concurrency, or performance. Those require integration testing against a disposable, version-pinned PostgreSQL instance with the required extensions and actual database roles.

## Current validation boundary

The source changes and regression test were committed through GitHub. This environment does not currently have psql, Docker, or an available database server, and the repository cannot be cloned here due to unavailable GitHub network resolution. SQL execution, Python-driver integration, RLS adversarial testing, PgBouncer validation, load testing, secret/history scanning, and restore drills remain unverified until run in a suitable environment.
