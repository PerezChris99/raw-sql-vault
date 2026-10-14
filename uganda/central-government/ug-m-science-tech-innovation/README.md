# Research Grant and Innovation Milestone Register

Synthetic PostgreSQL 15+ package for calls, pseudonymous proposals, funded projects and milestone evidence. It does not contain confidential inventions, real reviewer identities, unpublished results or protected IP documents.

## Setup
On a disposable database run `migrations/V0001__innovation_grants.sql`, then `08_tests.sql`. Use `05_queries.sql` for reports.

## Model
`calls` define an open grant/innovation opportunity; `proposals` use opaque references and pass through a review state; accepted proposals create project records; `milestones` record target dates and evidence references.

## Boundary
All examples are fictional. Real deployment needs an approved grant policy, conflict-of-interest handling, independent review, IP ownership rules, records retention, access segregation and transparent appeal/review processes. A milestone status is not proof of scientific validity or commercial success.