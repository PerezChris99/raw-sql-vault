-- ============================================================================
-- Road Condition Aggregator - V004 Spatial Views
-- PostgreSQL 14+ with PostGIS 3.x
-- Views for common spatial queries and analysis
-- ============================================================================

-- ============================================================================
-- Active Reports View
-- ============================================================================

-- Current active reports with full details
CREATE OR REPLACE VIEW vw_active_reports AS
SELECT 
    rr.report_id,
    rr.location,
    ST_AsGeoJSON(rr.location::geometry) as location_geojson,
    ST_X(rr.location::geometry) as longitude,
    ST_Y(rr.location::geometry) as latitude,
    rr.severity,
    rr.status,
    rr.reported_at,
    EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - rr.reported_at)) / 86400 as days_old,
    dt.name as damage_type,
    dt.severity_weight,
    d.name as district_name,
    rs.road_name,
    rs.road_class,
    rr.address_description,
    rr.notes
FROM road_reports rr
LEFT JOIN damage_types dt ON rr.damage_type_id = dt.damage_id
LEFT JOIN districts d ON rr.district_id = d.district_id
LEFT JOIN road_segments rs ON rr.segment_id = rs.segment_id
WHERE rr.status IN ('new', 'verified')
ORDER BY rr.severity DESC, rr.reported_at ASC;

COMMENT ON VIEW vw_active_reports IS 'Active reports awaiting repair with full context';

