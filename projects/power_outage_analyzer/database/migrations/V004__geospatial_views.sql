-- ============================================================================
-- Power Outage Pattern Analyzer - V004 Geospatial Views
-- PostgreSQL 14+ with PostGIS 3.x
-- Views for common geospatial queries and analysis
-- ============================================================================

-- ============================================================================
-- Active Outage Views
-- ============================================================================

-- Current active outages with geospatial data for live mapping
CREATE OR REPLACE VIEW vw_active_outages AS
SELECT 
    o.outage_id,
    o.district_id,
    d.name as district_name,
    o.location,
    ST_AsGeoJSON(o.location::geometry) as location_geojson,
    ST_X(o.location::geometry) as longitude,
    ST_Y(o.location::geometry) as latitude,
    o.affected_area,
    ST_AsGeoJSON(o.affected_area) as affected_area_geojson,
    o.customers_affected,
    o.estimated_load_lost_kw,
    o.severity,
    o.status,
    o.occurred_at,
    o.estimated_restore_at,
    EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - o.occurred_at)) / 3600 as hours_ongoing,
    oc.name as cause_name,
    oc.category as cause_category,
    o.outage_type,
    o.is_major_event
FROM outages o
JOIN districts d ON o.district_id = d.district_id
LEFT JOIN outage_causes oc ON o.cause_id = oc.cause_id
WHERE o.status NOT IN ('restored', 'closed')
ORDER BY o.customers_affected DESC, o.occurred_at ASC;

COMMENT ON VIEW vw_active_outages IS 'Real-time view of active outages for operations dashboard';

-- ============================================================================
-- Clustering Views
-- ============================================================================

-- K-Means cluster analysis (5 clusters, last 6 months)
CREATE OR REPLACE VIEW vw_outage_clusters_kmeans AS
WITH clustered AS (
    SELECT 
        outage_id,
        location,
        district_id,
        occurred_at,
        customers_affected,
        duration_minutes,
        cause_id,
        ST_ClusterKMeans(location::geometry, 5) OVER () as cluster_id
    FROM outages
    WHERE occurred_at >= CURRENT_DATE - INTERVAL '6 months'
      AND location IS NOT NULL
)
SELECT 
    cluster_id,
    COUNT(*) as outage_count,
    ST_Centroid(ST_Collect(location::geometry)) as cluster_center,
    ST_AsGeoJSON(ST_Centroid(ST_Collect(location::geometry))) as center_geojson,
    ST_ConvexHull(ST_Collect(location::geometry)) as cluster_boundary,
    ST_AsGeoJSON(ST_ConvexHull(ST_Collect(location::geometry))) as boundary_geojson,
    ST_Area(ST_ConvexHull(ST_Collect(location::geometry))::geography) / 1000000 as area_sq_km,
    SUM(customers_affected) as total_customers_affected,
    ROUND(AVG(customers_affected)) as avg_customers_affected,
    ROUND(AVG(duration_minutes)) as avg_duration_minutes,
    MIN(occurred_at) as first_outage,
    MAX(occurred_at) as last_outage
FROM clustered
GROUP BY cluster_id
ORDER BY outage_count DESC;

COMMENT ON VIEW vw_outage_clusters_kmeans IS 'K-Means clustered outage hotspots for pattern analysis';

-- DBSCAN density-based clustering (500m radius, min 3 points)
CREATE OR REPLACE VIEW vw_outage_clusters_dbscan AS
WITH clustered AS (
    SELECT 
        outage_id,
        location,
        district_id,
        occurred_at,
        customers_affected,
        duration_minutes,
        ST_ClusterDBSCAN(location::geometry, eps := 500, minpoints := 3) OVER () as cluster_id
    FROM outages
    WHERE occurred_at >= CURRENT_DATE - INTERVAL '90 days'
      AND location IS NOT NULL
)
SELECT 
    cluster_id,
    CASE WHEN cluster_id IS NULL THEN 'noise' ELSE 'cluster' END as point_type,
    COUNT(*) as outage_count,
    ST_Centroid(ST_Collect(location::geometry)) as cluster_center,
    ST_AsGeoJSON(ST_Centroid(ST_Collect(location::geometry))) as center_geojson,
    SUM(customers_affected) as total_customers_affected,
    ROUND(AVG(duration_minutes)) as avg_duration_minutes
