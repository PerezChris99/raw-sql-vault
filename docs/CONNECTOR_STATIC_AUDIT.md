# Connector and Shared Infrastructure Static Audit

**Review date:** 15 October 2026  
**Scope:** selected shared Node.js/Python PostgreSQL connectors, PgBouncer example, and shared RBAC/RLS SQL.  
**Method:** source inspection through the repository tree. No connector unit tests, PostgreSQL execution, PgBouncer execution, penetration test, or secret-history scan was run. Findings are static-review findings and require reproduction and remediation evidence.

## Remediation status after PRs #95–#97

The original findings below describe what the source review found at the time. The following source changes have since been merged. **Runtime verification remains pending**, so “remediated in source” must not be read as “verified safe in production.”

| Original finding | Source status | Remaining evidence |
|---|---|---|
| Invalid parameterized SET statements | Replaced with parameterized, transaction-local set_config calls | Execute Node/Python connector tests against PostgreSQL |
| Pooled context leakage | Context is transaction-local and cleanup/rollback handling was improved | Verify pool reuse, exceptions, and transaction pooling on real PostgreSQL/PgBouncer |
| Blind retries of arbitrary SQL | Removed from Node and Python connectors | Exercise deadlocks, serialization failures, disconnects, and ambiguous writes |
| Known placeholder passwords | Removed from executable role creation | Scan reachable history; rotate credentials in any database that ran the old script |
| PgBouncer MD5 and TLS ambiguity | Template now uses SCRAM-SHA-256 and explicit client/backend TLS | Start the exact deployed version with real certificates and test authentication/hostname failure |
| Python DSN interpolation and weak TLS default | Structured libpq parameters and verify-full default; asyncpg receives an SSL context | Run Python driver and TLS integration tests |
| Caller-settable role GUC used as admin proof | Generic admin bypass removed; privileged helper checks database role membership | Execute RLS adversarial test with actual roles |
| Shared tenant GUC spoofing | **Known architectural limitation**; documentation explicitly requires trusted backend-only access or tenant-specific DB roles | Select and verify the actual deployment trust model; this cannot be solved by a lint rule alone |
| Destructive/non-idempotent RBAC bootstrap | Destructive role cleanup removed; group role creation made idempotent | Run bootstrap twice on a disposable database and inspect grants/ownership |
| Missing regression coverage | Mocked Node tests and a disposable-DB RLS test added | Execute them; add Python driver tests and record output |

The connector implementation also does not provide an audit-log sink. The legacy audit flag is retained for compatibility only and defaults to disabled. Do not claim audit events are being written unless an actual protected audit pipeline is deployed and tested.

## Executive summary

The shared connector and infrastructure examples currently contain issues that block describing them as production-ready. These examples should be treated as educational starting points until the tracked issues are fixed and tested.

## High-priority findings

### 1. Parameterized SET statements are not valid PostgreSQL parameter syntax

The Node.js connector uses statements shaped like SET app.current_tenant_id = $1. The Python synchronous connector uses SET app.current_tenant_id = %s, and the async connector similarly passes a placeholder to SET. PostgreSQL's SET command does not accept bind parameters in that form. Use a valid parameterized mechanism such as set_config with carefully chosen transaction-local semantics, and test it against the target engine.

