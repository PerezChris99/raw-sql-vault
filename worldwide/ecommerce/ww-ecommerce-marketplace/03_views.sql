-- Purpose: query-friendly order, inventory and sales reporting.
-- Engine: PostgreSQL 15+; requires schema and seed files.
-- Rerun safety: CREATE OR REPLACE VIEW.

CREATE OR REPLACE VIEW shop_demo.v_order_summary AS
SELECT o.order_id, c.customer_ref, o.status, o.currency, o.total_amount,
       o.created_at, COUNT(i.product_id)::BIGINT AS line_count,
       COALESCE(SUM(i.quantity), 0)::BIGINT AS unit_count
FROM shop_demo.orders o
JOIN shop_demo.customers c ON c.customer_id = o.customer_id
LEFT JOIN shop_demo.order_items i ON i.order_id = o.order_id
GROUP BY o.order_id, c.customer_ref, o.status, o.currency, o.total_amount, o.created_at;

CREATE OR REPLACE VIEW shop_demo.v_low_stock AS
SELECT product_id, sku, product_name, stock_quantity, currency
FROM shop_demo.products
WHERE is_active = TRUE AND stock_quantity <= 10;

CREATE OR REPLACE VIEW shop_demo.v_order_revenue_by_utc_day AS
SELECT (o.created_at AT TIME ZONE 'UTC')::date AS utc_day, o.currency,
       COUNT(*) AS orders, SUM(o.total_amount) AS gross_order_value
FROM shop_demo.orders o
WHERE o.status IN ('paid', 'fulfilled')
GROUP BY (o.created_at AT TIME ZONE 'UTC')::date, o.currency;

COMMENT ON VIEW shop_demo.v_order_revenue_by_utc_day IS
    'Gross order value by UTC order-creation date; not net revenue or accounting recognition.';