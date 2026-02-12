-- ============================================================================
-- 🌾 AGRICULTURE YIELD ANALYTICS - VIEWS FOR REPORTING
-- ============================================================================
-- File: 06_views.sql
-- Purpose: Regular and materialized views for dashboards and reports
-- Database: PostgreSQL 14+
-- ============================================================================

SET search_path TO agri, public;

-- ============================================================================
-- SECTION 1: LOOKUP/REFERENCE VIEWS
-- ============================================================================

-- 1.1 Complete geographic hierarchy view
CREATE OR REPLACE VIEW agri.v_geography AS
SELECT 
    r.region_id,
    r.region_code,
    r.region_name,
    r.climate_zone,
    r.avg_annual_rainfall_mm AS region_rainfall,
    d.district_id,
    d.district_code,
    d.district_name,
    d.population AS district_population,
    d.farming_households,
    d.latitude AS district_lat,
    d.longitude AS district_lng,
    sc.sub_county_id,
    sc.sub_county_code,
    sc.sub_county_name
FROM agri.regions r
LEFT JOIN agri.districts d ON r.region_id = d.region_id
LEFT JOIN agri.sub_counties sc ON d.district_id = sc.district_id
WHERE r.is_active = TRUE AND d.is_active = TRUE;

COMMENT ON VIEW agri.v_geography IS 'Complete geographic hierarchy for lookups';

-- 1.2 Active crops with varieties view
CREATE OR REPLACE VIEW agri.v_crops_full AS
SELECT 
    c.crop_id,
    c.crop_code,
    c.crop_name,
    c.scientific_name,
    c.category,
    c.growth_period_days,
    c.optimal_rainfall_mm,
    c.optimal_temp_min,
    c.optimal_temp_max,
    c.is_export_crop,
    c.is_food_crop,
    c.default_unit,
    c.avg_national_yield,
    cv.variety_id,
    cv.variety_code,
    cv.variety_name,
    cv.is_hybrid,
    cv.is_drought_resistant,
    cv.is_disease_resistant,
    cv.maturity_days,
    cv.expected_yield AS variety_expected_yield
FROM agri.crops c
LEFT JOIN agri.crop_varieties cv ON c.crop_id = cv.crop_id AND cv.is_active = TRUE
WHERE c.is_active = TRUE;

COMMENT ON VIEW agri.v_crops_full IS 'Active crops with their varieties';

-- ============================================================================
-- SECTION 2: FARMER & FARM VIEWS
-- ============================================================================

-- 2.1 Farmer profile view
CREATE OR REPLACE VIEW agri.v_farmer_profiles AS
SELECT 
    f.farmer_id,
    f.farmer_code,
    f.first_name,
    f.last_name,
    f.first_name || ' ' || f.last_name AS full_name,
    f.gender,
    f.phone_primary,
    f.email,
    d.district_name,
    r.region_name,
    f.village,
    f.years_farming,
    f.cooperative_member,
    f.cooperative_name,
    f.registered_at,
    -- Calculated metrics
    (SELECT COUNT(*) FROM agri.farms WHERE farmer_id = f.farmer_id) AS farm_count,
    (SELECT SUM(total_area_hectares) FROM agri.farms WHERE farmer_id = f.farmer_id) AS total_land_ha,
    (SELECT COUNT(*) FROM agri.harvests WHERE farmer_id = f.farmer_id) AS total_harvests,
    (SELECT MAX(harvest_date) FROM agri.harvests WHERE farmer_id = f.farmer_id) AS last_harvest_date
FROM agri.farmers f
LEFT JOIN agri.districts d ON f.district_id = d.district_id
LEFT JOIN agri.regions r ON d.region_id = r.region_id
WHERE f.is_active = TRUE;

COMMENT ON VIEW agri.v_farmer_profiles IS 'Comprehensive farmer profiles with metrics';

