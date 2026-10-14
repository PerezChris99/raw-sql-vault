# SME Retail POS Sales and Returns Ledger

Synthetic PostgreSQL 15+ retail example for receipts, sale lines, stock movements and returns. It contains no card credentials or real customer records and is not a full accounting or tax system.

## Setup
In a disposable database run `migrations/V0001__retail_pos.sql`, then `08_tests.sql`. Use `05_queries.sql` for reports.

## Model
`products` define items and prices; `sales` and `sale_lines` capture price snapshots; `stock_events` records signed movements; `returns` link approved return quantities to source sale lines.

## Boundary
Fixtures are synthetic. Real use requires tax jurisdiction and receipt validation, refunds/payment-provider reconciliation, stock valuation, retention and role review. Use parameterised SQL in applications and do not store payment-card data.