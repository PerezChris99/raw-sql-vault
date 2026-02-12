-- ============================================================================
-- Power Outage Pattern Analyzer - Sample Data
-- Substations, power lines, transformers, service points, and outages
-- ============================================================================

-- ============================================================================
-- Substations
-- ============================================================================

INSERT INTO substations (district_id, name, code, location, substation_type, voltage_level_kv, capacity_mva, commissioned_date, status) VALUES
-- North Metro substations
(1, 'Downtown Main', 'SUB-DT01', ST_GeogFromText('POINT(-122.405 37.785)'), 'transmission', 230, 500.0, '1985-03-15', 'operational'),
(1, 'Central Distribution', 'SUB-DT02', ST_GeogFromText('POINT(-122.395 37.775)'), 'distribution', 69, 150.0, '1992-06-20', 'operational'),
(2, 'Financial Hub', 'SUB-FD01', ST_GeogFromText('POINT(-122.392 37.790)'), 'distribution', 69, 175.0, '1998-09-10', 'operational'),
(3, 'Northside Primary', 'SUB-NH01', ST_GeogFromText('POINT(-122.425 37.850)'), 'transmission', 115, 300.0, '1988-11-05', 'operational'),
(4, 'Harbor Substation', 'SUB-HP01', ST_GeogFromText('POINT(-122.475 37.800)'), 'distribution', 69, 125.0, '2005-04-22', 'operational'),
-- South Metro substations
(5, 'Industrial Main', 'SUB-IP01', ST_GeogFromText('POINT(-122.415 37.515)'), 'transmission', 230, 450.0, '1978-02-28', 'operational'),
(6, 'South Central Primary', 'SUB-SC01', ST_GeogFromText('POINT(-122.385 37.550)'), 'distribution', 69, 200.0, '2001-07-14', 'operational'),
(7, 'Riverside Hub', 'SUB-RS01', ST_GeogFromText('POINT(-122.440 37.415)'), 'distribution', 69, 140.0, '1995-12-01', 'operational'),
-- East Valley substations
(9, 'Valley Central', 'SUB-VC01', ST_GeogFromText('POINT(-121.900 37.670)'), 'transmission', 230, 350.0, '1990-05-18', 'operational'),
(10, 'East Hills Primary', 'SUB-EH01', ST_GeogFromText('POINT(-121.775 37.715)'), 'distribution', 69, 120.0, '2010-08-30', 'operational'),
-- West Coast substations
(12, 'Ocean View Main', 'SUB-OV01', ST_GeogFromText('POINT(-122.550 37.700)'), 'distribution', 69, 160.0, '1999-03-25', 'operational'),
(13, 'Coastal Primary', 'SUB-CH01', ST_GeogFromText('POINT(-122.555 37.600)'), 'distribution', 69, 130.0, '2008-10-12', 'operational');

-- ============================================================================
-- Power Lines
-- ============================================================================

INSERT INTO power_lines (start_substation_id, end_substation_id, name, line_type, voltage_kv, route, conductor_type, capacity_mw, installation_year, status) VALUES
-- North Metro transmission
(1, 4, 'DT-NH Transmission', 'transmission', 230, 
 ST_GeomFromText('LINESTRING(-122.405 37.785, -122.410 37.800, -122.415 37.820, -122.425 37.850)', 4326),
 'ACSR', 400.0, 1988, 'active'),
(1, 2, 'DT Main-Central', 'distribution', 69,
 ST_GeomFromText('LINESTRING(-122.405 37.785, -122.400 37.780, -122.395 37.775)', 4326),
 'AAC', 100.0, 1992, 'active'),
(2, 3, 'Central-Financial', 'distribution', 69,
 ST_GeomFromText('LINESTRING(-122.395 37.775, -122.393 37.780, -122.392 37.790)', 4326),
 'AAC', 80.0, 1998, 'active'),
(4, 5, 'Northside-Harbor', 'distribution', 69,
 ST_GeomFromText('LINESTRING(-122.425 37.850, -122.440 37.835, -122.460 37.815, -122.475 37.800)', 4326),
 'AAC', 90.0, 2005, 'active'),
-- South Metro transmission
(1, 6, 'DT-Industrial Main', 'transmission', 230,
 ST_GeomFromText('LINESTRING(-122.405 37.785, -122.408 37.700, -122.412 37.600, -122.415 37.515)', 4326),
 'ACSR', 450.0, 1978, 'active'),