-- 2.2 Farm details view
CREATE OR REPLACE VIEW agri.v_farm_details AS
SELECT 
    fm.farm_id,
    fm.farm_code,
    fm.farm_name,
    f.farmer_code,
    f.first_name || ' ' || f.last_name AS farmer_name,
    d.district_name,
    r.region_name,
    fm.village,
    fm.total_area_hectares,
    fm.cultivated_area_hectares,
    fm.size_class,
    fm.latitude,
    fm.longitude,
    fm.soil_type,
    fm.irrigation_available,
    fm.irrigation_type,
    fm.land_ownership,
    -- Plot summary
    (SELECT COUNT(*) FROM agri.farm_plots WHERE farm_id = fm.farm_id) AS plot_count,
    -- Recent activity
    (SELECT COUNT(*) FROM agri.harvests WHERE farm_id = fm.farm_id AND harvest_date > CURRENT_DATE - INTERVAL '1 year') AS harvests_last_year,
    (SELECT STRING_AGG(DISTINCT c.crop_name, ', ') 
     FROM agri.harvests h 
     JOIN agri.crops c ON h.crop_id = c.crop_id 
     WHERE h.farm_id = fm.farm_id AND h.harvest_date > CURRENT_DATE - INTERVAL '1 year') AS recent_crops
FROM agri.farms fm
JOIN agri.farmers f ON fm.farmer_id = f.farmer_id
JOIN agri.districts d ON fm.district_id = d.district_id
JOIN agri.regions r ON d.region_id = r.region_id
WHERE fm.is_active = TRUE;

COMMENT ON VIEW agri.v_farm_details IS 'Detailed farm information with owner and metrics';

-- ============================================================================
-- SECTION 3: HARVEST DETAIL VIEWS
-- ============================================================================

-- 3.1 Complete harvest view (Denormalized for reporting)
CREATE OR REPLACE VIEW agri.v_harvests_detail AS
SELECT 
    h.harvest_id,
    h.harvest_code,
    
    -- Farmer info
    f.farmer_code,
    f.first_name || ' ' || f.last_name AS farmer_name,
    f.phone_primary AS farmer_phone,
    
    -- Farm info
    fm.farm_code,
    fm.farm_name,
    fm.size_class,
    fm.soil_type,
    
    -- Location info
    d.district_code,
    d.district_name,
    r.region_code,
    r.region_name,
    
    -- Crop info
    c.crop_code,
    c.crop_name,
    c.category AS crop_category,
    cv.variety_name,
    cv.is_hybrid,
    
    -- Season info
    s.season_code,
    s.season_name,
    s.season_type,
    s.year AS season_year,
    
    -- Dates
    h.planting_date,
    h.harvest_date,
    h.harvest_date - h.planting_date AS growth_days,
    
    -- Yield metrics
    h.area_harvested_hectares,
    h.total_yield_kg,
    h.yield_per_hectare,
    h.yield_unit,
    h.quality_grade,
    
    -- Compared to benchmark
    c.avg_national_yield AS national_avg_yield,
    ROUND((h.yield_per_hectare / NULLIF(c.avg_national_yield, 0) * 100 - 100)::NUMERIC, 2) AS pct_vs_national_avg,
    
    -- Sales
    h.quantity_sold_kg,
    h.quantity_consumed_kg,
    h.quantity_stored_kg,
    h.sale_price_per_kg,
    h.total_revenue,
    
    -- Costs
    h.seed_cost,
    h.fertilizer_cost,
    h.pesticide_cost,
    h.labor_cost,
    h.transport_cost,
    h.other_costs,
    h.total_cost,
    
    -- Profit
    h.profit,
    CASE WHEN h.area_harvested_hectares > 0 
         THEN ROUND((h.profit / h.area_harvested_hectares)::NUMERIC, 2) 
         ELSE 0 
    END AS profit_per_hectare,
    
    -- Status
    h.verified,
    h.data_source,
    h.created_at,
    h.updated_at
