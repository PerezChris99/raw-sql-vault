-- Purpose: monthly sales, returns, category margin and repeat-customer analysis.
-- Engine: PostgreSQL 15+. Prerequisite: 01_schema.sql. Rerunnable.
CREATE OR REPLACE VIEW ug_sales_analytics.v_sale_line_net AS
SELECT s.sale_ref,s.business_ref,s.sale_channel,s.customer_token,s.sold_at,s.currency_code,
 p.product_ref,p.product_name,p.category_ref,l.quantity,l.unit_price,l.unit_cost,
 COALESCE(SUM(r.quantity),0)::NUMERIC(14,3) AS returned_quantity,
 l.quantity-COALESCE(SUM(r.quantity),0) AS net_quantity,
 l.quantity*l.unit_price-COALESCE(SUM(r.refund_amount),0) AS net_sales_amount,
 (l.quantity-COALESCE(SUM(r.quantity),0))*l.unit_cost AS net_cost_amount,
 (l.quantity*l.unit_price-COALESCE(SUM(r.refund_amount),0))-
 ((l.quantity-COALESCE(SUM(r.quantity),0))*l.unit_cost) AS gross_margin_amount
FROM ug_sales_analytics.sale_lines l JOIN ug_sales_analytics.sales s USING(sale_id)
JOIN ug_sales_analytics.products p USING(product_id)
LEFT JOIN ug_sales_analytics.returns r USING(sale_line_id)
WHERE s.status='completed'
GROUP BY l.sale_line_id,s.sale_ref,s.business_ref,s.sale_channel,s.customer_token,s.sold_at,s.currency_code,
 p.product_ref,p.product_name,p.category_ref,l.quantity,l.unit_price,l.unit_cost;

CREATE OR REPLACE VIEW ug_sales_analytics.v_monthly_category_sales AS
SELECT business_ref,date_trunc('month',sold_at)::date AS month_start,category_ref,currency_code,
 SUM(net_quantity) AS units_net,SUM(net_sales_amount)::NUMERIC(16,2) AS net_sales,
 SUM(net_cost_amount)::NUMERIC(16,2) AS net_cost,SUM(gross_margin_amount)::NUMERIC(16,2) AS gross_margin
FROM ug_sales_analytics.v_sale_line_net
GROUP BY business_ref,date_trunc('month',sold_at)::date,category_ref,currency_code;

CREATE OR REPLACE VIEW ug_sales_analytics.v_customer_repeat_summary AS
SELECT business_ref,customer_token,COUNT(DISTINCT sale_ref) AS completed_sales,
 MIN(sold_at) AS first_sale_at,MAX(sold_at) AS latest_sale_at,
 SUM(net_sales_amount)::NUMERIC(16,2) AS net_sales
FROM ug_sales_analytics.v_sale_line_net WHERE customer_token IS NOT NULL
GROUP BY business_ref,customer_token;
