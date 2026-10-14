# Trade Promotion and Export Readiness Tracker

Synthetic PostgreSQL 15+ model for trade-promotion programmes, opaque applicant references, service milestones and aggregate export-readiness reporting. It is not a business registry, customs system, tax system or official ministry portal.

## Setup
On a disposable database run `migrations/V0001__trade_promotion_demo.sql`, then `08_tests.sql`; reporting examples are in `05_queries.sql`.

## Model
`programmes` hold service initiatives; `applicant_refs` are opaque synthetic business tokens; `applications` record programme participation and current state; `milestones` track service delivery and outcomes with transition history.

## Boundary
All records are fictional. Real deployments require a current legal mandate, identity/registry verification, conflict-of-interest review, service eligibility controls, retention, access, and honest definition of export outcomes. Activity counts are not proof of national trade growth.