FROM clustered
GROUP BY cluster_id
HAVING cluster_id IS NOT NULL  -- Exclude noise points from summary
ORDER BY outage_count DESC;

COMMENT ON VIEW vw_outage_clusters_dbscan IS 'DBSCAN density clusters for identifying dense failure areas';

-- ============================================================================
-- District Analysis Views
-- ============================================================================

-- Outage statistics per district with area normalization
CREATE OR REPLACE VIEW vw_district_outage_stats AS
SELECT 
    d.district_id,
    d.name as district_name,
    d.code as district_code,
    r.name as region_name,
    d.boundary,
    ST_AsGeoJSON(d.boundary) as boundary_geojson,
    ST_Area(d.boundary::geography) / 1000000 as area_sq_km,
    d.population,
    COUNT(o.outage_id) as total_outages,
    COUNT(o.outage_id) FILTER (WHERE o.occurred_at >= CURRENT_DATE - INTERVAL '30 days') as outages_last_30d,
    COUNT(o.outage_id) FILTER (WHERE o.occurred_at >= CURRENT_DATE - INTERVAL '90 days') as outages_last_90d,
    COALESCE(SUM(o.customers_affected), 0) as total_customers_affected,
    ROUND(AVG(o.duration_minutes)) as avg_duration_minutes,
    ROUND(
        COUNT(o.outage_id)::NUMERIC / NULLIF(ST_Area(d.boundary::geography) / 1000000, 0), 
        2
    ) as outages_per_sq_km,
    ROUND(
        COUNT(o.outage_id)::NUMERIC / NULLIF(d.population::NUMERIC / 1000, 0), 
        2
    ) as outages_per_1000_pop
FROM districts d
JOIN regions r ON d.region_id = r.region_id
LEFT JOIN outages o ON d.district_id = o.district_id
    AND o.occurred_at >= CURRENT_DATE - INTERVAL '1 year'
GROUP BY d.district_id, d.name, d.code, r.name, d.boundary, d.population
ORDER BY total_outages DESC;

COMMENT ON VIEW vw_district_outage_stats IS 'District-level outage statistics with area normalization';

-- District risk heatmap data
CREATE OR REPLACE VIEW vw_district_risk_heatmap AS
SELECT 
    d.district_id,
    d.name,
    d.boundary,
    ST_AsGeoJSON(d.boundary) as boundary_geojson,
    COALESCE(recent.outage_count, 0) as recent_outages,
    COALESCE(recent.avg_duration, 0) as avg_duration,
    COALESCE(recent.equipment_failures, 0) as equipment_failures,
    COALESCE(recent.weather_events, 0) as weather_events,
    -- Risk score calculation
    ROUND(
        (COALESCE(recent.outage_count, 0) * 2.0 + 
         COALESCE(recent.equipment_failures, 0) * 3.0 +
         COALESCE(recent.avg_duration, 0) / 60.0) / 10.0,
        2
    ) as risk_score,
    CASE 
        WHEN COALESCE(recent.outage_count, 0) >= 50 THEN 'critical'
        WHEN COALESCE(recent.outage_count, 0) >= 25 THEN 'high'
        WHEN COALESCE(recent.outage_count, 0) >= 10 THEN 'medium'
        ELSE 'low'
    END as risk_level
FROM districts d
LEFT JOIN LATERAL (
    SELECT 
        COUNT(*) as outage_count,
        AVG(duration_minutes) as avg_duration,
        COUNT(*) FILTER (WHERE oc.category = 'equipment') as equipment_failures,
        COUNT(*) FILTER (WHERE oc.category = 'weather') as weather_events
    FROM outages o
    LEFT JOIN outage_causes oc ON o.cause_id = oc.cause_id
    WHERE o.district_id = d.district_id
      AND o.occurred_at >= CURRENT_DATE - INTERVAL '90 days'
) recent ON true
ORDER BY risk_score DESC;

COMMENT ON VIEW vw_district_risk_heatmap IS 'District risk levels for heatmap visualization';

-- ============================================================================
-- Infrastructure Analysis Views
-- ============================================================================

