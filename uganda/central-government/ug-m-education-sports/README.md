# School Learning-Material and Asset Allocation Register

Synthetic PostgreSQL example for school references, approved allocations, dispatches, receipts and exception tracking for textbooks, laboratory kits, sports equipment and classroom assets. It stores no student records and does not connect to any official ministry, school-management or examination system.

## Setup
Use PostgreSQL 15+ and a disposable database. Run `migrations/V0001__school_asset_allocation.sql`, then `08_tests.sql`; use `05_queries.sql` for reports.

## Model
`schools` and `asset_catalog` define synthetic reference data. `allocations` records planned, dispatched and received quantities; `allocation_events` preserves workflow history. Quantity constraints prevent receipt beyond dispatch or the approved allocation.

## Boundary
All records are fictional. Real deployments need validated school identifiers, grant/stock ownership, procurement contracts, receipt evidence, damaged/lost-goods workflow, audit retention, access approvals and independent reconciliation. Aggregate asset distribution is not proof of learning outcomes.