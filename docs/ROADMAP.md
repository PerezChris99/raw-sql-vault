# Raw SQL Vault — Phased Delivery Roadmap

## Mission

Build a carefully versioned library of database solutions, prioritising Uganda's public service and local context before expanding to private/NGO sectors and worldwide domains. The catalogue is broad by design; each implementation remains small enough to inspect, test and review.

The sequence follows the delivery model in the master prompt. **After each phase, stop and wait for the user's explicit “GO” before starting the next phase.** Within a phase, deliver one domain solution per commit-ready unit/pull request; do not attempt to implement the entire catalogue in one batch.

## Phase 0 — Blueprint (current)

### Deliverables
- `docs/MASTER_INDEX.md`: stable slugs for Uganda offices, ministry portfolios, named agencies, local-government levels, cross-sector problems, worldwide domains and SDGs 1–17.
- `docs/CONVENTIONS.md`: repository layout, package structure, naming, data modelling, dialect/version, migration, security, and operational standards.
- `docs/ROADMAP.md`: phases, per-unit acceptance gates, order of work and dependencies.
- `CONTRIBUTING.md`: branch, commit, merge, and history-preservation workflow.

### Exit gate
- Slugs and folder conventions approved.
- Scope boundaries and source-of-truth policy approved.
- Git workflow and the handling of the repository's already-open temporary-branch PR reconciled.
- No ministry/agency package has started implementation.

Phase 0 is a blueprint, not approval to access real agency systems, ingest real personal data, or represent a suggested design as an officially endorsed system.

## Phase 1 — Uganda central government (one unit per ministry/portfolio)

Implement one solution package at a time for the central-government entries in the master index. Confirm whether each label is a standalone ministry, an office, a ministerial portfolio, a programme, or a department before selecting its schema boundary. Some cross-cutting portfolios are administered through parent offices; do not invent legal entities.

Suggested order for initial low-risk, broadly useful foundations:
1. `ug-opm` — programme action register / inter-agency follow-up (metadata only).
2. `ug-m-local-government` — local service-request and service-level tracker.
3. `ug-m-works-transport` — road-defect and work-order workflow.
4. `ug-m-water-environment` — water-point inspection and maintenance.
5. `ug-m-aaiif` — synthetic cooperative produce-delivery reconciliation.
6. `ug-m-education-sports` — school asset or textbook distribution register.
7. `ug-m-health` — essential-medicine stock and expiry monitor using synthetic stock data, not identifiable clinical data.
8. `ug-m-finance-planning` — aggregate budget execution and reconciliation.
9. Remaining listed ministry/portfolio entries in index order, each after scope validation.

For each ministry, a “unit” is an independent, reviewable package; separate systems within a ministry should not be forced into one monolith. Define integration boundaries instead of copying whole databases between bodies.

## Phase 2 — Uganda agencies and local government

Implement individual units for the named agencies/authorities/bodies in the master index, then expand by validated official inventory. In parallel, build reusable administrative reference data for district/city, county where applicable, municipality, town council, sub-county, division, parish and village levels.

Priority candidates:
- `ug-ppda`: procurement/contract milestone and variation tracking.
- `ug-ura`: synthetic tax filing/reconciliation workflow; no live taxpayer data.
- `ug-ubos`: survey metadata, quality checks and disclosure-controlled statistics.
- `ug-nms` / `ug-nda`: lot/batch, expiry, recall and medicine supply-chain reporting.
- `ug-nira`: authorised integration contract and match-result metadata only, not a shadow national identity database.
- `ug-ec`: controlled logistics and publication workflow; never seed real voter information.
- `ug-kcca`: citizen service-request tracker and asset maintenance.
- `ug-local-government`: boundary/effective-date reference data and service reporting.

Check data-sharing authority, operational responsibility, legal basis, and current organisation status for each candidate before building any integration.

## Phase 3 — Uganda private sector, cooperatives, NGOs and civil society

Build reusable, sector-specific systems suitable for small organisations and larger operators:
- SACCO and microfinance ledger (synthetic educational prototype first).
- SME bookkeeping, billing, inventory, reconciliation and tax-preparation exports.
- Agriculture cooperatives, market-price collection and livestock traceability.
- Retail/POS, e-commerce, warehouse, last-mile delivery and customer support.
- Telecom/ISP subscriber service, outage and billing analytics.
- Tourism/hospitality reservation and inventory workflows.
- Manufacturing, mining/oil-and-gas compliance metadata and quality control.
- NGO/grant management, monitoring and evaluation, donor reporting, humanitarian logistics.
- Insurance/pensions, fleet/fuel, construction/real-estate and media workflows.

