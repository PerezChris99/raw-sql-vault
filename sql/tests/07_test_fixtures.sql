-- Purpose: deterministic regression fixture setup.
-- Engine: PostgreSQL 15+ with PostGIS.
-- WARNING: DESTRUCTIVE to vault_demo fixture data only. Never target production.
-- These are invented test records, not real people or places.

TRUNCATE TABLE
    vault_demo.sales,
    vault_demo.customers,
    vault_demo.users,
    vault_demo.places
RESTART IDENTITY CASCADE;

INSERT INTO vault_demo.customers (display_name, score) VALUES
    ('Synthetic Customer A', 85),
    ('Synthetic Customer B', NULL),
    ('Synthetic Customer C', 10);

INSERT INTO vault_demo.sales
    (customer_id, amount, currency, status, created_at, is_deleted)
VALUES
    (1, 10.00, 'UGX', 'paid',      '2024-01-25 12:00:00+00', FALSE),
    (1, 20.00, 'UGX', 'shipped',   '2024-01-27 09:15:00+00', FALSE),
    (2, 50.00, 'UGX', 'paid',      '2024-01-31 23:59:59+00', FALSE),
    (3, 100.00, 'UGX', 'delivered', '2024-02-01 00:00:00+00', FALSE),
    (3, 999.00, 'UGX', 'cancelled', '2024-02-01 12:00:00+00', FALSE),
    (1, 500.00, 'UGX', 'paid',     '2024-01-30 12:00:00+00', TRUE);

INSERT INTO vault_demo.places (name, name_normalized, location) VALUES
    ('Synthetic Place A', 'synthetic-place', ST_SetSRID(ST_MakePoint(0.00000, 0.00000), 4326)::geography),
    ('Synthetic Place B', 'synthetic-place', ST_SetSRID(ST_MakePoint(0.00005, 0.00000), 4326)::geography),
    ('Synthetic Place C', 'synthetic-place', ST_SetSRID(ST_MakePoint(1.00000, 1.00000), 4326)::geography);