-- ============================================================================
-- DBSCAN Clustering View (User's Sample Query Pattern)
-- ============================================================================

-- Real-time DBSCAN clustering of recent reports
CREATE OR REPLACE VIEW vw_report_clusters_dbscan AS
WITH clustered AS (
    SELECT 
        report_id,
        location,
        severity,
        damage_type_id,
        reported_at,
        ST_ClusterDBSCAN(location::geometry, 0.01, 3) OVER () as cluster_id
    FROM road_reports
    WHERE status IN ('new', 'verified')
      AND reported_at >= CURRENT_DATE - INTERVAL '30 days'
)
SELECT 
    cluster_id,
    CASE WHEN cluster_id IS NULL THEN 'noise' ELSE 'cluster' END as point_type,
    COUNT(*) as report_count,
    ROUND(AVG(severity), 2) as avg_severity,
    MAX(severity) as max_severity,
    MIN(reported_at) as oldest_report,
    MAX(reported_at) as newest_report,
    ST_Centroid(ST_Collect(location::geometry)) as cluster_center,
    ST_AsGeoJSON(ST_Centroid(ST_Collect(location::geometry))) as center_geojson,
    ST_ConvexHull(ST_Collect(location::geometry)) as cluster_boundary,
    ST_Area(ST_ConvexHull(ST_Collect(location::geometry))::geography) as area_sq_m
FROM clustered
GROUP BY cluster_id
HAVING COUNT(*) > 5  -- From user's sample query
ORDER BY avg_severity DESC;

COMMENT ON VIEW vw_report_clusters_dbscan IS 'DBSCAN clustering matching user sample query pattern';

-- ============================================================================
-- Priority Queue View
-- ============================================================================

-- Prioritized repair queue based on clusters
CREATE OR REPLACE VIEW vw_priority_queue AS
WITH clustered AS (
    SELECT 
        report_id,
        location,
        severity,
        damage_type_id,
        segment_id,
        ST_ClusterDBSCAN(location::geometry, 0.0005, 3) OVER () as cluster_id
    FROM road_reports
    WHERE status IN ('new', 'verified')
      AND reported_at >= CURRENT_DATE - INTERVAL '30 days'
),
cluster_stats AS (
    SELECT 
        c.cluster_id,
        COUNT(*) as report_count,
        AVG(c.severity) as avg_severity,
        MAX(c.severity) as max_severity,
        ST_Centroid(ST_Collect(c.location::geometry)) as work_center,
        ST_ConvexHull(ST_Collect(c.location::geometry)) as work_area,
        ARRAY_AGG(DISTINCT rs.road_name) FILTER (WHERE rs.road_name IS NOT NULL) as affected_roads,
        COALESCE(MAX(rc.priority_weight), 1) as road_priority,
        SUM(dt.estimated_repair_cost) as estimated_cost
    FROM clustered c
    LEFT JOIN road_segments rs ON c.segment_id = rs.segment_id
    LEFT JOIN road_classifications rc ON rs.road_class_id = rc.class_id
    LEFT JOIN damage_types dt ON c.damage_type_id = dt.damage_id
    WHERE c.cluster_id IS NOT NULL
    GROUP BY c.cluster_id
    HAVING COUNT(*) >= 3
)
SELECT 
    cluster_id,
    report_count,
    ROUND(avg_severity, 2) as avg_severity,
    max_severity,
    work_center,
    ST_AsGeoJSON(work_center) as work_center_geojson,
    work_area,
    affected_roads,
    estimated_cost,
    -- Priority Score calculation
    ROUND((
        (avg_severity / 10) * 40 +                    -- Severity: up to 40 pts
        LEAST(LOG(report_count + 1) * 15, 30) +       -- Density: up to 30 pts
        road_priority * 10                            -- Road importance: up to 30 pts
    )::NUMERIC, 2) as priority_score,
    ROW_NUMBER() OVER (ORDER BY 
        (avg_severity / 10) * 40 + 
        LEAST(LOG(report_count + 1) * 15, 30) + 
        road_priority * 10 DESC
    ) as priority_rank
FROM cluster_stats
ORDER BY priority_score DESC;

COMMENT ON VIEW vw_priority_queue IS 'Prioritized repair queue based on clustered reports';

-- ============================================================================
-- District Summary View
-- ============================================================================

CREATE OR REPLACE VIEW vw_district_summary AS
SELECT 
    d.district_id,
    d.name as district_name,
    d.code as district_code,
    d.boundary,
    ST_AsGeoJSON(d.boundary) as boundary_geojson,
    COALESCE(d.area_sq_km, ST_Area(d.boundary::geography) / 1000000) as area_sq_km,
    d.population,
    COUNT(rr.report_id) as total_reports,
    COUNT(rr.report_id) FILTER (WHERE rr.status = 'new') as new_reports,
    COUNT(rr.report_id) FILTER (WHERE rr.status = 'verified') as verified_reports,
    COUNT(rr.report_id) FILTER (WHERE rr.reported_at >= CURRENT_DATE - INTERVAL '7 days') as reports_last_7d,
    ROUND(AVG(rr.severity), 2) as avg_severity,
    COUNT(rr.report_id) FILTER (WHERE dt.name = 'Pothole') as pothole_count,
    -- Reports per sq km
    ROUND(
        COUNT(rr.report_id)::NUMERIC / NULLIF(COALESCE(d.area_sq_km, ST_Area(d.boundary::geography) / 1000000), 0),
        2
    ) as reports_per_sq_km
FROM districts d
LEFT JOIN road_reports rr ON d.district_id = rr.district_id
    AND rr.reported_at >= CURRENT_DATE - INTERVAL '90 days'
LEFT JOIN damage_types dt ON rr.damage_type_id = dt.damage_id
GROUP BY d.district_id, d.name, d.code, d.boundary, d.area_sq_km, d.population
ORDER BY total_reports DESC;

COMMENT ON VIEW vw_district_summary IS 'District-level report summary with geographic context';

-- ============================================================================
-- Road Segment Analysis View
-- ============================================================================

CREATE OR REPLACE VIEW vw_road_segment_analysis AS
SELECT 
    rs.segment_id,
    rs.road_name,
    rs.segment_name,
    rc.name as road_class,
    rs.geom,
    ST_AsGeoJSON(rs.geom) as geom_geojson,
    ROUND(rs.length_m::NUMERIC, 1) as length_m,
    rs.traffic_volume,
    rs.pavement_condition,
    rs.last_maintenance_date,
    d.name as district_name,
    -- Report statistics within 15m of segment
    COUNT(rr.report_id) as report_count,
    COUNT(rr.report_id) FILTER (WHERE rr.status IN ('new', 'verified')) as active_reports,
    ROUND(AVG(rr.severity), 2) as avg_severity,
    MAX(rr.severity) as max_severity,
    -- Reports per 100m of road
    ROUND(
        COUNT(rr.report_id)::NUMERIC / NULLIF(rs.length_m / 100, 0),
        2
    ) as reports_per_100m,
    ARRAY_AGG(DISTINCT dt.name) FILTER (WHERE dt.name IS NOT NULL) as damage_types
FROM road_segments rs
LEFT JOIN road_classifications rc ON rs.road_class_id = rc.class_id
LEFT JOIN districts d ON rs.district_id = d.district_id
LEFT JOIN road_reports rr ON ST_DWithin(rs.geom::geography, rr.location, 15)
    AND rr.reported_at >= CURRENT_DATE - INTERVAL '90 days'
LEFT JOIN damage_types dt ON rr.damage_type_id = dt.damage_id
WHERE rs.status = 'active'
GROUP BY rs.segment_id, rs.road_name, rs.segment_name, rc.name, rs.geom, 
         rs.length_m, rs.traffic_volume, rs.pavement_condition, 
         rs.last_maintenance_date, d.name
ORDER BY report_count DESC;

COMMENT ON VIEW vw_road_segment_analysis IS 'Road segments with nearby report aggregation';

-- ============================================================================
-- Work Order Map View
-- ============================================================================

CREATE OR REPLACE VIEW vw_work_order_map AS
SELECT 
    wo.work_order_id,
    wo.work_center,
    ST_AsGeoJSON(wo.work_center::geometry) as work_center_geojson,
    wo.work_area,
    ST_AsGeoJSON(wo.work_area) as work_area_geojson,
    wo.priority_score,
    wo.priority_rank,
    wo.status,
    wo.scheduled_date,
    wo.estimated_cost,
    rc.cluster_id,
    rc.report_count,
    rc.avg_severity,
    rc.affected_road_names,
    c.name as crew_name,
    c.crew_type
FROM repair_work_orders wo
LEFT JOIN report_clusters rc ON wo.cluster_id = rc.cluster_id
LEFT JOIN crews c ON wo.crew_id = c.crew_id
WHERE wo.status NOT IN ('cancelled', 'completed')
ORDER BY wo.priority_rank;

COMMENT ON VIEW vw_work_order_map IS 'Active work orders for field crew mapping';

-- ============================================================================
-- GeoJSON Export Views
-- ============================================================================

-- GeoJSON FeatureCollection of active reports
CREATE OR REPLACE VIEW vw_reports_geojson AS
SELECT json_build_object(
    'type', 'FeatureCollection',
    'generated_at', CURRENT_TIMESTAMP,
    'count', COUNT(*),
    'features', COALESCE(json_agg(
        json_build_object(
            'type', 'Feature',
            'geometry', ST_AsGeoJSON(rr.location::geometry)::json,
            'properties', json_build_object(
                'report_id', rr.report_id,
                'severity', rr.severity,
                'status', rr.status,
                'damage_type', dt.name,
                'district', d.name,
                'road_name', rs.road_name,
                'reported_at', rr.reported_at,
                'days_old', ROUND(EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - rr.reported_at)) / 86400, 1)
            )
        )
    ), '[]'::json)
) as geojson
FROM road_reports rr
LEFT JOIN damage_types dt ON rr.damage_type_id = dt.damage_id
LEFT JOIN districts d ON rr.district_id = d.district_id
LEFT JOIN road_segments rs ON rr.segment_id = rs.segment_id
WHERE rr.status IN ('new', 'verified');

