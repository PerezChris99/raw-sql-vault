# City Asset and Service Maintenance Register

Synthetic PostgreSQL 15+ model for municipal assets, inspections and maintenance requests. It is not connected to Kampala Capital City Authority systems and contains no real household reports, protected infrastructure details or caller identities.

## Setup
Use a disposable PostgreSQL database. Run `migrations/V0001__city_asset_service.sql`, then `08_tests.sql`. Use `05_queries.sql` for reporting examples.

## Model
`assets` hold fictional asset references and area codes; `inspections` record timestamped condition observations; `work_orders` track maintenance and status events.

## Boundary
All records are synthetic. Real use requires current authority validation, public-safety escalation, asset-owner confirmation, procurement and contractor controls, privacy and records retention review. A work-order queue is not evidence of completed physical work.