-- Transformer risk analysis
CREATE OR REPLACE VIEW vw_transformer_risk_analysis AS
SELECT 
    t.transformer_id,
    t.code,
    t.name,
    t.location,
    ST_AsGeoJSON(t.location::geometry) as location_geojson,
    ST_X(t.location::geometry) as longitude,
    ST_Y(t.location::geometry) as latitude,
    t.capacity_kva,
    t.age_years,
    t.customers_served,
    t.status,
    d.name as district_name,
    -- Nearby outages in different radii
    (SELECT COUNT(*) FROM outages o 
     WHERE ST_DWithin(t.location, o.location, 250) 
       AND o.occurred_at >= CURRENT_DATE - INTERVAL '1 year') as outages_within_250m,
    (SELECT COUNT(*) FROM outages o 
     WHERE ST_DWithin(t.location, o.location, 500) 
       AND o.occurred_at >= CURRENT_DATE - INTERVAL '1 year') as outages_within_500m,
    -- Risk factors
    CASE 
        WHEN t.age_years >= 30 THEN 'high'
        WHEN t.age_years >= 20 THEN 'medium'
        ELSE 'low'
    END as age_risk,
    -- Overall risk score
    ROUND(
        (COALESCE(t.age_years, 0) * 0.3 + 
         (SELECT COUNT(*) FROM outages o 
          WHERE ST_DWithin(t.location, o.location, 500) 
            AND o.occurred_at >= CURRENT_DATE - INTERVAL '1 year') * 2.0) / 10.0,
        2
    ) as risk_score
FROM transformers t
JOIN districts d ON t.district_id = d.district_id
WHERE t.status = 'operational'
ORDER BY risk_score DESC;

COMMENT ON VIEW vw_transformer_risk_analysis IS 'Transformer health and risk assessment with spatial context';

-- Power line vulnerability assessment
CREATE OR REPLACE VIEW vw_power_line_vulnerability AS
SELECT 
    pl.line_id,
    pl.name,
    pl.line_type,
    pl.voltage_kv,
    pl.length_km,
    pl.route,
    ST_AsGeoJSON(pl.route) as route_geojson,
    pl.installation_year,
    pl.status,
    s1.name as start_substation,
    s2.name as end_substation,
    -- Outages along this line (within 100m of route)
    (SELECT COUNT(*) FROM outages o 
     WHERE ST_DWithin(pl.route::geography, o.location, 100)
       AND o.occurred_at >= CURRENT_DATE - INTERVAL '1 year') as nearby_outages_1y,
    -- Intersections with other lines
    (SELECT COUNT(*) FROM power_lines pl2 
     WHERE pl.line_id < pl2.line_id 
       AND ST_Intersects(pl.route, pl2.route)) as line_intersections,
    -- Vulnerability score
    ROUND(
        (2024 - COALESCE(pl.installation_year, 2000)) * 0.1 +
        pl.length_km * 0.2 +
        (SELECT COUNT(*) FROM outages o 
         WHERE ST_DWithin(pl.route::geography, o.location, 100)
           AND o.occurred_at >= CURRENT_DATE - INTERVAL '1 year') * 1.5,
        2
    ) as vulnerability_score
FROM power_lines pl
JOIN substations s1 ON pl.start_substation_id = s1.substation_id
JOIN substations s2 ON pl.end_substation_id = s2.substation_id
WHERE pl.status = 'active'
ORDER BY vulnerability_score DESC;

COMMENT ON VIEW vw_power_line_vulnerability IS 'Power line vulnerability based on age, length, and historical outages';

-- ============================================================================
-- Proximity Analysis Views
-- ============================================================================

-- Outages near critical infrastructure (hospitals, schools, etc.)
CREATE OR REPLACE VIEW vw_outages_near_substations AS
SELECT 
    s.substation_id,
    s.name as substation_name,
    s.location as substation_location,
    s.capacity_mva,
    o.outage_id,
    o.location as outage_location,
    ST_Distance(s.location, o.location) as distance_meters,
    o.occurred_at,
    o.duration_minutes,
    o.customers_affected,
    o.status
FROM substations s
JOIN outages o ON ST_DWithin(s.location, o.location, 2000)  -- 2km radius
WHERE o.occurred_at >= CURRENT_DATE - INTERVAL '90 days'
ORDER BY s.substation_id, distance_meters;

COMMENT ON VIEW vw_outages_near_substations IS 'Outages occurring near substations for infrastructure impact analysis';

