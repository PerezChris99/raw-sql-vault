-- Complete SQL integration test entry point for PostgreSQL 15+ with PostGIS.
-- Invoke via psql -X -v ON_ERROR_STOP=1 -f sql/tests/all_packages.sql.
-- All packaged datasets are synthetic. OPM/local-government demo roles require a
-- role-creation-capable test user; GitHub Actions uses the disposable postgres service.
\set ON_ERROR_STOP on

-- Shared correctness patterns.
\ir run_all.sql

-- Phase 1 representative: inter-agency programme action register.
\ir ../../uganda/central-government/ug-opm/01_schema.sql
\ir ../../uganda/central-government/ug-opm/04_procedures.sql
\ir ../../uganda/central-government/ug-opm/02_seed.sql
\ir ../../uganda/central-government/ug-opm/03_views.sql
\ir ../../uganda/central-government/ug-opm/07_indexes_perf.sql
\ir ../../uganda/central-government/ug-opm/06_security.sql
\ir ../../uganda/central-government/ug-opm/08_tests.sql

-- Phase 2 representative: local government service requests.
\ir ../../uganda/local-government/ug-lg-service-requests/01_schema.sql
\ir ../../uganda/local-government/ug-lg-service-requests/04_procedures.sql
\ir ../../uganda/local-government/ug-lg-service-requests/02_seed.sql
\ir ../../uganda/local-government/ug-lg-service-requests/03_views.sql
\ir ../../uganda/local-government/ug-lg-service-requests/07_indexes_perf.sql
\ir ../../uganda/local-government/ug-lg-service-requests/06_security.sql
\ir ../../uganda/local-government/ug-lg-service-requests/08_tests.sql

-- Phase 3 representative: SME inventory ledger.
\ir ../../uganda/private-and-ngo/ug-sme-inventory/01_schema.sql
\ir ../../uganda/private-and-ngo/ug-sme-inventory/04_procedures.sql
\ir ../../uganda/private-and-ngo/ug-sme-inventory/02_seed.sql
\ir ../../uganda/private-and-ngo/ug-sme-inventory/03_views.sql
\ir ../../uganda/private-and-ngo/ug-sme-inventory/07_indexes_perf.sql
\ir ../../uganda/private-and-ngo/ug-sme-inventory/06_security.sql
\ir ../../uganda/private-and-ngo/ug-sme-inventory/08_tests.sql

-- Phase 4 representative: worldwide e-commerce marketplace checkout.
\ir ../../worldwide/ecommerce/ww-ecommerce-marketplace/01_schema.sql
\ir ../../worldwide/ecommerce/ww-ecommerce-marketplace/04_procedures.sql
\ir ../../worldwide/ecommerce/ww-ecommerce-marketplace/02_seed.sql
\ir ../../worldwide/ecommerce/ww-ecommerce-marketplace/03_views.sql
\ir ../../worldwide/ecommerce/ww-ecommerce-marketplace/07_indexes_perf.sql
\ir ../../worldwide/ecommerce/ww-ecommerce-marketplace/06_security.sql
\ir ../../worldwide/ecommerce/ww-ecommerce-marketplace/08_tests.sql

-- Phase 5 representative: warehouse ingestion and leakage-aware feature store.
\ir ../../shared/analytics/ww-data-warehouse-feature-store/01_schema.sql
\ir ../../shared/analytics/ww-data-warehouse-feature-store/04_procedures.sql
\ir ../../shared/analytics/ww-data-warehouse-feature-store/02_seed.sql
\ir ../../shared/analytics/ww-data-warehouse-feature-store/03_views.sql
\ir ../../shared/analytics/ww-data-warehouse-feature-store/07_indexes_perf.sql
\ir ../../shared/analytics/ww-data-warehouse-feature-store/06_security.sql
\ir ../../shared/analytics/ww-data-warehouse-feature-store/08_tests.sql

\echo 'PASS: integrated Raw SQL Vault SQL suites completed'