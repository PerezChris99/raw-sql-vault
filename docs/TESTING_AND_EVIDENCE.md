# Testing Strategy and Evidence Standard

## Evidence beats file presence
A schema, migration, test script, or security file is not proof that it works. Status claims must identify the commit, engine/version, command, output, and limitations.

## Test layers
1. Repository inventory and required-file checks.
2. Static checks: shell syntax, include paths, SQL lint, forbidden patterns, secret scanning.
3. Parse/compile checks on the declared engine.
4. Functional, constraint, lifecycle, and reporting tests.
5. Negative tests for invalid input and permission denial.
6. Transaction, rollback, idempotency, concurrency, and partial-failure tests.
7. Security tests for least privilege, RLS, tenant isolation, and unsafe SQL.
8. Performance tests on representative data and workload.
9. Backup/restore and migration-recovery exercises.
10. Domain owner and user acceptance tests.

## Existing commands
Static inventory: run `bash tools/lint_sql.sh` from the repository root.

Connector and security static checks: run `bash tools/lint_security.sh`.

Secret scan: install a trusted current Gitleaks release, fetch every intended remote ref, then run `bash tools/scan_secrets.sh`. This scans the working tree and locally reachable history; it cannot inspect refs/history that were not fetched. A finding requires triage and immediate rotation where a real credential is exposed. A clean scan is evidence for the scanned snapshot, not proof that no secret exists. This parses Node.js files, executes the mocked Node connector regression tests, compiles Python source, and checks for known unsafe patterns. It is not a substitute for PostgreSQL execution or a history-aware secret scanner.

Integrated SQL suite: set DATABASE_URL to a disposable PostgreSQL 15+ test database and run bash tools/run_sql_tests.sh. Install required extensions such as PostGIS only when needed. Never target production or valuable data. Keep credentials out of source and issues.

## Evidence record
Record commit SHA, date/operator, OS/environment, exact engine/extensions, exact command, exit code, relevant output, pass/fail/skip counts, dataset scale/source, limitations, reviewer, and follow-up issues. Do not include secrets or personal data.

## Status vocabulary
- **Indexed:** catalogue entry only.
- **Designed:** scope, model, assumptions, and access boundaries documented.
- **Implemented:** agreed files and package documentation exist.
- **Verified:** declared tests passed on the stated engine/version and evidence is recorded.
- **Operationally approved:** verification plus independent security/privacy, operations, recovery, data-owner, and acceptance gates completed for a specific deployment.

Verified does not mean universally production-ready. Operational approval is context-specific and expires when assumptions change.

## Failure and CI policy
Do not weaken assertions merely to obtain a green result. Track flaky, skipped, environment-dependent, and unsupported cases. The owner explicitly requested that no GitHub Actions or other repository CI workflows be added. This does not remove the need for tests; execution evidence must come from an approved manual/local environment or another expressly approved mechanism.

## RLS context regression test

After applying the shared RBAC and RLS setup to a **disposable** PostgreSQL database with a trusted DBA role, run `psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -f sql/tests/10_rls_context_regression.sql`. The test checks that a caller-set `app.current_roles=admin` value does not bypass the generic tenant policy and demonstrates that a caller who can issue arbitrary SQL as the shared application role can also set a different tenant context. The latter is an explicit trust-boundary demonstration, not a passing authorization property; use trusted backend-only access or tenant-specific database roles for stronger isolation.

## Current evidence boundary
A successful end-to-end SQL suite has not been confirmed in the current review. Static inventory is not a substitute. Track execution in [issue #73](https://github.com/PerezChris99/raw-sql-vault/issues/73).