(6, 7, 'Industrial-South Central', 'distribution', 69,
 ST_GeomFromText('LINESTRING(-122.415 37.515, -122.400 37.530, -122.385 37.550)', 4326),
 'AAC', 120.0, 2001, 'active'),
-- Cross-region
(6, 9, 'Industrial-Valley', 'transmission', 230,
 ST_GeomFromText('LINESTRING(-122.415 37.515, -122.200 37.550, -122.000 37.600, -121.900 37.670)', 4326),
 'ACSR', 300.0, 1990, 'active'),
(9, 10, 'Valley-EastHills', 'distribution', 69,
 ST_GeomFromText('LINESTRING(-121.900 37.670, -121.850 37.690, -121.775 37.715)', 4326),
 'AAC', 80.0, 2010, 'active');

-- ============================================================================
-- Transformers
-- ============================================================================

INSERT INTO transformers (district_id, line_id, name, code, location, transformer_type, capacity_kva, primary_voltage_v, secondary_voltage_v, installation_date, last_maintenance_date, status, customers_served) VALUES
-- Downtown Core transformers
(1, 2, 'DT-T001', 'TR-DT001', ST_GeogFromText('POINT(-122.402 37.782)'), 'pad_mounted', 500, 12470, 208, '2005-03-15', '2023-06-10', 'operational', 85),
(1, 2, 'DT-T002', 'TR-DT002', ST_GeogFromText('POINT(-122.398 37.778)'), 'pad_mounted', 750, 12470, 208, '2008-07-22', '2023-08-15', 'operational', 120),
(1, 2, 'DT-T003', 'TR-DT003', ST_GeogFromText('POINT(-122.408 37.777)'), 'underground', 1000, 12470, 208, '2012-11-30', '2024-01-20', 'operational', 180),
(1, 2, 'DT-T004', 'TR-DT004', ST_GeogFromText('POINT(-122.412 37.785)'), 'pad_mounted', 500, 12470, 208, '1998-05-10', '2022-09-05', 'degraded', 75),
-- Financial District transformers
(2, 3, 'FD-T001', 'TR-FD001', ST_GeogFromText('POINT(-122.393 37.792)'), 'underground', 1500, 12470, 208, '2015-09-28', '2024-02-14', 'operational', 250),
(2, 3, 'FD-T002', 'TR-FD002', ST_GeogFromText('POINT(-122.388 37.788)'), 'underground', 1500, 12470, 208, '2015-09-28', '2024-02-14', 'operational', 280),
-- Northside Heights transformers
(3, 4, 'NH-T001', 'TR-NH001', ST_GeogFromText('POINT(-122.435 37.852)'), 'pole_mounted', 167, 7200, 240, '1995-04-12', '2023-03-22', 'operational', 35),
(3, 4, 'NH-T002', 'TR-NH002', ST_GeogFromText('POINT(-122.428 37.845)'), 'pole_mounted', 167, 7200, 240, '1997-08-05', '2023-05-18', 'operational', 42),
(3, 4, 'NH-T003', 'TR-NH003', ST_GeogFromText('POINT(-122.442 37.838)'), 'pole_mounted', 250, 7200, 240, '2002-12-14', '2023-11-02', 'operational', 55),
-- Industrial Park transformers
(5, 5, 'IP-T001', 'TR-IP001', ST_GeogFromText('POINT(-122.420 37.525)'), 'pad_mounted', 2500, 12470, 480, '2000-06-30', '2023-07-25', 'operational', 15),
(5, 5, 'IP-T002', 'TR-IP002', ST_GeogFromText('POINT(-122.405 37.510)'), 'pad_mounted', 2500, 12470, 480, '2000-06-30', '2023-07-25', 'operational', 12),
-- Valley Center transformers
(9, 7, 'VC-T001', 'TR-VC001', ST_GeogFromText('POINT(-121.905 37.680)'), 'pole_mounted', 333, 7200, 240, '2005-02-18', '2024-01-10', 'operational', 65),
(9, 7, 'VC-T002', 'TR-VC002', ST_GeogFromText('POINT(-121.890 37.665)'), 'pole_mounted', 333, 7200, 240, '2005-02-18', '2023-12-08', 'operational', 58),
-- East Hills transformers
(10, 8, 'EH-T001', 'TR-EH001', ST_GeogFromText('POINT(-121.780 37.720)'), 'pole_mounted', 167, 7200, 240, '2012-09-15', '2024-02-28', 'operational', 28),
(10, 8, 'EH-T002', 'TR-EH002', ST_GeogFromText('POINT(-121.765 37.705)'), 'pole_mounted', 167, 7200, 240, '2012-09-15', '2024-02-28', 'operational', 32);

