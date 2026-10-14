-- Purpose: seed synthetic customer and catalogue references.
-- Engine: PostgreSQL 15+; requires 01_schema.sql.
-- Rerun safety: unique references/SKUs and ON CONFLICT DO NOTHING.

INSERT INTO shop_demo.customers(customer_ref) VALUES
    ('DEMO-CUSTOMER-A'),
    ('DEMO-CUSTOMER-B'),
    ('TEST-CHECKOUT-CUSTOMER')
ON CONFLICT (customer_ref) DO NOTHING;

INSERT INTO shop_demo.products(sku, product_name, unit_price, currency, stock_quantity)
VALUES
    ('DEMO-SKU-001', 'Synthetic notebook', 4000.00, 'UGX', 150),
    ('DEMO-SKU-002', 'Synthetic reusable bottle', 18000.00, 'UGX', 40),
    ('TEST-CHECKOUT-ITEM', 'Synthetic checkout test item', 1000.00, 'UGX', 10)
ON CONFLICT (sku) DO NOTHING;