COMMENT ON VIEW vw_reports_geojson IS 'GeoJSON export of active reports for mapping';

-- GeoJSON of cluster centroids for priority map
CREATE OR REPLACE VIEW vw_clusters_geojson AS
SELECT json_build_object(
    'type', 'FeatureCollection',
    'generated_at', CURRENT_TIMESTAMP,
    'features', COALESCE(json_agg(
        json_build_object(
            'type', 'Feature',
            'geometry', work_center_geojson::json,
            'properties', json_build_object(
                'cluster_id', cluster_id,
                'report_count', report_count,
                'avg_severity', avg_severity,
                'priority_score', priority_score,
                'priority_rank', priority_rank,
                'affected_roads', affected_roads,
                'estimated_cost', estimated_cost
            )
        )
    ), '[]'::json)
) as geojson
FROM vw_priority_queue;

COMMENT ON VIEW vw_clusters_geojson IS 'GeoJSON export of priority clusters for dispatch map';

-- ============================================================================
-- Temporal Analysis Views
-- ============================================================================

-- Weekly report trends
CREATE OR REPLACE VIEW vw_weekly_trends AS
SELECT 
    DATE_TRUNC('week', reported_at)::DATE as week_start,
    COUNT(*) as total_reports,
    COUNT(*) FILTER (WHERE severity >= 7) as high_severity,
    ROUND(AVG(severity), 2) as avg_severity,
    COUNT(DISTINCT district_id) as districts_affected,
    COUNT(*) FILTER (WHERE dt.name = 'Pothole') as potholes,
    COUNT(*) FILTER (WHERE status = 'repaired') as repaired
FROM road_reports rr
LEFT JOIN damage_types dt ON rr.damage_type_id = dt.damage_id
WHERE reported_at >= CURRENT_DATE - INTERVAL '12 weeks'
GROUP BY DATE_TRUNC('week', reported_at)
ORDER BY week_start DESC;

COMMENT ON VIEW vw_weekly_trends IS 'Weekly report volume and severity trends';

-- Hour of day distribution
CREATE OR REPLACE VIEW vw_hourly_distribution AS
SELECT 
    EXTRACT(HOUR FROM reported_at) as hour_of_day,
    COUNT(*) as report_count,
    ROUND(AVG(severity), 2) as avg_severity
FROM road_reports
WHERE reported_at >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY EXTRACT(HOUR FROM reported_at)
ORDER BY hour_of_day;

COMMENT ON VIEW vw_hourly_distribution IS 'Report distribution by hour of day';

-- ============================================================================
-- Crew Dispatch View
-- ============================================================================

CREATE OR REPLACE VIEW vw_crew_availability AS
SELECT 
    c.crew_id,
    c.name as crew_name,
    c.crew_type,
    c.member_count,
    c.status,
    c.current_location,
    ST_AsGeoJSON(c.current_location::geometry) as location_geojson,
    c.equipment_capacity,
    COUNT(wo.work_order_id) FILTER (WHERE wo.status = 'assigned') as active_assignments,
    COUNT(wo.work_order_id) FILTER (WHERE wo.status = 'completed' 
        AND wo.completed_at >= CURRENT_DATE - INTERVAL '7 days') as completed_last_7d
FROM crews c
LEFT JOIN repair_work_orders wo ON c.crew_id = wo.crew_id
GROUP BY c.crew_id, c.name, c.crew_type, c.member_count, c.status, 
         c.current_location, c.equipment_capacity
ORDER BY 
    CASE c.status WHEN 'available' THEN 0 WHEN 'assigned' THEN 1 ELSE 2 END,
    c.crew_type;

COMMENT ON VIEW vw_crew_availability IS 'Crew status and availability for dispatch';
