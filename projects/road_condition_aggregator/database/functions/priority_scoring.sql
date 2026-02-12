-- ============================================================================
-- Road Condition Aggregator - Priority Scoring Functions
-- PostgreSQL 14+ with PostGIS 3.x
-- Priority calculation and work order generation
-- ============================================================================

-- ============================================================================
-- Priority Score Calculation Function
-- Implements the formula: severity × density × road_importance
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_calculate_priority_score(
    p_avg_severity NUMERIC,
    p_report_count INTEGER,
    p_road_priority_weight NUMERIC DEFAULT 1.0,
    p_age_days INTEGER DEFAULT 0
)
RETURNS NUMERIC
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
    v_severity_component NUMERIC;
    v_density_component NUMERIC;
    v_road_component NUMERIC;
    v_age_bonus NUMERIC;
    v_total_score NUMERIC;
BEGIN
    -- Severity component: 0-40 points
    -- Normalizes severity (1-10) to 0-40 range
    v_severity_component := (p_avg_severity / 10.0) * 40;
    
    -- Density component: 0-30 points
    -- Uses log scale to prevent extreme values from dominating
    -- LOG(count + 1) * 15, capped at 30
    v_density_component := LEAST(LOG(p_report_count + 1) * 15, 30);
    
    -- Road importance component: 0-30 points
    -- Road priority weight ranges from 0.3 (Private) to 3.0 (Interstate)
    v_road_component := LEAST(p_road_priority_weight * 10, 30);
    
    -- Age bonus: up to 10 extra points for older unresolved clusters
    -- 0.5 points per day, capped at 10
    v_age_bonus := LEAST(p_age_days * 0.5, 10);
    
    -- Total score (0-110 theoretical max, typically 0-100)
    v_total_score := v_severity_component + v_density_component + v_road_component + v_age_bonus;
    
    RETURN ROUND(v_total_score, 2);
END;
$$;

COMMENT ON FUNCTION fn_calculate_priority_score IS 'Calculate priority score using severity, density, and road importance';

