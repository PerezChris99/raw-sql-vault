-- Purpose: cooperative and SME sales analytics with explicit returns and net margin.
-- Engine: PostgreSQL 15+. Prerequisites: schema, seed and views.
-- 01. Net sales and margin by month/category.
SELECT * FROM ug_sales_analytics.v_monthly_category_sales ORDER BY month_start,business_ref,category_ref;
-- 02. Product net sales and margin.
SELECT product_ref,product_name,category_ref,SUM(net_quantity) AS units_net,
 SUM(net_sales_amount)::NUMERIC(16,2) AS net_sales,SUM(gross_margin_amount)::NUMERIC(16,2) AS gross_margin
FROM ug_sales_analytics.v_sale_line_net GROUP BY product_ref,product_name,category_ref ORDER BY net_sales DESC;
-- 03. Repeat-customer summary; only use tokenised data with lawful purpose.
SELECT * FROM ug_sales_analytics.v_customer_repeat_summary ORDER BY business_ref,completed_sales DESC;
-- 04. Returns exceeding original line quantity (should return zero).
SELECT l.sale_line_id,l.quantity,SUM(r.quantity) AS returned
FROM ug_sales_analytics.sale_lines l JOIN ug_sales_analytics.returns r USING(sale_line_id)
GROUP BY l.sale_line_id,l.quantity HAVING SUM(r.quantity)>l.quantity;
-- 05. Completed sales without lines (data quality exception).
SELECT s.sale_ref FROM ug_sales_analytics.sales s LEFT JOIN ug_sales_analytics.sale_lines l USING(sale_id)
WHERE s.status='completed' GROUP BY s.sale_id,s.sale_ref HAVING COUNT(l.sale_line_id)=0;
