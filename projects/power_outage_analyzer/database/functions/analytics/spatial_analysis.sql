-- ============================================================================
-- Power Outage Pattern Analyzer - Spatial Analysis Functions
-- PostGIS functions for proximity analysis, buffer zones, and risk assessment
-- ============================================================================

-- ============================================================================
-- Proximity Analysis Functions
-- ============================================================================

-- Find all outages within a specified radius of a point
CREATE OR REPLACE FUNCTION fn_outages_near_point(
    p_longitude NUMERIC,
    p_latitude NUMERIC,
    p_radius_meters INTEGER DEFAULT 1000,
    p_days_back INTEGER DEFAULT 90
)
RETURNS TABLE (
    outage_id UUID,
    distance_meters NUMERIC,
    occurred_at TIMESTAMPTZ,
    customers_affected INTEGER,
    duration_minutes INTEGER,
    cause_name TEXT,
    severity VARCHAR,
    status VARCHAR
) AS $$
DECLARE
    v_point GEOGRAPHY;
BEGIN
    v_point := ST_GeogFromText('POINT(' || p_longitude || ' ' || p_latitude || ')');
    
    RETURN QUERY
    SELECT 
        o.outage_id,
        ROUND(ST_Distance(o.location, v_point)::NUMERIC, 1),
        o.occurred_at,
        o.customers_affected,
        o.duration_minutes,
        oc.name,
        o.severity,
        o.status
    FROM outages o
    LEFT JOIN outage_causes oc ON o.cause_id = oc.cause_id
    WHERE ST_DWithin(o.location, v_point, p_radius_meters)
      AND o.occurred_at >= CURRENT_DATE - (p_days_back || ' days')::INTERVAL
    ORDER BY ST_Distance(o.location, v_point);
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION fn_outages_near_point IS 'Find outages within radius of a specific coordinate';

-- Find nearest N outages to a location
CREATE OR REPLACE FUNCTION fn_nearest_outages(
    p_longitude NUMERIC,
    p_latitude NUMERIC,
    p_limit INTEGER DEFAULT 10,
    p_days_back INTEGER DEFAULT 180
)
RETURNS TABLE (
    outage_id UUID,
    distance_meters NUMERIC,
    direction TEXT,
    occurred_at TIMESTAMPTZ,
    customers_affected INTEGER,
    district_name TEXT
) AS $$
DECLARE
    v_point GEOGRAPHY;
BEGIN
    v_point := ST_GeogFromText('POINT(' || p_longitude || ' ' || p_latitude || ')');
    
    RETURN QUERY
    SELECT 
        o.outage_id,
        ROUND(ST_Distance(o.location, v_point)::NUMERIC, 1),
        -- Calculate cardinal direction
        CASE 
            WHEN ST_Azimuth(v_point::geometry, o.location::geometry) * 180 / PI() BETWEEN 337.5 AND 360 
              OR ST_Azimuth(v_point::geometry, o.location::geometry) * 180 / PI() BETWEEN 0 AND 22.5 THEN 'N'
            WHEN ST_Azimuth(v_point::geometry, o.location::geometry) * 180 / PI() BETWEEN 22.5 AND 67.5 THEN 'NE'
            WHEN ST_Azimuth(v_point::geometry, o.location::geometry) * 180 / PI() BETWEEN 67.5 AND 112.5 THEN 'E'
            WHEN ST_Azimuth(v_point::geometry, o.location::geometry) * 180 / PI() BETWEEN 112.5 AND 157.5 THEN 'SE'
            WHEN ST_Azimuth(v_point::geometry, o.location::geometry) * 180 / PI() BETWEEN 157.5 AND 202.5 THEN 'S'
            WHEN ST_Azimuth(v_point::geometry, o.location::geometry) * 180 / PI() BETWEEN 202.5 AND 247.5 THEN 'SW'
            WHEN ST_Azimuth(v_point::geometry, o.location::geometry) * 180 / PI() BETWEEN 247.5 AND 292.5 THEN 'W'
            ELSE 'NW'
        END,
        o.occurred_at,
        o.customers_affected,
        d.name
    FROM outages o
    JOIN districts d ON o.district_id = d.district_id
    WHERE o.occurred_at >= CURRENT_DATE - (p_days_back || ' days')::INTERVAL
    ORDER BY o.location <-> v_point
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION fn_nearest_outages IS 'Find N nearest outages to a point using KNN index';

-- ============================================================================
-- Buffer Zone Analysis
-- ============================================================================