Tracked in [issue #86](https://github.com/PerezChris99/raw-sql-vault/issues/86).

### 2. Pooled connection context can leak across borrowers

Tenant/user/request values are session state in the current examples. A pooled connection may be reused for a different request. Context must be transaction-local where possible, or reset reliably before and after use, including exception and rollback paths. The strategy must account for transaction pooling through PgBouncer.

Tracked in [issue #86](https://github.com/PerezChris99/raw-sql-vault/issues/86) and [issue #89](https://github.com/PerezChris99/raw-sql-vault/issues/89).

### 3. Generic automatic retry can duplicate or obscure write outcomes

The Node.js connector retries arbitrary SQL on selected errors using the same client. The Python connector retries OperationalError around general SQL statements. Some failures abort the current transaction; connection failures can leave a write outcome ambiguous. Retrying arbitrary statements is unsafe unless the whole operation has a defined idempotency and transaction boundary. Prefer bounded transaction-level retries only for known retryable errors and callbacks safe to rerun.

Tracked in [issue #87](https://github.com/PerezChris99/raw-sql-vault/issues/87).

### 4. Executable role bootstrap contains known placeholder passwords

The original RBAC SQL created login roles with the literal password CHANGE_IN_PRODUCTION. The current source no longer embeds that password and creates missing login roles without a password, so password authentication must be provisioned out of band. This does not rotate credentials on databases that ran the older script; use the credential remediation runbook and perform a history-aware secret scan.

Tracked in [issue #88](https://github.com/PerezChris99/raw-sql-vault/issues/88).

### 5. PgBouncer sample's production claims need qualification

The original example used MD5 authentication and left TLS settings commented out. The current template uses SCRAM-SHA-256, requires client TLS, and verifies backend TLS. The exact PgBouncer version, certificates, auth-file format, and session-state compatibility still require runtime validation.

Tracked in [issue #89](https://github.com/PerezChris99/raw-sql-vault/issues/89).

### 6. Python connector builds a DSN by interpolating values and defaults to sslmode=prefer

The original Python connector interpolated connection values into a DSN and defaulted to sslmode=prefer. The current source passes structured parameters and defaults to verify-full; asyncpg receives an SSL context. Run driver tests for special-character credentials, certificate verification, and hostname mismatch before treating the fix as verified.

Tracked in [issue #90](https://github.com/PerezChris99/raw-sql-vault/issues/90).

### 7. Caller-controlled RLS context may permit role/tenant spoofing

The shared RLS helpers read tenant, user, and role claims from PostgreSQL custom settings such as app.current_roles. A session able to issue arbitrary SQL may be able to set these custom settings itself. An RLS policy that trusts a caller-settable role string for an admin bypass is not a trustworthy authorization boundary by itself. The accepted design must define whether direct SQL users are in scope and bind authorization to database-authenticated identities or another trusted, constrained mechanism. Test attempted admin-role and tenant impersonation using actual database roles.

Tracked in [issue #93](https://github.com/PerezChris99/raw-sql-vault/issues/93). This is a static finding; no runtime exploit test was performed.

### 8. RBAC bootstrap reruns can have destructive or non-idempotent effects

The shared role bootstrap previously included a cleanup block that reassigned ownership and dropped privileges for app_user, and several group-role declarations were not idempotent. Re-running a setup script should not silently remove ownership/grants or fail because a group role already exists. The bootstrap has now been adjusted to create missing group roles without the destructive cleanup block. Existing databases that ran the old script still need an owner-reviewed permission/credential review; source changes do not reverse past database effects.

The login roles no longer receive a known placeholder password when newly created. If an older version was executed, rotate or revoke the previously known credential using a planned DBA operation; do not assume removing the literal from the file rotated existing secrets.

## Required follow-up validation

- Add focused Node.js and Python connector tests for parameter binding, pooled-context reset, transactions, retries, TLS, credentials with special characters, rate-limit memory, and shutdown.
- Run tests against a disposable PostgreSQL instance; mocks alone cannot establish RLS or transaction semantics.
- Test the selected PgBouncer mode with the exact session-context strategy.
- Scan current source and reachable Git history for real secrets and sensitive records.
- Review SECURITY DEFINER functions for ownership, grants, and safe search_path.
- Reassess any “production-ready” wording in shared files and package examples.
- Record exact engine versions, commands, output, and limitations.

Tracked in [issue #91](https://github.com/PerezChris99/raw-sql-vault/issues/91), with the wider history scan tracked in [issue #74](https://github.com/PerezChris99/raw-sql-vault/issues/74).

## Release decision

**Do not present the shared connectors or infrastructure templates as production-ready until these findings are resolved and tested.** This report is not a complete security audit, and absence of additional findings is not evidence that no other defects exist.
