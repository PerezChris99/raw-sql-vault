-- 20 POS sales/inventory reports.
-- 01 Receipt summary.
SELECT * FROM pos_demo.v_receipt_summary ORDER BY occurred_at DESC;
-- 02 Stock on hand.
SELECT * FROM pos_demo.v_stock_on_hand ORDER BY sku;
-- 03 Daily gross sales.
SELECT * FROM pos_demo.v_daily_sales ORDER BY sales_date,currency;
-- 04 Sales by terminal.
SELECT terminal_ref,COUNT(*) receipts FROM pos_demo.sales WHERE status<>'voided' GROUP BY terminal_ref;
-- 05 Sales by currency/status.
SELECT currency,status,COUNT(*),SUM(receipt_total) FROM pos_demo.v_receipt_summary GROUP BY 1,2;
-- 06 Units sold by SKU.
SELECT p.sku,SUM(l.quantity) units_sold FROM pos_demo.sale_lines l JOIN pos_demo.products p USING(product_id) GROUP BY p.sku ORDER BY units_sold DESC;
-- 07 Sales by hour UTC.
SELECT EXTRACT(HOUR FROM occurred_at AT TIME ZONE 'UTC') AS hour_utc,COUNT(*) FROM pos_demo.sales GROUP BY 1 ORDER BY 1;
-- 08 Zero stock / negative stock exceptions.
SELECT sku,quantity_on_hand FROM pos_demo.v_stock_on_hand WHERE quantity_on_hand<=0;
-- 09 Stock movement history.
SELECT p.sku,e.happened_at,e.reason,e.quantity_delta,e.source_ref FROM pos_demo.stock_events e JOIN pos_demo.products p USING(product_id) ORDER BY p.sku,e.happened_at;
-- 10 Returns by reason.
SELECT reason,COUNT(*),SUM(quantity) FROM pos_demo.returns GROUP BY reason;
-- 11 Returns per SKU.
SELECT p.sku,SUM(r.quantity) returned_units FROM pos_demo.returns r JOIN pos_demo.sale_lines l USING(sale_line_id) JOIN pos_demo.products p USING(product_id) GROUP BY p.sku;
-- 12 Sale lines with return totals.
SELECT s.receipt_ref,p.sku,l.quantity,COALESCE(SUM(r.quantity),0) returned FROM pos_demo.sale_lines l JOIN pos_demo.sales s USING(sale_id) JOIN pos_demo.products p USING(product_id) LEFT JOIN pos_demo.returns r USING(sale_line_id) GROUP BY s.receipt_ref,p.sku,l.quantity;
-- 13 Receipts with no lines.
SELECT receipt_ref FROM pos_demo.sales s WHERE NOT EXISTS(SELECT 1 FROM pos_demo.sale_lines l WHERE l.sale_id=s.sale_id);
-- 14 Products with no sales.
SELECT sku FROM pos_demo.products p WHERE NOT EXISTS(SELECT 1 FROM pos_demo.sale_lines l WHERE l.product_id=p.product_id);
-- 15 Gross value by SKU/currency.
SELECT p.sku,s.currency,SUM(l.line_total) FROM pos_demo.sale_lines l JOIN pos_demo.sales s USING(sale_id) JOIN pos_demo.products p USING(product_id) WHERE s.status<>'voided' GROUP BY p.sku,s.currency;
-- 16 Top receipt value.
SELECT receipt_ref,receipt_total FROM pos_demo.v_receipt_summary ORDER BY receipt_total DESC LIMIT 10;
-- 17 Average receipt value by terminal.
SELECT terminal_ref,AVG(receipt_total) FROM pos_demo.v_receipt_summary GROUP BY terminal_ref;
-- 18 Receipt volume by UTC month.
SELECT date_trunc('month',occurred_at AT TIME ZONE 'UTC') AS month_utc,COUNT(*) FROM pos_demo.sales GROUP BY 1 ORDER BY 1;
-- 19 Returns exceeding sold quantity (should be empty).
SELECT sale_line_id FROM pos_demo.returns GROUP BY sale_line_id HAVING SUM(quantity)>(SELECT quantity FROM pos_demo.sale_lines l WHERE l.sale_line_id=returns.sale_line_id);
-- 20 Sales total by day/currency.
SELECT sales_date,currency,SUM(gross_value) FROM pos_demo.v_daily_sales GROUP BY sales_date,currency ORDER BY sales_date,currency;