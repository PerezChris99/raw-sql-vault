# E-commerce Marketplace Checkout (Synthetic Demonstrator)

## Scope

Illustrates product catalogue, customer references, stock reservation, order lines, idempotency keys and order state history. It does not process payments or store card numbers, CVVs, payment credentials or real customer PII.

## Stakeholders

Shop operator, customer-facing application, fulfilment operator, accountant and reviewer.

## ERD

customers 1-to-many orders; orders 1-to-many order_items; products 1-to-many order_items; orders 1-to-many order_events. Inventory is reduced atomically at checkout and restored if a still-placed order is cancelled.

## Setup

PostgreSQL 15+, dedicated demo database, from repository root:
1. 01_schema.sql
2. 04_procedures.sql
3. 02_seed.sql
4. 03_views.sql
5. 07_indexes_perf.sql
6. 06_security.sql
7. Run read-only examples in 05_queries.sql.
8. Run 08_tests.sql.

All SKUs/customers are synthetic. Security role scripts require permission to create NOLOGIN roles.

## Invariants

- The idempotency key maps to one checkout payload/customer/currency.
- Product rows are locked in ascending ID order before stock is reserved.
- A checkout is atomic: an invalid line/insufficient stock rolls back the whole operation.
- A placed order can be cancelled and its stock restored; retrying cancellation does not restore stock twice.
- Paid orders are not cancelled by the demo; real payment workflows need processor reconciliation and charge/refund logic.

## Production considerations

Implement tax, discounts, shipping, currency conversion, payment intents/webhooks, fraud review, privacy retention, fulfilment, refunds, tax jurisdiction logic, observability and race tests before real use. The demo is not an accounting or payment-certified system.