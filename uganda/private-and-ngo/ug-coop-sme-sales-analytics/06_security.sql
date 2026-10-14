-- Purpose: aggregate analyst and sales clerk role separation.
-- Engine: PostgreSQL 15+. Run as controlled schema owner.
DO $roles$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='ug_sales_analytics_reader') THEN CREATE ROLE ug_sales_analytics_reader NOLOGIN; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='ug_sales_analytics_clerk') THEN CREATE ROLE ug_sales_analytics_clerk NOLOGIN; END IF;
END; $roles$;
REVOKE ALL ON SCHEMA ug_sales_analytics FROM PUBLIC;
GRANT USAGE ON SCHEMA ug_sales_analytics TO ug_sales_analytics_reader,ug_sales_analytics_clerk;
REVOKE ALL ON ALL TABLES IN SCHEMA ug_sales_analytics FROM PUBLIC;
GRANT SELECT ON ug_sales_analytics.v_monthly_category_sales TO ug_sales_analytics_reader;
GRANT SELECT ON ug_sales_analytics.sales,ug_sales_analytics.sale_lines,ug_sales_analytics.products TO ug_sales_analytics_clerk;
GRANT EXECUTE ON FUNCTION ug_sales_analytics.fn_record_return(TEXT,TEXT,TEXT,INTEGER,NUMERIC,NUMERIC,TEXT,TEXT,TEXT) TO ug_sales_analytics_clerk;
REVOKE ALL ON FUNCTION ug_sales_analytics.fn_record_return(TEXT,TEXT,TEXT,INTEGER,NUMERIC,NUMERIC,TEXT,TEXT,TEXT) FROM PUBLIC;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA ug_sales_analytics FROM PUBLIC;
-- Avoid customer token output in external dashboards; suppress small cohorts and apply tenant/business scoping.
