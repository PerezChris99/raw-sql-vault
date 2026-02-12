-- ============================================================================
-- Power Outage Pattern Analyzer - Clustering Functions
-- PostGIS functions for spatial clustering and hotspot detection
-- ============================================================================

-- ============================================================================
-- K-Means Clustering Functions
-- ============================================================================

-- Perform K-Means clustering on recent outages
CREATE OR REPLACE FUNCTION fn_cluster_outages_kmeans(
    p_num_clusters INTEGER DEFAULT 5,
    p_days_back INTEGER DEFAULT 180,
    p_min_outages INTEGER DEFAULT 3
)
RETURNS TABLE (
    cluster_id INTEGER,
    outage_count BIGINT,
    total_customers_affected BIGINT,
    avg_duration_minutes NUMERIC,
    cluster_center GEOMETRY,
    cluster_boundary GEOMETRY,
    area_sq_km NUMERIC,
    primary_cause TEXT,
    avg_severity_score NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    WITH clustered AS (
        SELECT 
            o.outage_id,
            o.location,
            o.customers_affected,
            o.duration_minutes,
            o.cause_id,
            o.severity,
            ST_ClusterKMeans(o.location::geometry, p_num_clusters) OVER () as kmeans_cluster
        FROM outages o
        WHERE o.occurred_at >= CURRENT_DATE - (p_days_back || ' days')::INTERVAL
          AND o.location IS NOT NULL
    ),
    cluster_stats AS (
        SELECT 
            c.kmeans_cluster,
            COUNT(*) as cnt,
            SUM(c.customers_affected) as total_customers,
            ROUND(AVG(c.duration_minutes), 1) as avg_duration,
            ST_Centroid(ST_Collect(c.location::geometry)) as center,
            ST_ConvexHull(ST_Collect(c.location::geometry)) as boundary,
            ROUND((ST_Area(ST_ConvexHull(ST_Collect(c.location::geometry))::geography) / 1000000)::NUMERIC, 2) as area,
            MODE() WITHIN GROUP (ORDER BY oc.name) as top_cause,
            ROUND(AVG(
                CASE c.severity 
                    WHEN 'critical' THEN 4 
                    WHEN 'major' THEN 3 
                    WHEN 'moderate' THEN 2 
                    ELSE 1 
                END
            ), 2) as severity_score
        FROM clustered c
        LEFT JOIN outage_causes oc ON c.cause_id = oc.cause_id
        GROUP BY c.kmeans_cluster
        HAVING COUNT(*) >= p_min_outages
    )
    SELECT 
        cs.kmeans_cluster,
        cs.cnt,
        cs.total_customers,
        cs.avg_duration,
        cs.center,
        cs.boundary,
        cs.area,
        cs.top_cause,
        cs.severity_score
    FROM cluster_stats cs
    ORDER BY cs.cnt DESC;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION fn_cluster_outages_kmeans IS 'K-Means clustering of outages with configurable cluster count and time window';

-- ============================================================================
-- DBSCAN Clustering Functions
-- ============================================================================

-- DBSCAN clustering for density-based hotspot detection
CREATE OR REPLACE FUNCTION fn_cluster_outages_dbscan(
    p_epsilon_meters NUMERIC DEFAULT 500,
    p_min_points INTEGER DEFAULT 3,
    p_days_back INTEGER DEFAULT 90
)
RETURNS TABLE (
    cluster_id INTEGER,
    point_count BIGINT,
    is_noise BOOLEAN,
    avg_customers_affected NUMERIC,
    total_duration_minutes BIGINT,
    cluster_centroid GEOMETRY,
    cluster_extent GEOMETRY,
    dominant_cause_category TEXT
) AS $$
BEGIN
    RETURN QUERY
    WITH clustered AS (
        SELECT 
            o.outage_id,
            o.location,
            o.customers_affected,
            o.duration_minutes,
            oc.category as cause_category,
            ST_ClusterDBSCAN(o.location::geometry, eps := p_epsilon_meters, minpoints := p_min_points) OVER () as dbscan_cluster
        FROM outages o
        LEFT JOIN outage_causes oc ON o.cause_id = oc.cause_id
        WHERE o.occurred_at >= CURRENT_DATE - (p_days_back || ' days')::INTERVAL
          AND o.location IS NOT NULL
    )
    SELECT 
        c.dbscan_cluster,
        COUNT(*)::BIGINT,
        c.dbscan_cluster IS NULL,
        ROUND(AVG(c.customers_affected), 0),
        SUM(c.duration_minutes)::BIGINT,
        ST_Centroid(ST_Collect(c.location::geometry)),
        ST_Envelope(ST_Collect(c.location::geometry)),
        MODE() WITHIN GROUP (ORDER BY c.cause_category)
    FROM clustered c
    GROUP BY c.dbscan_cluster
    ORDER BY COUNT(*) DESC;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION fn_cluster_outages_dbscan IS 'DBSCAN density clustering - identifies dense failure zones and noise points';

-- ============================================================================
-- Hotspot Detection Functions
-- ============================================================================

-- Identify the top N hotspot areas based on outage density
CREATE OR REPLACE FUNCTION fn_identify_hotspots(
    p_top_n INTEGER DEFAULT 10,
    p_grid_size_meters INTEGER DEFAULT 1000,
    p_days_back INTEGER DEFAULT 90
)
RETURNS TABLE (
    hotspot_rank INTEGER,
    grid_cell GEOMETRY,
    grid_center GEOMETRY,
    outage_count BIGINT,
    total_customers_affected BIGINT,
    avg_duration_minutes NUMERIC,
    density_per_sq_km NUMERIC,
    risk_score NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    WITH grid AS (
        -- Create grid cells covering the outage area
        SELECT 
            ST_SnapToGrid(o.location::geometry, p_grid_size_meters / 111000.0) as cell_origin
        FROM outages o
        WHERE o.occurred_at >= CURRENT_DATE - (p_days_back || ' days')::INTERVAL
    ),
    cell_stats AS (
        SELECT 
            g.cell_origin,
            ST_Buffer(g.cell_origin, p_grid_size_meters / 111000.0 / 2) as cell_geom,
            COUNT(DISTINCT o.outage_id) as cnt,
            COALESCE(SUM(o.customers_affected), 0) as total_affected,
            ROUND(AVG(o.duration_minutes), 1) as avg_dur
        FROM grid g
        JOIN outages o ON ST_DWithin(
            g.cell_origin::geography, 
            o.location, 
            p_grid_size_meters / 2
        )
        WHERE o.occurred_at >= CURRENT_DATE - (p_days_back || ' days')::INTERVAL
        GROUP BY g.cell_origin
        HAVING COUNT(DISTINCT o.outage_id) >= 2
    )
    SELECT 
        ROW_NUMBER() OVER (ORDER BY cs.cnt DESC)::INTEGER,
        cs.cell_geom,
        cs.cell_origin,
        cs.cnt,
        cs.total_affected,
        cs.avg_dur,
        ROUND((cs.cnt * 1000000.0 / ST_Area(cs.cell_geom::geography))::NUMERIC, 2),
        ROUND((cs.cnt * 2 + cs.total_affected / 100.0 + cs.avg_dur / 30.0)::NUMERIC, 2)
    FROM cell_stats cs
    ORDER BY cs.cnt DESC
    LIMIT p_top_n;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION fn_identify_hotspots IS 'Grid-based hotspot analysis with configurable resolution';

-- ============================================================================
-- Monthly Cluster Analysis (for trend tracking)
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_monthly_cluster_analysis(
    p_year INTEGER DEFAULT EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER,
    p_num_clusters INTEGER DEFAULT 5
)
RETURNS TABLE (
    analysis_month DATE,
    cluster_id INTEGER,
    outage_count BIGINT,
    customers_affected BIGINT,
    cluster_center GEOMETRY,
    area_sq_km NUMERIC,
    month_over_month_change NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    WITH monthly_clusters AS (
        SELECT 
            DATE_TRUNC('month', o.occurred_at)::DATE as month,
            ST_ClusterKMeans(o.location::geometry, p_num_clusters) OVER (
                PARTITION BY DATE_TRUNC('month', o.occurred_at)
            ) as cluster,
            o.outage_id,
            o.customers_affected,
            o.location
        FROM outages o
        WHERE EXTRACT(YEAR FROM o.occurred_at) = p_year
          AND o.location IS NOT NULL
    ),
    cluster_stats AS (
        SELECT 
            mc.month,
            mc.cluster,
            COUNT(*)::BIGINT as cnt,
            SUM(mc.customers_affected)::BIGINT as affected,
            ST_Centroid(ST_Collect(mc.location::geometry)) as center,
            ROUND((ST_Area(ST_ConvexHull(ST_Collect(mc.location::geometry))::geography) / 1000000)::NUMERIC, 2) as area
        FROM monthly_clusters mc
        GROUP BY mc.month, mc.cluster
    ),
    with_lag AS (
        SELECT 
            cs.*,
            LAG(cs.cnt) OVER (PARTITION BY cs.cluster ORDER BY cs.month) as prev_count
        FROM cluster_stats cs
    )
    SELECT 
        wl.month,
        wl.cluster,
        wl.cnt,
        wl.affected,
        wl.center,
        wl.area,
        CASE 
            WHEN wl.prev_count IS NOT NULL AND wl.prev_count > 0 
            THEN ROUND(((wl.cnt - wl.prev_count)::NUMERIC / wl.prev_count * 100), 1)
            ELSE NULL
        END
    FROM with_lag wl
    ORDER BY wl.month DESC, wl.cnt DESC;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION fn_monthly_cluster_analysis IS 'Track cluster evolution month over month within a year';

-- ============================================================================
-- Cluster Persistence Analysis
-- ============================================================================

-- Find clusters that persist across multiple time periods (chronic problem areas)
CREATE OR REPLACE FUNCTION fn_persistent_clusters(
    p_periods INTEGER DEFAULT 3,  -- Number of periods to check
    p_period_days INTEGER DEFAULT 30,  -- Days per period
    p_proximity_meters INTEGER DEFAULT 500  -- Distance to consider same cluster
)
RETURNS TABLE (
    location_center GEOMETRY,
    periods_active INTEGER,
    total_outages BIGINT,
    total_customers_affected BIGINT,
    avg_outages_per_period NUMERIC,
    persistence_score NUMERIC,
    primary_cause TEXT
) AS $$
BEGIN
    RETURN QUERY
    WITH period_clusters AS (
        SELECT 
            floor(EXTRACT(EPOCH FROM (CURRENT_DATE - o.occurred_at::date)) / (p_period_days * 86400))::INTEGER as period_num,
            ST_ClusterDBSCAN(o.location::geometry, eps := p_proximity_meters, minpoints := 2) OVER (
                PARTITION BY floor(EXTRACT(EPOCH FROM (CURRENT_DATE - o.occurred_at::date)) / (p_period_days * 86400))
            ) as cluster_in_period,
            o.outage_id,
            o.customers_affected,
            o.location,
            oc.name as cause_name
        FROM outages o
        LEFT JOIN outage_causes oc ON o.cause_id = oc.cause_id
        WHERE o.occurred_at >= CURRENT_DATE - (p_periods * p_period_days || ' days')::INTERVAL
          AND o.location IS NOT NULL
    ),
    cluster_centers AS (
        SELECT 
            pc.period_num,
            pc.cluster_in_period,
            ST_Centroid(ST_Collect(pc.location::geometry)) as center,
            COUNT(*) as outage_cnt,
            SUM(pc.customers_affected) as affected,
            MODE() WITHIN GROUP (ORDER BY pc.cause_name) as top_cause
        FROM period_clusters pc
        WHERE pc.cluster_in_period IS NOT NULL
        GROUP BY pc.period_num, pc.cluster_in_period
    ),
    matched_clusters AS (
        SELECT 
            c1.center as base_center,
            COUNT(DISTINCT c2.period_num) as periods_found,
            SUM(c2.outage_cnt)::BIGINT as total_outs,
            SUM(c2.affected)::BIGINT as total_aff,
            MODE() WITHIN GROUP (ORDER BY c2.top_cause) as common_cause
        FROM cluster_centers c1
        JOIN cluster_centers c2 ON ST_DWithin(c1.center::geography, c2.center::geography, p_proximity_meters)
        GROUP BY c1.center
        HAVING COUNT(DISTINCT c2.period_num) >= 2
    )
    SELECT DISTINCT ON (ST_SnapToGrid(mc.base_center, 0.001))
        mc.base_center,
        mc.periods_found,
        mc.total_outs,
        mc.total_aff,
        ROUND(mc.total_outs::NUMERIC / mc.periods_found, 1),
        ROUND((mc.periods_found * 10 + mc.total_outs * 0.5 + mc.total_aff * 0.001)::NUMERIC, 2),
        mc.common_cause
    FROM matched_clusters mc
    WHERE mc.periods_found >= 2
    ORDER BY ST_SnapToGrid(mc.base_center, 0.001), mc.periods_found DESC, mc.total_outs DESC;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION fn_persistent_clusters IS 'Identify chronic problem areas that persist across time periods';

-- ============================================================================
-- Store Cluster Results for Historical Tracking
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_store_cluster_analysis(
    p_analysis_type VARCHAR(30) DEFAULT 'kmeans',
    p_num_clusters INTEGER DEFAULT 5
)
RETURNS INTEGER AS $$
DECLARE
    v_count INTEGER := 0;
    v_today DATE := CURRENT_DATE;
BEGIN
    -- Delete existing analysis for today
    DELETE FROM outage_clusters 
    WHERE analysis_date = v_today AND analysis_type = p_analysis_type;
    
    IF p_analysis_type = 'kmeans' THEN
        INSERT INTO outage_clusters (
            analysis_date, analysis_type, cluster_number, centroid, boundary,
            outage_count, avg_duration_minutes, total_customers_affected, risk_score
        )
        SELECT 
            v_today,
            'kmeans',
            cluster_id,
            cluster_center::geography,
            cluster_boundary,
            outage_count::INTEGER,
            avg_duration_minutes,
            total_customers_affected::INTEGER,
            avg_severity_score * outage_count / 10
        FROM fn_cluster_outages_kmeans(p_num_clusters, 180, 3);
        
        GET DIAGNOSTICS v_count = ROW_COUNT;
        
    ELSIF p_analysis_type = 'dbscan' THEN
        INSERT INTO outage_clusters (
            analysis_date, analysis_type, cluster_number, centroid, boundary,
            outage_count, avg_duration_minutes, total_customers_affected
        )
        SELECT 
            v_today,
            'dbscan',
            COALESCE(cluster_id, -1),
            cluster_centroid::geography,
            cluster_extent,
            point_count::INTEGER,
            total_duration_minutes::NUMERIC / NULLIF(point_count, 0),
            avg_customers_affected::INTEGER * point_count::INTEGER
        FROM fn_cluster_outages_dbscan(500, 3, 90)
        WHERE NOT is_noise;
        
        GET DIAGNOSTICS v_count = ROW_COUNT;
    END IF;
    
    RETURN v_count;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION fn_store_cluster_analysis IS 'Persist cluster analysis results for historical tracking';