FROM agri.harvests h
JOIN agri.farmers f ON h.farmer_id = f.farmer_id
JOIN agri.farms fm ON h.farm_id = fm.farm_id
JOIN agri.districts d ON h.district_id = d.district_id
JOIN agri.regions r ON d.region_id = r.region_id
JOIN agri.crops c ON h.crop_id = c.crop_id
LEFT JOIN agri.crop_varieties cv ON h.variety_id = cv.variety_id
JOIN agri.seasons s ON h.season_id = s.season_id;

COMMENT ON VIEW agri.v_harvests_detail IS 'Fully denormalized harvest data for reporting and exports';

-- ============================================================================
-- SECTION 4: DASHBOARD SUMMARY VIEWS
-- ============================================================================

-- 4.1 Executive dashboard summary
CREATE OR REPLACE VIEW agri.v_dashboard_summary AS
WITH current_season AS (
    SELECT season_id, season_code, season_name FROM agri.seasons WHERE is_current = TRUE
),
season_metrics AS (
    SELECT 
        COUNT(DISTINCT h.farmer_id) AS total_farmers,
        COUNT(DISTINCT h.farm_id) AS total_farms,
        COUNT(h.harvest_id) AS total_harvests,
        ROUND(SUM(h.area_harvested_hectares)::NUMERIC, 2) AS total_area_ha,
        ROUND(SUM(h.total_yield_kg)::NUMERIC, 0) AS total_production_kg,
        ROUND(SUM(h.total_revenue)::NUMERIC, 0) AS total_revenue_ugx,
        ROUND(SUM(h.profit)::NUMERIC, 0) AS total_profit_ugx,
        ROUND(AVG(h.yield_per_hectare)::NUMERIC, 2) AS avg_yield_per_ha,
        ROUND(AVG(h.profit / NULLIF(h.area_harvested_hectares, 0))::NUMERIC, 0) AS avg_profit_per_ha,
        ROUND(100.0 * COUNT(*) FILTER (WHERE h.quality_grade IN ('grade_a', 'grade_b')) / NULLIF(COUNT(*), 0), 2) AS high_quality_pct,
        ROUND(100.0 * COUNT(*) FILTER (WHERE h.verified = TRUE) / NULLIF(COUNT(*), 0), 2) AS verified_pct
    FROM agri.harvests h
    WHERE h.season_id = (SELECT season_id FROM current_season)
)
SELECT 
    cs.season_code,
    cs.season_name,
    sm.*,
    (SELECT COUNT(*) FROM agri.crops WHERE is_active = TRUE) AS available_crops,
    (SELECT COUNT(*) FROM agri.districts WHERE is_active = TRUE) AS active_districts
FROM current_season cs
CROSS JOIN season_metrics sm;

COMMENT ON VIEW agri.v_dashboard_summary IS 'Main dashboard KPIs for current season';

-- 4.2 Regional performance dashboard
CREATE OR REPLACE VIEW agri.v_regional_dashboard AS
SELECT 
    r.region_name,
    COUNT(DISTINCT h.farmer_id) AS farmers,
    COUNT(DISTINCT h.farm_id) AS farms,
    COUNT(h.harvest_id) AS harvests,
    ROUND(SUM(h.area_harvested_hectares)::NUMERIC, 2) AS total_area_ha,
    ROUND(SUM(h.total_yield_kg) / 1000::NUMERIC, 2) AS production_tonnes,
    ROUND(AVG(h.yield_per_hectare)::NUMERIC, 2) AS avg_yield_kg_ha,
    ROUND(SUM(h.profit) / 1000000::NUMERIC, 2) AS profit_millions_ugx,
    RANK() OVER (ORDER BY SUM(h.total_yield_kg) DESC) AS production_rank,
    RANK() OVER (ORDER BY AVG(h.yield_per_hectare) DESC) AS efficiency_rank,
    STRING_AGG(DISTINCT c.crop_name, ', ' ORDER BY c.crop_name) FILTER (
        WHERE c.crop_id IN (
            SELECT h2.crop_id FROM agri.harvests h2 
            WHERE h2.district_id = ANY(ARRAY_AGG(DISTINCT h.district_id))
            GROUP BY h2.crop_id ORDER BY SUM(h2.total_yield_kg) DESC LIMIT 3
        )
    ) AS top_crops
