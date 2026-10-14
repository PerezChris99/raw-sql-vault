# Local Government Programme and Grant Tracker

Synthetic portfolio-level design for programme milestones and aggregate budget execution. It is distinct from the separate local service-request workflow. Not an official ministry product or connected to any government finance system.

## Setup
PostgreSQL 15+, disposable test database. Run `migrations/V0001__local_government_demo.sql`, then `08_tests.sql`; examine read-only examples in `05_queries.sql`. The versioned bootstrap uses psql `\ir`, not a portable Flyway/Liquibase manifest.

## Model
`authorities` stores synthetic administrative-area references; `programmes` stores approved/released/spent budget values and target dates; `programme_events` preserves status changes. Money is exact NUMERIC, denominated in UGX for demo only.

## Boundary
All values are synthetic. Validate authority/mandate, reporting definitions, fiscal-year policy, grant rules, data-owner permissions, retention, reconciliation, monitoring, migration rollback and backup restoration before considering any real deployment. A utilisation metric is not an audit finding.