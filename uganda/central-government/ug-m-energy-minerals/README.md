# Energy and Mineral Operations Licence Tracker

Synthetic PostgreSQL package for licence metadata, renewable/expiry reminders, inspection observations and corrective-action workflow. It contains no live permit data, protected facility details, reserve locations or sensitive infrastructure information.

## Setup
On PostgreSQL 15+ in a disposable database, run `migrations/V0001__licence_monitoring_demo.sql`, then `08_tests.sql`. Explore `05_queries.sql`.

## Model
`licence_holders` contains opaque demo references; `licences` is the permit lifecycle; `inspections` records timestamped observations against a licence; `corrective_actions` tracks non-sensitive remediation state. It does not encode legal approval criteria or automatically decide enforcement.

## Operational boundary
All records are invented. Real use requires a verified mandate, approved licence taxonomy, legal review, evidence retention, access segmentation, conflict-of-interest controls and an accountable human reviewer. Overdue items are triage signals, not proof of breach.