# Raw SQL Vault — Conventions and Engineering Standards

**Applies to:** all new units and material changes  
**Primary dialect:** PostgreSQL 15+  
**Secondary dialects:** MySQL 8 and SQL Server 2019 when syntax or behavior differs meaningfully

## 1. Repository layout

The existing `practice/` and `projects/` tree remains intact. New indexed sector/domain solutions live in dedicated top-level namespaces rather than mixing runnable projects into tutorial exercises.

```text
raw-sql-vault/
├── README.md
├── CONTRIBUTING.md
├── docs/
│   ├── MASTER_INDEX.md
│   ├── CONVENTIONS.md
│   ├── ROADMAP.md
│   ├── GITHUB_FLOW.md
│   └── audits/
├── practice/                         # existing learning curriculum
├── projects/                         # existing projects
├── uganda/
│   ├── central-government/<slug>/
│   ├── agencies/<slug>/
│   ├── local-government/<slug>/
│   └── private-and-ngo/<slug>/
├── worldwide/<domain>/<slug>/
├── shared/
│   ├── reference-data/
│   ├── audit-patterns/
│   ├── rls-patterns/
│   ├── migration-templates/
│   └── test-fixtures/
└── tools/
    ├── run_all.sh
    ├── lint_sql.sh
    └── docker-compose.yml
```

Do not create a project folder just to reserve a name. Add the folder when its first package is ready for review. The index tracks planned units.

## 2. Standard package layout

Each unit is self-contained and must declare required engine/version, dependencies, startup order, synthetic fixture policy and expected checks.

```text
<slug>/
├── README.md
├── migrations/
│   ├── V0001__create_base_schema.sql
│   └── V0002__add_reporting_indexes.sql
├── 01_schema.sql
├── 02_seed.sql
├── 03_views.sql
├── 04_procedures.sql
├── 05_queries.sql
├── 06_security.sql
├── 07_indexes_perf.sql
├── 08_tests.sql
└── dialects/
    ├── mysql8/
    └── sqlserver2019/
```

The numbered top-level SQL files provide a simple learning/demo path. Versioned migration files are the deployment source of truth; do not maintain two conflicting schema definitions. If files overlap, state clearly whether the numbered script is generated, a bootstrap wrapper, or an instructional excerpt.

- `01_schema.sql`: schemas, types, tables, keys, constraints.
- `02_seed.sql`: synthetic, deterministic, clearly labelled examples only.
- `03_views.sql`: views/materialized views and refresh assumptions.
- `04_procedures.sql`: functions/procedures/triggers only where they enforce a clear invariant or useful domain operation.
- `05_queries.sql`: numbered and commented examples; use 15–30 meaningful queries when the domain warrants them.
- `06_security.sql`: roles/grants/RLS and threat assumptions; no credentials.
- `07_indexes_perf.sql`: justified indexes and EXPLAIN instructions, not blanket index creation.
- `08_tests.sql`: executable assertions that fail on violated expectations.
- `README.md`: context, ERD, setup order, assumptions, data classification, operational risks, expected output and test commands.

## 3. Naming

- Slugs and folders: lowercase kebab-case, prefixed by stable namespaces such as `ug-` or `ww-`.
- SQL object names: lowercase snake_case; avoid quoted mixed-case identifiers and reserved words.
- Schema namespaces: use domain-specific namespaces when they improve ownership and permissions; common examples are `core`, `ref`, `audit`, and `reporting`.
- Tables: plural nouns (e.g. `service_requests`), except established event/fact names where a singular/collective name is clearer.
- Primary key: normally `id`; foreign key: referenced entity name plus `_id` (e.g. `district_id`).
- Constraints: `pk_<table>`, `fk_<table>__<column>`, `ux_<table>__<columns>`, `ck_<table>__<rule>`.
- Indexes: `ix_<table>__<columns>`; partial/covering index names should reflect their predicate/purpose.
- Views: `v_<subject>`; materialized views: `mv_<subject>`.
- SQL functions: `fn_<verb_noun>`; procedures: `sp_<verb_noun>`; triggers: `trg_<table>__<event>`; trigger functions: `fn_trg_<purpose>`.
- Test assertions: `assert_<invariant>` or a clearly numbered comment/test identifier.
- Every SQL file begins with purpose, supported dialect/version, prerequisites, whether it is safe to rerun, and whether it mutates/destroys data.

