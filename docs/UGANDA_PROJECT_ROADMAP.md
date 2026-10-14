# Uganda SQL Vault: Project Expansion Roadmap

## Existing coverage

The current README already lists 15 projects: agriculture yield analytics, corruption-report auditing, education dropout forecasting, healthcare outbreak detection, job matching, power outage analysis, road conditions, water points, refugee aid allocation, waste collection, boda accident mapping, fisheries quotas, tea prices, land disputes, and milk traceability.

This catalogue adds candidate projects and identifies the next builds. It does not claim that any ministry, district, utility, NGO, or private company has endorsed these ideas. Validate each problem with intended users and the data owner before implementation. Begin with synthetic data and avoid duplicating authoritative systems.

## Project design rules

Every implementation should include a problem statement, named user roles, data owner, ER diagram, data dictionary, versioned migrations, realistic synthetic seeds, parameterised queries, integrity constraints, tests, auditability where appropriate, privacy/retention rules, deployment instructions, backup/restore procedure, CI checks, and measurable outcomes. Do not claim a system is production-ready without security review, operational ownership, recovery tests, and user acceptance.

## Additional project candidates

### Government and public service delivery

16. **Local government service-request tracker** — residents report drainage, potholes, waste, streetlights, and other municipal issues. SQL: geospatial references, duplicate detection, status history, SLA metrics. Safeguard: protect complainant contact details and moderate public submissions.
17. **Government works and contractor milestone register** — tracks planned works, budgets, milestones, change orders, certificates, and completion evidence. SQL: budget versions, approvals, variance queries, immutable audit events. Safeguard: separation of duties and controlled publication.
18. **Procurement award and contract-delivery monitor** — tracks published notices, awards, deliverables, contract variations, and milestone status. SQL: procurement lifecycle, aggregate dashboards, audit logs. Safeguard: disclose only lawful records; do not expose confidential bid material.
19. **Permit and licence case workflow** — tracks applications, required documents, review steps, fees, decisions, renewals, and appeals. SQL: state transitions, constraints, history, transactional approvals. Safeguard: accountable human decisions and an appeal path.
20. **Public asset and maintenance register** — tracks vehicles, equipment, buildings, custody transfers, inspections, and maintenance. SQL: asset lifecycle events, work orders, overdue reports. Safeguard: restrict sensitive facility/location information.
21. **Official records and correspondence index** — tracks reference numbers, sender/recipient office, classification, custodian, retention date, and transfer history. SQL: metadata, access roles, retention workflow. Safeguard: store protected document contents separately with access controls.
22. **Budget execution and service-output dashboard** — compares approved budgets, releases, commitments, expenditure, and outputs by period. SQL: reconciliation, fact tables, variance reporting. Safeguard: clear definitions, provenance, and quality flags.
23. **Public complaints and referral case tracker** — manages referrals, response deadlines, resolution and aggregate trends. SQL: restricted case roles, event history, deadlines. Safeguard: strict confidentiality, no public case narratives.

### Health and education

24. **Essential-medicine stock and expiry monitor** — facility stock movements, batches, expiry, replenishment and stock-out days. SQL: inventory ledger, batch tracking, reconciliation. Safeguard: no patient-level data is needed for core stock reporting.
25. **Clinic appointment and queue planner** — appointment slots, queue tokens, waiting times, cancellations, and service capacity. SQL: concurrency, scheduling, indexes, time-zone handling. Safeguard: do not expose patient attendance or clinical details.
26. **Cold-chain and medical-equipment maintenance** — temperature observations, missing readings, calibration, faults and repairs. SQL: time series, threshold queries, maintenance history. Safeguard: preserve readings and correction audit trails.
27. **School textbook distribution register** — tracks allocations, deliveries, receipts, stock, shortages, and returns. SQL: inventory transactions, reconciliation, exception reports. Safeguard: transparent adjustment reasons.
28. **School attendance support workflow** — attendance summaries and follow-up actions by authorised staff. SQL: term-based facts, trends, controlled case access. Safeguard: protect children's data and avoid punitive automated labels.
29. **Scholarship and bursary application workflow** — eligibility checks, documents, approvals, disbursement, and appeals. SQL: state machines, audit, reconciliation. Safeguard: human review, privacy and equitable access.
30. **TVET and apprenticeship outcomes tracker** — courses, skills, placements, completion, and employer feedback. SQL: many-to-many skill modelling, cohort analysis. Safeguard: fair matching and controlled personal data.

