-- ============================================================================
-- Boda Accident Hotspot Mapper - Initial Schema
-- PostgreSQL 14+ with PostGIS
-- ============================================================================

-- Enable PostGIS
CREATE EXTENSION IF NOT EXISTS postgis;

-- Districts
CREATE TABLE IF NOT EXISTS districts (
    district_id SERIAL PRIMARY KEY,
    district_name VARCHAR(100) NOT NULL UNIQUE,
    region VARCHAR(50),
    population INT,
    area_sqkm DECIMAL(10,2),
    boda_registered INT,
    geom GEOMETRY(MULTIPOLYGON, 4326)
);

-- Accident severity levels
CREATE TABLE IF NOT EXISTS severity_levels (
    severity_id SERIAL PRIMARY KEY,
    severity_name VARCHAR(20) NOT NULL UNIQUE,
    severity_score INT NOT NULL
);

-- Accidents
CREATE TABLE IF NOT EXISTS accidents (
    accident_id SERIAL PRIMARY KEY,
    district_id INT REFERENCES districts(district_id),
    location GEOMETRY(POINT, 4326),
    accident_date DATE NOT NULL,
    accident_time TIME,
    severity_id INT REFERENCES severity_levels(severity_id),
    fatalities INT DEFAULT 0,
    injuries INT DEFAULT 0,
    vehicles_involved INT DEFAULT 1,
    cause VARCHAR(100),
    road_condition VARCHAR(50),
    weather VARCHAR(50),
    reported_by VARCHAR(100),
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Indexes
CREATE INDEX idx_accidents_district ON accidents(district_id);
CREATE INDEX idx_accidents_date ON accidents(accident_date);
CREATE INDEX idx_accidents_location ON accidents USING GIST(location);
CREATE INDEX idx_districts_geom ON districts USING GIST(geom);

-- ============================================================================
-- Views using NTILE (User's Sample Query)
-- ============================================================================

-- User's sample: SELECT district, COUNT(*), NTILE(4) OVER (ORDER BY COUNT(*)) as risk_quartile
CREATE OR REPLACE VIEW vw_district_risk_quartiles AS
WITH district_counts AS (
    SELECT 
        d.district_id,
        d.district_name,
        d.region,
        d.population,
        COUNT(a.accident_id) AS accidents,
        SUM(a.fatalities) AS total_fatalities,
        SUM(a.injuries) AS total_injuries
    FROM districts d
    LEFT JOIN accidents a ON d.district_id = a.district_id
    GROUP BY d.district_id, d.district_name, d.region, d.population
)
SELECT 
    district_name,
    region,
    accidents,
    total_fatalities,
    total_injuries,
    -- User's NTILE pattern
    NTILE(4) OVER (ORDER BY accidents) AS risk_quartile,
    PERCENT_RANK() OVER (ORDER BY accidents)::DECIMAL(4,2) AS risk_percentile,
    CASE NTILE(4) OVER (ORDER BY accidents)
        WHEN 4 THEN '🔴 High Risk'
        WHEN 3 THEN '🟠 Moderate'
        WHEN 2 THEN '🟡 Low-Moderate'
        ELSE '🟢 Low Risk'
    END AS risk_level,
    ROUND(accidents * 100000.0 / NULLIF(population, 0), 2) AS accidents_per_100k
FROM district_counts
ORDER BY accidents DESC;

COMMENT ON VIEW vw_district_risk_quartiles IS 'User sample: NTILE(4) OVER (ORDER BY COUNT(*)) as risk_quartile';

-- ============================================================================
-- Spatial Clustering View
-- ============================================================================

CREATE OR REPLACE VIEW vw_accident_clusters AS
SELECT 
    accident_id,
    district_id,
    location,
    accident_date,
    fatalities,
    ST_ClusterDBSCAN(location, eps := 0.01, minpoints := 3) OVER () AS cluster_id
FROM accidents
WHERE location IS NOT NULL;

-- ============================================================================
-- Hotspot Analysis Function
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_get_hotspots(p_min_accidents INT DEFAULT 5)
RETURNS TABLE (
    cluster_id INT,
    accident_count BIGINT,
    total_fatalities BIGINT,
    center_point GEOMETRY,
    risk_quartile BIGINT
) AS $$
WITH clustered AS (
    SELECT 
        ST_ClusterDBSCAN(location, eps := 0.005, minpoints := 3) OVER () AS cluster_id,
        location,
        fatalities
    FROM accidents
    WHERE location IS NOT NULL
),
cluster_stats AS (
    SELECT 
        cluster_id,
        COUNT(*) AS accident_count,
        SUM(fatalities) AS total_fatalities,
        ST_Centroid(ST_Collect(location)) AS center_point
    FROM clustered
    WHERE cluster_id IS NOT NULL
    GROUP BY cluster_id
    HAVING COUNT(*) >= p_min_accidents
)
SELECT 
    cluster_id,
    accident_count,
    total_fatalities,
    center_point,
    NTILE(4) OVER (ORDER BY accident_count) AS risk_quartile
FROM cluster_stats
ORDER BY accident_count DESC;
$$ LANGUAGE SQL;
