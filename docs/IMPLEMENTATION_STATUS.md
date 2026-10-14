# Raw SQL Vault — Implementation Status

**Last reviewed:** 15 October 2026  
**Primary engine:** PostgreSQL 15+  
**CI policy:** Do not add GitHub Actions or other repository CI workflows; the owner explicitly declined them.  
**Status vocabulary:** indexed, designed, implemented, verified, operationally approved

## Executive status

The repository now contains more than the original five-package implementation slice. The README and roadmap describe the intended scope; they are not evidence that every indexed candidate exists. The packages listed below are confirmed by repository files and recent commits. **SQL execution remains unverified unless a successful run and its output are recorded.**

| Phase | Confirmed implementation examples | Current assessment |
|---|---|---|
| 0 — Blueprint | README, master index, conventions, roadmap, contributor workflow, production standards, audit/status documents | Documentation baseline exists; continue maintaining consistency and validation evidence |
| 1 — Uganda central government | Road works; water-point maintenance; medicine stock/expiry; cold-chain; clinic scheduling; bursary; textbook distribution; attendance support; TVET outcomes; budget execution; official records; public transport; market-price validation | Domain packages merged through reviewed PRs; target-engine execution has not been confirmed |
| 2 — Agencies and local government | Service requests; city assets; administrative geography; permit/licence; public complaints; public works contract milestones; procurement monitor; waste collection reliability | Domain packages merged through reviewed PRs; SQL execution remains unconfirmed |
| 3 — Uganda private sector/NGO | SME inventory/POS; cooperative produce/payment; purchase orders; support SLA; fleet audit; payroll inputs/leave; bookkeeping ledger; SACCO prototype; hospitality booking/stock; humanitarian reconciliation; cyber remediation; sales analytics; NGO grants | Synthetic packages exist; high-risk financial models are prototypes; SQL execution remains unconfirmed |
| 4 — Worldwide domains | E-commerce checkout/order lifecycle | Representative package exists; no payment processing or production conformance claim; SQL execution is unconfirmed |
| 5 — Shared analytics | Warehouse ingestion and point-in-time feature-store example | Representative package exists; production lineage/governance and SQL execution remain unverified |

## Confirmed package locations

### Phase 1 — Central-government and public-service examples

- `uganda/central-government/ug-m-works-transport/`: synthetic road asset inspection and work-order register.
- `uganda/central-government/ug-m-water-environment/`: synthetic water-point observation and maintenance register.
- `uganda/central-government/ug-m-health/`: essential-medicine batch, stock-movement, expiry and guarded issue/receipt demonstrator. It contains no patient or prescription data and is not connected to live HMIS, NDA or NMS systems.
- `uganda/central-government/ug-cold-chain-monitor/`: temperature readings, calibration snapshots, excursion queue and maintenance work orders; no patient or vaccine-batch data.
- `uganda/central-government/ug-clinic-appointment-planner/`: synthetic appointment slots, conflict-safe bookings, cancellation history and aggregate clinic load; no clinical records.
- `uganda/central-government/ug-scholarship-bursary-workflow/`: application review, appeal handling and award-ceiling disbursement records using opaque student references.
- `uganda/central-government/ug-market-price-validation/`: sourced synthetic commodity-price observations, human review and candidate outlier reports; no official prices loaded.
- `uganda/central-government/ug-works-contract-milestone-register/`: versioned contract budgets, milestones, evidence-backed certificates and separate payment references.
- `uganda/central-government/ug-budget-execution-dashboard/`: appropriations, releases, commitments, expenditure and service outputs; not a general ledger.
- `uganda/central-government/ug-official-records-index/`: metadata-only custody/retention index with legal holds and disposition controls.
- `uganda/central-government/ug-school-textbook-distribution/`: textbook stock, allocation, dispatch, receipt and shortage reconciliation.
- `uganda/central-government/ug-school-attendance-support/`: pseudonymous attendance marks, corrections and human-led support; no punitive automated score.
- `uganda/central-government/ug-tvet-apprenticeship-outcomes/`: skill assessments, cohorts, placements and aggregate outcomes.
- `uganda/central-government/ug-public-transport-reliability/`: route-level schedules, departure observations and disruption reporting.

### Phase 2 — Local government

- `uganda/local-government/ug-administrative-geography/`: synthetic, effective-dated hierarchy reference, parent-level rules, ancestry queries and steward review metadata. It is not an authoritative list of real Ugandan administrative units.
- `uganda/local-government/ug-lg-service-requests/`: locality references, service requests/events, controlled transitions and reporting.
- `uganda/local-government/ug-city-asset-maintenance/`: synthetic municipal assets, inspections, work orders and event history.
- `uganda/local-government/ug-permit-licence-workflow/`: permit/licence case states, evidence-backed human decisions, document metadata and fee-event reporting. Not connected to a live issuing office.
- `uganda/local-government/ug-waste-collection-reliability/`: route/shift pickup evidence, missed-service exceptions and completion metrics.
- `uganda/agencies/ug-procurement-contract-monitor/`: procurement notices, disclosure-reviewed awards, deliverables and variation review.

### Phase 3 — Private sector and NGO