-- ============================================================================
-- Priority Queue Function
-- Returns prioritized list of clusters ready for repair
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_get_priority_queue(
    p_eps FLOAT DEFAULT 0.0005,
    p_min_points INTEGER DEFAULT 3,
    p_days_back INTEGER DEFAULT 30,
    p_limit INTEGER DEFAULT 50
)
RETURNS TABLE (
    priority_rank BIGINT,
    cluster_id INTEGER,
    priority_score NUMERIC,
    report_count BIGINT,
    avg_severity NUMERIC,
    max_severity INTEGER,
    work_center GEOGRAPHY,
    work_center_geojson TEXT,
    affected_roads TEXT[],
    estimated_cost NUMERIC,
    oldest_report TIMESTAMPTZ,
    days_pending INTEGER
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    WITH cluster_data AS (
        SELECT 
            cs.cluster_id,
            cs.report_count,
            cs.avg_severity,
            cs.max_severity,
            cs.cluster_center,
            cs.oldest_report,
            cs.damage_types,
            -- Find affected roads
            (SELECT ARRAY_AGG(DISTINCT rs.road_name)
             FROM fn_cluster_reports(p_eps, p_min_points, p_days_back) cr
             JOIN road_segments rs ON ST_DWithin(rs.geom::geography, cr.location, 20)
             WHERE cr.cluster_id = cs.cluster_id) as affected_roads,
            -- Get max road priority for cluster
            COALESCE((
                SELECT MAX(rc.priority_weight)
                FROM fn_cluster_reports(p_eps, p_min_points, p_days_back) cr
                JOIN road_segments rs ON ST_DWithin(rs.geom::geography, cr.location, 20)
                JOIN road_classifications rc ON rs.road_class_id = rc.class_id
                WHERE cr.cluster_id = cs.cluster_id
            ), 1.0) as road_priority,
            -- Estimate repair cost
            (SELECT SUM(dt.estimated_repair_cost)
             FROM fn_cluster_reports(p_eps, p_min_points, p_days_back) cr
             JOIN damage_types dt ON cr.damage_type_id = dt.damage_id
             WHERE cr.cluster_id = cs.cluster_id) as estimated_cost
        FROM fn_get_cluster_stats(p_eps, p_min_points, p_days_back) cs
    )
    SELECT 
        ROW_NUMBER() OVER (ORDER BY 
            fn_calculate_priority_score(
                cd.avg_severity, 
                cd.report_count::INTEGER, 
                cd.road_priority,
                EXTRACT(DAY FROM CURRENT_TIMESTAMP - cd.oldest_report)::INTEGER
            ) DESC
        ) as priority_rank,
        cd.cluster_id,
        fn_calculate_priority_score(
            cd.avg_severity, 
            cd.report_count::INTEGER, 
            cd.road_priority,
            EXTRACT(DAY FROM CURRENT_TIMESTAMP - cd.oldest_report)::INTEGER
        ) as priority_score,
        cd.report_count,
        cd.avg_severity,
        cd.max_severity,
        cd.cluster_center as work_center,
        ST_AsGeoJSON(cd.cluster_center::geometry) as work_center_geojson,
        cd.affected_roads,
        cd.estimated_cost,
        cd.oldest_report,
        EXTRACT(DAY FROM CURRENT_TIMESTAMP - cd.oldest_report)::INTEGER as days_pending
    FROM cluster_data cd
    ORDER BY priority_score DESC
    LIMIT p_limit;
END;
$$;

COMMENT ON FUNCTION fn_get_priority_queue IS 'Get prioritized queue of clusters for repair scheduling';

-- ============================================================================
-- Generate Work Orders Procedure
-- Creates work orders from top priority clusters
-- ============================================================================

CREATE OR REPLACE PROCEDURE sp_generate_work_orders(
    p_top_n INTEGER DEFAULT 10,
    p_eps FLOAT DEFAULT 0.0005,
    p_min_points INTEGER DEFAULT 3
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_cluster RECORD;
    v_crew_id UUID;
    v_work_order_count INTEGER := 0;
BEGIN
    -- Process top N priority clusters
    FOR v_cluster IN 
        SELECT * FROM fn_get_priority_queue(p_eps, p_min_points, 30, p_top_n)
    LOOP
        -- Find available crew for this cluster
        SELECT c.crew_id INTO v_crew_id
        FROM crews c
        WHERE c.status = 'available'
          AND c.crew_type IN (
              CASE 
                  WHEN v_cluster.avg_severity >= 8 THEN 'full_repair'
                  WHEN v_cluster.avg_severity >= 5 THEN 'pothole_patch'
                  ELSE 'maintenance'
              END,
              'full_repair'  -- Full repair can handle any job
          )
        ORDER BY ST_Distance(c.current_location, v_cluster.work_center)
        LIMIT 1;
        
        -- Create work order
        INSERT INTO repair_work_orders (
            work_center,
            work_area,
            priority_score,
            priority_rank,
            estimated_cost,
            status
        )
        SELECT 
            v_cluster.work_center,
            ST_ConvexHull(ST_Collect(cr.location::geometry)) as work_area,
            v_cluster.priority_score,
            v_cluster.priority_rank::INTEGER,
            v_cluster.estimated_cost,
            CASE WHEN v_crew_id IS NOT NULL THEN 'assigned' ELSE 'pending' END
        FROM fn_cluster_reports(p_eps, p_min_points) cr
        WHERE cr.cluster_id = v_cluster.cluster_id
        GROUP BY v_cluster.work_center, v_cluster.priority_score, 
                 v_cluster.priority_rank, v_cluster.estimated_cost, v_crew_id;
        
        v_work_order_count := v_work_order_count + 1;
        
        -- Update crew status if assigned
        IF v_crew_id IS NOT NULL THEN
            UPDATE crews 
            SET status = 'assigned', updated_at = CURRENT_TIMESTAMP
            WHERE crew_id = v_crew_id;
        END IF;
    END LOOP;
    
    RAISE NOTICE 'Generated % work orders', v_work_order_count;
END;
$$;

COMMENT ON PROCEDURE sp_generate_work_orders IS 'Generate work orders from top priority clusters';

-- ============================================================================
-- District Priority Summary Function
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_district_priority_summary()
RETURNS TABLE (
    district_id UUID,
    district_name TEXT,
    total_clusters INTEGER,
    total_reports BIGINT,
    avg_priority_score NUMERIC,
    max_priority_score NUMERIC,
    high_priority_clusters INTEGER,
    estimated_total_cost NUMERIC
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    WITH cluster_districts AS (
        SELECT 
            d.district_id,
            d.name as district_name,
            pq.*
        FROM fn_get_priority_queue() pq
        JOIN districts d ON ST_Contains(d.boundary, pq.work_center::geometry)
    )
    SELECT 
        cd.district_id,
        cd.district_name,
        COUNT(*)::INTEGER as total_clusters,
        SUM(cd.report_count) as total_reports,
        ROUND(AVG(cd.priority_score), 2) as avg_priority_score,
        MAX(cd.priority_score) as max_priority_score,
        COUNT(*) FILTER (WHERE cd.priority_score >= 70)::INTEGER as high_priority_clusters,
        SUM(cd.estimated_cost) as estimated_total_cost
    FROM cluster_districts cd
    GROUP BY cd.district_id, cd.district_name
    ORDER BY avg_priority_score DESC;
END;
$$;

COMMENT ON FUNCTION fn_district_priority_summary IS 'Summary of priority clusters by district';

-- ============================================================================
-- SLA Compliance Check
-- Calculates time-based urgency
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_sla_compliance_check(
    p_severity INTEGER,
    p_reported_at TIMESTAMPTZ
)
RETURNS TABLE (
    sla_target_days INTEGER,
    days_elapsed NUMERIC,
    compliance_status TEXT,
    urgency_multiplier NUMERIC
)
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
    v_target_days INTEGER;
    v_elapsed NUMERIC;
BEGIN
    -- SLA targets based on severity
    v_target_days := CASE 
        WHEN p_severity >= 9 THEN 1   -- Critical: 24 hours
        WHEN p_severity >= 7 THEN 3   -- High: 3 days
        WHEN p_severity >= 5 THEN 7   -- Medium: 1 week
        WHEN p_severity >= 3 THEN 14  -- Low: 2 weeks
        ELSE 30                       -- Minor: 1 month
    END;
    
    v_elapsed := EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - p_reported_at)) / 86400;
    
    RETURN QUERY
    SELECT 
        v_target_days,
        ROUND(v_elapsed, 1),
        CASE 
            WHEN v_elapsed <= v_target_days * 0.5 THEN 'on_track'
            WHEN v_elapsed <= v_target_days THEN 'at_risk'
            ELSE 'overdue'
        END,
        CASE 
            WHEN v_elapsed <= v_target_days THEN 1.0
            ELSE LEAST(1.0 + ((v_elapsed - v_target_days) / v_target_days) * 0.5, 2.0)
        END;
END;
$$;

COMMENT ON FUNCTION fn_sla_compliance_check IS 'Check SLA compliance and calculate urgency multiplier';

-- ============================================================================
-- Cost Estimation Function
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_estimate_cluster_cost(
    p_cluster_id INTEGER,
    p_eps FLOAT DEFAULT 0.0005,
    p_min_points INTEGER DEFAULT 3
)
RETURNS TABLE (
    labor_cost NUMERIC,
    material_cost NUMERIC,
    equipment_cost NUMERIC,
    total_estimated_cost NUMERIC
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_report_count INTEGER;
    v_base_repair_cost NUMERIC;
    v_severity_avg NUMERIC;
BEGIN
    -- Get cluster info
    SELECT cs.report_count, cs.avg_severity
    INTO v_report_count, v_severity_avg
    FROM fn_get_cluster_stats(p_eps, p_min_points) cs
    WHERE cs.cluster_id = p_cluster_id;
    
    -- Calculate base repair cost from damage types
    SELECT COALESCE(SUM(dt.estimated_repair_cost), 0)
    INTO v_base_repair_cost
    FROM fn_cluster_reports(p_eps, p_min_points) cr
    JOIN damage_types dt ON cr.damage_type_id = dt.damage_id
    WHERE cr.cluster_id = p_cluster_id;
    
    RETURN QUERY
    SELECT 
        -- Labor: $50/hr, ~1hr per report for minor, ~3hr for severe
        (v_report_count * 50 * (1 + v_severity_avg / 10))::NUMERIC as labor_cost,
        -- Material: 60% of base repair cost
        (v_base_repair_cost * 0.6)::NUMERIC as material_cost,
        -- Equipment: flat rate per cluster complexity
        (100 + v_severity_avg * 20)::NUMERIC as equipment_cost,
        -- Total
        ((v_report_count * 50 * (1 + v_severity_avg / 10)) + 
         (v_base_repair_cost * 0.6) + 
         (100 + v_severity_avg * 20))::NUMERIC as total_estimated_cost;
END;
$$;

COMMENT ON FUNCTION fn_estimate_cluster_cost IS 'Estimate repair cost breakdown for a cluster';
