# Uganda Implementation Checklist — Autopilot Delivery

**Review date:** 15 October 2026  
**Primary SQL dialect:** PostgreSQL 15+  
**Delivery rule:** a package marked *implemented* has repository artifacts; it is **not** SQL-verified, legally approved, officially endorsed, or production-ready until its actual checks and operational gates pass.

## Scope and completion definition

This checklist reconciles the Uganda-focused project candidates numbered 16–50 in `docs/UGANDA_PROJECT_ROADMAP.md` against the current repository. Each candidate is mapped to an existing or newly implemented package. The implementation work adds schemas, constraints, deterministic synthetic seeds, reporting queries/views, guarded routines where appropriate, role grants, indexes, migrations, tests and package documentation.

**Important distinction:** the Master Index also lists 116 public-body/portfolio entries. That is an institutional directory snapshot, not a requirement to create 116 duplicate bespoke systems. Institution-specific ownership, mandates, authoritative data and workflow differences still require discovery with each data owner. This checklist covers the 35 reusable domain candidates; it does not assert that every listed public body has adopted or separately commissioned a system.

## Candidate-domain checklist (35/35 mapped)

| # | Candidate domain | Repository implementation | Status and boundary |
|---:|---|---|---|
| 16 | Local government service requests | `uganda/local-government/ug-lg-service-requests/` | Implemented; synthetic locality/request references; SQL execution unverified |
| 17 | Public works and contractor milestones | `uganda/central-government/ug-works-contract-milestone-register/` | Implemented; versioned budgets, milestones, certificate review and separate payment references; not an official register |
| 18 | Procurement award and contract delivery | `uganda/agencies/ug-procurement-contract-monitor/` | Implemented; disclosure-reviewed view and variation controls; procurement-law validation remains local |
| 19 | Permit/licence workflow | `uganda/local-government/ug-permit-licence-workflow/` | Implemented; human decisions, evidence and appeal/case metadata; issuing-office rules remain local |
| 20 | Public asset and maintenance register | `uganda/local-government/ug-city-asset-maintenance/` | Implemented; synthetic assets and maintenance events; sensitive asset/location controls required |
| 21 | Official records and correspondence index | `uganda/central-government/ug-official-records-index/` | Implemented; metadata only, legal holds and controlled disposition; document content stays separately secured |
| 22 | Budget execution and service outputs | `uganda/central-government/ug-budget-execution-dashboard/` | Implemented; appropriation versions, releases, commitments and evidence-backed expenditure; not a general ledger |
| 23 | Complaints and referral case tracking | `uganda/local-government/ug-public-complaints-referrals/` | Implemented; restricted case data and event history; no public narratives |
| 24 | Essential-medicine stock and expiry | `uganda/central-government/ug-m-health/` | Implemented; batch/stock workflow; not connected to live HMIS, NDA or NMS |
| 25 | Clinic appointment and queue planning | `uganda/central-government/ug-clinic-appointment-planner/` | Implemented; conflict-safe slots and aggregate load; no clinical records |
| 26 | Cold-chain and equipment maintenance | `uganda/central-government/ug-cold-chain-monitor/` | Implemented; readings, calibration, excursions and maintenance; no clinical disposition logic |
| 27 | School textbook distribution | `uganda/central-government/ug-school-textbook-distribution/` | Implemented; stock ledger, allocations, dispatches, receipts and shortage reconciliation; no learner data |
| 28 | School attendance support | `uganda/central-government/ug-school-attendance-support/` | Implemented; pseudonymous marks, evidence-backed corrections and supportive follow-up; no automated punitive scoring |
| 29 | Scholarship and bursary workflow | `uganda/central-government/ug-scholarship-bursary-workflow/` | Implemented; evidence-backed human decisions, appeals and award-bounded disbursement records; opaque learner references |
| 30 | TVET/apprenticeship outcomes | `uganda/central-government/ug-tvet-apprenticeship-outcomes/` | Implemented; skills evidence, cohorts and placements; no automated accreditation or hiring decisions |
| 31 | Cooperative produce payment ledger | `uganda/private-and-ngo/ug-coop-produce-payment-ledger/` | Implemented as a synthetic settlement model; independent accounting review required |
| 32 | Agricultural input distribution | `uganda/central-government/ug-agri-input-distribution/` | Implemented; batch/stock tracing and delivery reconciliation; synthetic references |
| 33 | Market-price collection and validation | `uganda/central-government/ug-market-price-validation/` | Implemented; sourced observations and human review; no official prices loaded |
| 34 | Water-point repair and downtime | `uganda/central-government/ug-m-water-environment/`, `projects/water_point_monitor/` | Implemented coverage; distinguish observed, unverified and missing readings; local water-quality authority required |
| 35 | Waste collection reliability | `uganda/local-government/ug-waste-collection-reliability/`, `projects/waste_collection_optimizer/` | Implemented; route/shift evidence and exception reporting; no household-level public tracking |
| 36 | Road-defect inspection and repair | `uganda/central-government/ug-m-works-transport/`, `projects/road_condition_aggregator/` | Implemented coverage; spatial/maintenance workflows; human review for prioritisation |
| 37 | Public transport reliability | `uganda/central-government/ug-public-transport-reliability/` | Implemented; route-level schedule and punctuality reporting; no passenger movement profiles |
| 38 | Power/water outage reporting | `projects/power_outage_analyzer/`, `uganda/central-government/ug-m-water-environment/` | Implemented coverage across existing outage analysis and water downtime examples; not connected to live utility systems |
| 39 | SME bookkeeping/cash-flow ledger | `uganda/private-and-ngo/ug-sme-bookkeeping-ledger/` | Implemented as a double-entry teaching ledger; not certified accounting/tax software |
| 40 | SACCO savings and loans | `uganda/private-and-ngo/ug-sacco-savings-loan-prototype/` | Implemented as a high-risk synthetic prototype; no real money, interest calculations or regulatory reporting |
| 41 | Supplier and purchase-order workflow | `uganda/private-and-ngo/ug-supplier-purchase-order-workflow/` | Implemented; purchase orders, receipts and invoice exceptions; no payment execution |
| 42 | Payroll input and leave workflow | `uganda/private-and-ngo/ug-payroll-input-leave-workflow/` | Implemented; period approval and frozen-input trigger; not a payroll calculator or statutory filing engine |
| 43 | NGO grant and activity expenditure | `uganda/private-and-ngo/ug-ngo-grant-management/` | Implemented; synthetic grant budgets and activity tracking; donor terms/data-sharing require local validation |
| 44 | Humanitarian assistance reconciliation | `uganda/private-and-ngo/ug-humanitarian-assistance-reconciliation/`, `projects/refugee_aid_allocator/` | Implemented coverage; high-sensitivity pseudonymous workflow; no automated eligibility or public beneficiary lists |
| 45 | SME inventory and reorder | `uganda/private-and-ngo/ug-sme-inventory/` | Implemented; idempotent stock movements and underflow protection; not a complete accounting ledger |
| 46 | Customer support/SLA tracking | `uganda/private-and-ngo/ug-customer-support-sla-tracker/` | Implemented; redacted tickets, event history and response/resolution reporting; business-calendar rules need validation |
| 47 | Fleet fuel and maintenance audit | `uganda/private-and-ngo/ug-fleet-fuel-maintenance-audit/` | Implemented; guarded fuel ledger and human-review anomaly candidates; flags are not proof of misconduct |
| 48 | Defensive cybersecurity remediation | `uganda/private-and-ngo/ug-cybersecurity-remediation-register/` | Implemented; authorised asset/finding metadata and independent verification; no credentials or exploit payloads |
| 49 | Hospitality booking and stock | `uganda/private-and-ngo/ug-hospitality-booking-stock/` | Implemented; row-locked booking conflicts and stock guards; no payment-card data |
| 50 | Cooperative/SME sales analytics | `uganda/private-and-ngo/ug-coop-sme-sales-analytics/`, `uganda/private-and-ngo/ug-retail-pos/` | Implemented; net sales, returns, category margin and tokenised repeat-sale summaries; tax/currency policy remains separate |