## 4. Data modelling and integrity

- Model entities, attributes, cardinality and optionality before writing the DDL. Document the ERD in Mermaid or text.
- Target 3NF minimum; consider BCNF where functional dependencies justify it. Denormalise only with a measured reason and a consistency plan.
- Use explicit primary/foreign keys, uniqueness, `NOT NULL`, and `CHECK` constraints for true invariants. Avoid encoding mutable business policy in hard-to-change constraints when a versioned reference/rules table is more appropriate.
- Every FK column must have an index unless an explicit review note explains why an existing index already covers it or the workload/engine makes it unnecessary.
- Prefer `ON DELETE RESTRICT` by default. Use `CASCADE` only when child lifecycle is truly dependent on the parent and the blast radius is documented.
- Use lookup/reference tables for evolving status categories. If a closed `CHECK` set is used, document the migration required to change it.
- Avoid duplicate facts across tables. If materialised summaries or caches duplicate data, define refresh/reconciliation and stale-data behavior.

## 5. Default record metadata and justified exceptions

For ordinary mutable business/master tables, the default shape is:

```sql
id          BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
created_by  BIGINT,
is_deleted  BOOLEAN NOT NULL DEFAULT FALSE
```

These fields are a default policy, **not permission to invent a global user table or add meaningless columns**. Before using `created_by`, identify the authorised actor reference and its lifecycle. Add an FK when the referenced actor table exists and has the same scope. Use a documented exception when an append-only audit/event log, pure junction table, external staging table, or immutable reference snapshot has different semantics. Audit records must not be hidden or erased by soft deletion. Exceptions require a short design note in the unit README or ADR.

- Soft delete only where logical removal is meaningful and retention permits it; define which reads exclude deleted rows and how uniqueness works for live rows.
- Maintain `updated_at` consistently (trigger or explicit application write path) and test it.
- Use `TIMESTAMPTZ` for instants and store/compare in UTC. Keep the original time zone or local-calendar context when it is a business requirement.
- Use `NUMERIC(18,2)` for ordinary 2-decimal monetary values; use an explicit currency code. Choose scale/range suitable for the actual domain. Never use binary floating point for exact currency.
- Use `BIGINT GENERATED ... AS IDENTITY` when a simple monotonic key fits. PostgreSQL 15 does not provide the later built-in `uuidv7()` facility; if UUIDv7 is chosen, generate it through an explicitly declared and tested supported library/service rather than assuming it exists natively.
- Add comments with PostgreSQL `COMMENT ON` for tables/columns where the business meaning is not self-evident, especially sensitive, derived, unit-bearing, or externally sourced data.

## 6. DDL, migrations and repeatability

- PostgreSQL is the source-of-truth dialect for new units unless the unit explicitly states otherwise.
- Versioned migrations are immutable after they have reached a shared environment. Correct a deployed migration with a new forward migration, not by silently rewriting history.
- Use `IF NOT EXISTS` / `IF EXISTS` where it improves safe bootstrap/re-run behavior, but do not use it to mask incompatible existing objects or incomplete migrations.
- Avoid destructive `DROP ... CASCADE` in ordinary setup scripts. If destruction is genuinely required, isolate it in an explicitly named reset script with a strong warning and a safe test fixture.
- Most schema/data migrations should be transactional, but some operations (for example certain concurrent index builds) cannot run inside a transaction. State such exceptions, rollback/recovery steps, locking risk and expected duration.
- Migration order must be deterministic. Test a clean database build and an upgrade from the previously supported schema version.
- Seeds must be synthetic, deterministic, idempotent where practical, and never contain real personal records, real access tokens, passwords, or unapproved production extracts.

