-- Complete SQL integration suite for PostgreSQL 15+ with PostGIS.
-- Invoke with psql -X -v ON_ERROR_STOP=1 -f sql/tests/all_packages.sql.
-- All records are synthetic. Role-creation statements require a trusted test DBA.
\set ON_ERROR_STOP on

-- Shared SQL correctness patterns and assertions.
\ir run_all.sql

-- Phase 1 representative: OPM programme action register.
\ir ../../uganda/central-government/ug-opm/migrations/V0001__opm_action_demo.sql
\ir ../../uganda/central-government/ug-opm/08_tests.sql

-- Phase 2 representative: local service request tracker.
\ir ../../uganda/local-government/ug-lg-service-requests/migrations/V0001__service_request_demo.sql
\ir ../../uganda/local-government/ug-lg-service-requests/08_tests.sql

-- Phase 3 representative: SME inventory ledger.
\ir ../../uganda/private-and-ngo/ug-sme-inventory/migrations/V0001__sme_inventory_demo.sql
\ir ../../uganda/private-and-ngo/ug-sme-inventory/08_tests.sql

-- Phase 4 representative: worldwide marketplace checkout.
\ir ../../worldwide/ecommerce/ww-ecommerce-marketplace/migrations/V0001__marketplace_demo.sql
\ir ../../worldwide/ecommerce/ww-ecommerce-marketplace/08_tests.sql

-- Phase 5 representative: warehouse and point-in-time feature store.
\ir ../../shared/analytics/ww-data-warehouse-feature-store/migrations/V0001__warehouse_feature_demo.sql
\ir ../../shared/analytics/ww-data-warehouse-feature-store/08_tests.sql

\echo 'PASS: integrated Raw SQL Vault SQL suites completed'