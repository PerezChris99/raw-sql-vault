# City Asset and Service Maintenance Register

Synthetic PostgreSQL 15+ model for municipal assets, inspections and maintenance requests. It is not connected to a live city system and contains no resident identities, protected infrastructure details or caller records.

## Setup
Use a disposable database, run `migrations/V0001__city_asset_service.sql`, then `08_tests.sql`. Reports are in `05_queries.sql`.

## Model
`assets` holds fictional asset references and area codes; `inspections` records timestamped condition observations; `work_orders` tracks maintenance and status events.

## Boundary
All records are synthetic. Real use requires public-safety escalation, asset-owner confirmation, procurement and contractor controls, privacy and retention review. A work-order queue is not evidence of completed physical work.