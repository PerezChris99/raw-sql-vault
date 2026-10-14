# Water-Point Quality Observation and Maintenance Register

Synthetic PostgreSQL demonstrator for water-point references, laboratory/field observation metadata and maintenance work. It is not connected to a live ministry, district, utility, water laboratory or national water-information system.

## Setup
Use PostgreSQL 15+ with a disposable database. Run `migrations/V0001__water_point_demo.sql`, then `08_tests.sql`; reporting examples are in `05_queries.sql`.

## ERD
`water_points` has many `water_observations` and `maintenance_jobs`; jobs have `maintenance_events`. Sample outcomes record the responsible method/standard reference rather than asserting a universal legal water-quality threshold.

## Boundaries
All identifiers and results are synthetic. A database status is not health advice or a compliance certificate. Real use needs validated test protocols, authorised laboratory sign-off, chain of custody, data provenance, public-health escalation, location disclosure rules and independent operations/security review.