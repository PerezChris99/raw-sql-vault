-- Purpose: inspect monthly sales and return balance queries.
-- Engine: PostgreSQL 15+. Run after representative synthetic data is loaded.
ANALYZE ug_sales_analytics.sales;
ANALYZE ug_sales_analytics.sale_lines;
ANALYZE ug_sales_analytics.returns;
EXPLAIN (COSTS, VERBOSE)
SELECT sale_id,product_id,SUM(quantity*unit_price) FROM ug_sales_analytics.sale_lines GROUP BY sale_id,product_id;
EXPLAIN (COSTS, VERBOSE)
SELECT sale_line_id,SUM(quantity) FROM ug_sales_analytics.returns WHERE sale_line_id=1 GROUP BY sale_line_id;
