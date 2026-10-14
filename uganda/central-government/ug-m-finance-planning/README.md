# Budget Allocation, Release and Expenditure Reconciliation

Synthetic PostgreSQL demonstrator for approved vote/programme ceilings, dated releases, expenditure entries and budget execution reports. It is not an official IFMS, appropriation, release instruction, audit, tax record or current Ugandan budget dataset.

## Setup
On PostgreSQL 15+ in a disposable database, run `migrations/V0001__budget_execution_demo.sql`, then `08_tests.sql`; review the catalogue in `05_queries.sql`.

## Model
`budget_lines` define an approved UGX ceiling and fiscal year. `releases` and `expenditures` are separate, idempotently keyed movements. The demo defines fiscal year 2026 as 1 July 2026 through 30 June 2027; validate any real legal/fiscal calendar before reuse.

## Guardrails
Recordings are append-only examples; corrections require separately approved reversal entries in a real system. A computed variance is a reconciliation exception to investigate, not proof of fraud or non-compliance. Production use needs authenticated source documents, workflow approvals, delegation-of-authority checks, immutable audit controls, retention, independent financial control review and tested recovery.