-- ============================================================================
-- Sample Outages (Historical Data - Last 6 months)
-- Includes cluster patterns for hotspot analysis
-- ============================================================================

-- Helper: Create outages with proper geospatial distribution
DO $$
DECLARE
    v_outage_id UUID;
    i INTEGER;
    v_lat NUMERIC;
    v_lon NUMERIC;
BEGIN
    -- Cluster 1: Downtown equipment issues (dense cluster)
    FOR i IN 1..25 LOOP
        v_lat := 37.780 + (random() * 0.008);
        v_lon := -122.405 + (random() * 0.012);
        
        INSERT INTO outages (
            district_id, cause_id, weather_condition_id, location,
            occurred_at, restored_at, customers_affected, estimated_load_lost_kw,
            outage_type, status
        ) VALUES (
            1,
            (ARRAY[8, 10, 11, 14])[floor(random() * 4 + 1)],  -- Equipment causes
            1,  -- Clear weather
            ST_GeogFromText('POINT(' || v_lon || ' ' || v_lat || ')'),
            CURRENT_TIMESTAMP - (random() * 180 || ' days')::INTERVAL,
            CURRENT_TIMESTAMP - (random() * 180 || ' days')::INTERVAL + (random() * 4 || ' hours')::INTERVAL,
            floor(random() * 800 + 50),
            floor(random() * 2000 + 100),
            'unplanned',
            'closed'
        );
    END LOOP;
    
    -- Cluster 2: Northside weather events
    FOR i IN 1..18 LOOP
        v_lat := 37.845 + (random() * 0.015);
        v_lon := -122.438 + (random() * 0.015);
        
        INSERT INTO outages (
            district_id, cause_id, weather_condition_id, location,
            occurred_at, restored_at, customers_affected, estimated_load_lost_kw,
            outage_type, status
        ) VALUES (
            3,
            (ARRAY[1, 2, 3])[floor(random() * 3 + 1)],  -- Weather causes
            (ARRAY[6, 7, 10])[floor(random() * 3 + 1)],  -- Bad weather
            ST_GeogFromText('POINT(' || v_lon || ' ' || v_lat || ')'),
            CURRENT_TIMESTAMP - (random() * 150 || ' days')::INTERVAL,
            CURRENT_TIMESTAMP - (random() * 150 || ' days')::INTERVAL + (random() * 6 || ' hours')::INTERVAL,
            floor(random() * 500 + 100),
            floor(random() * 1500 + 200),
            'unplanned',
            'closed'
        );
    END LOOP;
    
    -- Cluster 3: Industrial area overloads
    FOR i IN 1..15 LOOP
        v_lat := 37.515 + (random() * 0.020);
        v_lon := -122.418 + (random() * 0.025);
        
        INSERT INTO outages (
            district_id, cause_id, weather_condition_id, location,
            occurred_at, restored_at, customers_affected, estimated_load_lost_kw,
            outage_type, status
        ) VALUES (
            5,
            (ARRAY[27, 28])[floor(random() * 2 + 1)],  -- Overload causes
            14,  -- Extreme heat
            ST_GeogFromText('POINT(' || v_lon || ' ' || v_lat || ')'),
            CURRENT_TIMESTAMP - (random() * 90 || ' days')::INTERVAL,
            CURRENT_TIMESTAMP - (random() * 90 || ' days')::INTERVAL + (random() * 2 || ' hours')::INTERVAL,
            floor(random() * 200 + 20),
            floor(random() * 5000 + 1000),
            'unplanned',
            'closed'
        );
    END LOOP;
    
    -- Cluster 4: Valley Center vegetation
    FOR i IN 1..20 LOOP
        v_lat := 37.665 + (random() * 0.025);
        v_lon := -121.895 + (random() * 0.030);
        
        INSERT INTO outages (
            district_id, cause_id, weather_condition_id, location,
            occurred_at, restored_at, customers_affected, estimated_load_lost_kw,
            outage_type, status
        ) VALUES (
            9,
            (ARRAY[17, 18, 19])[floor(random() * 3 + 1)],  -- Vegetation causes
            (ARRAY[1, 2, 4])[floor(random() * 3 + 1)],  -- Various weather
            ST_GeogFromText('POINT(' || v_lon || ' ' || v_lat || ')'),
            CURRENT_TIMESTAMP - (random() * 120 || ' days')::INTERVAL,
            CURRENT_TIMESTAMP - (random() * 120 || ' days')::INTERVAL + (random() * 3 || ' hours')::INTERVAL,
            floor(random() * 300 + 30),
            floor(random() * 800 + 100),
            'unplanned',
            'closed'
        );
    END LOOP;
    
    -- Scattered outages across other districts
    FOR i IN 1..30 LOOP
        INSERT INTO outages (
            district_id, cause_id, weather_condition_id, location,
            occurred_at, restored_at, customers_affected, estimated_load_lost_kw,
            outage_type, status
        ) VALUES (
            (ARRAY[2, 4, 6, 7, 8, 10, 11, 12, 13, 14])[floor(random() * 10 + 1)],
            floor(random() * 28 + 1),
            floor(random() * 18 + 1),
            ST_GeogFromText('POINT(' || (-122.55 + random() * 0.85) || ' ' || (37.40 + random() * 0.50) || ')'),
            CURRENT_TIMESTAMP - (random() * 180 || ' days')::INTERVAL,
            CURRENT_TIMESTAMP - (random() * 180 || ' days')::INTERVAL + (random() * 5 || ' hours')::INTERVAL,
            floor(random() * 600 + 25),
            floor(random() * 1800 + 50),
            CASE WHEN random() < 0.1 THEN 'planned' ELSE 'unplanned' END,
            'closed'
        );
    END LOOP;
    
    -- Active outages (currently ongoing)
    FOR i IN 1..5 LOOP
        INSERT INTO outages (
            district_id, cause_id, weather_condition_id, location,
            occurred_at, customers_affected, estimated_load_lost_kw,
            outage_type, status, severity
        ) VALUES (
            (ARRAY[1, 3, 5, 9, 12])[i],
            floor(random() * 15 + 1),
            floor(random() * 10 + 1),
            ST_GeogFromText('POINT(' || (-122.50 + random() * 0.75) || ' ' || (37.45 + random() * 0.45) || ')'),
            CURRENT_TIMESTAMP - (random() * 4 || ' hours')::INTERVAL,
            floor(random() * 1500 + 100),
            floor(random() * 3000 + 200),
            'unplanned',
            (ARRAY['active', 'crew_assigned', 'in_repair'])[floor(random() * 3 + 1)],
            (ARRAY['minor', 'moderate', 'major'])[floor(random() * 3 + 1)]
        );
    END LOOP;
