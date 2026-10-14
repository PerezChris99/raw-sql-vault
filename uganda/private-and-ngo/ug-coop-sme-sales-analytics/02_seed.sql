-- Purpose: synthetic product and sale fixture. Safe to rerun.
-- Engine: PostgreSQL 15+. Prerequisite: 01_schema.sql.
INSERT INTO ug_sales_analytics.products(product_ref,product_name,category_ref,unit_code)
VALUES('UGSA-P-DEMO-001','Synthetic maize flour bag','SYN-FOOD','bag')
ON CONFLICT(product_ref) DO NOTHING;
INSERT INTO ug_sales_analytics.sales(sale_ref,idempotency_key,business_ref,sale_channel,customer_token,sold_at,source_receipt_ref,recorded_by_ref)
VALUES('UGSA-S-DEMO-001','sales-demo-idem-001','SYN-COOP-01','market','SYN-CUSTOMER-001',
 TIMESTAMPTZ '2026-10-01 10:00:00+03','SYN-RECEIPT-001','SYN-SALES-CLERK')
ON CONFLICT(sale_ref) DO NOTHING;
INSERT INTO ug_sales_analytics.sale_lines(sale_id,line_no,product_id,quantity,unit_price,unit_cost)
SELECT s.sale_id,1,p.product_id,10,5000,3500 FROM ug_sales_analytics.sales s
CROSS JOIN ug_sales_analytics.products p
WHERE s.sale_ref='UGSA-S-DEMO-001' AND p.product_ref='UGSA-P-DEMO-001'
ON CONFLICT(sale_id,line_no) DO NOTHING;
