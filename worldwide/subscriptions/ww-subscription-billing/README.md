# Subscription Lifecycle and Billing Ledger

Synthetic PostgreSQL package for customer references, recurring plans, subscription state, invoices and idempotent payment records. It stores no card numbers, CVVs, credentials or real customer details and does not connect to a payment processor.

## Setup
Use PostgreSQL 15+ and a disposable database. Run `migrations/V0001__subscription_billing.sql`, then `08_tests.sql`; inspect `05_queries.sql`.

## ERD
Customers have subscriptions; each subscription points to a priced plan; invoices cover a unique subscription billing period; payments are separate entries against invoices. Amounts remain grouped by explicit currency code.

## Boundaries
This is an educational recurring-billing ledger, not a complete revenue-recognition system or tax-compliant billing platform. Production use needs provider webhook reconciliation, refunds/chargebacks, tax jurisdiction, proration, dunning, invoice numbering/legal requirements, privacy retention, and concurrency/restore testing.