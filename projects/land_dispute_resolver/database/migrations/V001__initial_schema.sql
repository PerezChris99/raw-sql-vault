-- ============================================================================
-- Land Dispute Resolver - Initial Schema
-- PostgreSQL 14+ with PostGIS
-- ============================================================================

-- Enable PostGIS
CREATE EXTENSION IF NOT EXISTS postgis;

-- Districts
CREATE TABLE IF NOT EXISTS land_districts (
    district_id SERIAL PRIMARY KEY,
    district_name VARCHAR(100) NOT NULL UNIQUE,
    region VARCHAR(50),
    boundary GEOMETRY(MULTIPOLYGON, 4326)
);

-- Land parcels
CREATE TABLE IF NOT EXISTS parcels (
    parcel_id SERIAL PRIMARY KEY,
    district_id INT REFERENCES land_districts(district_id),
    plot_number VARCHAR(50) NOT NULL,
    block_number VARCHAR(20),
    owner_name VARCHAR(200) NOT NULL,
    owner_nin VARCHAR(20), -- National ID
    boundary GEOMETRY(POLYGON, 4326) NOT NULL,
    area_sqm DECIMAL(12,2) GENERATED ALWAYS AS (ST_Area(boundary::geography)) STORED,
    title_number VARCHAR(50),
    title_type VARCHAR(30) CHECK (title_type IN ('freehold', 'leasehold', 'mailo', 'customary')),
    registered_date DATE,
    survey_date DATE,
    survey_accuracy_m DECIMAL(5,2),
    status VARCHAR(20) DEFAULT 'active',
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Land disputes
CREATE TABLE IF NOT EXISTS disputes (
    dispute_id SERIAL PRIMARY KEY,
    parcel1_id INT NOT NULL REFERENCES parcels(parcel_id),
    parcel2_id INT NOT NULL REFERENCES parcels(parcel_id),
    overlap_geometry GEOMETRY(POLYGON, 4326),
    overlap_area_sqm DECIMAL(12,2),
    overlap_pct_parcel1 DECIMAL(5,2),
    overlap_pct_parcel2 DECIMAL(5,2),
    detected_date DATE DEFAULT CURRENT_DATE,
    status VARCHAR(20) DEFAULT 'open' CHECK (status IN ('open', 'investigating', 'mediation', 'court', 'resolved')),
    resolution_type VARCHAR(50),
    resolution_date DATE,
    notes TEXT,
    UNIQUE(parcel1_id, parcel2_id)
);

-- Indexes
CREATE INDEX idx_parcels_district ON parcels(district_id);
CREATE INDEX idx_parcels_boundary ON parcels USING GIST(boundary);
CREATE INDEX idx_parcels_owner ON parcels(owner_name);
CREATE INDEX idx_disputes_status ON disputes(status);

-- ============================================================================
-- View: Overlapping Parcels (User's Sample Query)
-- SELECT p1.owner, p2.owner FROM parcels p1, p2 WHERE ST_Intersects(p1.geom, p2.geom) AND p1.id != p2.id
-- ============================================================================

CREATE OR REPLACE VIEW vw_overlapping_parcels AS
SELECT 
    p1.parcel_id AS parcel1_id,
    p1.plot_number AS plot1,
    p1.owner_name AS owner1,
    p2.parcel_id AS parcel2_id,
    p2.plot_number AS plot2,
    p2.owner_name AS owner2,
    ST_Area(ST_Intersection(p1.boundary, p2.boundary)::geography) AS overlap_sqm,
    ROUND((ST_Area(ST_Intersection(p1.boundary, p2.boundary)::geography) / p1.area_sqm * 100)::NUMERIC, 2) AS pct_of_parcel1,
    ROUND((ST_Area(ST_Intersection(p1.boundary, p2.boundary)::geography) / p2.area_sqm * 100)::NUMERIC, 2) AS pct_of_parcel2
FROM parcels p1, parcels p2
-- User's sample: WHERE ST_Intersects(p1.geom, p2.geom) AND p1.id != p2.id
WHERE ST_Intersects(p1.boundary, p2.boundary) 
  AND p1.parcel_id < p2.parcel_id  -- Avoid duplicates
  AND p1.status = 'active'
  AND p2.status = 'active'
  AND ST_Area(ST_Intersection(p1.boundary, p2.boundary)::geography) > 1; -- Min 1 sqm overlap

COMMENT ON VIEW vw_overlapping_parcels IS 'User sample: WHERE ST_Intersects(p1.geom, p2.geom) AND p1.id != p2.id';

-- ============================================================================
-- View: Dispute Summary
-- ============================================================================

CREATE OR REPLACE VIEW vw_dispute_summary AS
SELECT 
    d.dispute_id,
    p1.plot_number || ' (' || p1.owner_name || ')' AS parcel_1,
    p2.plot_number || ' (' || p2.owner_name || ')' AS parcel_2,
    ROUND(d.overlap_area_sqm, 0) AS overlap_sqm,
    d.overlap_pct_parcel1 || '%' AS overlap_pct_1,
    d.overlap_pct_parcel2 || '%' AS overlap_pct_2,
    d.status,
    d.detected_date,
    CASE 
        WHEN d.overlap_area_sqm > 1000 THEN '🔴 Major (>1000 sqm)'
        WHEN d.overlap_area_sqm > 100 THEN '🟠 Significant (>100 sqm)'
        ELSE '🟡 Minor (<100 sqm)'
    END AS severity
FROM disputes d
JOIN parcels p1 ON d.parcel1_id = p1.parcel_id
JOIN parcels p2 ON d.parcel2_id = p2.parcel_id
ORDER BY d.overlap_area_sqm DESC;

-- ============================================================================
-- Function: Detect New Overlaps
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_detect_overlaps()
RETURNS TABLE (
    parcel1_id INT,
    owner1 VARCHAR,
    parcel2_id INT,
    owner2 VARCHAR,
    overlap_sqm DECIMAL,
    severity VARCHAR
) AS $$
    -- User's query pattern: SELECT p1.owner, p2.owner FROM parcels p1, p2 WHERE ST_Intersects...
    SELECT 
        p1.parcel_id,
        p1.owner_name::VARCHAR,
        p2.parcel_id,
        p2.owner_name::VARCHAR,
        ROUND(ST_Area(ST_Intersection(p1.boundary, p2.boundary)::geography), 2),
        CASE 
            WHEN ST_Area(ST_Intersection(p1.boundary, p2.boundary)::geography) > 1000 THEN 'Major'
            WHEN ST_Area(ST_Intersection(p1.boundary, p2.boundary)::geography) > 100 THEN 'Significant'
            ELSE 'Minor'
        END::VARCHAR
    FROM parcels p1, parcels p2
    WHERE ST_Intersects(p1.boundary, p2.boundary)
      AND p1.parcel_id < p2.parcel_id
      AND p1.status = 'active'
      AND p2.status = 'active'
      AND ST_Area(ST_Intersection(p1.boundary, p2.boundary)::geography) > 1
      AND NOT EXISTS (
          SELECT 1 FROM disputes d 
          WHERE (d.parcel1_id = p1.parcel_id AND d.parcel2_id = p2.parcel_id)
             OR (d.parcel1_id = p2.parcel_id AND d.parcel2_id = p1.parcel_id)
      )
    ORDER BY ST_Area(ST_Intersection(p1.boundary, p2.boundary)::geography) DESC;
$$ LANGUAGE SQL;

-- ============================================================================
-- Procedure: Register Detected Disputes
-- ============================================================================

CREATE OR REPLACE PROCEDURE sp_register_disputes()
LANGUAGE plpgsql
AS $$
DECLARE
    v_overlap RECORD;
    v_count INT := 0;
BEGIN
    FOR v_overlap IN SELECT * FROM fn_detect_overlaps()
    LOOP
        INSERT INTO disputes (parcel1_id, parcel2_id, overlap_area_sqm, overlap_pct_parcel1, overlap_pct_parcel2)
        SELECT 
            v_overlap.parcel1_id,
            v_overlap.parcel2_id,
            v_overlap.overlap_sqm,
            ROUND((v_overlap.overlap_sqm / p1.area_sqm * 100)::NUMERIC, 2),
            ROUND((v_overlap.overlap_sqm / p2.area_sqm * 100)::NUMERIC, 2)
        FROM parcels p1, parcels p2
        WHERE p1.parcel_id = v_overlap.parcel1_id
          AND p2.parcel_id = v_overlap.parcel2_id
        ON CONFLICT (parcel1_id, parcel2_id) DO NOTHING;
        
        v_count := v_count + 1;
    END LOOP;
    
    RAISE NOTICE 'Registered % new disputes', v_count;
END;
$$;