FROM agri.harvests h
JOIN agri.districts d ON h.district_id = d.district_id
JOIN agri.regions r ON d.region_id = r.region_id
JOIN agri.crops c ON h.crop_id = c.crop_id
WHERE h.harvest_date > CURRENT_DATE - INTERVAL '1 year'
GROUP BY r.region_id, r.region_name;

COMMENT ON VIEW agri.v_regional_dashboard IS 'Regional performance summary for last 12 months';

-- 4.3 Crop performance dashboard
CREATE OR REPLACE VIEW agri.v_crop_dashboard AS
SELECT 
    c.crop_code,
    c.crop_name,
    c.category,
    c.avg_national_yield AS benchmark_yield,
    COUNT(DISTINCT h.farmer_id) AS growing_farmers,
    COUNT(DISTINCT d.district_id) AS growing_districts,
    ROUND(SUM(h.area_harvested_hectares)::NUMERIC, 2) AS total_area_ha,
    ROUND(SUM(h.total_yield_kg) / 1000::NUMERIC, 2) AS production_tonnes,
    ROUND(AVG(h.yield_per_hectare)::NUMERIC, 2) AS actual_avg_yield,
    ROUND((AVG(h.yield_per_hectare) / NULLIF(c.avg_national_yield, 0) - 1) * 100::NUMERIC, 2) AS pct_vs_benchmark,
    ROUND(AVG(h.sale_price_per_kg)::NUMERIC, 2) AS avg_price_per_kg,
    ROUND(AVG(h.profit / NULLIF(h.area_harvested_hectares, 0))::NUMERIC, 0) AS profit_per_ha,
    -- Quality distribution
    ROUND(100.0 * COUNT(*) FILTER (WHERE h.quality_grade = 'grade_a') / NULLIF(COUNT(*), 0), 1) AS grade_a_pct,
    ROUND(100.0 * COUNT(*) FILTER (WHERE h.quality_grade = 'grade_b') / NULLIF(COUNT(*), 0), 1) AS grade_b_pct
FROM agri.crops c
LEFT JOIN agri.harvests h ON c.crop_id = h.crop_id AND h.harvest_date > CURRENT_DATE - INTERVAL '1 year'
LEFT JOIN agri.districts d ON h.district_id = d.district_id
WHERE c.is_active = TRUE
GROUP BY c.crop_id, c.crop_code, c.crop_name, c.category, c.avg_national_yield
ORDER BY production_tonnes DESC NULLS LAST;

COMMENT ON VIEW agri.v_crop_dashboard IS 'Crop performance comparison for last 12 months';

-- ============================================================================
-- SECTION 5: MATERIALIZED VIEWS (For Performance)
-- ============================================================================

-- 5.1 Pre-aggregated regional stats (Refreshed daily)
CREATE MATERIALIZED VIEW IF NOT EXISTS agri.mv_regional_stats AS
SELECT 
    r.region_id,
    r.region_name,
    d.district_id,
    d.district_name,
    c.crop_id,
    c.crop_name,
    s.season_id,
    s.season_code,
    s.year,
    s.season_type,
    
    -- Counts
    COUNT(DISTINCT h.farmer_id) AS farmer_count,
    COUNT(DISTINCT h.farm_id) AS farm_count,
    COUNT(h.harvest_id) AS harvest_count,
    
    -- Area
    SUM(h.area_harvested_hectares) AS total_area_ha,
    
    -- Production
    SUM(h.total_yield_kg) AS total_yield_kg,
    AVG(h.yield_per_hectare) AS avg_yield_per_ha,
    MIN(h.yield_per_hectare) AS min_yield,
    MAX(h.yield_per_hectare) AS max_yield,
    STDDEV(h.yield_per_hectare) AS stddev_yield,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY h.yield_per_hectare) AS median_yield,
    
    -- Financial
    SUM(h.total_revenue) AS total_revenue,
    SUM(h.total_cost) AS total_cost,
    SUM(h.profit) AS total_profit,
    AVG(h.sale_price_per_kg) AS avg_price_per_kg,
    
    -- Quality
    COUNT(*) FILTER (WHERE h.quality_grade = 'grade_a') AS grade_a_count,
    COUNT(*) FILTER (WHERE h.quality_grade = 'grade_b') AS grade_b_count,
    COUNT(*) FILTER (WHERE h.quality_grade = 'grade_c') AS grade_c_count,
    
    CURRENT_TIMESTAMP AS refreshed_at
