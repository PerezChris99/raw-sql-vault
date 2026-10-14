#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "Checking test runner shell syntax..."
bash -n tools/run_sql_tests.sh
bash -n tools/lint_sql.sh

echo "Checking recursive psql include paths..."
python3 tools/check_sql_includes.py sql/tests/all_packages.sql

echo "Checking required package files..."
required=(
  sql/fixes/00_demo_schema.sql
  sql/fixes/01_sales_filter_consistency.sql
  sql/fixes/02_date_range_overlap.sql
  sql/fixes/03_null_safe_scoring.sql
  sql/fixes/04_rolling_window.sql
  sql/fixes/05_spatial_dedup.sql
  sql/fixes/06_batch_insert_safety.sql
  sql/tests/08_regression_tests.sql
  sql/tests/09_reusable_patterns.sql
  uganda/central-government/ug-opm/08_tests.sql
  uganda/local-government/ug-lg-service-requests/08_tests.sql
  uganda/private-and-ngo/ug-sme-inventory/08_tests.sql
  worldwide/ecommerce/ww-ecommerce-marketplace/08_tests.sql
  shared/analytics/ww-data-warehouse-feature-store/08_tests.sql
)
for file in "${required[@]}"; do
  if [[ ! -s "$file" ]]; then
    echo "ERROR: required file missing or empty: $file" >&2
    exit 1
  fi
done

echo "PASS: static SQL package inventory and psql includes"
