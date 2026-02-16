-- ============================================================================
-- Waste Collection Optimizer - Views and CTEs
-- PostgreSQL 14+
-- Migration: V002 - CTE-based analysis views
-- ============================================================================

-- ============================================================================
-- View: Full Bins by Route (User's Sample Query)
-- WITH full_bins AS (SELECT * FROM bins WHERE level > 80)
-- SELECT route_id, COUNT(*) as urgent FROM full_bins GROUP BY route_id
-- ============================================================================

CREATE OR REPLACE VIEW vw_urgent_routes AS
WITH full_bins AS (
    SELECT 
        bin_id,
        route_id,
        bin_code,
        current_level,
        last_emptied,
        EXTRACT(HOURS FROM NOW() - last_emptied) AS hours_since_emptied
    FROM bins 
    WHERE current_level > 80
      AND status = 'active'
)
SELECT 
    r.route_id,
    r.route_name,
    z.zone_name,
    COUNT(*) AS urgent_bins,
    ROUND(AVG(fb.current_level), 0) AS avg_fill_level,
    MAX(fb.hours_since_emptied)::INT AS max_hours_unfilled
FROM full_bins fb
JOIN routes r ON fb.route_id = r.route_id
JOIN zones z ON r.zone_id = z.zone_id
GROUP BY r.route_id, r.route_name, z.zone_name
ORDER BY COUNT(*) DESC;

COMMENT ON VIEW vw_urgent_routes IS 'User sample: WITH full_bins AS ... SELECT route_id, COUNT(*) as urgent';

-- ============================================================================
-- View: Route Priority Queue (Multiple CTEs)
-- ============================================================================

CREATE OR REPLACE VIEW vw_route_priority AS
WITH 
-- CTE 1: Bin statistics per route
bin_stats AS (
    SELECT 
        route_id,
        COUNT(*) AS total_bins,
        COUNT(*) FILTER (WHERE current_level > 80) AS full_bins,
        COUNT(*) FILTER (WHERE current_level BETWEEN 50 AND 80) AS moderate_bins,
        AVG(current_level) AS avg_level
    FROM bins
    WHERE status = 'active'
    GROUP BY route_id
),
-- CTE 2: Route urgency score
route_scores AS (
    SELECT 
        route_id,
        total_bins,
        full_bins,
        moderate_bins,
        avg_level,
        -- Urgency score calculation
        (full_bins * 10 + moderate_bins * 3 + avg_level * 0.5)::DECIMAL(6,1) AS urgency_score
    FROM bin_stats
),
-- CTE 3: Ranking
ranked_routes AS (
    SELECT 
        *,
        RANK() OVER (ORDER BY urgency_score DESC) AS priority_rank
    FROM route_scores
)
SELECT 
    rr.priority_rank,
    r.route_name,
    z.zone_name,
    rr.total_bins,
    rr.full_bins,
    rr.moderate_bins,
    ROUND(rr.avg_level, 0) AS avg_fill_pct,
    rr.urgency_score,
    r.distance_km,
    r.estimated_duration_mins
FROM ranked_routes rr
JOIN routes r ON rr.route_id = r.route_id
JOIN zones z ON r.zone_id = z.zone_id
WHERE r.status = 'active'
ORDER BY rr.priority_rank;

-- ============================================================================
-- View: Collection Efficiency (CTE with Window Functions)
-- ============================================================================

CREATE OR REPLACE VIEW vw_collection_efficiency AS
WITH daily_collections AS (
    SELECT 
        DATE(collected_at) AS collection_date,
        route_id,
        COUNT(*) AS bins_collected,
        SUM(weight_kg) AS total_weight,
        AVG(level_before) AS avg_level_before
    FROM collections
    WHERE collected_at >= CURRENT_DATE - INTERVAL '30 days'
    GROUP BY DATE(collected_at), route_id
),
with_prev AS (
    SELECT 
        *,
        LAG(bins_collected) OVER (PARTITION BY route_id ORDER BY collection_date) AS prev_day_bins,
        AVG(bins_collected) OVER (
            PARTITION BY route_id 
            ORDER BY collection_date 
            ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
        ) AS rolling_avg
    FROM daily_collections
)
SELECT 
    collection_date,
    r.route_name,
    bins_collected,
    total_weight,
    ROUND(avg_level_before, 0) AS avg_fill_level,
    prev_day_bins,
    ROUND(rolling_avg, 1) AS week_avg,
    CASE 
        WHEN bins_collected > rolling_avg * 1.2 THEN 'Above Normal'
        WHEN bins_collected < rolling_avg * 0.8 THEN 'Below Normal'
        ELSE 'Normal'
    END AS status
FROM with_prev wp
JOIN routes r ON wp.route_id = r.route_id
ORDER BY collection_date DESC, r.route_name;

-- ============================================================================
-- View: Zone Summary (Nested CTEs)
-- ============================================================================

CREATE OR REPLACE VIEW vw_zone_summary AS
WITH 
zone_bins AS (
    SELECT 
        z.zone_id,
        z.zone_name,
        COUNT(b.bin_id) AS total_bins,
        SUM(b.capacity_liters) AS total_capacity,
        COUNT(*) FILTER (WHERE b.current_level > 80) AS critical_bins,
        COUNT(*) FILTER (WHERE b.current_level > 50) AS attention_bins
    FROM zones z
    LEFT JOIN routes r ON z.zone_id = r.zone_id
    LEFT JOIN bins b ON r.route_id = b.route_id AND b.status = 'active'
    GROUP BY z.zone_id, z.zone_name
),
zone_collections AS (
    SELECT 
        z.zone_id,
        COUNT(c.collection_id) AS collections_30d,
        SUM(c.weight_kg) AS weight_30d
    FROM zones z
    LEFT JOIN routes r ON z.zone_id = r.zone_id
    LEFT JOIN collections c ON r.route_id = c.route_id 
        AND c.collected_at >= CURRENT_DATE - INTERVAL '30 days'
    GROUP BY z.zone_id
)
SELECT 
    zb.zone_name,
    zb.total_bins,
    zb.critical_bins,
    zb.attention_bins,
    zc.collections_30d,
    ROUND(zc.weight_30d, 0) AS weight_30d_kg,
    CASE 
        WHEN zb.critical_bins > zb.total_bins * 0.3 THEN '🔴 Critical'
        WHEN zb.critical_bins > zb.total_bins * 0.1 THEN '🟠 Attention'
        ELSE '🟢 Normal'
    END AS status
FROM zone_bins zb
LEFT JOIN zone_collections zc ON zb.zone_id = zc.zone_id
ORDER BY zb.critical_bins DESC;

-- ============================================================================
-- Function: Get Optimized Route (Using CTE)
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_get_optimized_route(p_route_id INT, p_threshold INT DEFAULT 50)
RETURNS TABLE (
    sequence INT,
    bin_code VARCHAR,
    location_desc VARCHAR,
    current_level INT,
    priority_score DECIMAL(6,2),
    cumulative_capacity INT
) AS $$
WITH prioritized_bins AS (
    SELECT 
        bin_id,
        bin_code,
        location_desc,
        current_level,
        capacity_liters,
        -- Priority based on fill level and time since emptied
        (current_level + COALESCE(EXTRACT(HOURS FROM NOW() - last_emptied) / 24 * 10, 0))::DECIMAL(6,2) AS priority_score
    FROM bins
    WHERE route_id = p_route_id
      AND current_level >= p_threshold
      AND status = 'active'
)
SELECT 
    ROW_NUMBER() OVER (ORDER BY priority_score DESC)::INT AS sequence,
    bin_code::VARCHAR,
    location_desc::VARCHAR,
    current_level,
    priority_score,
    SUM(capacity_liters) OVER (ORDER BY priority_score DESC ROWS UNBOUNDED PRECEDING)::INT AS cumulative_capacity
FROM prioritized_bins
ORDER BY priority_score DESC;
$$ LANGUAGE SQL;

COMMENT ON FUNCTION fn_get_optimized_route IS 'Get optimized collection sequence using CTE';