END $$;

-- ============================================================================
-- Sample Crew Dispatches
-- ============================================================================

INSERT INTO crew_dispatches (outage_id, crew_id, dispatched_at, acknowledged_at, en_route_at, arrived_at, work_started_at, completed_at, travel_distance_km, notes)
SELECT 
    o.outage_id,
    (floor(random() * 8) + 1)::INTEGER,
    o.occurred_at + INTERVAL '15 minutes',
    o.occurred_at + INTERVAL '18 minutes',
    o.occurred_at + INTERVAL '22 minutes',
    o.occurred_at + INTERVAL '45 minutes',
    o.occurred_at + INTERVAL '50 minutes',
    o.restored_at - INTERVAL '5 minutes',
    round((random() * 15 + 2)::NUMERIC, 1),
    'Standard repair completed'
FROM outages o
WHERE o.status = 'closed'
LIMIT 50;

-- ============================================================================
-- Sample Outage Updates
-- ============================================================================

INSERT INTO outage_updates (outage_id, update_type, message, estimated_restore_at, is_public)
SELECT 
    o.outage_id,
    'initial',
    'Outage reported. Crews being dispatched.',
    o.occurred_at + INTERVAL '2 hours',
    true
FROM outages o
WHERE o.status = 'closed'
LIMIT 40;

INSERT INTO outage_updates (outage_id, update_type, message, estimated_restore_at, is_public)
SELECT 
    o.outage_id,
    'restored',
    'Power has been restored. Thank you for your patience.',
    o.restored_at,
    true
FROM outages o
WHERE o.status = 'closed' AND o.restored_at IS NOT NULL
LIMIT 40;
