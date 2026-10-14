-- Purpose: seed invented products and opening-stock events.
-- Engine: PostgreSQL 15+; requires 01_schema.sql.
-- Rerun safety: stable SKUs and movement idempotency keys.

INSERT INTO sme_stock_demo.products
    (sku, product_name, category, unit_of_measure, unit_cost, unit_price, currency, reorder_level)
VALUES
    ('DEMO-TEA-UG', 'Synthetic packed tea', 'grocery', 'pack', 1800.00, 2500.00, 'UGX', 15),
    ('DEMO-RICE-UG', 'Synthetic rice bag', 'grocery', 'bag', 48000.00, 56000.00, 'UGX', 8),
    ('DEMO-SOAP-UG', 'Synthetic soap carton', 'household', 'carton', 22000.00, 27000.00, 'UGX', 5)
ON CONFLICT (sku) DO NOTHING;

INSERT INTO sme_stock_demo.stock_movements
    (product_id, quantity_delta, reason, idempotency_key, source_ref, actor_ref)
SELECT p.product_id, v.quantity_delta, 'receipt', v.idempotency_key, 'synthetic-opening-stock', 'seed-script'
FROM (VALUES
    ('DEMO-TEA-UG', 100, 'seed-stock-tea-v1'),
    ('DEMO-RICE-UG', 5, 'seed-stock-rice-v1'),
    ('DEMO-SOAP-UG', 20, 'seed-stock-soap-v1')
) AS v(sku, quantity_delta, idempotency_key)
JOIN sme_stock_demo.products p ON p.sku = v.sku
ON CONFLICT (idempotency_key) DO NOTHING;