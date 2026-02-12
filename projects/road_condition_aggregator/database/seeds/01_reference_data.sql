-- ============================================================================
-- Road Condition Aggregator - Reference Data
-- PostgreSQL 14+ with PostGIS 3.x
-- Static reference data for testing and initial setup
-- ============================================================================

-- ============================================================================
-- Damage Types
-- ============================================================================

INSERT INTO damage_types (name, description, severity_weight, estimated_repair_cost, repair_method)
VALUES
    ('Pothole', 'Depression in road surface caused by wear and weather', 1.5, 150.00, 'hot_patch'),
    ('Crack', 'Linear fracture in pavement surface', 0.8, 75.00, 'seal_coat'),
    ('Alligator Cracking', 'Interconnected cracks resembling alligator skin', 1.2, 500.00, 'full_depth'),
    ('Rutting', 'Depression or groove worn by wheels', 1.3, 350.00, 'resurfacing'),
    ('Edge Break', 'Deterioration of road edge', 1.0, 200.00, 'edge_repair'),
    ('Surface Wear', 'General wearing of road surface', 0.6, 100.00, 'surface_treatment'),
    ('Sinkhole', 'Collapse of road surface due to underground erosion', 2.0, 2500.00, 'full_excavation'),
    ('Frost Heave', 'Uplift caused by freezing ground water', 1.1, 400.00, 'reconstruction'),
    ('Bleeding', 'Excess asphalt on road surface', 0.5, 80.00, 'sand_cover'),
    ('Raveling', 'Loss of aggregate from road surface', 0.7, 150.00, 'chip_seal')
ON CONFLICT (name) DO UPDATE SET
    description = EXCLUDED.description,
    severity_weight = EXCLUDED.severity_weight,
    estimated_repair_cost = EXCLUDED.estimated_repair_cost,
    repair_method = EXCLUDED.repair_method;

-- ============================================================================
-- Road Classifications
-- ============================================================================

INSERT INTO road_classifications (name, description, speed_limit, priority_weight, lane_count)
VALUES
    ('Interstate', 'Major highway connecting states', 70, 3.0, 4),
    ('US Highway', 'Federal highway system', 65, 2.5, 4),
    ('State Route', 'State-maintained highway', 55, 2.0, 2),
    ('Arterial', 'Major urban road carrying high traffic', 45, 1.8, 4),
    ('Collector', 'Road connecting local streets to arterials', 35, 1.5, 2),
    ('Local', 'Residential or light commercial road', 30, 1.0, 2),
    ('Alley', 'Narrow service road', 15, 0.5, 1),
    ('Private', 'Private road or driveway', 25, 0.3, 1)
ON CONFLICT (name) DO UPDATE SET
    description = EXCLUDED.description,
    speed_limit = EXCLUDED.speed_limit,
    priority_weight = EXCLUDED.priority_weight,
    lane_count = EXCLUDED.lane_count;

-- ============================================================================
-- Districts (Sample city districts)
-- ============================================================================

-- Using a simple grid of sample districts for a hypothetical city
-- Coordinates centered around 40.7128° N, 74.0060° W (NYC area as example)

