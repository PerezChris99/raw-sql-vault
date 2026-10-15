# Database Incident Response Playbook

Adapt this baseline to the actual system, contracts, jurisdiction, and severity.

## Prepare
Assign an incident lead, database operator, application owner, security/privacy contact, communications owner, and business decision-maker. Maintain architecture, restore procedures, escalation contacts, access inventory, and tested backups. Define severity and notification requirements in advance.

## Triage
1. Protect people and data; pause unsafe automation if needed.
2. Determine impact, start time, affected services, and whether the issue concerns availability, integrity, confidentiality, or performance.
3. Preserve relevant logs and metrics with controlled access.
4. Avoid destructive diagnostics before evidence and recovery options are understood.
5. Check recent deploys/migrations, capacity, connections, lock waits, replication, storage, and provider status.
6. Record decisions and timestamps in an access-controlled incident log.

## Containment
Choose the least disruptive action that reduces harm: disable a feature, rotate a compromised credential, isolate a workload, limit traffic, pause a migration, or terminate runaway sessions when justified. Consider transaction rollback, in-flight work, data loss, and audit requirements.

## Recovery
Use the documented recovery plan. Confirm backup integrity and recovery point. Restore to an isolated environment where feasible, validate schema/migration state, run smoke tests, reconcile critical records, and obtain owner approval before reopening traffic. A database accepting connections is not sufficient proof of recovery.

## Communications and privacy
Communicate known facts, impact, mitigation, and next update time. Avoid speculation. Follow applicable notification obligations and organisational policy. Do not place secrets or personal records in public issues.

## Post-incident review
Document timeline, impact, cause and contributing factors, detection/response gaps, integrity checks, recovery objectives, corrective actions with owners/dates, and updates to monitoring/tests/runbooks. Focus on system improvement.

Raw SQL Vault is not an on-call service. Deploying teams must define accountable response arrangements. This playbook is not a promise of support or response time.
