-- ============================================================================
-- Road Condition Aggregator - Sample Data
-- PostgreSQL 14+ with PostGIS 3.x
-- Sample road segments and reports for testing DBSCAN clustering
-- ============================================================================

-- ============================================================================
-- Road Segments (Sample street network)
-- ============================================================================

-- Get road class IDs
DO $$
DECLARE
    v_arterial_id INTEGER;
    v_collector_id INTEGER;
    v_local_id INTEGER;
    v_downtown_id INTEGER;
    v_midtown_id INTEGER;
    v_westside_id INTEGER;
    v_eastside_id INTEGER;
BEGIN
    SELECT class_id INTO v_arterial_id FROM road_classifications WHERE name = 'Arterial';
    SELECT class_id INTO v_collector_id FROM road_classifications WHERE name = 'Collector';
    SELECT class_id INTO v_local_id FROM road_classifications WHERE name = 'Local';
    
    SELECT district_id INTO v_downtown_id FROM districts WHERE code = 'DT';
    SELECT district_id INTO v_midtown_id FROM districts WHERE code = 'MT';
    SELECT district_id INTO v_westside_id FROM districts WHERE code = 'WS';
    SELECT district_id INTO v_eastside_id FROM districts WHERE code = 'ES';
    
    -- Main Street (N-S arterial through downtown)
    INSERT INTO road_segments (road_name, segment_name, geom, road_class_id, district_id, traffic_volume, pavement_condition, last_maintenance_date)
    VALUES 
    ('Main Street', 'Main St - Downtown', 
     ST_SetSRID(ST_MakeLine(ST_MakePoint(-74.010, 40.710), ST_MakePoint(-74.010, 40.720)), 4326),
     v_arterial_id, v_downtown_id, 15000, 6, '2023-06-15'),
    ('Main Street', 'Main St - Midtown',
     ST_SetSRID(ST_MakeLine(ST_MakePoint(-74.010, 40.720), ST_MakePoint(-74.010, 40.730)), 4326),
     v_arterial_id, v_midtown_id, 18000, 7, '2023-08-20');
    
    -- First Avenue (E-W collector)
    INSERT INTO road_segments (road_name, segment_name, geom, road_class_id, district_id, traffic_volume, pavement_condition, last_maintenance_date)
    VALUES 
    ('First Avenue', '1st Ave - West',
     ST_SetSRID(ST_MakeLine(ST_MakePoint(-74.020, 40.715), ST_MakePoint(-74.010, 40.715)), 4326),
     v_collector_id, v_westside_id, 8000, 5, '2022-11-10'),
    ('First Avenue', '1st Ave - Downtown',
     ST_SetSRID(ST_MakeLine(ST_MakePoint(-74.010, 40.715), ST_MakePoint(-74.000, 40.715)), 4326),
     v_collector_id, v_downtown_id, 9000, 4, '2022-08-05');
    
    -- Oak Street (Local road - high damage area for clustering demo)
    INSERT INTO road_segments (road_name, segment_name, geom, road_class_id, district_id, traffic_volume, pavement_condition, last_maintenance_date)
    VALUES 
    ('Oak Street', 'Oak St - Block 1',
     ST_SetSRID(ST_MakeLine(ST_MakePoint(-74.012, 40.718), ST_MakePoint(-74.008, 40.718)), 4326),
     v_local_id, v_downtown_id, 2000, 3, '2021-04-15'),
    ('Oak Street', 'Oak St - Block 2',
     ST_SetSRID(ST_MakeLine(ST_MakePoint(-74.008, 40.718), ST_MakePoint(-74.004, 40.718)), 4326),
     v_local_id, v_eastside_id, 2200, 3, '2021-04-15');
    
    -- Elm Street (Another damaged local road)
    INSERT INTO road_segments (road_name, segment_name, geom, road_class_id, district_id, traffic_volume, pavement_condition, last_maintenance_date)
    VALUES 
    ('Elm Street', 'Elm St - Block 1',
     ST_SetSRID(ST_MakeLine(ST_MakePoint(-74.012, 40.722), ST_MakePoint(-74.008, 40.722)), 4326),
     v_local_id, v_midtown_id, 1800, 4, '2022-02-20');
    
    -- Park Boulevard (Arterial through midtown)
    INSERT INTO road_segments (road_name, segment_name, geom, road_class_id, district_id, traffic_volume, pavement_condition, last_maintenance_date)
    VALUES 
    ('Park Boulevard', 'Park Blvd - Central',
     ST_SetSRID(ST_MakeLine(ST_MakePoint(-74.015, 40.725), ST_MakePoint(-74.005, 40.725)), 4326),
     v_arterial_id, v_midtown_id, 20000, 7, '2023-10-01');
END $$;

-- Update segment lengths
UPDATE road_segments SET length_m = ST_Length(geom::geography) WHERE length_m IS NULL;

-- ============================================================================
-- Sample Reports - Clustered for DBSCAN demo
-- Reports are intentionally clustered to demonstrate ST_ClusterDBSCAN
-- ============================================================================