-- Create risk buffer zones around high-risk infrastructure
CREATE OR REPLACE FUNCTION fn_transformer_risk_zones(
    p_min_outages INTEGER DEFAULT 3,
    p_radius_meters INTEGER DEFAULT 500,
    p_days_back INTEGER DEFAULT 365
)
RETURNS TABLE (
    transformer_id INTEGER,
    transformer_code VARCHAR,
    age_years INTEGER,
    nearby_outages BIGINT,
    risk_zone_inner GEOMETRY,
    risk_zone_outer GEOMETRY,
    risk_level TEXT,
    recommended_inspection_date DATE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        t.transformer_id,
        t.code,
        t.age_years,
        COUNT(o.outage_id),
        ST_Buffer(t.location::geometry, p_radius_meters / 111000.0 / 2),  -- Inner 250m
        ST_Buffer(t.location::geometry, p_radius_meters / 111000.0),      -- Outer 500m
        CASE 
            WHEN COUNT(o.outage_id) >= 10 OR COALESCE(t.age_years, 0) >= 25 THEN 'critical'
            WHEN COUNT(o.outage_id) >= 5 OR COALESCE(t.age_years, 0) >= 20 THEN 'high'
            WHEN COUNT(o.outage_id) >= 3 OR COALESCE(t.age_years, 0) >= 15 THEN 'medium'
            ELSE 'low'
        END,
        CASE 
            WHEN COUNT(o.outage_id) >= 10 THEN CURRENT_DATE + INTERVAL '7 days'
            WHEN COUNT(o.outage_id) >= 5 THEN CURRENT_DATE + INTERVAL '30 days'
            WHEN COUNT(o.outage_id) >= 3 THEN CURRENT_DATE + INTERVAL '90 days'
            ELSE CURRENT_DATE + INTERVAL '365 days'
        END::DATE
    FROM transformers t
    LEFT JOIN outages o ON ST_DWithin(t.location, o.location, p_radius_meters)
        AND o.occurred_at >= CURRENT_DATE - (p_days_back || ' days')::INTERVAL
    WHERE t.status = 'operational'
    GROUP BY t.transformer_id, t.code, t.age_years, t.location
    HAVING COUNT(o.outage_id) >= p_min_outages
    ORDER BY COUNT(o.outage_id) DESC, t.age_years DESC NULLS LAST;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION fn_transformer_risk_zones IS 'Generate risk buffer zones around transformers with nearby outages';

-- ============================================================================
-- Infrastructure Risk Assessment
-- ============================================================================

-- Comprehensive risk scoring for all infrastructure
CREATE OR REPLACE FUNCTION fn_calculate_infrastructure_risk()
RETURNS TABLE (
    entity_type VARCHAR,
    entity_id INTEGER,
    entity_name VARCHAR,
    location GEOGRAPHY,
    outages_90d BIGINT,
    outages_1y BIGINT,
    age_factor NUMERIC,
    proximity_factor NUMERIC,
    overall_risk_score NUMERIC,
    risk_category TEXT
) AS $$
BEGIN
    RETURN QUERY
    WITH transformer_risk AS (
        SELECT 
            'transformer'::VARCHAR as etype,
            t.transformer_id as eid,
            t.name as ename,
            t.location as loc,
            COUNT(o.outage_id) FILTER (WHERE o.occurred_at >= CURRENT_DATE - INTERVAL '90 days') as out_90,
            COUNT(o.outage_id) FILTER (WHERE o.occurred_at >= CURRENT_DATE - INTERVAL '1 year') as out_1y,
            COALESCE(t.age_years, 0) * 0.1 as age_f,
            COUNT(o.outage_id) * 0.5 as prox_f,
            (COALESCE(t.age_years, 0) * 0.1 + COUNT(o.outage_id) * 2 + 
             COUNT(o.outage_id) FILTER (WHERE o.occurred_at >= CURRENT_DATE - INTERVAL '90 days') * 3) as risk
        FROM transformers t
        LEFT JOIN outages o ON ST_DWithin(t.location, o.location, 500)
            AND o.occurred_at >= CURRENT_DATE - INTERVAL '1 year'
        WHERE t.status = 'operational'
        GROUP BY t.transformer_id, t.name, t.location, t.age_years
    ),
    substation_risk AS (
        SELECT 
            'substation'::VARCHAR as etype,
            s.substation_id as eid,
            s.name as ename,
            s.location as loc,
            COUNT(o.outage_id) FILTER (WHERE o.occurred_at >= CURRENT_DATE - INTERVAL '90 days') as out_90,
            COUNT(o.outage_id) FILTER (WHERE o.occurred_at >= CURRENT_DATE - INTERVAL '1 year') as out_1y,
            (2024 - COALESCE(EXTRACT(YEAR FROM s.commissioned_date)::INTEGER, 2000)) * 0.05 as age_f,
            COUNT(o.outage_id) * 0.3 as prox_f,
            ((2024 - COALESCE(EXTRACT(YEAR FROM s.commissioned_date)::INTEGER, 2000)) * 0.05 + 
             COUNT(o.outage_id) * 1.5 + 
             COUNT(o.outage_id) FILTER (WHERE o.occurred_at >= CURRENT_DATE - INTERVAL '90 days') * 2) as risk
        FROM substations s
        LEFT JOIN outages o ON ST_DWithin(s.location, o.location, 2000)
            AND o.occurred_at >= CURRENT_DATE - INTERVAL '1 year'
        WHERE s.status = 'operational'
        GROUP BY s.substation_id, s.name, s.location, s.commissioned_date
    ),
    combined AS (
        SELECT * FROM transformer_risk
        UNION ALL
        SELECT * FROM substation_risk
    )
    SELECT 
        c.etype,
        c.eid,
        c.ename,
        c.loc,
        c.out_90,
        c.out_1y,
        ROUND(c.age_f, 2),
        ROUND(c.prox_f, 2),
        ROUND(c.risk, 2),
        CASE 
            WHEN c.risk >= 20 THEN 'critical'
            WHEN c.risk >= 10 THEN 'high'
            WHEN c.risk >= 5 THEN 'medium'
            ELSE 'low'
        END
    FROM combined c
    ORDER BY c.risk DESC;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION fn_calculate_infrastructure_risk IS 'Calculate risk scores for all infrastructure components';

-- Store risk scores for tracking over time
CREATE OR REPLACE FUNCTION fn_store_infrastructure_risk_scores()
RETURNS INTEGER AS $$
DECLARE
    v_count INTEGER;
BEGIN
    INSERT INTO infrastructure_risk_scores (
        assessment_date, entity_type, entity_id, location,
        nearby_outages_90d, nearby_outages_1y, failure_probability,
        risk_score, risk_level
    )
    SELECT 
        CURRENT_DATE,
        entity_type,
        entity_id,
        location,
        outages_90d::INTEGER,
        outages_1y::INTEGER,
        LEAST(overall_risk_score / 100, 1.0),
        overall_risk_score,
        risk_category
    FROM fn_calculate_infrastructure_risk();
    
    GET DIAGNOSTICS v_count = ROW_COUNT;
    RETURN v_count;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION fn_store_infrastructure_risk_scores IS 'Persist daily infrastructure risk assessment';

-- ============================================================================
-- Service Area Analysis
-- ============================================================================

-- Calculate service coverage area for a substation
CREATE OR REPLACE FUNCTION fn_substation_service_area(
    p_substation_id INTEGER,
    p_method VARCHAR DEFAULT 'voronoi'  -- 'voronoi' or 'buffer'
)
RETURNS TABLE (
    substation_id INTEGER,
    substation_name VARCHAR,
    service_area GEOMETRY,
    area_sq_km NUMERIC,
    transformer_count BIGINT,
    estimated_customers INTEGER
) AS $$
BEGIN
    IF p_method = 'buffer' THEN
        -- Simple buffer-based service area
        RETURN QUERY
        SELECT 
            s.substation_id,
            s.name,
            ST_Buffer(s.location::geometry, 0.05),  -- ~5km radius
            ROUND((ST_Area(ST_Buffer(s.location::geometry, 0.05)::geography) / 1000000)::NUMERIC, 2),
            COUNT(t.transformer_id),
            COALESCE(SUM(t.customers_served), 0)::INTEGER
        FROM substations s
        LEFT JOIN transformers t ON s.district_id = t.district_id
        WHERE s.substation_id = p_substation_id
        GROUP BY s.substation_id, s.name, s.location;
    ELSE
        -- Voronoi-based service area (requires multiple substations)
        RETURN QUERY
        WITH voronoi AS (
            SELECT 
                (ST_Dump(ST_VoronoiPolygons(ST_Collect(location::geometry)))).geom as cell
            FROM substations
            WHERE status = 'operational'
        ),
        matched AS (
            SELECT 
                s.substation_id,
                s.name,
                v.cell as service_area
            FROM substations s
            JOIN voronoi v ON ST_Contains(v.cell, s.location::geometry)
            WHERE s.substation_id = p_substation_id
        )
        SELECT 
            m.substation_id,
            m.name,
            m.service_area,
            ROUND((ST_Area(m.service_area::geography) / 1000000)::NUMERIC, 2),
            COUNT(t.transformer_id),
            COALESCE(SUM(t.customers_served), 0)::INTEGER
        FROM matched m
        LEFT JOIN transformers t ON ST_Contains(m.service_area, t.location::geometry)
        GROUP BY m.substation_id, m.name, m.service_area;
    END IF;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION fn_substation_service_area IS 'Calculate theoretical service area for a substation';

-- ============================================================================
-- Crew Dispatch Optimization
-- ============================================================================

-- Find optimal crew for a new outage based on location and specialization
CREATE OR REPLACE FUNCTION fn_find_optimal_crew(
    p_outage_longitude NUMERIC,
    p_outage_latitude NUMERIC,
    p_required_specialization VARCHAR DEFAULT NULL,
    p_limit INTEGER DEFAULT 5
)
RETURNS TABLE (
    crew_id INTEGER,
    crew_name VARCHAR,
    specialization VARCHAR,
    current_status VARCHAR,
    distance_meters NUMERIC,
    estimated_travel_minutes INTEGER,
    suitability_score NUMERIC
) AS $$
DECLARE
    v_outage_location GEOGRAPHY;
BEGIN
    v_outage_location := ST_GeogFromText('POINT(' || p_outage_longitude || ' ' || p_outage_latitude || ')');
    
    RETURN QUERY
    SELECT 
        c.crew_id,
        c.name,
        c.specialization,
        c.status,
        ROUND(ST_Distance(c.current_location, v_outage_location)::NUMERIC, 0),
        -- Estimate 40 km/h average speed
        ROUND((ST_Distance(c.current_location, v_outage_location) / 1000 / 40 * 60)::INTEGER),
        -- Suitability score (lower is better)
        ROUND((
            ST_Distance(c.current_location, v_outage_location) / 1000 +  -- Distance in km
            CASE c.status WHEN 'available' THEN 0 WHEN 'standby' THEN 10 ELSE 100 END +  -- Status penalty
            CASE WHEN p_required_specialization IS NULL THEN 0
                 WHEN c.specialization = p_required_specialization THEN -5  -- Bonus for matching specialization
                 WHEN c.specialization = 'emergency' THEN -2  -- Emergency crews can handle anything
                 ELSE 5
            END
        )::NUMERIC, 2)
    FROM crews c
    WHERE c.current_location IS NOT NULL
      AND c.status IN ('available', 'standby')
      AND (p_required_specialization IS NULL OR c.specialization IN (p_required_specialization, 'emergency', 'general'))
    ORDER BY 
        ST_Distance(c.current_location, v_outage_location),
        CASE c.status WHEN 'available' THEN 0 ELSE 1 END
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION fn_find_optimal_crew IS 'Find best available crew for outage response based on location and skills';

-- ============================================================================
-- GeoJSON Export Functions
-- ============================================================================

-- Export active outages as GeoJSON
CREATE OR REPLACE FUNCTION fn_export_outages_geojson(
    p_status VARCHAR[] DEFAULT ARRAY['active', 'crew_assigned', 'in_repair'],
    p_limit INTEGER DEFAULT 100
)
RETURNS JSON AS $$
BEGIN
    RETURN (
        SELECT json_build_object(
            'type', 'FeatureCollection',
            'generated_at', CURRENT_TIMESTAMP,
            'count', COUNT(*),
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
                        'cause', oc.name,
                        'cause_category', oc.category
                    )
                )
            ), '[]'::json)
        )
        FROM outages o
        JOIN districts d ON o.district_id = d.district_id
        LEFT JOIN outage_causes oc ON o.cause_id = oc.cause_id
        WHERE o.status = ANY(p_status)
        LIMIT p_limit
    );
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION fn_export_outages_geojson IS 'Export outages as GeoJSON FeatureCollection for mapping';

