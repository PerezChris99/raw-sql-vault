# Security and Threat Model

**Status:** baseline guidance; package-specific testing remains required.

## Objectives and assets
Protect confidentiality, integrity, availability, accountability, and recoverability. Assets may include credentials, personal data, financial/health records, case metadata, workflow decisions, audit history, migration state, backups, and service availability.

## Trust boundaries
Document boundaries between user input and application code, application roles and PostgreSQL, tenant A and tenant B, runtime and migration roles, operators and production administration, production data and exports/backups, and repository source and deployed artifacts.

## Threats to assess
- SQL injection through values or dynamic identifiers.
- Excessive grants, role inheritance, ownership, unsafe SECURITY DEFINER routines, or unsafe search paths.
- RLS bypass, permissive policies, missing tenant predicates, or untrusted session variables.
- Cross-tenant access, unsafe views, and direct object reference flaws.
- Duplicate retries, races, lost updates, double booking, over-allocation, and partial transactions.
- Malformed input, unsafe casts, unbounded requests, and constraint bypass.
- Secrets in history, fixtures, logs, dumps, or issue reports.
- Denial of service from expensive queries, lock contention, connection exhaustion, and storage exhaustion.
- Destructive migrations, engine mismatch, and incomplete restores.

## Minimum controls
1. Parameterize values; allow-list and safely quote dynamic identifiers.
2. Separate owner/migration, runtime, read-only, and support roles where appropriate.
3. Review SECURITY DEFINER owner, fixed safe search_path, grants, and input validation.
4. Test RLS using multiple roles, including cross-tenant denial and bypass attempts.
5. Enforce invariants with constraints and transactions where feasible, not only application checks.
6. Define idempotency and retry semantics for retryable side effects.
7. Bound results and review plans on representative data.
8. Keep secrets out of source; rotate any potentially exposed credential.
9. Minimise sensitive data and control logs, exports, and backups.
10. Monitor authentication failures, privilege changes, denied access, lock waits, deadlocks, storage, replication, and backup health as appropriate.

For relevant packages test unauthorised reads/writes, cross-tenant access, duplicates, invalid transitions, over-allocation, invalid dates, concurrent conflicts, rollback after failure, and direct writes that bypass routines. Document omissions and reasons.

Record commit, engine/version, roles, commands, results, limitations, reviewer, and date. Static grep or the presence of a security file does not prove absence of vulnerabilities. High-risk domains need data-owner, legal/privacy, human-oversight, and deployment-specific threat-model review.

Follow [Incident Response](INCIDENT_RESPONSE.md) and [SECURITY.md](../SECURITY.md). Do not put secrets or sensitive incident details in public issues. This document is a review method, not a certification.
