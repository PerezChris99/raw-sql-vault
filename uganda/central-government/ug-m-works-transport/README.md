# Road Asset Inspection and Work-Order Register

Synthetic PostgreSQL demonstrator for road asset metadata, inspection observations, work priorities, due dates, cost estimates and work-order state history. It is not an official Uganda roads database and contains no sensitive or live infrastructure-security details.

## Setup
Use PostgreSQL 15+ and a disposable database. Run `migrations/V0001__road_work_order_demo.sql`, then `08_tests.sql`; inspect the read-only query catalogue in `05_queries.sql`.

## ERD
`road_assets` has many `road_inspections`; a road may have many `work_orders`; work orders have an event history. Inspection condition is an observation at a point in time, not a maintenance certification.

## Guardrails
All road identifiers, lengths, inspection findings and costs are synthetic. A real implementation needs verified asset ownership, location precision policy, safety escalation procedures, procurement controls, approved cost definitions, offline field capture, retention, access review and operational acceptance.