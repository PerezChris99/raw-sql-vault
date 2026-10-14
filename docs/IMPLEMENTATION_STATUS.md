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
| 1 — Uganda central government | OPM-style programme-action pattern; road asset inspection/work orders; water-point observation/maintenance; essential-medicine stock and expiry | Representative synthetic packages exist; target-engine execution has not been confirmed |
| 2 — Agencies and local government | Local service-request tracker; city asset and maintenance register; effective-dated administrative geography reference; permit/licence case workflow | Additional synthetic packages merged through reviewed PRs; wider agency coverage remains incomplete and SQL execution is unconfirmed |
| 3 — Uganda private sector/NGO | SME stock-movement ledger; SME retail POS, sales and returns; cooperative produce delivery and payment allocation ledger | Representative synthetic packages exist; cooperative settlement is a teaching model, not a banking/accounting system; SQL execution is unconfirmed |
| 4 — Worldwide domains | E-commerce checkout/order lifecycle | Representative package exists; no payment processing or production conformance claim; SQL execution is unconfirmed |
| 5 — Shared analytics | Warehouse ingestion and point-in-time feature-store example | Representative package exists; production lineage/governance and SQL execution remain unverified |

## Confirmed package locations

### Phase 1 — Central-government and public-service examples

- `uganda/central-government/ug-m-works-transport/`: synthetic road asset inspection and work-order register.
- `uganda/central-government/ug-m-water-environment/`: synthetic water-point observation and maintenance register.
- `uganda/central-government/ug-m-health/`: essential-medicine batch, stock-movement, expiry and guarded issue/receipt demonstrator. It contains no patient or prescription data and is not connected to live HMIS, NDA or NMS systems.
- The programme-action register is described in prior implementation notes; verify its current file inventory before treating it as a complete package.

### Phase 2 — Local government

- `uganda/local-government/ug-administrative-geography/`: synthetic, effective-dated hierarchy reference, parent-level rules, ancestry queries and steward review metadata. It is not an authoritative list of real Ugandan administrative units.
- `uganda/local-government/ug-lg-service-requests/`: locality references, service requests/events, controlled transitions and reporting.
- `uganda/local-government/ug-city-asset-maintenance/`: synthetic municipal assets, inspections, work orders and event history.
- `uganda/local-government/ug-permit-licence-workflow/`: permit/licence case states, evidence-backed human decisions, document metadata and fee-event reporting. Not connected to a live issuing office.

### Phase 3 — Private sector and NGO

- `uganda/private-and-ngo/ug-sme-inventory/`: idempotent stock-movement ledger and underflow protection; not a full double-entry accounting ledger.
- `uganda/private-and-ngo/ug-retail-pos/`: receipts, sale lines, stock events and guarded returns; not a full tax/payment system.
- `uganda/private-and-ngo/ug-coop-produce-payment-ledger/`: effective-dated produce rates, accepted weights, approved deductions, idempotent payment references and bounded payment allocations. Synthetic settlement example only.

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

The root README was previously merged through PR #31. Uganda implementation units were merged separately through PR #33 (administrative geography), PR #34 (permit/licence workflow), PR #35 (permit workflow hardening), and PR #36 (cooperative produce settlement). After each merge, `perez` was synchronized to `main`; at the latest check they were identical with zero commits ahead or behind. SQL execution remains unverified.

Continue using the two-branch policy in `CONTRIBUTING.md`: one coherent package per change, detailed commit message, PR from `perez` to `main`, no force-push/rebase of `main`, and post-merge reachability checks. Do not create CI workflows.

## Next execution priorities

1. Run static checks and the integrated SQL suite on an available, disposable PostgreSQL 15+/PostGIS environment; capture output and fix actual failures.
2. Continue reconciling the package inventory against `docs/MASTER_INDEX.md`; this status update adds the three new package paths and preserves their unverified execution status.
3. Continue missing central-government packages, then agencies/local-government, private/NGO, worldwide, and shared infrastructure in roadmap order.
4. Keep each package self-contained with scope, ERD/data dictionary, migrations, deterministic synthetic fixtures, useful queries, least-privilege security, justified indexes, executable assertions, setup instructions and honest status.
5. Mark a phase complete only after its agreed scope has passed the per-package gates. Operational approval additionally requires independent data-owner, security/privacy, migration, performance, monitoring and backup/restore review.