INSERT INTO districts (name, code, boundary, area_sq_km, population)
VALUES
    ('Downtown', 'DT', 
     ST_SetSRID(ST_MakePolygon(ST_MakeLine(ARRAY[
         ST_MakePoint(-74.015, 40.710),
         ST_MakePoint(-74.005, 40.710),
         ST_MakePoint(-74.005, 40.720),
         ST_MakePoint(-74.015, 40.720),
         ST_MakePoint(-74.015, 40.710)
     ])), 4326),
     1.2, 25000),
    ('Midtown', 'MT',
     ST_SetSRID(ST_MakePolygon(ST_MakeLine(ARRAY[
         ST_MakePoint(-74.015, 40.720),
         ST_MakePoint(-74.005, 40.720),
         ST_MakePoint(-74.005, 40.730),
         ST_MakePoint(-74.015, 40.730),
         ST_MakePoint(-74.015, 40.720)
     ])), 4326),
     1.2, 35000),
    ('Uptown', 'UT',
     ST_SetSRID(ST_MakePolygon(ST_MakeLine(ARRAY[
         ST_MakePoint(-74.015, 40.730),
         ST_MakePoint(-74.005, 40.730),
         ST_MakePoint(-74.005, 40.740),
         ST_MakePoint(-74.015, 40.740),
         ST_MakePoint(-74.015, 40.730)
     ])), 4326),
     1.2, 28000),
    ('West Side', 'WS',
     ST_SetSRID(ST_MakePolygon(ST_MakeLine(ARRAY[
         ST_MakePoint(-74.025, 40.715),
         ST_MakePoint(-74.015, 40.715),
         ST_MakePoint(-74.015, 40.735),
         ST_MakePoint(-74.025, 40.735),
         ST_MakePoint(-74.025, 40.715)
     ])), 4326),
     2.4, 42000),
    ('East Side', 'ES',
     ST_SetSRID(ST_MakePolygon(ST_MakeLine(ARRAY[
         ST_MakePoint(-74.005, 40.715),
         ST_MakePoint(-73.995, 40.715),
         ST_MakePoint(-73.995, 40.735),
         ST_MakePoint(-74.005, 40.735),
         ST_MakePoint(-74.005, 40.715)
     ])), 4326),
     2.4, 38000),
    ('Industrial', 'IN',
     ST_SetSRID(ST_MakePolygon(ST_MakeLine(ARRAY[
         ST_MakePoint(-73.995, 40.700),
         ST_MakePoint(-73.980, 40.700),
         ST_MakePoint(-73.980, 40.715),
         ST_MakePoint(-73.995, 40.715),
         ST_MakePoint(-73.995, 40.700)
     ])), 4326),
     2.8, 8000)
ON CONFLICT (code) DO UPDATE SET
    name = EXCLUDED.name,
    boundary = EXCLUDED.boundary,
    area_sq_km = EXCLUDED.area_sq_km,
    population = EXCLUDED.population;

-- ============================================================================
-- Crews
-- ============================================================================

INSERT INTO crews (name, crew_type, member_count, status, current_location, equipment_capacity)
VALUES
    ('Alpha Team', 'pothole_patch', 4, 'available', 
     ST_SetSRID(ST_MakePoint(-74.010, 40.715), 4326)::geography, 'light'),
    ('Beta Squad', 'pothole_patch', 4, 'available', 
     ST_SetSRID(ST_MakePoint(-74.008, 40.725), 4326)::geography, 'light'),
    ('Heavy Repair 1', 'full_repair', 8, 'assigned', 
     ST_SetSRID(ST_MakePoint(-74.012, 40.720), 4326)::geography, 'heavy'),
    ('Heavy Repair 2', 'full_repair', 8, 'available', 
     ST_SetSRID(ST_MakePoint(-74.020, 40.718), 4326)::geography, 'heavy'),
    ('Maintenance 1', 'maintenance', 3, 'available', 
     ST_SetSRID(ST_MakePoint(-74.006, 40.712), 4326)::geography, 'medium'),
    ('Emergency Response', 'emergency', 6, 'standby', 
     ST_SetSRID(ST_MakePoint(-74.010, 40.722), 4326)::geography, 'heavy')
ON CONFLICT DO NOTHING;

-- ============================================================================
-- Report Sources
-- ============================================================================

INSERT INTO report_sources (name, reliability_score, description)
VALUES
    ('311 System', 0.85, 'Citizen reports via 311 phone/app'),
    ('Mobile App', 0.80, 'Road Report mobile application'),
    ('Street Inspector', 0.95, 'Official street inspection team'),
    ('Vehicle Sensor', 0.70, 'Automated pothole detection from city vehicles'),
    ('Social Media', 0.50, 'Reports extracted from social media posts'),
    ('Email', 0.75, 'Direct email reports to department'),
    ('Council Request', 0.90, 'Requests from city council members')
ON CONFLICT (name) DO UPDATE SET
    reliability_score = EXCLUDED.reliability_score,
    description = EXCLUDED.description;

-- ============================================================================
-- Verify Reference Data
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE 'Reference data loaded:';
    RAISE NOTICE '  - Damage types: %', (SELECT COUNT(*) FROM damage_types);
    RAISE NOTICE '  - Road classifications: %', (SELECT COUNT(*) FROM road_classifications);
    RAISE NOTICE '  - Districts: %', (SELECT COUNT(*) FROM districts);
    RAISE NOTICE '  - Crews: %', (SELECT COUNT(*) FROM crews);
    RAISE NOTICE '  - Report sources: %', (SELECT COUNT(*) FROM report_sources);
END $$;
