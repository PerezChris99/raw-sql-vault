# Cooperative Produce Delivery and Payables Ledger

Synthetic PostgreSQL package for producer/member references, produce lots, accepted/rejected weights, grade references, pricing and payment reconciliation. It includes no names, telephone numbers, wallet identifiers or real member records and does not connect to an SACCO, mobile-money provider or cooperative ledger.

## Setup
PostgreSQL 15+ disposable database: run `migrations/V0001__cooperative_delivery.sql`, then `08_tests.sql`; reports are in `05_queries.sql`.

## Model
Cooperatives reference pseudonymous member IDs; deliveries link produce, weighed quantities and grade references; payment entries are separate idempotent movements. A row-locked routine prevents cumulative payments from exceeding the approved payable amount.

## Boundaries
Figures and references are fictional. Real use needs validated weighing/tare procedures, price/grade governance, consent/legal basis, disputes/appeals, cash controls, payment provider reconciliation, audit retention and financial controls. This is not a complete accounting or SACCO system.