## Engineering acceptance state

The package artifacts are now present and merged, but the full operational acceptance checklist is **not yet complete**:

- [x] All 35 candidate domains above map to a package or existing project.
- [x] New packages include a README, schema, synthetic seed, reporting queries, security role grants, index/plan examples, migration and SQL assertion script.
- [x] Changes were delivered as individual pull requests and `perez` was synchronized to `main` after each merge.
- [x] No GitHub Actions or other CI workflow was added.
- [ ] Run `tools/lint_sql.sh` against a local checkout and record its actual output.
- [ ] Run the integrated `tools/run_sql_tests.sh` on a disposable PostgreSQL 15+/PostGIS environment, fix all failures, and record the actual output.
- [ ] Review new package SQL for syntax, privilege correctness, trigger/function behaviour, transaction isolation and concurrency on PostgreSQL.
- [ ] Test backup/restore, migration reruns, representative query plans and rollback/recovery.
- [ ] Obtain data-owner, privacy/security and sector-specific review before any live use.
- [ ] Reconcile the 116-entry institutional directory with actual agency/office-specific needs; do not assume a generic package automatically fits every institution.

## Remaining Uganda-specific decisions

1. **Official body mapping:** confirm each organisation's current mandate, parent office, legal status, data owner and whether a separate implementation is actually needed.
2. **Local requirements:** validate workflows, retention, appeal paths, disclosure rules, accessibility and offline/manual fallback with the relevant office or organisation.
3. **Production hardening:** complete the unchecked acceptance gates above. Package existence alone does not mean 100% production-ready.
4. **Next roadmap phases:** after these gates, proceed to the separately planned international domain implementations, full learning materials and shared engineering work.

