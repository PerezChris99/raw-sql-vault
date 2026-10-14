# Tax Filing and Payment Reconciliation (Synthetic Demonstrator)

This PostgreSQL package models opaque taxpayer references, filing periods, versioned declared/assessed amounts, payment entries and reconciliation exceptions. All data are fictional and the example does not calculate statutory tax rates, interpret tax law, connect to URA or perform customs clearance.

## Setup
On PostgreSQL 15+ in a disposable database, run `migrations/V0001__filing_reconciliation.sql`, then `08_tests.sql`; reports are in `05_queries.sql`.

## Model
`tax_accounts` hold opaque synthetic references, `filings` capture filing type/period and explicitly declared/assessed payable values, and `payments` are idempotent entries against one filing. Revisions are retained with a sequence number instead of overwritten.

## Boundary
No real taxpayer identifiers, personal data, credentials, returns or tax formulas are present. Production use requires current law/authority review, data-owner approval, least privilege, retention rules, source-document custody, reconciliation to external payment systems, dispute/appeal handling and independent security review. Reconciliation flags are not fraud findings.