FROM agri.harvests h
JOIN agri.districts d ON h.district_id = d.district_id
JOIN agri.regions r ON d.region_id = r.region_id
JOIN agri.crops c ON h.crop_id = c.crop_id
JOIN agri.seasons s ON h.season_id = s.season_id
GROUP BY 
    r.region_id, r.region_name, 
    d.district_id, d.district_name,
    c.crop_id, c.crop_name,
    s.season_id, s.season_code, s.year, s.season_type
WITH DATA;

-- Index for fast lookups
CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_regional_stats_pk 
ON agri.mv_regional_stats(region_id, district_id, crop_id, season_id);

CREATE INDEX IF NOT EXISTS idx_mv_regional_stats_season 
ON agri.mv_regional_stats(season_id);

CREATE INDEX IF NOT EXISTS idx_mv_regional_stats_crop 
ON agri.mv_regional_stats(crop_id);

COMMENT ON MATERIALIZED VIEW agri.mv_regional_stats IS 'Pre-aggregated regional statistics - refresh daily';

-- 5.2 Farmer leaderboard (Refreshed weekly)
CREATE MATERIALIZED VIEW IF NOT EXISTS agri.mv_farmer_leaderboard AS
SELECT 
    f.farmer_id,
    f.farmer_code,
    f.first_name || ' ' || f.last_name AS farmer_name,
    d.district_name,
    r.region_name,
    
    -- Activity
    COUNT(DISTINCT h.season_id) AS seasons_active,
    COUNT(h.harvest_id) AS total_harvests,
    COUNT(DISTINCT h.crop_id) AS crops_grown,
    
    -- Performance
    SUM(h.area_harvested_hectares) AS total_area_ha,
    SUM(h.total_yield_kg) AS total_production_kg,
    AVG(h.yield_per_hectare) AS avg_yield_per_ha,
    
    -- Financial
    SUM(h.total_revenue) AS total_revenue,
    SUM(h.profit) AS total_profit,
    AVG(h.profit / NULLIF(h.area_harvested_hectares, 0)) AS profit_per_ha,
    
    -- Rankings
    PERCENT_RANK() OVER (ORDER BY AVG(h.yield_per_hectare)) AS yield_percentile,
    PERCENT_RANK() OVER (ORDER BY SUM(h.profit)) AS profit_percentile,
    
    -- Tier assignment
    CASE 
        WHEN PERCENT_RANK() OVER (ORDER BY AVG(h.yield_per_hectare)) >= 0.90 THEN 'PLATINUM'
        WHEN PERCENT_RANK() OVER (ORDER BY AVG(h.yield_per_hectare)) >= 0.75 THEN 'GOLD'
        WHEN PERCENT_RANK() OVER (ORDER BY AVG(h.yield_per_hectare)) >= 0.50 THEN 'SILVER'
        WHEN PERCENT_RANK() OVER (ORDER BY AVG(h.yield_per_hectare)) >= 0.25 THEN 'BRONZE'
        ELSE 'DEVELOPING'
    END AS performance_tier,
    
    CURRENT_TIMESTAMP AS refreshed_at
