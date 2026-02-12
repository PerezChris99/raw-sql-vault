-- ============================================================================
-- Road Condition Aggregator - Clustering Functions
-- PostgreSQL 14+ with PostGIS 3.x
-- DBSCAN clustering functions for report aggregation
-- ============================================================================

-- ============================================================================
-- Core Clustering Function
-- Wraps ST_ClusterDBSCAN with configurable parameters
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_cluster_reports(
    p_eps FLOAT DEFAULT 0.0005,      -- ~55m at equator (in degrees)
    p_min_points INTEGER DEFAULT 3,   -- Minimum reports for a cluster
    p_days_back INTEGER DEFAULT 30,   -- Only cluster recent reports
    p_status TEXT[] DEFAULT ARRAY['new', 'verified']
)
RETURNS TABLE (
    report_id UUID,
    cluster_id INTEGER,
    location GEOGRAPHY,
    severity INTEGER,
    damage_type_id INTEGER,
    reported_at TIMESTAMPTZ
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        rr.report_id,
        ST_ClusterDBSCAN(rr.location::geometry, p_eps, p_min_points) OVER () as cluster_id,
        rr.location,
        rr.severity,
        rr.damage_type_id,
        rr.reported_at
    FROM road_reports rr
    WHERE rr.status = ANY(p_status)
      AND rr.reported_at >= CURRENT_DATE - (p_days_back || ' days')::INTERVAL;
END;
$$;

COMMENT ON FUNCTION fn_cluster_reports IS 'DBSCAN clustering of road reports with configurable parameters';

-- ============================================================================
-- Cluster Statistics Function
-- Aggregates cluster details including geometry and severity
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_get_cluster_stats(
    p_eps FLOAT DEFAULT 0.0005,
    p_min_points INTEGER DEFAULT 3,
    p_days_back INTEGER DEFAULT 30
)
RETURNS TABLE (
    cluster_id INTEGER,
    report_count BIGINT,
    avg_severity NUMERIC,
    max_severity INTEGER,
    cluster_center GEOGRAPHY,
    cluster_boundary GEOMETRY,
    area_sq_m FLOAT,
    oldest_report TIMESTAMPTZ,
    newest_report TIMESTAMPTZ,
    damage_types TEXT[]
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    WITH clustered AS (
        SELECT * FROM fn_cluster_reports(p_eps, p_min_points, p_days_back)
    )
    SELECT 
        c.cluster_id,
        COUNT(*) as report_count,
        ROUND(AVG(c.severity), 2) as avg_severity,
        MAX(c.severity) as max_severity,
        ST_Centroid(ST_Collect(c.location::geometry))::geography as cluster_center,
        ST_ConvexHull(ST_Collect(c.location::geometry)) as cluster_boundary,
        ST_Area(ST_ConvexHull(ST_Collect(c.location::geometry))::geography) as area_sq_m,
        MIN(c.reported_at) as oldest_report,
        MAX(c.reported_at) as newest_report,
        ARRAY_AGG(DISTINCT dt.name) FILTER (WHERE dt.name IS NOT NULL) as damage_types
    FROM clustered c
    LEFT JOIN damage_types dt ON c.damage_type_id = dt.damage_id
    WHERE c.cluster_id IS NOT NULL
    GROUP BY c.cluster_id
    HAVING COUNT(*) >= p_min_points
    ORDER BY avg_severity DESC;
END;
$$;

COMMENT ON FUNCTION fn_get_cluster_stats IS 'Get aggregated statistics for each report cluster';

-- ============================================================================
-- Find Reports Near Point
-- Useful for mobile app integration
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_find_nearby_reports(
    p_longitude FLOAT,
    p_latitude FLOAT,
    p_radius_m FLOAT DEFAULT 100,
    p_status TEXT[] DEFAULT ARRAY['new', 'verified'],
    p_limit INTEGER DEFAULT 50
)
RETURNS TABLE (
    report_id UUID,
    distance_m FLOAT,
    severity INTEGER,
    status TEXT,
    damage_type TEXT,
    address_description TEXT,
    reported_at TIMESTAMPTZ
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_point GEOGRAPHY;
BEGIN
    v_point := ST_SetSRID(ST_MakePoint(p_longitude, p_latitude), 4326)::geography;
    
    RETURN QUERY
    SELECT 
        rr.report_id,
        ROUND(ST_Distance(rr.location, v_point)::NUMERIC, 1)::FLOAT as distance_m,
        rr.severity,
        rr.status::TEXT,
        dt.name as damage_type,
        rr.address_description,
        rr.reported_at
    FROM road_reports rr
    LEFT JOIN damage_types dt ON rr.damage_type_id = dt.damage_id
    WHERE ST_DWithin(rr.location, v_point, p_radius_m)
      AND rr.status = ANY(p_status)
    ORDER BY ST_Distance(rr.location, v_point)
    LIMIT p_limit;
END;
$$;

COMMENT ON FUNCTION fn_find_nearby_reports IS 'Find reports within radius of a given point';

-- ============================================================================
-- Find Affected Road Segments
-- Match cluster to road network
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_find_affected_segments(
    p_cluster_id INTEGER,
    p_eps FLOAT DEFAULT 0.0005,
    p_min_points INTEGER DEFAULT 3,
    p_buffer_m FLOAT DEFAULT 20
)
RETURNS TABLE (
    segment_id UUID,
    road_name TEXT,
    segment_name TEXT,
    road_class TEXT,
    reports_nearby BIGINT,
    avg_severity NUMERIC
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    WITH cluster_reports AS (
        SELECT * 
        FROM fn_cluster_reports(p_eps, p_min_points)
        WHERE cluster_id = p_cluster_id
    )
    SELECT 
        rs.segment_id,
        rs.road_name,
        rs.segment_name,
        rc.name as road_class,
        COUNT(cr.report_id) as reports_nearby,
        ROUND(AVG(cr.severity), 2) as avg_severity
    FROM road_segments rs
    LEFT JOIN road_classifications rc ON rs.road_class_id = rc.class_id
    JOIN cluster_reports cr ON ST_DWithin(rs.geom::geography, cr.location, p_buffer_m)
    GROUP BY rs.segment_id, rs.road_name, rs.segment_name, rc.name
    ORDER BY reports_nearby DESC;
END;
$$;

COMMENT ON FUNCTION fn_find_affected_segments IS 'Find road segments affected by a specific cluster';

-- ============================================================================
-- Merge Clusters Procedure
-- Consolidates overlapping clusters
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_merge_overlapping_clusters(
    p_eps FLOAT DEFAULT 0.0005,
    p_min_points INTEGER DEFAULT 3,
    p_overlap_threshold FLOAT DEFAULT 0.5  -- 50% overlap triggers merge
)
RETURNS TABLE (
    merged_cluster_id INTEGER,
    original_clusters INTEGER[],
    total_reports BIGINT,
    combined_center GEOGRAPHY
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    WITH clusters AS (
        SELECT * FROM fn_get_cluster_stats(p_eps, p_min_points)
    ),
    overlaps AS (
        SELECT 
            c1.cluster_id as cluster1,
            c2.cluster_id as cluster2,
            ST_Area(ST_Intersection(c1.cluster_boundary, c2.cluster_boundary)) / 
            LEAST(ST_Area(c1.cluster_boundary), ST_Area(c2.cluster_boundary)) as overlap_ratio
        FROM clusters c1
        JOIN clusters c2 ON c1.cluster_id < c2.cluster_id
        WHERE ST_Intersects(c1.cluster_boundary, c2.cluster_boundary)
    )
    SELECT 
        MIN(o.cluster1) as merged_cluster_id,
        ARRAY_AGG(DISTINCT unnest) as original_clusters,
        SUM(c.report_count) as total_reports,
        ST_Centroid(ST_Collect(c.cluster_center::geometry))::geography as combined_center
    FROM overlaps o
    CROSS JOIN LATERAL unnest(ARRAY[o.cluster1, o.cluster2]) as unnest
    JOIN clusters c ON c.cluster_id = unnest
    WHERE o.overlap_ratio >= p_overlap_threshold
    GROUP BY LEAST(o.cluster1, o.cluster2);
END;
$$;

COMMENT ON FUNCTION fn_merge_overlapping_clusters IS 'Identify overlapping clusters that should be merged';

-- ============================================================================
-- Persist Clusters to Table
-- Saves current clustering results for work order generation
-- ============================================================================

CREATE OR REPLACE PROCEDURE sp_persist_clusters(
    p_eps FLOAT DEFAULT 0.0005,
    p_min_points INTEGER DEFAULT 3,
    p_days_back INTEGER DEFAULT 30
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_clusters_created INTEGER := 0;
    v_reports_assigned INTEGER := 0;
BEGIN
    -- Deactivate old clusters
    UPDATE report_clusters 
    SET status = 'merged', updated_at = CURRENT_TIMESTAMP
    WHERE status = 'active';
    
    -- Insert new clusters
    WITH cluster_stats AS (
        SELECT * FROM fn_get_cluster_stats(p_eps, p_min_points, p_days_back)
    )
    INSERT INTO report_clusters (
        cluster_center,
        cluster_boundary,
        report_count,
        avg_severity,
        max_severity,
        affected_road_names,
        status,
        calculated_at
    )
    SELECT 
        cs.cluster_center,
        cs.cluster_boundary,
        cs.report_count::INTEGER,
        cs.avg_severity,
        cs.max_severity,
        (SELECT ARRAY_AGG(DISTINCT rs.road_name) 
         FROM fn_cluster_reports(p_eps, p_min_points, p_days_back) cr
         JOIN road_segments rs ON ST_DWithin(rs.geom::geography, cr.location, 20)
         WHERE cr.cluster_id = cs.cluster_id),
        'active',
        CURRENT_TIMESTAMP
    FROM cluster_stats cs;
    
    GET DIAGNOSTICS v_clusters_created = ROW_COUNT;
    
    RAISE NOTICE 'Persisted % clusters', v_clusters_created;
END;
$$;

COMMENT ON PROCEDURE sp_persist_clusters IS 'Persist current DBSCAN clusters to report_clusters table';

-- ============================================================================
-- Cluster Density Function (alternative clustering metric)
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_cluster_density(
    p_cluster_id INTEGER,
    p_eps FLOAT DEFAULT 0.0005,
    p_min_points INTEGER DEFAULT 3
)
RETURNS NUMERIC
LANGUAGE plpgsql
AS $$
DECLARE
    v_density NUMERIC;
BEGIN
    SELECT 
        COALESCE(report_count / NULLIF(area_sq_m / 1000000.0, 0), 0)  -- Reports per sq km
    INTO v_density
    FROM fn_get_cluster_stats(p_eps, p_min_points)
    WHERE cluster_id = p_cluster_id;
    
    RETURN ROUND(v_density, 2);
END;
$$;

COMMENT ON FUNCTION fn_cluster_density IS 'Calculate report density per sq km for a cluster';
