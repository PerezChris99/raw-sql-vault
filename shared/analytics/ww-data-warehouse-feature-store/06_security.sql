-- Purpose: demonstration grants for pipeline and read-only consumers.
-- Engine: PostgreSQL 15+; run as trusted migration/DBA role.
-- Roles are NOLOGIN placeholders; production identity mapping must be designed separately.

DO $roles$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'analytics_demo_pipeline') THEN
        CREATE ROLE analytics_demo_pipeline NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'analytics_demo_analyst') THEN
        CREATE ROLE analytics_demo_analyst NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'analytics_demo_feature_reader') THEN
        CREATE ROLE analytics_demo_feature_reader NOLOGIN;
    END IF;
END;
$roles$;

REVOKE ALL ON SCHEMA analytics_demo FROM PUBLIC;
GRANT USAGE ON SCHEMA analytics_demo TO analytics_demo_pipeline, analytics_demo_analyst, analytics_demo_feature_reader;
REVOKE ALL ON ALL TABLES IN SCHEMA analytics_demo FROM PUBLIC;
GRANT SELECT ON ALL TABLES IN SCHEMA analytics_demo TO analytics_demo_analyst;
GRANT SELECT ON analytics_demo.feature_registry, analytics_demo.feature_values TO analytics_demo_feature_reader;
GRANT SELECT ON analytics_demo.dim_dates, analytics_demo.dim_products, analytics_demo.dim_locations,
    analytics_demo.staging_sales TO analytics_demo_pipeline;
GRANT INSERT, UPDATE ON analytics_demo.dim_dates TO analytics_demo_pipeline;
GRANT INSERT ON analytics_demo.fact_sales TO analytics_demo_pipeline;
GRANT EXECUTE ON FUNCTION analytics_demo.fn_load_sales_batch(UUID) TO analytics_demo_pipeline;
GRANT EXECUTE ON FUNCTION analytics_demo.fn_features_as_of(TEXT, TEXT, TIMESTAMPTZ)
    TO analytics_demo_feature_reader;

COMMENT ON SCHEMA analytics_demo IS
    'Synthetic warehouse. Production grants must be aligned to source/data-owner boundaries.';