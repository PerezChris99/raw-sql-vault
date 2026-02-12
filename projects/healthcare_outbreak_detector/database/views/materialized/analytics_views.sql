-- ============================================================================
-- Views: Materialized Views for Performance
-- Purpose: Pre-computed aggregates for dashboard and analytics
-- ============================================================================

SET search_path TO surveillance, public;

-- Dashboard summary (refreshed every 15 minutes)
CREATE MATERIALIZED VIEW IF NOT EXISTS surveillance.mv_dashboard_summary AS
SELECT 
    CURRENT_TIMESTAMP AS last_updated,
    
    -- Today's statistics
    COUNT(*) FILTER (WHERE c.report_date = CURRENT_DATE) AS cases_today,
    COUNT(*) FILTER (WHERE c.report_date = CURRENT_DATE AND c.case_status = 'confirmed') AS confirmed_today,
    COUNT(*) FILTER (WHERE c.outcome_date = CURRENT_DATE AND c.outcome = 'dead') AS deaths_today,
    
    -- This week
    COUNT(*) FILTER (WHERE c.report_date >= DATE_TRUNC('week', CURRENT_DATE)) AS cases_this_week,
    
    -- This month
    COUNT(*) FILTER (WHERE c.report_date >= DATE_TRUNC('month', CURRENT_DATE)) AS cases_this_month,
    
    -- Active alerts count
    (SELECT COUNT(*) FROM surveillance.alerts WHERE alert_status = 'active') AS active_alerts,
    (SELECT COUNT(*) FROM surveillance.alerts WHERE alert_status = 'active' AND alert_level = 'emergency') AS emergency_alerts,
    
    -- Pending specimens
    (SELECT COUNT(*) FROM surveillance.specimens WHERE status = 'pending') AS pending_specimens
FROM surveillance.cases c
WHERE c.report_date >= CURRENT_DATE - INTERVAL '30 days';

CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_dashboard_unique ON surveillance.mv_dashboard_summary (last_updated);

-- Disease hotspots (refreshed hourly)
CREATE MATERIALIZED VIEW IF NOT EXISTS surveillance.mv_disease_hotspots AS
SELECT 
    d.disease_id,
    d.disease_code,
    d.disease_name,
    dist.district_id,
    dist.district_code,
    dist.district_name,
    dist.latitude,
    dist.longitude,
    r.region_name,
    COUNT(*) AS case_count,
    COUNT(*) FILTER (WHERE c.case_status = 'confirmed') AS confirmed_count,
    COUNT(*) FILTER (WHERE c.outcome = 'dead') AS death_count,
    MAX(c.report_date) AS latest_case_date,
    -- Calculate attack rate per 100,000
    ROUND(COUNT(*) * 100000.0 / COALESCE(NULLIF(dist.population, 0), 100000), 2) AS attack_rate
FROM surveillance.cases c
JOIN surveillance.diseases d ON c.disease_id = d.disease_id
JOIN surveillance.districts dist ON c.district_id = dist.district_id
JOIN surveillance.regions r ON dist.region_id = r.region_id
WHERE c.report_date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY d.disease_id, d.disease_code, d.disease_name,
         dist.district_id, dist.district_code, dist.district_name, 
         dist.latitude, dist.longitude, r.region_name
HAVING COUNT(*) >= 1
ORDER BY case_count DESC;

CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_hotspots_unique 
    ON surveillance.mv_disease_hotspots (disease_id, district_id);
CREATE INDEX IF NOT EXISTS idx_mv_hotspots_attack_rate 
    ON surveillance.mv_disease_hotspots (attack_rate DESC);

-- Time series for trend analysis (daily refresh)
CREATE MATERIALIZED VIEW IF NOT EXISTS surveillance.mv_daily_trends AS
SELECT 
    c.report_date,
    d.disease_id,
    d.disease_code,
    d.disease_name,
    r.region_id,
    r.region_name,
    COUNT(*) AS case_count,
    COUNT(*) FILTER (WHERE c.case_status = 'confirmed') AS confirmed_count,
    COUNT(*) FILTER (WHERE c.outcome = 'dead') AS death_count,
    -- 7-day moving average
    AVG(COUNT(*)) OVER (
        PARTITION BY d.disease_id, r.region_id 
        ORDER BY c.report_date 
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) AS moving_avg_7d
FROM surveillance.cases c
JOIN surveillance.diseases d ON c.disease_id = d.disease_id
JOIN surveillance.districts dist ON c.district_id = dist.district_id
JOIN surveillance.regions r ON dist.region_id = r.region_id
WHERE c.report_date >= CURRENT_DATE - INTERVAL '365 days'
GROUP BY c.report_date, d.disease_id, d.disease_code, d.disease_name, 
         r.region_id, r.region_name
ORDER BY c.report_date DESC;

CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_trends_unique 
    ON surveillance.mv_daily_trends (report_date, disease_id, region_id);

-- Refresh function
CREATE OR REPLACE FUNCTION surveillance.refresh_materialized_views(p_view_name TEXT DEFAULT NULL)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
BEGIN
    IF p_view_name IS NULL OR p_view_name = 'dashboard_summary' THEN
        REFRESH MATERIALIZED VIEW CONCURRENTLY surveillance.mv_dashboard_summary;
    END IF;
    
    IF p_view_name IS NULL OR p_view_name = 'disease_hotspots' THEN
        REFRESH MATERIALIZED VIEW CONCURRENTLY surveillance.mv_disease_hotspots;
    END IF;
    
    IF p_view_name IS NULL OR p_view_name = 'daily_trends' THEN
        REFRESH MATERIALIZED VIEW CONCURRENTLY surveillance.mv_daily_trends;
    END IF;
    
    RETURN 'Materialized views refreshed at ' || CURRENT_TIMESTAMP;
END;
$$;

COMMENT ON MATERIALIZED VIEW surveillance.mv_dashboard_summary IS 'Pre-computed dashboard statistics, refresh every 15 minutes';
COMMENT ON MATERIALIZED VIEW surveillance.mv_disease_hotspots IS 'Geographic disease hotspots for mapping, refresh hourly';
COMMENT ON MATERIALIZED VIEW surveillance.mv_daily_trends IS 'Daily case trends with moving averages, refresh daily';
