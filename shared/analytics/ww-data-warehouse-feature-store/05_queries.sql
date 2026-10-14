-- Purpose: read-only warehouse, data-quality and feature-store examples.
-- Engine: PostgreSQL 15+; synthetic sources only.

-- 01. Staging quality distribution.
SELECT quality_status, COUNT(*) FROM analytics_demo.v_staging_sales_quality
GROUP BY quality_status ORDER BY quality_status;

-- 02. Batch summary.
SELECT * FROM analytics_demo.v_batch_summary ORDER BY batch_id;

-- 03. Daily sales by currency.
SELECT * FROM analytics_demo.v_daily_sales_by_currency ORDER BY calendar_date, currency, source_sku;

-- 04. Sales over time by SKU and currency.
SELECT calendar_date, source_sku, currency, gross_sales,
       SUM(gross_sales) OVER (
           PARTITION BY source_sku, currency ORDER BY calendar_date
           ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
       ) AS seven_observation_total
FROM analytics_demo.v_daily_sales_by_currency;

-- 05. Unique source-sale duplicates (should be prevented by the fact constraint).
SELECT source_system, source_sale_id, COUNT(*)
FROM analytics_demo.fact_sales GROUP BY source_system, source_sale_id HAVING COUNT(*) > 1;

-- 06. Facts missing a dimension (foreign keys should prevent this).
SELECT f.fact_id FROM analytics_demo.fact_sales f
LEFT JOIN analytics_demo.dim_products p USING (product_key)
LEFT JOIN analytics_demo.dim_locations l USING (location_key)
WHERE p.product_key IS NULL OR l.location_key IS NULL;

-- 07. Fact totals by source system and currency.
SELECT source_system, currency, COUNT(*) AS rows, SUM(amount) AS amount
FROM analytics_demo.fact_sales GROUP BY source_system, currency ORDER BY source_system, currency;

-- 08. Source rows that did not become facts.
SELECT s.source_system, s.source_sale_id, q.quality_status
FROM analytics_demo.staging_sales s
JOIN analytics_demo.v_staging_sales_quality q USING (staging_row_id)
LEFT JOIN analytics_demo.fact_sales f
  ON f.source_system = s.source_system AND f.source_sale_id = s.source_sale_id
WHERE q.quality_status = 'accepted' AND f.fact_id IS NULL;

-- 09. Facts by location and date.
SELECT l.locality_code, f.calendar_date, f.currency, SUM(f.amount) AS gross_sales
FROM analytics_demo.fact_sales f JOIN analytics_demo.dim_locations l USING (location_key)
GROUP BY l.locality_code, f.calendar_date, f.currency ORDER BY f.calendar_date, l.locality_code;

-- 10. High-value sales (illustrative threshold, not fraud logic).
SELECT source_system, source_sale_id, sold_at, amount, currency
FROM analytics_demo.fact_sales WHERE amount >= 1000000 ORDER BY amount DESC;

-- 11. Unknown SKU staging rows.
SELECT * FROM analytics_demo.v_staging_sales_quality WHERE quality_status = 'unknown_sku';

-- 12. Unknown locality staging rows.
SELECT * FROM analytics_demo.v_staging_sales_quality WHERE quality_status = 'unknown_locality';

-- 13. Feature metadata catalogue.
SELECT feature_name, entity_type, value_type, description, owner_ref, active
FROM analytics_demo.feature_registry ORDER BY entity_type, feature_name;

-- 14. Feature-history rows with both timestamps.
SELECT entity_type, entity_id, feature_name, feature_timestamp, source_available_at,
       numeric_value, text_value
FROM analytics_demo.feature_values
ORDER BY entity_type, entity_id, feature_name, feature_timestamp;

-- 15. Features eligible as of a prediction time; requires a known entity ID.
SELECT * FROM analytics_demo.fn_features_as_of(
    'product', 'DEMO-SKU-001', TIMESTAMPTZ '2026-10-12 23:59:59+00'
);

-- 16. Features that would be future leakage for a given prediction time.
SELECT * FROM analytics_demo.feature_values
WHERE feature_timestamp <= TIMESTAMPTZ '2026-10-12 23:59:59+00'
  AND source_available_at > TIMESTAMPTZ '2026-10-12 23:59:59+00';

-- 17. Feature records available later than their event timestamp.
SELECT feature_name, COUNT(*) AS late_arrivals
FROM analytics_demo.feature_values
WHERE source_available_at > feature_timestamp GROUP BY feature_name;

-- 18. Sales by calendar month and currency.
SELECT date_trunc('month', calendar_date)::date AS month, currency, SUM(amount) AS amount
FROM analytics_demo.fact_sales GROUP BY 1, currency ORDER BY 1, currency;

-- 19. Dimension cardinality.
SELECT 'product' AS dimension, COUNT(*) AS row_count FROM analytics_demo.dim_products
UNION ALL SELECT 'location', COUNT(*) FROM analytics_demo.dim_locations
UNION ALL SELECT 'date', COUNT(*) FROM analytics_demo.dim_dates;

-- 20. Staging freshness by batch.
SELECT batch_id, MIN(received_at) AS first_received, MAX(received_at) AS last_received,
       COUNT(*) AS rows
FROM analytics_demo.staging_sales GROUP BY batch_id ORDER BY last_received DESC;