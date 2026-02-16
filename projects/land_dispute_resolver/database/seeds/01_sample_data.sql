-- ============================================================================
-- Land Dispute Resolver - Sample Data
-- PostgreSQL 14+ with PostGIS
-- ============================================================================

-- Districts
INSERT INTO land_districts (district_name, region) VALUES
('Wakiso', 'Central'),
('Mukono', 'Central'),
('Kampala', 'Central'),
('Jinja', 'Eastern'),
('Mbarara', 'Western')
ON CONFLICT (district_name) DO NOTHING;

-- Sample parcels with some intentional overlaps
-- Base coordinates around Kampala region (0.3°N, 32.6°E)

-- Non-overlapping parcels
INSERT INTO parcels (district_id, plot_number, block_number, owner_name, title_type, boundary, registered_date)
VALUES
(1, 'WKS-001', 'BLK-A', 'Mukasa John', 'freehold',
 ST_GeomFromText('POLYGON((32.60 0.30, 32.601 0.30, 32.601 0.301, 32.60 0.301, 32.60 0.30))', 4326),
 '2020-01-15'),
 
(1, 'WKS-002', 'BLK-A', 'Nambi Sarah', 'mailo',
 ST_GeomFromText('POLYGON((32.602 0.30, 32.603 0.30, 32.603 0.301, 32.602 0.301, 32.602 0.30))', 4326),
 '2019-06-20'),

(1, 'WKS-003', 'BLK-B', 'Ochieng Peter', 'leasehold',
 ST_GeomFromText('POLYGON((32.60 0.302, 32.601 0.302, 32.601 0.303, 32.60 0.303, 32.60 0.302))', 4326),
 '2021-03-10');

-- Overlapping parcels (for testing ST_Intersects)
INSERT INTO parcels (district_id, plot_number, block_number, owner_name, title_type, boundary, registered_date)
VALUES
-- These two parcels overlap significantly
(1, 'WKS-004', 'BLK-C', 'Kato David', 'freehold',
 ST_GeomFromText('POLYGON((32.605 0.305, 32.607 0.305, 32.607 0.307, 32.605 0.307, 32.605 0.305))', 4326),
 '2018-08-01'),
 
(1, 'WKS-005', 'BLK-C', 'Atim Grace', 'mailo',
 ST_GeomFromText('POLYGON((32.606 0.306, 32.608 0.306, 32.608 0.308, 32.606 0.308, 32.606 0.306))', 4326),
 '2017-04-15'),

-- Minor overlap
(1, 'WKS-006', 'BLK-D', 'Okello James', 'freehold',
 ST_GeomFromText('POLYGON((32.61 0.31, 32.612 0.31, 32.612 0.312, 32.61 0.312, 32.61 0.31))', 4326),
 '2019-11-20'),

(1, 'WKS-007', 'BLK-D', 'Nakito Mary', 'leasehold',
 ST_GeomFromText('POLYGON((32.6115 0.3105, 32.6135 0.3105, 32.6135 0.3125, 32.6115 0.3125, 32.6115 0.3105))', 4326),
 '2020-02-28'),

-- Another district
(2, 'MKN-001', 'BLK-A', 'Wasswa Henry', 'customary',
 ST_GeomFromText('POLYGON((32.75 0.35, 32.752 0.35, 32.752 0.352, 32.75 0.352, 32.75 0.35))', 4326),
 '2015-07-10'),

(2, 'MKN-002', 'BLK-A', 'Nabirye Rose', 'freehold',
 ST_GeomFromText('POLYGON((32.751 0.351, 32.753 0.351, 32.753 0.353, 32.751 0.353, 32.751 0.351))', 4326),
 '2016-09-22');

-- Add more parcels for variety
INSERT INTO parcels (district_id, plot_number, block_number, owner_name, title_type, boundary, registered_date)
SELECT 
    (seq % 5) + 1,
    'PLT-' || LPAD(seq::TEXT, 4, '0'),
    'BLK-' || CHR(65 + (seq % 10)),
    'Owner ' || seq,
    CASE seq % 4 WHEN 0 THEN 'freehold' WHEN 1 THEN 'leasehold' WHEN 2 THEN 'mailo' ELSE 'customary' END,
    ST_GeomFromText('POLYGON((' ||
        (32.5 + (seq % 20) * 0.01) || ' ' || (0.2 + (seq / 20) * 0.01) || ',' ||
        (32.502 + (seq % 20) * 0.01) || ' ' || (0.2 + (seq / 20) * 0.01) || ',' ||
        (32.502 + (seq % 20) * 0.01) || ' ' || (0.202 + (seq / 20) * 0.01) || ',' ||
        (32.5 + (seq % 20) * 0.01) || ' ' || (0.202 + (seq / 20) * 0.01) || ',' ||
        (32.5 + (seq % 20) * 0.01) || ' ' || (0.2 + (seq / 20) * 0.01) ||
    '))', 4326),
    CURRENT_DATE - (RANDOM() * 2000)::INT
FROM GENERATE_SERIES(10, 30) AS seq;

-- Register any detected overlaps as disputes
CALL sp_register_disputes();

SELECT 'Sample data loaded' AS status;
SELECT 'Parcels: ' || COUNT(*) FROM parcels;
SELECT 'Overlapping pairs: ' || COUNT(*) FROM vw_overlapping_parcels;
SELECT 'Disputes: ' || COUNT(*) FROM disputes;
