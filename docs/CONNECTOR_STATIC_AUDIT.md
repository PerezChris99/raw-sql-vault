# Connector and Shared Infrastructure Static Audit

**Review date:** 15 October 2026  
**Scope:** selected shared Node.js/Python PostgreSQL connectors, PgBouncer example, and shared RBAC/RLS SQL.  
**Method:** source inspection through the repository tree. No connector unit tests, PostgreSQL execution, PgBouncer execution, penetration test, or secret-history scan was run. Findings are static-review findings and require reproduction and remediation evidence.

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

The shared RBAC SQL creates login roles with the literal password CHANGE_IN_PRODUCTION. If executed unchanged, it creates credentials that are known from source. The idempotent role-creation blocks do not automatically rotate an existing role's password. Replace executable password literals with a controlled provisioning process and separate NOLOGIN group roles from login identities.

Tracked in [issue #88](https://github.com/PerezChris99/raw-sql-vault/issues/88).

### 5. PgBouncer sample's production claims need qualification

The example shows MD5 authentication, transaction pooling, and TLS options commented out. Production settings need an explicit supported-version/authentication decision, certificate verification, and documented session-state limitations. Session variables, prepared statements, temporary tables, advisory locks, and other features may behave differently under transaction pooling.

Tracked in [issue #89](https://github.com/PerezChris99/raw-sql-vault/issues/89).

### 6. Python connector builds a DSN by interpolating values and defaults to sslmode=prefer

The Python connector constructs a libpq DSN using string interpolation of host, database, username, and password. Special characters can break the DSN and unsafe values can alter its interpretation. The default sslmode=prefer does not require verified TLS. Use structured connection parameters or a safely quoted DSN, avoid logging credentials, and define secure production TLS settings.

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
