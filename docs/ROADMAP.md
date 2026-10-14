# Raw SQL Vault — Phased Delivery Roadmap

## Mission and execution authorization

Build a carefully versioned library of database solutions, prioritising Uganda's public-service and local context before expanding to private/NGO sectors, worldwide domains, and shared analytics infrastructure. The catalogue is broad by design; each implementation remains small enough to inspect, test and review.

**Execution instruction:** The repository owner has explicitly authorised proceeding through all phases without stopping for a separate “GO” at every phase. Continue sequentially through the phases and their agreed units, reporting blockers honestly. This authorisation does not waive data-owner/legal checks, package review, test requirements, or release gates. It also does not make the entire catalogue feasible to complete in one batch: work remains one independently reviewable package per change.

**CI constraint:** Do not create GitHub Actions, CI workflows, or CI configuration. The owner has explicitly declined repository CI. Run the documented static and database checks in an approved local/manual environment when available, and record the actual output. Missing test output is never a pass.

## Phase 0 — Blueprint and repository controls

### Deliverables
- `docs/MASTER_INDEX.md`: stable slugs for Uganda offices, ministry portfolios, named agencies, local-government levels, cross-sector problems, worldwide domains and SDGs 1–17.
- `docs/CONVENTIONS.md`: repository layout, package structure, naming, data modelling, dialect/version, migration, security, and operational standards.
- `docs/ROADMAP.md`: phases, per-unit acceptance gates, order of work and dependencies.
- `CONTRIBUTING.md`: branch, commit, merge, and history-preservation workflow.
- Root `README.md`: navigation, diagrams, scope, status vocabulary, testing and delivery workflow.

### Exit gate
- Slugs and folder conventions are documented.
- Scope boundaries and source-of-truth policy are documented.
- Two-branch Git workflow and history-preservation requirements are explicit.
- No workflow adds GitHub Actions/CI.
- The index distinguishes planned candidates from implemented and verified packages.

Phase 0 is a blueprint, not approval to access real agency systems, ingest real personal data, or represent a suggested design as an officially endorsed system.

## Phase 1 — Uganda central government

Implement one solution package at a time for the central-government entries in the master index. Confirm whether each label is a standalone ministry, an office, a ministerial portfolio, a programme, or a department before selecting its schema boundary. Some cross-cutting portfolios are administered through parent offices; do not invent legal entities.

Initial priority order:
1. `ug-opm` — programme action register / inter-agency follow-up (metadata only).
2. `ug-m-local-government` — local service-request and service-level tracker.
3. `ug-m-works-transport` — road-defect and work-order workflow.
4. `ug-m-water-environment` — water-point inspection and maintenance.
5. `ug-m-aaiif` — synthetic cooperative produce-delivery reconciliation.
6. `ug-m-education-sports` — school asset or textbook distribution register.
7. `ug-m-health` — essential-medicine stock and expiry monitor using synthetic stock data, not identifiable clinical data.
8. `ug-m-finance-planning` — aggregate budget execution and reconciliation.
9. Remaining listed ministry/portfolio entries in index order, each after scope validation.

Some priority packages already exist in demo form. Inspect and validate them before duplicating work; a package's presence is not proof of passing tests. Separate systems within a ministry should not be forced into one monolith. Define integration boundaries instead of copying whole databases between bodies.

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
9. Run static SQL lint and a clean PostgreSQL 15+ build/test in an approved environment; run dialect variants on their own engines. No CI workflow is to be added.
10. Inspect query plans and relevant write/locking costs using representative synthetic data.
11. Review the full diff, check sensitive data/secrets, document limitations and open one pull request for the unit.
12. Merge only after review and the applicable checks pass; verify the resulting history before beginning the next unit.

## Release / completion gates

A unit can be marked **implemented** only when a reviewer can reproduce setup and tests from a clean database. A unit can be described as **production-ready** only after operational ownership, threat/privacy review, performance testing, migration rehearsal, monitoring, backup/restore drills, recovery objectives and user acceptance are complete.

Project health must be reported honestly:
- **Indexed**: a slug and planned purpose exist.
- **Designed**: ERD/schema proposal reviewed.
- **Implemented**: code, migrations, seeds and tests exist.
- **Verified**: stated test commands succeeded on the declared engine/version and evidence is recorded.
- **Operationally approved**: independent security, data-owner and operations sign-off exists.

Never promote status merely because files were committed.

## Phase checkpoints

| Checkpoint | Must be true before marking the phase complete |
|---|---|
| Phase 0 | Index, conventions, roadmap, README, and Git workflow are consistent; no CI workflow is present |
| Phase 1 | Every agreed central-government unit has passed its own package review gate |
| Phase 2 | Agency/local-government inventory has been reviewed and each agreed unit passed |
| Phase 3 | Private/NGO candidates are prioritised and each approved unit passed |
| Phase 4 | Worldwide units document jurisdiction and conformance limits; tests passed |
| Phase 5 | Shared analytical/data platform patterns are validated against domain contracts and recovery/security requirements |

Because execution across all phases is authorised, checkpoints are reporting and quality gates rather than requests for another “GO.” Continue to the next phase after recording the previous phase's outcome. If a required check cannot be run, report the phase as blocked/unverified rather than silently treating it as complete.
