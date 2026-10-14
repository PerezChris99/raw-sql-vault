# Essential Medicine Stock and Expiry Monitor (Synthetic Demonstrator)

## Problem and scope

Models facility references, medicine catalogue, batch/lot expiry, stock movements, expiry dashboards and guarded issue/receipt operations. It uses invented medicine names and facility codes, carries no patient or prescription data, and is not connected to the Ugandan HMIS, NDA, NMS or any live pharmacy system.

## Stakeholders

Facility storekeeper, medicines manager, supply-chain officer, district reviewer and database operator.

## ERD

facilities 1-to-many stock_movements; medicine_products 1-to-many medicine_batches; medicine_batches 1-to-many stock_movements. Stock on hand is the sum of movement deltas by batch and facility. Expiry is stored on a batch/lot and must not be silently overwritten.

## Setup

PostgreSQL 15+, dedicated demo database:
1. Run migrations/V0001__medicine_stock_demo.sql with psql.
2. Run 08_tests.sql for assertions.
3. Run read-only reports from 05_queries.sql.

The migration manifest uses psql's include directive; it is a versioned demo bootstrap, not a Flyway/Liquibase-compatible migration file. Convert the SQL into the target migration system before production deployment.

## Safety invariants

- Opening receipts and movements use unique idempotency keys.
- Negative movements cannot drive a facility/batch balance below zero.
- Issue operations reject expired, quarantined, recalled or closed batches.
- Expiry/wastage write-offs can record unusable stock without pretending the stock is safe to issue.
- Historical movement events are corrected with a compensating movement, not edited.
- Reorder/expiry indicators are operational warnings, not clinical advice.

## Production boundary

Before real use, validate the data owner and legal basis, stock units and pack conversion, pharmacy procedures, batch recall workflow, return quarantine, dual-control adjustments, reconciliation, offline sync and backup restoration. A production system must additionally enforce role mapping, approved audit retention, and validated NMS/facility integration.