-- Purpose: operational and analytical read-only examples.
-- Engine: PostgreSQL 15+; synthetic records only.

-- 01. Latest orders.
SELECT * FROM shop_demo.v_order_summary ORDER BY created_at DESC, order_id DESC;

-- 02. Low stock catalogue.
SELECT * FROM shop_demo.v_low_stock ORDER BY stock_quantity, sku;

-- 03. Order counts and values by status.
SELECT status, currency, COUNT(*) AS orders, SUM(total_amount) AS gross_value
FROM shop_demo.orders GROUP BY status, currency ORDER BY status, currency;

-- 04. Order items with price snapshots.
SELECT o.order_id, p.sku, i.quantity, i.unit_price, i.line_total
FROM shop_demo.order_items i JOIN shop_demo.orders o USING (order_id)
JOIN shop_demo.products p USING (product_id) ORDER BY o.order_id, p.sku;

-- 05. Revenue by UTC day.
SELECT * FROM shop_demo.v_order_revenue_by_utc_day ORDER BY utc_day, currency;

-- 06. Customers who have never ordered.
SELECT c.customer_ref FROM shop_demo.customers c
WHERE NOT EXISTS (SELECT 1 FROM shop_demo.orders o WHERE o.customer_id = c.customer_id);

-- 07. Top products by units sold.
SELECT p.sku, SUM(i.quantity) AS units
FROM shop_demo.order_items i JOIN shop_demo.products p USING (product_id)
JOIN shop_demo.orders o USING (order_id) WHERE o.status <> 'cancelled'
GROUP BY p.sku ORDER BY units DESC LIMIT 10;

-- 08. Top products by gross order value.
SELECT p.sku, SUM(i.line_total) AS gross_value
FROM shop_demo.order_items i JOIN shop_demo.products p USING (product_id)
JOIN shop_demo.orders o USING (order_id) WHERE o.status IN ('paid', 'fulfilled')
GROUP BY p.sku ORDER BY gross_value DESC LIMIT 10;

-- 09. Order event history.
SELECT o.order_id, e.previous_status, e.new_status, e.actor_ref, e.happened_at
FROM shop_demo.order_events e JOIN shop_demo.orders o USING (order_id)
ORDER BY o.order_id, e.happened_at, e.event_id;

-- 10. Latest status event per order.
SELECT DISTINCT ON (order_id) order_id, new_status, happened_at
FROM shop_demo.order_events ORDER BY order_id, happened_at DESC, event_id DESC;

-- 11. Average order value by customer reference.
SELECT c.customer_ref, AVG(o.total_amount) AS average_order_value, COUNT(o.order_id) AS order_count
FROM shop_demo.customers c LEFT JOIN shop_demo.orders o
ON o.customer_id = c.customer_id AND o.status IN ('paid', 'fulfilled')
GROUP BY c.customer_ref ORDER BY average_order_value DESC NULLS LAST;

-- 12. Basket size distribution.
SELECT unit_count, COUNT(*) AS orders
FROM shop_demo.v_order_summary GROUP BY unit_count ORDER BY unit_count;

-- 13. Items with inconsistent stored line totals (generated column should prevent this).
SELECT order_id, product_id, quantity, unit_price, line_total
FROM shop_demo.order_items WHERE line_total <> quantity * unit_price;

-- 14. Order idempotency key reuse duplicates (unique constraint should prevent rows).
SELECT idempotency_key, COUNT(*) FROM shop_demo.orders
GROUP BY idempotency_key HAVING COUNT(*) > 1;

-- 15. Revenue share by SKU within currency.
WITH sku_revenue AS (
    SELECT o.currency, p.sku, SUM(i.line_total) AS amount
    FROM shop_demo.order_items i JOIN shop_demo.orders o USING (order_id)
    JOIN shop_demo.products p USING (product_id)
    WHERE o.status IN ('paid', 'fulfilled')
    GROUP BY o.currency, p.sku
)
SELECT currency, sku, amount,
       ROUND(100.0 * amount / NULLIF(SUM(amount) OVER (PARTITION BY currency), 0), 2) AS currency_revenue_pct
FROM sku_revenue ORDER BY currency, amount DESC;

-- 16. Orders created in the previous 30 days using a half-open timestamp range.
SELECT order_id, status, total_amount, created_at
FROM shop_demo.orders WHERE created_at >= now() - INTERVAL '30 days' AND created_at < now()
ORDER BY created_at DESC;

-- 17. Orders with no line items (should be empty for checkout-created orders).
SELECT o.order_id FROM shop_demo.orders o
WHERE NOT EXISTS (SELECT 1 FROM shop_demo.order_items i WHERE i.order_id = o.order_id);

-- 18. Stock exposure by currency.
SELECT currency, SUM(stock_quantity) AS units, COUNT(*) AS skus
FROM shop_demo.products WHERE is_active GROUP BY currency ORDER BY currency;

-- 19. Conversion of placed orders to paid/fulfilled, by order month.
SELECT date_trunc('month', created_at) AS month,
       COUNT(*) AS placed_or_later,
       COUNT(*) FILTER (WHERE status IN ('paid', 'fulfilled')) AS paid_or_fulfilled
FROM shop_demo.orders GROUP BY 1 ORDER BY 1;

-- 20. Customers whose last order is older than 90 days or who have never ordered.
SELECT c.customer_ref, MAX(o.created_at) AS last_order_at
FROM shop_demo.customers c LEFT JOIN shop_demo.orders o USING (customer_id)
GROUP BY c.customer_ref
HAVING MAX(o.created_at) IS NULL OR MAX(o.created_at) < now() - INTERVAL '90 days'
ORDER BY last_order_at NULLS FIRST;