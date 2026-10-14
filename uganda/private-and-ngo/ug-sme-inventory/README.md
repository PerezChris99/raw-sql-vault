# SME Inventory and Stock-Movement Ledger

## Problem

This educational package models an SME stock ledger. Stock is derived from signed movements; it is not an editable cached quantity. Every movement has a unique idempotency key so network retries should not double-apply a receipt or sale.

## Stakeholders

Owner/store manager, store operator, purchasing clerk, accountant and reviewer.

## ERD

products 1-to-many stock_movements. Current on-hand quantity is the sum of movement deltas by product. Product identity/catalogue fields are separated from the append-only movement ledger.

## Setup

PostgreSQL 15+, from repository root, on a dedicated demo database:
1. 01_schema.sql
2. 04_procedures.sql
3. 02_seed.sql
4. 03_views.sql
5. 07_indexes_perf.sql
6. 06_security.sql
7. Execute read-only examples in 05_queries.sql.
8. Run 08_tests.sql.

The test fixtures use invented SKUs and prices in UGX. They contain no payment-card details or real customer records.

## Important invariants

- One row per idempotency key.
- The stock function locks the product row and checks the ledger balance before accepting an outgoing movement.
- The runtime role executes the reviewed function; it must not receive direct write access to the movement ledger.
- Ledger adjustments should be additional correction movements, not edits to historic movements.

## Production boundary

Before live use, test concurrency against the real driver/isolation configuration, reconciliation, barcode/import errors, returns, period close, cost valuation, access grants, backup/restore and retention. The sample does not implement accounting valuation or a full double-entry financial ledger.