## Pull requests delivered in this autopilot batch

- [#45 — Public works contract milestones](https://github.com/PerezChris99/raw-sql-vault/pull/45)
- [#46 — Procurement award/contract monitor](https://github.com/PerezChris99/raw-sql-vault/pull/46)
- [#47 — School textbook distribution](https://github.com/PerezChris99/raw-sql-vault/pull/47)
- [#48 — Official records metadata index](https://github.com/PerezChris99/raw-sql-vault/pull/48)
- [#49 — Budget execution dashboard](https://github.com/PerezChris99/raw-sql-vault/pull/49)
- [#50 — School attendance support](https://github.com/PerezChris99/raw-sql-vault/pull/50)
- [#51 — TVET/apprenticeship outcomes](https://github.com/PerezChris99/raw-sql-vault/pull/51)
- [#52 — Supplier purchase-order workflow](https://github.com/PerezChris99/raw-sql-vault/pull/52)
- [#53 — Customer support/SLA tracker](https://github.com/PerezChris99/raw-sql-vault/pull/53)
- [#54 — Fleet fuel/maintenance audit](https://github.com/PerezChris99/raw-sql-vault/pull/54)
- [#55 — Waste collection reliability](https://github.com/PerezChris99/raw-sql-vault/pull/55)
- [#56 — HR leave/payroll input workflow](https://github.com/PerezChris99/raw-sql-vault/pull/56)
- [#57 — Public transport reliability](https://github.com/PerezChris99/raw-sql-vault/pull/57)
- [#58 — Humanitarian assistance reconciliation](https://github.com/PerezChris99/raw-sql-vault/pull/58)
- [#59 — Defensive cybersecurity remediation](https://github.com/PerezChris99/raw-sql-vault/pull/59)
- [#60 — SME double-entry bookkeeping](https://github.com/PerezChris99/raw-sql-vault/pull/60)
- [#61 — Hospitality booking/stock](https://github.com/PerezChris99/raw-sql-vault/pull/61)
- [#62 — SACCO savings/loan prototype](https://github.com/PerezChris99/raw-sql-vault/pull/62)
- [#63 — Cooperative/SME sales analytics](https://github.com/PerezChris99/raw-sql-vault/pull/63)

## Final status language

- **Domain checklist coverage:** 35/35 candidate domains mapped to repository implementations.
- **Institution-specific coverage:** not complete by inference; verify the current official directory and each data owner's real need.
- **SQL verified:** no, not until actual target-engine execution output is recorded.
- **Production approved:** no; requires independent sector, privacy/security, recovery and user acceptance review.
