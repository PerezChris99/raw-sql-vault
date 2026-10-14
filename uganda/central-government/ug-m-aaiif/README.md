# Agricultural Extension and Input Delivery Register

Synthetic PostgreSQL 15+ package for extension visits, crop-cycle notes and input delivery reconciliation. It does not integrate with any official extension service.

## Setup
In a disposable database run `migrations/V0001__agri_extension_demo.sql`, then `08_tests.sql`. See `05_queries.sql` for reports.

## Model
`service_areas` hold fictional area references; `farm_refs` are opaque demo tokens; `extension_visits` record dated follow-ups; `input_deliveries` track dispatch and receipt quantities.

## Guardrails
Do not store names, national IDs, exact household coordinates or sensitive narratives in the sample. This is not an official farmer registry, phytosanitary system or veterinary record. Delivery volume is not evidence of higher yield.