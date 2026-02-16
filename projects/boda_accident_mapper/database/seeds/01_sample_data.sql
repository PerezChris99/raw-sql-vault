-- ============================================================================
-- Boda Accident Hotspot Mapper - Sample Data
-- PostgreSQL 14+ with PostGIS
-- ============================================================================

-- Severity levels
INSERT INTO severity_levels (severity_name, severity_score) VALUES
('minor', 10), ('moderate', 30), ('serious', 60), ('fatal', 100)
ON CONFLICT (severity_name) DO NOTHING;

-- Districts (Uganda sample)
INSERT INTO districts (district_name, region, population, area_sqkm, boda_registered) VALUES
('Kampala', 'Central', 1650000, 189, 85000),
('Wakiso', 'Central', 2007700, 2807, 42000),
('Mukono', 'Central', 599817, 2986, 28000),
('Jinja', 'Eastern', 331079, 767, 18000),
('Mbale', 'Eastern', 568778, 518, 22000),
('Gulu', 'Northern', 443733, 3449, 15000),
('Mbarara', 'Western', 472629, 1846, 19000),
('Masaka', 'Central', 297004, 603, 14000),
('Arua', 'West Nile', 782077, 4274, 12000),
('Lira', 'Northern', 408043, 1485, 11000)
ON CONFLICT (district_name) DO NOTHING;

-- Sample accidents (varied distribution)
INSERT INTO accidents (district_id, location, accident_date, accident_time, severity_id, fatalities, injuries, cause, road_condition, weather)
SELECT 
    d.district_id,
    ST_SetSRID(ST_MakePoint(
        32.5 + (RANDOM() * 0.2 - 0.1),  -- longitude around Kampala
        0.3 + (RANDOM() * 0.2 - 0.1)    -- latitude
    ), 4326),
    CURRENT_DATE - (RANDOM() * 365)::INT,
    (RANDOM() * 24 || ':' || (RANDOM() * 60)::INT || ':00')::TIME,
    (RANDOM() * 3 + 1)::INT,
    CASE WHEN RANDOM() > 0.85 THEN (RANDOM() * 3)::INT ELSE 0 END,
    (RANDOM() * 4)::INT,
    CASE (RANDOM() * 5)::INT 
        WHEN 0 THEN 'Speeding'
        WHEN 1 THEN 'Drunk driving'
        WHEN 2 THEN 'Overloading'
        WHEN 3 THEN 'Poor visibility'
        ELSE 'Reckless driving'
    END,
    CASE (RANDOM() * 3)::INT WHEN 0 THEN 'Good' WHEN 1 THEN 'Poor' ELSE 'Wet' END,
    CASE (RANDOM() * 3)::INT WHEN 0 THEN 'Clear' WHEN 1 THEN 'Rainy' ELSE 'Foggy' END
FROM districts d
CROSS JOIN GENERATE_SERIES(1, 
    CASE 
        WHEN d.district_name = 'Kampala' THEN 150
        WHEN d.district_name = 'Wakiso' THEN 100
        WHEN d.district_name IN ('Jinja', 'Mbale', 'Mbarara') THEN 60
        ELSE 30
    END
);

SELECT 'Sample data loaded' AS status;
SELECT district_name, COUNT(*) AS accidents 
FROM accidents a JOIN districts d USING(district_id) 
GROUP BY district_name ORDER BY accidents DESC;