-- Export clusters as GeoJSON
CREATE OR REPLACE FUNCTION fn_export_clusters_geojson(
    p_analysis_type VARCHAR DEFAULT 'kmeans'
)
RETURNS JSON AS $$
BEGIN
    RETURN (
        SELECT json_build_object(
            'type', 'FeatureCollection',
            'analysis_type', p_analysis_type,
            'generated_at', CURRENT_TIMESTAMP,
            'features', COALESCE(json_agg(
                json_build_object(
                    'type', 'Feature',
                    'geometry', ST_AsGeoJSON(oc.centroid::geometry)::json,
                    'properties', json_build_object(
                        'cluster_id', oc.cluster_id,
                        'cluster_number', oc.cluster_number,
                        'outage_count', oc.outage_count,
                        'total_customers', oc.total_customers_affected,
                        'avg_duration', oc.avg_duration_minutes,
                        'risk_score', oc.risk_score
                    )
                )
            ), '[]'::json)
        )
        FROM outage_clusters oc
        WHERE oc.analysis_type = p_analysis_type
          AND oc.analysis_date = (SELECT MAX(analysis_date) FROM outage_clusters WHERE analysis_type = p_analysis_type)
    );
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION fn_export_clusters_geojson IS 'Export latest cluster analysis as GeoJSON';
