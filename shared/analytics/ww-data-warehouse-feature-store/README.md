# Warehouse Ingestion and Point-in-Time Feature Store

## Problem

This synthetic project demonstrates controlled staging, source-quality checks, star-schema facts, idempotent loading and feature-store lookups that respect what information was actually available at prediction time.

## Stakeholders

Data engineer, analytics engineer, data steward, ML engineer, auditor and data owner.

## ERD

dim_products / dim_locations / dim_dates each relate one-to-many with fact_sales. staging_sales stores incoming rows with batch and source keys. feature_registry defines feature metadata; feature_values stores timestamped values and source-availability times.

## Setup

PostgreSQL 15+, from repository root:
1. 01_schema.sql
2. 04_procedures.sql
3. 02_seed.sql
4. 03_views.sql
5. 07_indexes_perf.sql
6. 06_security.sql
7. Execute examples from 05_queries.sql.
8. Run 08_tests.sql.

The test batch ID, products, localities and feature values are invented. No real customer/official records are present.

## Correctness requirements

- Source-system plus source-sale ID is the idempotency key for fact loading.
- A batch containing any unaccepted row is rejected as a unit.
- Monetary measures stay grouped by currency unless an explicitly versioned FX transformation is applied.
- Features must meet both feature-time and source-availability cutoffs at the prediction timestamp.

## Production boundaries

Production systems need governed source contracts, lineage, schema evolution, access controls, PII classification, quality thresholds, reprocessing/correction policy, model versioning, freshness monitoring, dimensional-history policy, and backup/recovery. The demo does not prove model fairness, predictive quality, or SDG impact.