-- ============================================================================
-- GeoJSON Export Views
-- ============================================================================

-- Full GeoJSON FeatureCollection of current outages
CREATE OR REPLACE VIEW vw_outages_geojson AS
SELECT json_build_object(
    'type', 'FeatureCollection',
    'generated_at', CURRENT_TIMESTAMP,
    'features', COALESCE(json_agg(
        json_build_object(
            'type', 'Feature',
            'geometry', ST_AsGeoJSON(o.location::geometry)::json,
            'properties', json_build_object(
                'outage_id', o.outage_id,
                'district', d.name,
                'customers_affected', o.customers_affected,
                'severity', o.severity,
                'status', o.status,
                'occurred_at', o.occurred_at,
                'hours_ongoing', ROUND(EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - o.occurred_at)) / 3600, 1),
                'cause', oc.name
            )
        )
    ), '[]'::json)
) as geojson
FROM outages o
JOIN districts d ON o.district_id = d.district_id
LEFT JOIN outage_causes oc ON o.cause_id = oc.cause_id
WHERE o.status NOT IN ('restored', 'closed');

COMMENT ON VIEW vw_outages_geojson IS 'GeoJSON export of active outages for mapping applications';

-- GeoJSON of cluster centers
CREATE OR REPLACE VIEW vw_clusters_geojson AS
SELECT json_build_object(
    'type', 'FeatureCollection',
    'analysis_type', 'kmeans',
    'period', '6 months',
    'generated_at', CURRENT_TIMESTAMP,
    'features', COALESCE(json_agg(
        json_build_object(
            'type', 'Feature',
            'geometry', center_geojson::json,
            'properties', json_build_object(
                'cluster_id', cluster_id,
                'outage_count', outage_count,
                'total_customers_affected', total_customers_affected,
                'avg_duration_minutes', avg_duration_minutes,
                'area_sq_km', area_sq_km
            )
        )
    ), '[]'::json)
) as geojson
FROM vw_outage_clusters_kmeans;

COMMENT ON VIEW vw_clusters_geojson IS 'GeoJSON export of outage cluster centroids';

-- ============================================================================
-- Temporal Geospatial Views
-- ============================================================================

-- Monthly outage density by district
CREATE OR REPLACE VIEW vw_monthly_outage_density AS
SELECT 
    DATE_TRUNC('month', o.occurred_at) as month,
    d.district_id,
    d.name as district_name,
    d.boundary,
    COUNT(*) as outage_count,
    SUM(o.customers_affected) as total_customers_affected,
    ROUND(AVG(o.duration_minutes)) as avg_duration,
    COUNT(*)::NUMERIC / (ST_Area(d.boundary::geography) / 1000000) as outages_per_sq_km
FROM outages o
JOIN districts d ON o.district_id = d.district_id
WHERE o.occurred_at >= DATE_TRUNC('month', CURRENT_DATE) - INTERVAL '12 months'
GROUP BY DATE_TRUNC('month', o.occurred_at), d.district_id, d.name, d.boundary
ORDER BY month DESC, outage_count DESC;

COMMENT ON VIEW vw_monthly_outage_density IS 'Monthly outage density per district for trend analysis';

-- Recent outage timeline with spatial data
CREATE OR REPLACE VIEW vw_recent_outage_timeline AS
SELECT 
    o.outage_id,
    o.location,
    ST_X(o.location::geometry) as longitude,
    ST_Y(o.location::geometry) as latitude,
    d.name as district_name,
    o.occurred_at,
    DATE(o.occurred_at AT TIME ZONE 'UTC') as outage_date,
    EXTRACT(HOUR FROM o.occurred_at) as hour_of_day,
    TO_CHAR(o.occurred_at, 'Day') as day_of_week,
    o.customers_affected,
    o.duration_minutes,
    o.severity,
    o.status,
    oc.name as cause_name,
    oc.category as cause_category
FROM outages o
JOIN districts d ON o.district_id = d.district_id
LEFT JOIN outage_causes oc ON o.cause_id = oc.cause_id
WHERE o.occurred_at >= CURRENT_DATE - INTERVAL '30 days'
ORDER BY o.occurred_at DESC;

COMMENT ON VIEW vw_recent_outage_timeline IS 'Recent outages with temporal patterns for time-series analysis';