### Agriculture, water, environment and transport

31. **Cooperative produce payment ledger** — farmer deliveries, weights, grade, deductions, payments, disputes and corrections. SQL: transaction ledger, reconciliation, idempotent imports. Safeguard: explain deductions and preserve correction history.
32. **Agricultural input distribution audit** — batches from supplier through stores to authorised recipients. SQL: inventory movement, lot tracing, duplicate detection. Safeguard: minimise beneficiary personal data and audit stock adjustments.
33. **Market-price collection and validation** — commodity prices by market, date, grade and unit. SQL: time-series trends, outlier checks, percentile summaries. Safeguard: show source, date, units and sample size.
34. **Water-point repair and downtime tracker** — inspection, faults, downtime, repair costs and water-quality observations. SQL: asset lifecycle, uptime metrics, event history. Safeguard: label unverified test results and track sample provenance.
35. **Waste collection service reliability** — routes, shifts, missed pickups, complaints and volumes. SQL: event data, route completion, SLA reporting. Safeguard: avoid publishing sensitive household-location patterns.
36. **Road-defect inspection and repair workflow** — reported defects, inspection severity, work orders, budgets and follow-up. SQL: spatial queries, before/after metrics. Safeguard: transparent prioritisation and human review.
37. **Public transport reliability dashboard** — route, stop, scheduled/observed departure, delay and service disruption. SQL: time-series analysis, missing-data treatment. Safeguard: aggregate service patterns; avoid individual movement profiles.
38. **Power and water outage reporting** — incident timelines, affected service areas, restoration, and aggregate reliability. SQL: intervals, outage duration, SLA calculations. Safeguard: do not publish details that expose critical infrastructure vulnerabilities.

### Private organisations, SACCOs, SMEs and civil society

39. **SME bookkeeping and cash-flow reporting** — invoices, expenses, payments, receivables and periods. SQL: ledger design, reconciliation, aging reports. Safeguard: posted financial events require auditable corrections rather than silent overwrites.
40. **SACCO savings and loan ledger** — members, deposits, loan schedules, repayments, arrears, statements and approvals. SQL: transaction isolation, idempotency, ledger reconciliation. Safeguard: treat as high-risk financial software; prototype with synthetic data and require independent review before live use.
41. **Supplier and purchase-order workflow** — quotations, approvals, orders, receipts, invoices and payments. SQL: state transitions, approval separation, matching and reconciliation. Safeguard: retain an audit trail and manage conflicts of interest.
42. **Payroll input and leave workflow** — effective-dated staff data, leave balances, approvals and payroll inputs. SQL: effective dates, constraints, reporting. Safeguard: restrict payroll exports and separate HR/payroll permissions.
43. **NGO grant and activity expenditure tracker** — grant budgets, activity plans, spending, outputs, evidence and donor reports. SQL: budget versioning, reconciliation, data-quality rules. Safeguard: protect beneficiary records and donor-restricted data.
44. **Humanitarian assistance delivery reconciliation** — authorised eligibility, assistance type, delivery status and referral. SQL: deduplication, inventory reconciliation, controlled case access. Safeguard: high sensitivity; never publish identifiable beneficiary lists.
45. **SME inventory, expiry and reorder platform** — stock movements, purchases, sales, returns, losses and batches. SQL: transaction consistency, reorder reports, costing. Safeguard: handle concurrent sales and auditable adjustments.
46. **Customer support and service-level tracker** — tickets, categories, assignment, response/resolution timestamps and feedback. SQL: status history, indexes, aggregate metrics. Safeguard: redact passwords, payment data and sensitive support content.
47. **Fleet fuel and maintenance audit** — vehicles, assignments, mileage, fuel issues, repairs and exceptions. SQL: event ledger, odometer validation, anomaly reports. Safeguard: treat flags as leads for review, not proof of misconduct.
48. **Cybersecurity asset and remediation register** — authorised assets, vulnerability findings, owners, due dates and remediation evidence. SQL: access control, history, compliance reports. Safeguard: keep exploit details and network-sensitive data restricted.
49. **Hotel/restaurant booking and stock integration** — bookings, orders, inventory consumption, supplier purchases and waste. SQL: reservation conflicts, transaction boundaries, stock movements. Safeguard: do not store raw payment-card data.
50. **Cooperative and SME sales analytics** — product sales, seasonality, repeat purchases and margin by category. SQL: joins, windows, aggregation and reporting. Safeguard: lawful use of customer data and data minimisation.

