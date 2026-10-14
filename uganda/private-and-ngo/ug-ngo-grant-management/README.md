# NGO Grant Budget and Outcome-Tracking Ledger

Synthetic PostgreSQL package for donor/grant agreements, programme milestones, expense references, cumulative spending caps and aggregate outcome observations. It stores no real beneficiary or refugee information and does not connect to a donor portal, bank or humanitarian case system.

## Setup
On PostgreSQL 15+ in a disposable database, run `migrations/V0001__ngo_grant_management.sql`, then `08_tests.sql`; review the query catalogue in `05_queries.sql`.

## Model
Donors fund projects through grants. Grants have an explicit currency and ceiling; expenditures are idempotent entries and cannot exceed the grant ceiling. Milestones retain evidence references and workflow state. Outcomes are aggregate indicator snapshots, not beneficiary-level records.

## Boundaries
All data are fictional. Production use needs grant agreement validation, procurement/expense approvals, FX policy, donor-specific eligible-cost definitions, safeguarding controls, confidentiality and retention rules, financial audit and backup restoration. The sample is not a full accounting ledger or proof of programme impact.