# Medicine Supply Dispatch and Facility Receipt Reconciliation

Synthetic PostgreSQL package for central-store references, medicine batches, dispatch quantities, facility receipt quantities, lot status and discrepancy follow-up. It does not connect to National Medical Stores, the Ministry of Health, NDA or any real facility/pharmacy system and contains no patient information.

## Setup
PostgreSQL 15+ disposable database: run `migrations/V0001__medicine_dispatch_receipts.sql`, then `08_tests.sql`; use `05_queries.sql` for reports.

## Model
Warehouses dispatch batch quantities to synthetic facilities; dispatch lines record shipped quantity; receipt entries are idempotent and reconciled per batch. Short deliveries can remain open or be marked disputed through the final-receipt contract.

## Boundaries
All names, lots, quantities and references are synthetic. Real use requires validated pack conversions, FEFO policy, batch recall/expiry handling, controlled cold-chain/temperature fields where relevant, authorised integration, source documents, dispute workflow and independent supply-chain reconciliation.