### Cross-cutting data infrastructure

51. **Authorised data-import quality gate** — staging, schema checks, deduplication, rejected-row reports and reconciliation. SQL: staging tables, batch IDs, idempotency, lineage. Safeguard: never overwrite accepted data without traceability.
52. **Inter-organisation data exchange contract** — validates approved fields and versions before authorised transfers. SQL: schema contracts, checksums, reconciliation. Safeguard: written data-sharing authority, minimum necessary fields and access logging.
53. **Public dataset catalogue and freshness monitor** — owner, definition, licence, update cadence, quality, last success and known limitations. SQL: metadata, snapshots, alert rules. Safeguard: review disclosure and source licensing.
54. **Aggregate service-access dashboard** — service counts and coverage by approved geography/time period. SQL: warehouse facts/dimensions, ETL, reconciliation. Safeguard: suppress small cells and prevent re-identification.
55. **Survey/research data pipeline** — import, validate, version and analyse survey datasets. SQL: staging, reproducible transformations, quality tests. Safeguard: consent, anonymisation and restricted raw data.
56. **Document retention and disposition register** — record category, retention rule, hold, approval, and final disposition. SQL: policy-driven dates, audit trail, exception reports. Safeguard: never automatically destroy records under legal hold.
57. **Service-provider performance and contract SLA dashboard** — agreed service metrics, incidents, corrective actions and reporting periods. SQL: interval logic, aggregation, audit. Safeguard: transparent metric definitions and data provenance.
58. **Data-quality observability dashboard** — monitors freshness, null rates, duplicates, range violations and reconciliation drift. SQL: validation queries, snapshots, alerts. Safeguard: alerts support investigation and should not silently modify source records.

## Recommended build sequence

**Beginner (first three):**
1. Inventory and expiry tracker (45) — tables, CRUD, constraints, joins.
2. Customer support tracker (46) — foreign keys, status history, date arithmetic.
3. Water-point repair tracker (34) — event history, aggregates, missing readings.

**Intermediate:**
4. Produce payment ledger (31) — transaction boundaries and reconciliation.
5. Service-request tracker (16) — geospatial concepts and workflow.
6. Data-import quality gate (51) — staging, validation and idempotency.

**Advanced, only after security and transaction modules:**
7. Medicine stock monitor (24).
8. Budget execution dashboard (22).
9. SACCO ledger (40), as a synthetic-data educational prototype only.
10. Aggregate service-access dashboard (54).

## Current implementation mapping

The roadmap candidate domains numbered 16–50 have been mapped to existing or newly merged packages. See [Uganda Implementation Checklist](UGANDA_IMPLEMENTATION_CHECKLIST.md) for exact paths, scope boundaries and outstanding validation gates. This does not mean all 116 directory entries have bespoke systems or that SQL execution has been verified.

## Project acceptance checklist

- [ ] Problem and intended users validated; data owner and authority identified.
- [ ] ER diagram, data dictionary, constraints and migration strategy reviewed.
- [ ] Synthetic seed data and clean setup command included.
- [ ] Parameterised queries and least-privilege roles used.
- [ ] Unit/integration tests cover NULLs, duplicates, boundary values, rollback and permissions.
- [ ] Concurrency and idempotency tested where repeated requests or simultaneous updates can occur.
- [ ] Sensitive operations produce auditable events with access controls.
- [ ] Retention, export, correction, and deletion rules documented.
- [ ] Query plans measured on representative synthetic data.
- [ ] Backup restoration and operational recovery tested.
- [ ] Approved local/manual checks pass and their actual output is recorded; changes merged through a reviewed PR. Do not add CI workflows under repository owner policy.
- [ ] Baseline and outcome measures documented without inventing impact figures.

## Uganda-specific deployment considerations

Confirm the actual problem and workflow with users in the relevant district, facility, agency, cooperative, or business. Plan for intermittent connectivity, shared devices, limited support budgets, training, local terminology, data ownership, and manual fallback. Seek qualified guidance on applicable Ugandan data-protection and sector requirements before handling identifiable or regulated data. Automated risk scores must not alone determine access to essential services, education, healthcare, credit, aid, or legal remedies.
