-- Purpose: deterministic synthetic dimensions, staging batch and feature examples.
-- Engine: PostgreSQL 15+; requires 01_schema.sql.
-- Rerun safety: uses natural keys and staging batch/source uniqueness.

INSERT INTO analytics_demo.dim_products(source_sku, product_name)
VALUES ('DEMO-SKU-001', 'Synthetic notebook'), ('DEMO-SKU-002', 'Synthetic tea pack')
ON CONFLICT (source_sku) DO NOTHING;

INSERT INTO analytics_demo.dim_locations(locality_code, locality_name, locality_type)
VALUES ('DEMO-KLA', 'Synthetic Central Area', 'urban'),
       ('DEMO-WAK', 'Synthetic District Area', 'district')
ON CONFLICT (locality_code) DO NOTHING;

INSERT INTO analytics_demo.feature_registry(feature_name, entity_type, value_type, description, owner_ref)
VALUES ('avg_units_7d', 'product', 'numeric', 'Synthetic seven-day units feature', 'demo-data-owner')
ON CONFLICT (feature_name, entity_type) DO NOTHING;

INSERT INTO analytics_demo.staging_sales
    (batch_id, source_system, source_sale_id, sold_at, source_sku, locality_code, amount, currency)
VALUES
    ('11111111-1111-4111-8111-111111111111', 'synthetic-pos', 'POS-DEMO-001', '2026-10-01 08:00:00+00', 'DEMO-SKU-001', 'DEMO-KLA', 4000.00, 'UGX'),
    ('11111111-1111-4111-8111-111111111111', 'synthetic-pos', 'POS-DEMO-002', '2026-10-02 10:00:00+00', 'DEMO-SKU-002', 'DEMO-WAK', 5000.00, 'UGX'),
    ('11111111-1111-4111-8111-111111111111', 'synthetic-pos', 'POS-DEMO-003', '2026-10-02 13:00:00+00', 'DEMO-SKU-001', 'DEMO-KLA', 8000.00, 'UGX')
ON CONFLICT (batch_id, source_system, source_sale_id) DO NOTHING;

INSERT INTO analytics_demo.feature_values
    (entity_type, entity_id, feature_name, feature_timestamp, source_available_at, numeric_value, source_record_ref)
VALUES
    ('product', 'DEMO-SKU-001', 'avg_units_7d', '2026-10-10 00:00:00+00', '2026-10-11 00:00:00+00', 12.5, 'synthetic-feature-v1'),
    ('product', 'DEMO-SKU-001', 'avg_units_7d', '2026-10-11 00:00:00+00', '2026-10-13 00:00:00+00', 99.9, 'synthetic-feature-late-v1')
ON CONFLICT DO NOTHING;