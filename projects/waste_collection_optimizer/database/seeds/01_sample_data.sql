-- ============================================================================
-- Waste Collection Optimizer - Sample Data
-- PostgreSQL 14+
-- ============================================================================

-- Zones (Kampala divisions)
INSERT INTO zones (zone_name, division, area_sqkm, population, households) VALUES
('Nakawa Central', 'Nakawa', 15.2, 85000, 21000),
('Nakawa Industrial', 'Nakawa', 12.8, 42000, 10500),
('Makindye East', 'Makindye', 18.5, 92000, 23000),
('Makindye West', 'Makindye', 14.3, 78000, 19500),
('Kawempe North', 'Kawempe', 20.1, 110000, 27500),
('Kawempe South', 'Kawempe', 16.7, 95000, 23750),
('Rubaga Central', 'Rubaga', 13.9, 88000, 22000),
('Lubaga Market', 'Rubaga', 8.2, 65000, 16250),
('Central Business', 'Central', 9.5, 35000, 8750),
('Old Kampala', 'Central', 7.8, 48000, 12000)
ON CONFLICT (zone_name) DO NOTHING;

-- Trucks
INSERT INTO trucks (plate_number, model, capacity_kg, capacity_liters, status) VALUES
('UAX 123A', 'Isuzu FTR', 8000, 12000, 'available'),
('UAX 456B', 'Isuzu FTR', 8000, 12000, 'available'),
('UAX 789C', 'Hino 300', 6000, 9000, 'available'),
('UAX 012D', 'Hino 300', 6000, 9000, 'in_use'),
('UAX 345E', 'Mitsubishi Canter', 4000, 6000, 'available'),
('UAX 678F', 'Mitsubishi Canter', 4000, 6000, 'maintenance')
ON CONFLICT (plate_number) DO NOTHING;

-- Routes
INSERT INTO routes (zone_id, route_name, route_code, distance_km, estimated_duration_mins, schedule_days, truck_id)
SELECT z.zone_id, z.zone_name || ' Route ' || seq, 
       UPPER(LEFT(z.zone_name, 3)) || '-R' || seq,
       (RANDOM() * 15 + 10)::DECIMAL(4,1),
       (RANDOM() * 120 + 60)::INT,
       CASE seq % 3 WHEN 0 THEN 'Mon,Wed,Fri' WHEN 1 THEN 'Tue,Thu,Sat' ELSE 'Mon,Thu' END,
       (SELECT truck_id FROM trucks WHERE status = 'available' ORDER BY RANDOM() LIMIT 1)
FROM zones z
CROSS JOIN GENERATE_SERIES(1, 2) AS seq
ON CONFLICT (route_code) DO NOTHING;

-- Bins (20-40 per route)
INSERT INTO bins (route_id, bin_code, location_desc, latitude, longitude, capacity_liters, bin_type, current_level, last_emptied, installed_date)
SELECT 
    r.route_id,
    r.route_code || '-B' || LPAD(seq::TEXT, 3, '0'),
    CASE (RANDOM() * 5)::INT 
        WHEN 0 THEN 'Near market entrance'
        WHEN 1 THEN 'Street corner'
        WHEN 2 THEN 'Shopping center'
        WHEN 3 THEN 'Residential area'
        WHEN 4 THEN 'Bus stop'
        ELSE 'Commercial zone'
    END,
    0.3 + (RANDOM() * 0.1),
    32.5 + (RANDOM() * 0.1),
    CASE (RANDOM() * 3)::INT WHEN 0 THEN 660 WHEN 1 THEN 1100 ELSE 240 END,
    CASE (RANDOM() * 4)::INT WHEN 0 THEN 'recyclable' WHEN 1 THEN 'organic' ELSE 'general' END,
    (RANDOM() * 100)::INT,
    NOW() - ((RANDOM() * 72) || ' hours')::INTERVAL,
    CURRENT_DATE - (RANDOM() * 365)::INT
FROM routes r
CROSS JOIN GENERATE_SERIES(1, (RANDOM() * 20 + 20)::INT) AS seq
ON CONFLICT (bin_code) DO NOTHING;

-- Update bin levels to simulate realistic patterns (more full bins in busy areas)
UPDATE bins SET current_level = LEAST(100, current_level + 30)
WHERE route_id IN (SELECT route_id FROM routes r JOIN zones z ON r.zone_id = z.zone_id 
                   WHERE z.zone_name LIKE '%Market%' OR z.zone_name LIKE '%Central%');

-- Sample collections (last 30 days)
INSERT INTO collections (bin_id, truck_id, route_id, collected_at, level_before, weight_kg, collector_name)
SELECT 
    b.bin_id,
    r.truck_id,
    b.route_id,
    CURRENT_TIMESTAMP - ((RANDOM() * 30)::INT || ' days')::INTERVAL - ((RANDOM() * 8)::INT || ' hours')::INTERVAL,
    (RANDOM() * 40 + 60)::INT,
    (b.capacity_liters * (RANDOM() * 0.4 + 0.5) * 0.3)::DECIMAL(6,2),
    'Collector ' || (RANDOM() * 10 + 1)::INT
FROM bins b
JOIN routes r ON b.route_id = r.route_id
CROSS JOIN GENERATE_SERIES(1, 3);

SELECT 'Sample data loaded' AS status;
SELECT COUNT(*) || ' zones' AS zones FROM zones;
SELECT COUNT(*) || ' routes' AS routes FROM routes;
SELECT COUNT(*) || ' bins' AS bins FROM bins;
SELECT COUNT(*) || ' collections' AS collections FROM collections;