## 7. SQL style and dialect variants

- SQL keywords uppercase; identifiers lowercase snake_case; one major clause per line; qualify column names in joins and ambiguous queries.
- Avoid `SELECT *` in application/reporting interfaces. Select the columns the caller is authorised and expected to use.
- Bind user-supplied values as parameters. Never build a SQL statement by concatenating untrusted values. Dynamic table/column names must be allow-listed and safely quoted with the driver/engine mechanism.
- Every sample query states assumptions and demonstrates edge cases where relevant (NULL, no rows, duplicates, time boundaries and concurrent writes).
- Mark dialect-specific functions, date arithmetic, upserts, paging, JSON, procedural code and identity syntax. Do not advertise MySQL SQL as PostgreSQL-runnable.
- Only add MySQL 8 / SQL Server 2019 equivalents when the syntax or behavior materially differs. Run each variant on its stated engine.
- ANSI SQL should be used when practical, without pretending that all engines share identical behavior.

## 8. Security and privacy

- Runtime application roles do not own tables and do not have superuser or schema-owner privileges.
- Grant the minimum required operation/column/table rights. Use RLS for genuinely multi-tenant or policy-segmented tables and test cross-tenant read and write failures.
- RLS context values must be set and cleared safely per transaction/connection. Under pooling, prefer transaction-local context (`SET LOCAL` or driver-supported equivalents); never trust a caller-controlled header as proof of identity or tenant authority.
- `SECURITY DEFINER` routines require an explicit threat review, fixed safe `search_path`, narrow execute grants, careful object qualification and injection review. Avoid them when invoker rights suffice.
- Audit security-sensitive access and mutations with restricted read/write access, retention and anti-tampering controls. Do not log secrets or unnecessary personal data.
- Classify sensitive fields, minimise collection, define purpose/access/retention/export/deletion and disclosure rules, and use synthetic fixtures.
- No credential, key, token, production data dump or secret may be committed. If a secret leaks, revoke/rotate it; removing the line does not erase Git history.
- High-impact services (identity, tax, health, financial services, justice, benefits, elections, refugee assistance) require accountable human review and an appeal/correction path; database scores alone must not determine essential-service eligibility.

## 9. Performance and operations

- Index decisions require query shape, selectivity, table size, write cost and measured plans. Do not assert an index or SQL rewrite is “always faster.”
- Include `EXPLAIN` and, in a safe test environment, `EXPLAIN (ANALYZE, BUFFERS)` instructions for important PostgreSQL queries.
- Use keyset pagination for deep mutable feeds where a stable ordering/key is available; offset pagination is acceptable for shallow pages or cases where it is the correct interface.
- Partition only when expected table size, retention, pruning and maintenance justify the extra complexity. There is no universal row-count threshold.
- Document connection-pool limits, statement/query timeouts, vacuum/analyse expectations, backup/restore, recovery objectives, monitoring and alert ownership for operationally critical units.
- Backups are not proven until restore drills have succeeded. State RPO/RTO targets and test them.

## 10. Required package quality

Before review, each unit must provide:
- clear problem statement, users, owner, legal/purpose boundary and data classification;
- ERD, data dictionary, normalized schema, keys, constraints, indexes and deletion/retention rules;
- migrations, synthetic seed data and reproducible setup instructions;
- 15–30 useful CRUD/reporting/analytics queries where that scope makes sense;
- views/functions/procedures only when useful and explained;
- least-privilege role/grant/RLS model where applicable;
- tests with expected results, including negative/permission tests for sensitive operations;
- relevant EXPLAIN/benchmark notes rather than unsupported speed claims;
- documented dialect/version and working variant tests where applicable;
- README and a clear list of limitations/assumptions.

A package is not production-ready just because the SQL parses. Deployment readiness additionally requires code review, realistic load tests, security/privacy review, backup-restore test, migration rehearsal, operational ownership, and approval from the real data owner.
