-- Purpose: report staging quality and currency-specific sales aggregates.
-- Engine: PostgreSQL 15+; requires schema and dimensions.
-- Rerun safety: CREATE OR REPLACE VIEW.

CREATE OR REPLACE VIEW analytics_demo.v_staging_sales_quality AS
SELECT s.staging_row_id, s.batch_id, s.source_system, s.source_sale_id,
       CASE
           WHEN NULLIF(btrim(s.source_system), '') IS NULL THEN 'missing_source_system'
           WHEN NULLIF(btrim(s.source_sale_id), '') IS NULL THEN 'missing_source_sale_id'
           WHEN s.sold_at IS NULL THEN 'missing_sold_at'
           WHEN NULLIF(btrim(s.source_sku), '') IS NULL THEN 'missing_sku'
           WHEN NULLIF(btrim(s.locality_code), '') IS NULL THEN 'missing_locality'
           WHEN s.amount IS NULL THEN 'missing_amount'
           WHEN s.amount < 0 THEN 'negative_amount'
           WHEN s.currency IS NULL OR length(btrim(s.currency)) <> 3 THEN 'invalid_currency'
           WHEN NOT EXISTS (SELECT 1 FROM analytics_demo.dim_products p WHERE p.source_sku = s.source_sku) THEN 'unknown_sku'
           WHEN NOT EXISTS (SELECT 1 FROM analytics_demo.dim_locations l WHERE l.locality_code = s.locality_code) THEN 'unknown_locality'
           ELSE 'accepted'
       END AS quality_status
FROM analytics_demo.staging_sales s;

CREATE OR REPLACE VIEW analytics_demo.v_daily_sales_by_currency AS
SELECT f.calendar_date, p.source_sku, l.locality_code, f.currency,
       COUNT(*) AS sale_count, SUM(f.amount) AS gross_sales
FROM analytics_demo.fact_sales f
JOIN analytics_demo.dim_products p USING (product_key)
JOIN analytics_demo.dim_locations l USING (location_key)
GROUP BY f.calendar_date, p.source_sku, l.locality_code, f.currency;

CREATE OR REPLACE VIEW analytics_demo.v_batch_summary AS
SELECT batch_id,
       COUNT(*) AS staged_rows,
       COUNT(*) FILTER (WHERE quality_status = 'accepted') AS accepted_rows,
       COUNT(*) FILTER (WHERE quality_status <> 'accepted') AS rejected_rows
FROM analytics_demo.v_staging_sales_quality
GROUP BY batch_id;

COMMENT ON VIEW analytics_demo.v_staging_sales_quality IS
    'Shows the first detected quality issue by priority order; it is not a complete multi-error profiler.';