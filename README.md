# Raw SQL Vault

**A structured SQL learning, database engineering, and domain-solution portfolio.**  
**Primary dialect:** PostgreSQL 15+ · **Additional dialects:** MySQL 8 and SQL Server 2019 where explicitly documented  
**Repository status:** Proprietary pre-release workspace · **Validation status:** package-level SQL execution evidence is required before verification claims

Raw SQL Vault combines a progressive SQL curriculum with reusable engineering patterns and small, independently reviewable database solution packages. It prioritises Uganda-relevant public-service and private-sector problems, then extends to worldwide domains and shared analytics infrastructure. The catalogue is a plan and navigation aid—not a claim that every indexed system is implemented, officially endorsed, compliant, or production-ready.

## Contents

- [Mission and scope](#mission-and-scope)
- [How the repository is organised](#how-the-repository-is-organised)
- [Learning path](#learning-path)
- [Domain delivery roadmap](#domain-delivery-roadmap)
- [Package architecture](#package-architecture)
- [Engineering and safety standards](#engineering-and-safety-standards)
- [Run the checks](#run-the-checks)
- [Delivery workflow](#delivery-workflow)
- [Status definitions](#status-definitions)
- [Documentation map](#documentation-map)
- [Limitations and data-use policy](#limitations-and-data-use-policy)
- [Ownership](#ownership)

## Mission and scope

The vault has three connected goals:

1. **Learn SQL deeply:** progress from relational fundamentals to query planning, transactions, access control, migrations, and operations.
2. **Practise professional database engineering:** apply constraints, normalized modelling, explicit migrations, repeatable fixtures, security boundaries, executable assertions, and measured performance work.
3. **Build domain-specific reference implementations:** model useful workflows in self-contained packages with documented assumptions and synthetic data.

This is both a learning environment and an engineering portfolio. A realistic-looking schema or a large query catalogue does not by itself establish correctness or production readiness.

## How the repository is organised

The high-level layout separates curriculum, reusable patterns, domain examples, and delivery documentation:

```mermaid
flowchart TD
    A[Raw SQL Vault] --> B[practice/]
    A --> C[projects/]
    A --> D[uganda/]
    A --> E[worldwide/]
    A --> F[shared/]
    A --> G[sql/]
    A --> H[docs/ and tools/]
    B --> B1[Progressive SQL lessons]
    C --> C1[Applied learning projects]
    D --> D1[Government and local context]
    D --> D2[Private sector and NGOs]
    E --> E1[International domain examples]
    F --> F1[Analytics, test fixtures, and reusable patterns]
    G --> G1[SQL fixes and regression suites]
    H --> H1[Standards, roadmap, indexes, and validation tools]
```

| Path | Responsibility |
|---|---|
| `practice/` | Progressive lessons, exercises, and reference SQL |
| `projects/` | Applied projects retained from the original learning portfolio |
| `uganda/` | Uganda-centred public-service, agency, local-government, and sector packages |
| `worldwide/` | International and cross-industry domain examples |
| `shared/` | Reusable reference data, audit/security patterns, migration templates, fixtures, and analytics patterns |
| `sql/fixes/` | Focused SQL correctness examples and reusable fixes |
| `sql/tests/` | Integrated psql test entry point and regression assertions |
| `docs/` | Master index, conventions, phased roadmap, audits, and implementation status |
| `tools/` | Static SQL/include checks and explicit test runner |

The precise set of implemented packages evolves. Use the [Master Index](docs/MASTER_INDEX.md) and [Implementation Status](docs/IMPLEMENTATION_STATUS.md) rather than assuming every candidate in the roadmap already exists.

## Learning path

Follow the lessons in order where possible, and run examples only on the engine and version declared by each file.

```mermaid
flowchart LR
    A[Foundations<br/>syntax, types, constraints] --> B[Core SQL<br/>joins, grouping, subqueries, CTEs]
    B --> C[Intermediate<br/>windows, dates, strings, NULL]
    C --> D[Advanced<br/>transactions, routines, JSON, recursion]
    D --> E[Engineering<br/>security, migrations, performance, operations]
    E --> F[Applied projects<br/>model, implement, test, explain]
```

- **Foundations:** relational concepts, data types, keys, constraints, and basic queries.
- **Core SQL:** joins, aggregation, subqueries, common table expressions, and set operations.
- **Intermediate SQL:** window functions, conditional logic, string/date operations, NULL semantics, and edge cases.
- **Advanced SQL:** views, routines, triggers, transactions, recursive queries, JSON, and database administration.
- **Professional practice:** data modelling, least privilege, row-level security, migration safety, query plans, backup/restore, and testing.

The curriculum and supplement are navigation aids; lesson count and coverage should be checked against the actual files.

## Domain delivery roadmap

The roadmap progresses from shared foundations to increasingly broad domain coverage:

```mermaid
flowchart TD
    P0[Phase 0 — Blueprint and standards] --> P1[Phase 1 — Uganda central-government portfolios]
    P1 --> P2[Phase 2 — Agencies and local government]
    P2 --> P3[Phase 3 — Private sector, cooperatives, NGOs]
    P3 --> P4[Phase 4 — Worldwide domains]
    P4 --> P5[Phase 5 — Shared analytics and data infrastructure]
    P5 --> Q[Continuous verification and maintenance]
```

| Phase | Focus | Example work |
|---|---|---|
| 0 | Blueprint and standards | Index, conventions, package contract, delivery and review workflow |
| 1 | Central government | Programme actions, service delivery, works, water, education, health, aggregate finance |
| 2 | Agencies and local government | Procurement milestones, statistical metadata, public assets, administrative geography |
| 3 | Private sector and civil society | SME inventory/POS, cooperatives, NGO/grant reporting, logistics |
| 4 | Worldwide domains | E-commerce, finance, health exchange, HR, energy, transport, identity/access patterns |
| 5 | Shared data infrastructure | Staging, warehouse models, lineage, quality controls, feature-store and time-series patterns |

The scope is intentionally broad. Each package must still be validated independently, and high-impact domains require additional human, legal, privacy, and security review. See [Roadmap](docs/ROADMAP.md) for the candidate queue and exit gates.

## Package architecture

Each domain solution should be independently understandable and reviewable. A standard package normally includes:

```mermaid
flowchart TD
    R[README: scope, assumptions, ERD, setup] --> M[Versioned migrations]
    M --> S[Deterministic synthetic seed data]
    S --> O[Views, routines, and reporting queries]
    O --> X[Security model and justified indexes]
    X --> T[Executable assertions and negative tests]
    T --> V[Review and target-engine validation]
    V --> D[Documented status and known limitations]
```

Typical package files:

```text
<package>/
├── README.md
├── migrations/
│   └── V0001__create_base_schema.sql
├── 01_schema.sql
├── 02_seed.sql
├── 03_views.sql
├── 04_procedures.sql
├── 05_queries.sql
├── 06_security.sql
├── 07_indexes_perf.sql
├── 08_tests.sql
└── dialects/                 # only when a variant is actually supported
```

The exact layout may vary for a small or specialised unit. Versioned migrations are the deployment source of truth. If instructional scripts overlap with migrations, document which is authoritative and avoid maintaining conflicting schema definitions.

## Engineering and safety standards

- **PostgreSQL 15+ first.** Mark dialect-specific syntax clearly. Do not call a variant supported unless it has been tested on that engine.
- **Model before coding.** Document entities, relationships, cardinality, optionality, data definitions, and intentional denormalisation.
- **Enforce invariants.** Use appropriate primary/foreign keys, uniqueness, `NOT NULL`, `CHECK`, and transaction boundaries.
- **Treat migrations as history.** Once shared, migrations are immutable; correct them with forward migrations.
- **Use synthetic fixtures.** Seeds must be deterministic and contain no unapproved real personal records, credentials, or production extracts.
- **Apply least privilege.** Runtime roles should not own tables. Use RLS where the domain requires tenant or policy isolation and test denied access.
- **Parameterise inputs.** Never concatenate untrusted values into SQL. Allow-list and safely quote dynamic identifiers.
- **Measure performance.** Justify indexes with query shape and plans. Avoid blanket claims that a particular index or rewrite is always faster.
- **Test negative paths.** Include relevant NULL, duplicate, empty-result, boundary-date, rollback, permission-denial, and concurrency cases.
- **Document operations.** Critical examples need migration/recovery notes, monitoring assumptions, backup/restore expectations, and ownership before production use.
- **Protect sensitive domains.** Health, finance, identity, justice, children, employment, refugee assistance, and public-benefit examples require extra review. Do not use database scores alone to make high-impact eligibility decisions.

Full rules live in [Conventions](docs/CONVENTIONS.md) and [Production Standards](docs/PRODUCTION_STANDARDS.md).

## Run the checks

### 1. Static checks

From the repository root:

```bash
bash tools/lint_sql.sh
bash tools/lint_security.sh
bash tools/scan_secrets.sh
```

This checks shell syntax, recursive psql include paths, and the presence of required package files. It is a static inventory check; it does **not** execute SQL or prove that migrations and assertions pass.

### 2. SQL regression suite

Use a dedicated, disposable PostgreSQL 15+ test database with any required extensions (including PostGIS where needed). Ensure the target contains no valuable data.

```bash
export DATABASE_URL='postgresql://USER:PASSWORD@HOST:PORT/TEST_DB'
bash tools/run_sql_tests.sh
```

The runner uses psql with `ON_ERROR_STOP=1` and executes `sql/tests/all_packages.sql`. Supply local credentials through your environment; never commit them or paste production connection strings into issue reports.

**Current evidence:** the repository includes these commands, but a successful end-to-end database run has not been confirmed in the current review. Treat SQL execution status as unverified until the command has actually completed against the declared engine and the output has been reviewed. No CI workflow is required or implied by this README.

## Delivery workflow

The repository's documented policy uses exactly two durable branches:

- `main` — canonical accepted history.
- `perez` — working branch for changes and package preparation.

Do not create per-feature branches, force-push `main`, rebase `main`, or delete refs until their commits are safely reachable from a retained durable branch.

```mermaid
flowchart TD
    A[Fetch and inspect main/perez] --> B[Prepare one coherent unit on perez]
    B --> C[Review status, diff, secrets, and commit message]
    C --> D[Run available static and database checks]
    D --> E{Required checks and review pass?}
    E -- No --> F[Fix defects or record a blocker]
    F --> C
    E -- Yes --> G[Open or review PR: perez → main]
    G --> H[Merge using approved repository workflow]
    H --> I[Sync perez from main]
    I --> J[Verify graph, reachability, and clean diff]
```

The repository owner has explicitly requested that **GitHub Actions/CI workflows must not be added**. Validation must therefore use reviewed local or otherwise explicitly approved execution; missing test output is not a pass. Never report tests that were not run.

For commit format, merge procedure, and no-orphan checks, follow [CONTRIBUTING.md](CONTRIBUTING.md) and [GitHub Flow](docs/GITHUB_FLOW.md).

## Status definitions

Use these terms precisely in the index, package README, and status report:

| Status | Meaning |
|---|---|
| **Indexed** | A planned slug and purpose exist. |
| **Designed** | Scope, data model, assumptions, and access boundary have been reviewed. |
| **Implemented** | The package contains its agreed schema, migrations, synthetic fixtures, queries, security notes, tests, and documentation. |
| **Verified** | The declared test procedure completed successfully on the stated engine/version and evidence is recorded. |
| **Operationally approved** | Data-owner, security/privacy, operations, recovery, and user-acceptance gates have been independently completed. |

A commit does not automatically advance a package's status. No package should be described as production-ready solely because its SQL parses or its files exist.

## Documentation map

- [Master Index](docs/MASTER_INDEX.md) — planned domains and stable slugs.
- [Phased Roadmap](docs/ROADMAP.md) — delivery scope, order, and acceptance gates.
- [Implementation Status](docs/IMPLEMENTATION_STATUS.md) — current package coverage, evidence, and blockers.
- [Uganda Implementation Checklist](docs/UGANDA_IMPLEMENTATION_CHECKLIST.md) — candidate-domain mapping, package paths, and remaining validation gates.
- [Engineering Conventions](docs/CONVENTIONS.md) — naming, schema, migrations, security, and performance.
- [Production Standards](docs/PRODUCTION_STANDARDS.md) — operational and production-readiness expectations.
- [SQL Correctness Audit](docs/SQL_CORRECTNESS_AUDIT.md) — known correctness findings and status.
- [Beginner SQL Gap Review](docs/BEGINNER_SQL_GAP_REVIEW.md) — curriculum gaps and learning prerequisites.
- [Curriculum Supplement](docs/CURRICULUM_SUPPLEMENT.md) — beginner-to-practitioner progression.
- [GitHub Flow](docs/GITHUB_FLOW.md) — branch history and review discipline.
- [Public Release Disclaimer](docs/PUBLIC_RELEASE_DISCLAIMER.md) — limitations, non-endorsement, and safe use.
- [Security and Threat Model](docs/SECURITY_AND_THREAT_MODEL.md) — database trust boundaries and controls.
- [Connector Static Audit](docs/CONNECTOR_STATIC_AUDIT.md) — original source-review findings.
- [Connector Remediation Notes](_infrastructure/connectors/README.md) — implemented fixes, safe-use boundaries, and validation status.
- [Security Remediation Runbook](docs/SECURITY_REMEDIATION_RUNBOOK.md) — credential rotation and safe RBAC recovery.
- [Secret Scanning](tools/scan_secrets.sh) — current-tree and reachable-history scanning with Gitleaks.
- [Performance and Scalability](docs/PERFORMANCE_AND_SCALABILITY.md) — measurement-first performance guidance.
- [Operations, Backup and Restore](docs/OPERATIONS_BACKUP_RESTORE.md) — executable logical backup/restore scripts and required recovery evidence.
- [Data Governance](docs/DATA_GOVERNANCE.md) — privacy, provenance, retention, and sensitive domains.
- [Testing and Evidence](docs/TESTING_AND_EVIDENCE.md) — test levels and status claims.
- [Migration and Deployment](docs/MIGRATION_AND_DEPLOYMENT.md) — safe schema evolution.
- [Incident Response](docs/INCIDENT_RESPONSE.md) — database incident handling.
- [Engine Support Matrix](docs/ENGINE_SUPPORT_MATRIX.md) — tested versus unverified dialects.
- [Release Readiness Checklist](docs/RELEASE_READINESS_CHECKLIST.md) — go/no-go gates.
- [Ownership, Licensing, and Reuse](docs/LICENSING_AND_REUSE.md) — proprietary permission-required terms and provenance checks.
- [Contribution Guide](CONTRIBUTING.md) — mandatory commit and merge workflow.

## Limitations and data-use policy

All example datasets must be synthetic unless a specific, authorised public dataset has been explicitly approved and its licence and privacy conditions documented. Do not connect these packages to live government, healthcare, financial, identity, or other sensitive systems without explicit authority, a legal/purpose review, and a security/privacy assessment.

References to public bodies or regulated industries describe example problem domains; they do not imply official sponsorship, endorsement, legal compliance, certification, or permission to integrate. Standards-aligned naming is not proof of conformance.

## Public release status and disclaimer

**Release state: not approved for public release.** Repository visibility is configured separately from the proprietary notice and must match the owner's permission model. Release gates remain unresolved. Documentation is not certification of correctness, security, legal compliance, performance, or operational suitability.

Raw SQL Vault is an educational and engineering reference library. Materials are provided “as is” and “as available,” to the maximum extent permitted by applicable law. No guarantee is made that every script executes, every invariant is enforced across all write paths, every race condition is tested, or any database will never crash, slow down, lose availability, or lose data. Performance depends on engine/version, hardware, storage, network, schema, data distribution, concurrency, configuration, and workload.

Do not run examples against production or valuable data without independent review, testing on the declared engine/version, and adaptation to the target environment. Use disposable databases for tests. Back up data and verify restoration before migrations. Static lint or passing tests on one environment do not establish production readiness elsewhere.

The repository is not legal, financial, medical, accounting, tax, cybersecurity, safety, or regulatory advice. Institutional names and workflows are illustrative and do not imply official endorsement, affiliation, certification, legal compliance, or permission to integrate. High-impact workflows require accountable human, legal, privacy, security, and domain review.

Fixtures must be synthetic unless a specific dataset has documented provenance, lawful reuse rights, and approval. Never publish credentials, personal data, private operational records, or confidential institutional information.

## Ownership and licensing status

**Proprietary; all rights reserved.** The root [LICENSE](LICENSE) notice requires prior express written permission for reuse, redistribution, commercial use, or contributions. This is not an open-source license. Public visibility does not itself grant reuse rights. Ownership/provenance checks and review of third-party material remain release gates. See [Ownership, Licensing, and Reuse](docs/LICENSING_AND_REUSE.md) and [issue #72](https://github.com/PerezChris99/raw-sql-vault/issues/72).

---

*Build deliberately. Version every change. Test what can fail. Record what remains unverified.*