Financial, insurance, health, refugee, child, employment, religious, and other sensitive domains require additional privacy/security review before any use with real records.

## Phase 4 — Worldwide universal domains

Use the worldwide domain slugs from the index as the portfolio. Each unit must declare jurisdiction/standards scope, currency/time-zone rules, internationalisation needs, data exchange and retention assumptions. Implement domains such as banking/payments, healthcare/FHIR-aligned exchange, insurance, aviation, shipping/customs, WMS/TMS, retail/POS, marketplaces, streaming, ride-hailing, HR/payroll, CRM, ERP, education/LMS, e-government, smart-city/IoT, energy, climate/ESG, humanitarian logistics, sports, gaming, SIEM/audit logs, ledger integrations, identity/access and subscriptions.

Do not imply formal compliance with SWIFT, ISO 20022, HL7/FHIR, ICD, accounting rules, or any other standard merely because a sample schema has similar labels. Include conformance profiles and independent validation when certification is a requirement.

## Phase 5 — Cross-cutting analytical infrastructure

Develop shared components after the domain examples establish stable data contracts:
- reporting warehouse patterns (star schema, snowflake and Data Vault where justified);
- ingestion/staging, schema contracts, batch IDs, idempotency, lineage and reconciliation;
- privacy-preserving aggregate reporting and disclosure controls;
- analytics quality gates, freshness monitors and metrics catalogues;
- AI/ML feature registry, point-in-time correctness, dataset/model lineage and reproducibility;
- event/time-series storage, retention/partitioning and controlled data exchange;
- common audit, roles/RLS, migration, test-fixture and recovery patterns.

Shared infrastructure must not become a global table that centralises all personal data. Shared libraries are schemas/patterns and contracts; data remain under an approved data owner and access boundary.

## Per-unit workflow

1. Confirm the problem with intended users and identify the real data owner.
2. Record scope, stakeholders, workflows, legal/purpose boundary, security classification, retention and measurable outcome.
3. Design the ERD and data dictionary, state assumptions and target engine/version.
4. Write normalized DDL, constraints and indexes; document intentional denormalisation.
5. Add deterministic synthetic seeds; never require a production dump to run the project.
6. Add 15–30 meaningful queries where appropriate, views and routines only when useful, and explain the expected results.
7. Add least-privilege permissions, RLS where relevant, audit behavior and negative access tests.
8. Add migration scripts and executable assertions with known expected outcomes.
9. Run static SQL lint and a clean PostgreSQL 15+ build/test; run dialect variants on their own engines.
10. Inspect query plans and relevant write/locking costs using representative synthetic data.
11. Review the full diff, check sensitive data/secrets, document limitations and open one pull request for the unit.
12. Merge only after review and the applicable checks pass; verify the resulting history before beginning the next unit.

## Release / completion gates

A unit can be marked **implemented** only when a reviewer can reproduce setup and tests from a clean database. A unit can be described as **production-ready** only after operational ownership, threat/privacy review, performance testing, migration rehearsal, monitoring, backup/restore drills, recovery objectives and user acceptance are complete.

Project health must be reported honestly:
- **Indexed**: a slug and planned purpose exist.
- **Designed**: ERD/schema proposal reviewed.
- **Implemented**: code, migrations, seeds and tests exist.
- **Verified**: stated test commands succeeded on the declared engine/version.
- **Operationally approved**: independent security, data-owner and operations sign-off exists.

Never promote status merely because files were committed.

## Phase checkpoints

| Checkpoint | Must be true before moving on |
|---|---|
| End Phase 0 | user approves master index, conventions, roadmap and Git workflow |
| End Phase 1 | every agreed central-government unit has passed its own review gate |
| End Phase 2 | agency/local-government registry has been reviewed and each agreed unit passed |
| End Phase 3 | private/NGO candidates prioritised by users and data owners; each approved unit passed |
| End Phase 4 | worldwide units document jurisdiction and conformance limits; tests passed |
| End Phase 5 | shared analytical/data platform patterns are validated against domain contracts and recovery/security requirements |

At each checkpoint, provide a concise status report, list blocked/unverified items, and wait for explicit “GO” before beginning the next phase.
