# Production Standards — Raw SQL Vault

These standards are review criteria, not proof that a system is production-ready.

## Schema and integrity

- Model entities, cardinality, functional dependencies and ownership before writing DDL. Target 3NF or BCNF where appropriate; denormalise only with measured justification and reconciliation.
- Declare primary/foreign keys, NOT NULL, UNIQUE and CHECK constraints for actual invariants. Use ON DELETE RESTRICT by default; document justified cascades.
- Index frequently joined/filtered foreign-key columns unless an existing index covers the access pattern or measurement justifies an exception.
- Use exact NUMERIC/DECIMAL for money, never binary floating point. Store an explicit currency code and choose scale/range for the domain.
- Use TIMESTAMPTZ for instants and define the business time zone for local-calendar reports.
- UUIDv7 is not built into PostgreSQL 15; declare/test an external generator if chosen.
- Comment tables/columns whose meaning, units, derivation or sensitivity are not self-evident.

## Default metadata and exceptions

For ordinary mutable business/master tables, prefer a primary key, created_at, updated_at, an authorised actor reference where one exists, and is_deleted only if logical deletion fits the lifecycle.

Do not invent a global users table just to fill created_by. Append-only audit events, pure junctions, immutable reference snapshots and external staging tables may need different metadata; document the reason. Soft deletion does not replace retention policy, access revocation or legally required deletion. Audit records must not be silently soft-deleted.

## SQL and performance

- Bind all user values as parameters. Never concatenate untrusted input into SQL. For dynamic identifiers, use a strict allow-list and a trusted quoting mechanism.
- Mark each script's engine/version and prerequisites. Select explicit columns in application/reporting interfaces.
- Index decisions are hypotheses to test, not universal speed guarantees. Measure query plans, table size, write overhead, selectivity and concurrency.
- Use EXPLAIN and, in safe staging, EXPLAIN (ANALYZE, BUFFERS) for important PostgreSQL paths. ANALYZE executes the query.
- Keyset pagination is often preferable for deep mutable feeds with stable ordering; OFFSET remains acceptable for shallow pages when justified.
- Partition according to workload, retention and pruning needs; there is no universal row-count threshold.
- Use time-based window frames when the requirement specifies calendar time; ROWS counts observations, not days.
- Test duplicate, empty, NULL, boundary, retry, concurrent-update and no-permission behavior where relevant.

## Transactions and migrations

- Keep migrations ordered, reviewable and forward-corrected after they reach a shared environment.
- Test clean installation and supported upgrade paths. Document rollback/recovery steps and locking implications.
- Most schema/data migrations should be transactional, but operations that cannot run in a transaction must be isolated and documented.
- Use IF NOT EXISTS / IF EXISTS when useful, but do not hide incompatible schemas behind them. Avoid unreviewed DROP ... CASCADE.
- Batch jobs require stable ordering, checkpoints, idempotency, error handling and coordination between workers. A sleep alone is not safe batching.
- Backups are not validated until restore drills pass. Record RPO/RTO, monitoring ownership and recovery procedures.

## Security and privacy

- Runtime roles should not own tables and should have only the required privileges. Separate migration-owner credentials from application credentials.
- RLS is useful for policy-separated data. Test permitted and denied reads/writes; remember superusers and BYPASSRLS roles can bypass it.
- Set tenant context through trusted authentication middleware and transaction-local settings with connection-pool hygiene. A caller-controlled HTTP header is not identity proof.
- SECURITY DEFINER routines require a threat review, safe search_path, qualified objects and narrow EXECUTE grants. Prefer invoker rights otherwise.
- Protect audit logs and minimise logged personal data. Do not record tokens, passwords or unnecessary sensitive payloads.
- Use synthetic seeds only. Classify data and define purpose, access, retention, export, deletion and disclosure controls.
- High-impact workflows such as identity, health, finance, justice, elections, tax, benefits and humanitarian aid need accountable human oversight and correction/appeal routes.

## Production readiness gate

SQL that parses is not automatically production-ready. Deployment approval requires independent security/privacy review, migration rehearsal, performance/concurrency tests, monitoring, successful backup restoration, operational ownership, user acceptance and relevant legal/sector review. Record actual test commands and results; never invent a passing result.