FROM agri.farmers f
JOIN agri.harvests h ON f.farmer_id = h.farmer_id
JOIN agri.districts d ON f.district_id = d.district_id
JOIN agri.regions r ON d.region_id = r.region_id
GROUP BY 
    f.farmer_id, f.farmer_code, f.first_name, f.last_name,
    d.district_name, r.region_name
HAVING COUNT(h.harvest_id) >= 2  -- Minimum 2 harvests to be ranked
WITH DATA;

CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_farmer_leaderboard_pk 
ON agri.mv_farmer_leaderboard(farmer_id);

CREATE INDEX IF NOT EXISTS idx_mv_farmer_leaderboard_tier 
ON agri.mv_farmer_leaderboard(performance_tier);

CREATE INDEX IF NOT EXISTS idx_mv_farmer_leaderboard_region 
ON agri.mv_farmer_leaderboard(region_name);

COMMENT ON MATERIALIZED VIEW agri.mv_farmer_leaderboard IS 'Farmer rankings and performance tiers - refresh weekly';

-- 5.3 Yield trends (Refreshed daily)
CREATE MATERIALIZED VIEW IF NOT EXISTS agri.mv_yield_trends AS
WITH seasonal_data AS (
    SELECT 
        c.crop_id,
        c.crop_name,
        s.year,
        s.season_type,
        s.start_date,
        AVG(h.yield_per_hectare) AS avg_yield,
        SUM(h.total_yield_kg) AS total_production,
        COUNT(h.harvest_id) AS harvest_count
    FROM agri.harvests h
    JOIN agri.crops c ON h.crop_id = c.crop_id
    JOIN agri.seasons s ON h.season_id = s.season_id
    GROUP BY c.crop_id, c.crop_name, s.year, s.season_type, s.start_date
)
SELECT 
    crop_id,
    crop_name,
    year,
    season_type,
    avg_yield,
    total_production,
    harvest_count,
    
    -- Moving averages
    AVG(avg_yield) OVER (PARTITION BY crop_id ORDER BY start_date ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS ma_3_seasons,
    AVG(avg_yield) OVER (PARTITION BY crop_id ORDER BY start_date ROWS BETWEEN 4 PRECEDING AND CURRENT ROW) AS ma_5_seasons,
    
    -- Change metrics
    LAG(avg_yield) OVER (PARTITION BY crop_id ORDER BY start_date) AS prev_season_yield,
    avg_yield - LAG(avg_yield) OVER (PARTITION BY crop_id ORDER BY start_date) AS yield_change,
    ROUND(((avg_yield / NULLIF(LAG(avg_yield) OVER (PARTITION BY crop_id ORDER BY start_date), 0) - 1) * 100)::NUMERIC, 2) AS pct_change,
    
    -- Trend direction
    CASE 
        WHEN avg_yield > LAG(avg_yield) OVER (PARTITION BY crop_id ORDER BY start_date) * 1.1 THEN 'STRONG_UP'
        WHEN avg_yield > LAG(avg_yield) OVER (PARTITION BY crop_id ORDER BY start_date) THEN 'UP'
        WHEN avg_yield < LAG(avg_yield) OVER (PARTITION BY crop_id ORDER BY start_date) * 0.9 THEN 'STRONG_DOWN'
        WHEN avg_yield < LAG(avg_yield) OVER (PARTITION BY crop_id ORDER BY start_date) THEN 'DOWN'
        ELSE 'STABLE'
    END AS trend_direction,
    
    CURRENT_TIMESTAMP AS refreshed_at
FROM seasonal_data
WITH DATA;

CREATE INDEX IF NOT EXISTS idx_mv_yield_trends_crop ON agri.mv_yield_trends(crop_id);
CREATE INDEX IF NOT EXISTS idx_mv_yield_trends_year ON agri.mv_yield_trends(year, season_type);

COMMENT ON MATERIALIZED VIEW agri.mv_yield_trends IS 'Pre-calculated yield trends per crop - refresh daily';

-- ============================================================================
-- SECTION 6: REFRESH PROCEDURES FOR MATERIALIZED VIEWS
-- ============================================================================

-- Refresh all materialized views
CREATE OR REPLACE PROCEDURE agri.refresh_all_materialized_views()
LANGUAGE plpgsql
AS $$
BEGIN
    RAISE NOTICE 'Refreshing mv_regional_stats...';
    REFRESH MATERIALIZED VIEW CONCURRENTLY agri.mv_regional_stats;
    
    RAISE NOTICE 'Refreshing mv_farmer_leaderboard...';
    REFRESH MATERIALIZED VIEW CONCURRENTLY agri.mv_farmer_leaderboard;
    
    RAISE NOTICE 'Refreshing mv_yield_trends...';
    REFRESH MATERIALIZED VIEW CONCURRENTLY agri.mv_yield_trends;
    
    RAISE NOTICE 'All materialized views refreshed at %', CURRENT_TIMESTAMP;
END;
$$;

-- ============================================================================
-- SECTION 7: SYSTEM MONITORING VIEWS
-- ============================================================================

-- 7.1 System health check
CREATE OR REPLACE VIEW agri.v_system_health AS
SELECT 
    'Tables' AS category,
    (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'agri' AND table_type = 'BASE TABLE')::TEXT AS count
UNION ALL
SELECT 'Views', (SELECT COUNT(*) FROM information_schema.views WHERE table_schema = 'agri')::TEXT
UNION ALL
SELECT 'Indexes', (SELECT COUNT(*) FROM pg_indexes WHERE schemaname = 'agri')::TEXT
UNION ALL
SELECT 'Functions', (SELECT COUNT(*) FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid WHERE n.nspname = 'agri')::TEXT
UNION ALL
SELECT 'Total Farmers', (SELECT COUNT(*)::TEXT FROM agri.farmers)
UNION ALL
SELECT 'Total Farms', (SELECT COUNT(*)::TEXT FROM agri.farms)
UNION ALL
SELECT 'Total Harvests', (SELECT COUNT(*)::TEXT FROM agri.harvests)
UNION ALL
SELECT 'Database Size', pg_size_pretty(pg_database_size(current_database()));

COMMENT ON VIEW agri.v_system_health IS 'Quick system health overview';

-- 7.2 Data freshness check
CREATE OR REPLACE VIEW agri.v_data_freshness AS
SELECT 
    'Latest Harvest' AS metric,
    (SELECT MAX(harvest_date)::TEXT FROM agri.harvests) AS value
UNION ALL
SELECT 'Most Recent Data Entry', (SELECT MAX(created_at)::TEXT FROM agri.harvests)
UNION ALL
SELECT 'Current Season', (SELECT season_name FROM agri.seasons WHERE is_current = TRUE)
UNION ALL
SELECT 'Regions Stats Last Refresh', (SELECT MAX(refreshed_at)::TEXT FROM agri.mv_regional_stats)
UNION ALL
SELECT 'Leaderboard Last Refresh', (SELECT MAX(refreshed_at)::TEXT FROM agri.mv_farmer_leaderboard);

COMMENT ON VIEW agri.v_data_freshness IS 'Data freshness and last update times';

-- ============================================================================
-- VERIFICATION
-- ============================================================================

DO $$
DECLARE
    view_count INTEGER;
    mv_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO view_count
    FROM information_schema.views WHERE table_schema = 'agri';
    
    SELECT COUNT(*) INTO mv_count
    FROM pg_matviews WHERE schemaname = 'agri';
    
    RAISE NOTICE '=====================================';
    RAISE NOTICE 'VIEWS CREATED SUCCESSFULLY';
    RAISE NOTICE '=====================================';
    RAISE NOTICE 'Regular views: %', view_count;
    RAISE NOTICE 'Materialized views: %', mv_count;
    RAISE NOTICE '=====================================';
END $$;
