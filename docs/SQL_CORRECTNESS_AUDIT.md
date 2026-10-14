# SQL Correctness Audit — Findings and Implemented Fixes

**Target:** PostgreSQL 15+; PostGIS is required for the spatial example.  
**Scope:** targeted corrections from the previous review, not a claim of exhaustive repository validation.

## Correction map

| Finding | Implemented example | Core invariant | Execution status |
|---|---|---|---|
| Inconsistent countable-sale filters | `sql/fixes/01_sales_filter_consistency.sql` | One defined status policy is used by downstream reports | Included in SQL test suite; pass not confirmed |
| End-date timestamp loss | `sql/fixes/02_date_range_overlap.sql` | Inclusive date input converts to a half-open timestamp range | Included in SQL test suite; pass not confirmed |
| NULL misclassification | `sql/fixes/03_null_safe_scoring.sql` | NULL scores remain `unknown`, not a low score | Included in SQL test suite; pass not confirmed |
| ROWS mistaken for calendar days | `sql/fixes/04_rolling_window.sql` | Rolling revenue spans six days preceding the current day | Included in SQL test suite; pass not confirmed |
| Duplicate/reversed spatial pairs and wrong distance units | `sql/fixes/05_spatial_dedup.sql` | Return each canonical pair once using geography distance in metres | Included in PostGIS test suite; pass not confirmed |
| Batch import retry/injection hazards | `sql/fixes/06_batch_insert_safety.sql` | Bind arrays, validate shape and make duplicate-email retries no-op | Included in SQL test suite; pass not confirmed |

## Local test entry point

Use only a disposable PostgreSQL 15+ database with PostGIS, never production:

```bash
DATABASE_URL=postgresql://postgres:postgres@localhost:5432/vault_test bash tools/run_sql_tests.sh
```

The runner requires an explicit DATABASE_URL. The CI workflow starts an ephemeral PostGIS container and runs the same entry point. At the time of writing, the observed GitHub Actions run failed before exposing any steps; no passing SQL execution result is claimed.

## Scope limitations

These fixes are synthetic demonstrations under the `vault_demo` schema. They do not silently replace production project schemas, do not establish one global sales policy for all businesses, and do not determine tax, fraud, legal ownership, medical eligibility or public-benefit decisions. Business owners must confirm the relevant semantics before adopting any example.
