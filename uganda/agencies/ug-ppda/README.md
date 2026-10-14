# Procurement Plan and Contract-Milestone Register

Synthetic PostgreSQL demonstrator for procurement plan references, tender milestones, contract metadata and evidence-backed delivery checkpoints. It does not evaluate bidders, determine awards, or connect to PPDA or any live procurement platform.

## Setup
PostgreSQL 15+ disposable database: run `migrations/V0001__procurement_milestones.sql`, then `08_tests.sql`; review `05_queries.sql`.

## ERD
`procurement_plans` contains a procurement activity; `tenders` relate to plans; `contracts` relate to tenders; `contract_milestones` and `milestone_events` record planned and evidenced milestones. Supplier identifiers are opaque synthetic references.

## Safeguards
No bid evaluations or real supplier details are included. Real deployment requires current procurement law/process validation, conflict-of-interest controls, authorised roles, public disclosure policy, source-document custody and independent procurement/audit review. A missing or disputed document is not proof of wrongdoing.