-- Get IDs for inserts
DO $$
DECLARE
    v_pothole_id INTEGER;
    v_crack_id INTEGER;
    v_alligator_id INTEGER;
    v_rutting_id INTEGER;
    v_311_id INTEGER;
    v_app_id INTEGER;
    v_inspector_id INTEGER;
BEGIN
    SELECT damage_id INTO v_pothole_id FROM damage_types WHERE name = 'Pothole';
    SELECT damage_id INTO v_crack_id FROM damage_types WHERE name = 'Crack';
    SELECT damage_id INTO v_alligator_id FROM damage_types WHERE name = 'Alligator Cracking';
    SELECT damage_id INTO v_rutting_id FROM damage_types WHERE name = 'Rutting';
    
    SELECT source_id INTO v_311_id FROM report_sources WHERE name = '311 System';
    SELECT source_id INTO v_app_id FROM report_sources WHERE name = 'Mobile App';
    SELECT source_id INTO v_inspector_id FROM report_sources WHERE name = 'Street Inspector';

    -- =========================================================================
    -- CLUSTER 1: Oak Street Problem Area (8 reports within ~50m)
    -- This should form a cluster with eps=0.01 (~1.1km), minpoints=3
    -- =========================================================================
    INSERT INTO road_reports (location, severity, status, damage_type_id, source_id, address_description, notes, reported_at)
    VALUES
    (ST_SetSRID(ST_MakePoint(-74.0100, 40.7180), 4326)::geography, 8, 'verified', 
     v_pothole_id, v_311_id, '100 Oak Street', 'Large pothole, tire hazard', NOW() - INTERVAL '5 days'),
    (ST_SetSRID(ST_MakePoint(-74.0098, 40.7181), 4326)::geography, 7, 'verified', 
     v_pothole_id, v_app_id, '102 Oak Street', 'Adjacent pothole forming', NOW() - INTERVAL '4 days'),
    (ST_SetSRID(ST_MakePoint(-74.0102, 40.7179), 4326)::geography, 9, 'verified', 
     v_pothole_id, v_inspector_id, '98 Oak Street', 'Deep pothole - 6 inches', NOW() - INTERVAL '6 days'),
    (ST_SetSRID(ST_MakePoint(-74.0095, 40.7182), 4326)::geography, 6, 'new', 
     v_crack_id, v_311_id, '106 Oak Street', 'Spreading cracks', NOW() - INTERVAL '3 days'),
    (ST_SetSRID(ST_MakePoint(-74.0103, 40.7178), 4326)::geography, 8, 'verified', 
     v_alligator_id, v_app_id, '96 Oak Street', 'Alligator cracking spreading', NOW() - INTERVAL '7 days'),
    (ST_SetSRID(ST_MakePoint(-74.0097, 40.7183), 4326)::geography, 7, 'new', 
     v_pothole_id, v_app_id, '104 Oak Street', 'New pothole after rain', NOW() - INTERVAL '1 day'),
    (ST_SetSRID(ST_MakePoint(-74.0101, 40.7177), 4326)::geography, 8, 'verified', 
     v_pothole_id, v_311_id, '94 Oak Street', 'Pothole damaged my rim', NOW() - INTERVAL '8 days'),
    (ST_SetSRID(ST_MakePoint(-74.0099, 40.7180), 4326)::geography, 9, 'verified', 
     v_pothole_id, v_inspector_id, '101 Oak Street', 'Critical - needs immediate repair', NOW() - INTERVAL '2 days');

    -- =========================================================================
    -- CLUSTER 2: Main Street / First Avenue intersection (6 reports)
    -- =========================================================================
    INSERT INTO road_reports (location, severity, status, damage_type_id, source_id, address_description, notes, reported_at)
    VALUES
    (ST_SetSRID(ST_MakePoint(-74.0100, 40.7150), 4326)::geography, 7, 'verified', 
     v_pothole_id, v_311_id, 'Main St & 1st Ave', 'Pothole at intersection', NOW() - INTERVAL '10 days'),
    (ST_SetSRID(ST_MakePoint(-74.0098, 40.7152), 4326)::geography, 6, 'new', 
     v_rutting_id, v_app_id, 'Main St near 1st Ave', 'Rutting from heavy trucks', NOW() - INTERVAL '8 days'),
    (ST_SetSRID(ST_MakePoint(-74.0102, 40.7148), 4326)::geography, 8, 'verified', 
     v_pothole_id, v_inspector_id, '1st Ave at Main', 'Multiple potholes forming', NOW() - INTERVAL '12 days'),
    (ST_SetSRID(ST_MakePoint(-74.0099, 40.7151), 4326)::geography, 7, 'verified', 
     v_crack_id, v_311_id, 'Main St & 1st Ave NW', 'Cracks near drain', NOW() - INTERVAL '9 days'),
    (ST_SetSRID(ST_MakePoint(-74.0101, 40.7149), 4326)::geography, 5, 'new', 
     v_crack_id, v_app_id, 'Main St & 1st Ave SW', 'Surface cracks', NOW() - INTERVAL '6 days'),
    (ST_SetSRID(ST_MakePoint(-74.0097, 40.7153), 4326)::geography, 6, 'verified', 
     v_pothole_id, v_311_id, '1st Ave N of Main', 'Small pothole', NOW() - INTERVAL '7 days');

    -- =========================================================================
    -- CLUSTER 3: Park Boulevard area (7 reports - high traffic area)
    -- =========================================================================
    INSERT INTO road_reports (location, severity, status, damage_type_id, source_id, address_description, notes, reported_at)
    VALUES
    (ST_SetSRID(ST_MakePoint(-74.0100, 40.7250), 4326)::geography, 6, 'new', 
     v_pothole_id, v_app_id, '200 Park Boulevard', 'Pothole in travel lane', NOW() - INTERVAL '3 days'),
    (ST_SetSRID(ST_MakePoint(-74.0095, 40.7252), 4326)::geography, 7, 'verified', 
     v_pothole_id, v_311_id, '204 Park Boulevard', 'Growing pothole', NOW() - INTERVAL '5 days'),
    (ST_SetSRID(ST_MakePoint(-74.0105, 40.7248), 4326)::geography, 5, 'new', 
     v_crack_id, v_app_id, '196 Park Boulevard', 'Longitudinal crack', NOW() - INTERVAL '2 days'),
    (ST_SetSRID(ST_MakePoint(-74.0098, 40.7251), 4326)::geography, 8, 'verified', 
     v_pothole_id, v_inspector_id, '202 Park Boulevard', 'Severe pothole', NOW() - INTERVAL '6 days'),
    (ST_SetSRID(ST_MakePoint(-74.0102, 40.7249), 4326)::geography, 6, 'new', 
     v_rutting_id, v_311_id, '198 Park Boulevard', 'Bus stop rutting', NOW() - INTERVAL '4 days'),
    (ST_SetSRID(ST_MakePoint(-74.0092, 40.7253), 4326)::geography, 7, 'verified', 
     v_pothole_id, v_app_id, '208 Park Boulevard', 'Another pothole', NOW() - INTERVAL '8 days'),
    (ST_SetSRID(ST_MakePoint(-74.0108, 40.7247), 4326)::geography, 5, 'new', 
     v_crack_id, v_311_id, '192 Park Boulevard', 'Minor cracking', NOW() - INTERVAL '1 day');

    -- =========================================================================
    -- SCATTERED REPORTS (noise points for DBSCAN)
    -- These should NOT form clusters
    -- =========================================================================
    INSERT INTO road_reports (location, severity, status, damage_type_id, source_id, address_description, notes, reported_at)
    VALUES
    (ST_SetSRID(ST_MakePoint(-74.0200, 40.7300), 4326)::geography, 4, 'new', 
     v_crack_id, v_app_id, '500 West Ave', 'Minor crack', NOW() - INTERVAL '15 days'),
    (ST_SetSRID(ST_MakePoint(-73.9980, 40.7100), 4326)::geography, 5, 'verified', 
     v_pothole_id, v_311_id, '800 Industrial Way', 'Small pothole', NOW() - INTERVAL '20 days'),
    (ST_SetSRID(ST_MakePoint(-74.0150, 40.7350), 4326)::geography, 3, 'new', 
     v_crack_id, v_app_id, '123 North St', 'Surface wear', NOW() - INTERVAL '25 days'),
    (ST_SetSRID(ST_MakePoint(-73.9950, 40.7200), 4326)::geography, 6, 'new', 
     v_pothole_id, v_311_id, '456 East End', 'Single pothole', NOW() - INTERVAL '18 days');

END $$;

-- ============================================================================
-- Verify Sample Data
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE 'Sample data loaded:';
    RAISE NOTICE '  - Road segments: %', (SELECT COUNT(*) FROM road_segments);
    RAISE NOTICE '  - Total reports: %', (SELECT COUNT(*) FROM road_reports);
    RAISE NOTICE '  - Reports per status:';
    RAISE NOTICE '    - New: %', (SELECT COUNT(*) FROM road_reports WHERE status = 'new');
    RAISE NOTICE '    - Verified: %', (SELECT COUNT(*) FROM road_reports WHERE status = 'verified');
END $$;

-- ============================================================================
-- Quick Cluster Preview
-- ============================================================================

-- Show cluster preview to verify data setup
SELECT 
    cluster_id,
    COUNT(*) as report_count,
    ROUND(AVG(severity), 2) as avg_severity
FROM (
    SELECT 
        report_id,
        severity,
        ST_ClusterDBSCAN(location::geometry, 0.01, 3) OVER () as cluster_id
    FROM road_reports
    WHERE status IN ('new', 'verified')
) clustered
GROUP BY cluster_id
ORDER BY cluster_id NULLS LAST;