- `uganda/private-and-ngo/ug-sme-inventory/`: idempotent stock-movement ledger and underflow protection; not a full double-entry accounting ledger.
- `uganda/private-and-ngo/ug-retail-pos/`: receipts, sale lines, stock events and guarded returns; not a full tax/payment system.
- `uganda/private-and-ngo/ug-coop-produce-payment-ledger/`: effective-dated produce rates, accepted weights, approved deductions, idempotent payment references and bounded payment allocations. Synthetic settlement example only.
- `uganda/private-and-ngo/ug-supplier-purchase-order-workflow/`: purchase requests, purchase orders, goods receipts and invoice match exceptions.
- `uganda/private-and-ngo/ug-customer-support-sla-tracker/`: redacted tickets, lifecycle history and SLA summaries.
- `uganda/private-and-ngo/ug-fleet-fuel-maintenance-audit/`: fuel events, odometer checks, maintenance queues and human-review candidates.
- `uganda/private-and-ngo/ug-payroll-input-leave-workflow/`: evidence-backed leave decisions and frozen payroll input periods; no salary calculation or payment.
- `uganda/private-and-ngo/ug-sme-bookkeeping-ledger/`: balanced double-entry journals and immutable posted lines; educational ledger only.
- `uganda/private-and-ngo/ug-sacco-savings-loan-prototype/`: pseudonymous savings/loan transaction prototype; high-risk, non-production.
- `uganda/private-and-ngo/ug-hospitality-booking-stock/`: row-locked resource bookings and stock guards; no card data.
- `uganda/private-and-ngo/ug-humanitarian-assistance-reconciliation/`: pseudonymous authorisations, bounded delivery records and restricted referrals.
- `uganda/private-and-ngo/ug-cybersecurity-remediation-register/`: authorised asset metadata and independent remediation verification.
- `uganda/private-and-ngo/ug-coop-sme-sales-analytics/`: net sales, returns, category margin and tokenised repeat-sale summaries.

### Phase 4 — Worldwide domains

- `worldwide/ecommerce/ww-ecommerce-marketplace/`: idempotent checkout, atomic stock reservation, order state history and cancellation restoration; no payment/card handling.

### Phase 5 — Shared analytics

- `shared/analytics/ww-data-warehouse-feature-store/`: staging checks, idempotent fact loading, dimensions, and feature values constrained by event time and source-availability time.

## Shared SQL engineering work

The repository also contains focused examples for canonical sales policy, inclusive date-range reporting, NULL-safe scoring, calendar-time rolling revenue, PostGIS near-duplicate candidates, parameterised/idempotent batch inserts, cursor pagination, tenant RLS, row-change auditing, soft-delete indexing, and idempotent upserts. Review each script's prerequisites and test evidence before reuse.

## Validation evidence and blockers

- `tools/lint_sql.sh` performs shell syntax, recursive psql include-path, and required-file inventory checks. It is not a SQL execution test.
- `tools/run_sql_tests.sh` requires `psql`, a caller-supplied `DATABASE_URL`, and a dedicated disposable PostgreSQL/PostGIS database; it runs `sql/tests/all_packages.sql` with `ON_ERROR_STOP=1`.
- A successful end-to-end SQL regression run has **not been confirmed** in this review. Do not mark packages verified without actual execution and reviewed output.
- No GitHub Actions/CI workflow should be added. The former workflow was removed at the owner's request. Use approved local/manual checks and record their actual outcomes; missing output is not a pass.
- MySQL 8 and SQL Server 2019 variants are not comprehensively implemented/tested for the representative packages. Mark any variant as unverified unless it was run on its own engine.
- The repository contains a broad catalogue of additional ministry, agency, local-government, private/NGO, worldwide and analytical candidates. The catalogue is not 116 delivered systems.
- The old `docs/beginner-gap-audit-uganda-projects` branch was a known extra ref. Branch cleanup must preserve commit reachability and should be done only through an explicitly available, safe operation after checking the current branch inventory.
- No claim is made that any example is officially endorsed, legally compliant, certified, secure for live deployment, or operationally production-ready.

## Git status and delivery discipline

The root README was previously merged through PR #31. The Uganda implementation batch added PRs #45–#63 for public works contracts, procurement, textbooks, official records, budget execution, attendance support, TVET, supplier purchasing, support SLA, fleet audit, waste collection, payroll inputs, public transport, humanitarian assistance, cyber remediation, bookkeeping, hospitality, SACCO and cooperative/SME sales analytics; PR #64 reconciled the checklist and status, and PR #65 corrected public-transport cancellation state. After each merge, `perez` was synchronized to `main`; the latest check found them identical with zero commits ahead or behind. SQL execution remains unverified.

**Branch inventory:** `main` and `perez` are synchronized. Two legacy branches (`autopilot-unit` and `docs/beginner-gap-audit-uganda-projects`) remain and are each 77 commits behind `main` with zero unique commits ahead. The available repository connector exposes no branch-delete action, so they have not been deleted. Remove them through GitHub branch settings when authorized.

Continue using the two-branch policy in `CONTRIBUTING.md`: one coherent package per change, detailed commit message, PR from `perez` to `main`, no force-push/rebase of `main`, and post-merge reachability checks. Do not create CI workflows.

## Next execution priorities

1. Run static checks and the integrated SQL suite on an available, disposable PostgreSQL 15+/PostGIS environment; capture output and fix actual failures.
2. Use `docs/UGANDA_IMPLEMENTATION_CHECKLIST.md` for the 35 roadmap candidate domains (16–50), and continue reconciling institution-specific needs against `docs/MASTER_INDEX.md`.
3. The 35 Uganda domain candidates are now mapped to packages or existing projects; remaining Uganda work is institution-specific discovery and validation, not a claim that every public body has a bespoke system.
4. Keep each package self-contained with scope, ERD/data dictionary, migrations, deterministic synthetic fixtures, useful queries, least-privilege security, justified indexes, executable assertions, setup instructions and honest status.
5. Mark a phase complete only after its agreed scope has passed the per-package gates. Operational approval additionally requires independent data-owner, security/privacy, migration, performance, monitoring and backup/restore review.
