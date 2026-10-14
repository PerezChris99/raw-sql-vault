# Urban Development Permit and Inspection Tracker

Synthetic PostgreSQL 15+ package for planning applications, non-sensitive site reference tokens, permit status and inspection follow-up. No cadastral parcel titles, owner identities, precise protected sites or real planning cases are included.

## Setup
In a disposable database run `migrations/V0001__urban_permits.sql`, then `08_tests.sql`; reports are in `05_queries.sql`.

## Model
`planning_applications` reference development type, locality code and an opaque applicant token; `permits` hold decision metadata; `inspections` and `actions` preserve follow-up workflow.

## Boundaries
This is not a land-title registry or an automated development approval engine. Use with real data only after the responsible authority confirms legal mandate, current planning rules, appeal paths, sensitive-location protections, retention and human decision accountability.