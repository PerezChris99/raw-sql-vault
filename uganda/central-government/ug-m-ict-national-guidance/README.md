# Public ICT Asset and Service Catalogue

Synthetic PostgreSQL 15+ register for ICT assets, service ownership, maintenance windows and incident/request tracking. It does not inventory real government networks, credentials, security zones or production endpoints.

## Setup
Run `migrations/V0001__ict_service_catalogue.sql` and then `08_tests.sql` on a disposable database. Examples are in `05_queries.sql`.

## Model
`service_owners` describe accountable teams; `services` catalogue a service and its intended availability tier; `assets` hold non-sensitive abstract inventory; `work_items` track incident/change/maintenance workflow.

## Boundary
All references are fictional. Do not store passwords, tokens, secret URLs, network diagrams or vulnerability exploit details. Production use requires configuration-management ownership, asset discovery validation, identity federation, incident response, retention, backup and security operations review.