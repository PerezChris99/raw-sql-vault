-- ============================================================================
-- 🌾 AGRICULTURE YIELD ANALYTICS - ANALYTICS QUERIES
-- ============================================================================
-- File: 04_analytics.sql
-- Purpose: Enterprise-grade analytics queries for yield analysis & forecasting
-- Database: PostgreSQL 14+
-- ============================================================================

SET search_path TO agri, public;

-- ============================================================================
-- SECTION 1: REGIONAL YIELD ANALYSIS
-- ============================================================================

/*
Core Query: Regional yield comparison with rankings
Used by: Dashboard, Regional Reports, Policy Analysis
*/

-- 1.1 Regional yield summary by season
SELECT 
    r.region_name,
    d.district_name,
    c.crop_name,
    s.season_name,
    COUNT(DISTINCT h.farmer_id) AS total_farmers,
    COUNT(h.harvest_id) AS harvest_count,
    SUM(h.area_harvested_hectares) AS total_area_ha,
    SUM(h.total_yield_kg) AS total_yield_kg,
    ROUND(AVG(h.yield_per_hectare)::NUMERIC, 2) AS avg_yield_per_ha,
    ROUND(MIN(h.yield_per_hectare)::NUMERIC, 2) AS min_yield,
    ROUND(MAX(h.yield_per_hectare)::NUMERIC, 2) AS max_yield,
    ROUND(STDDEV(h.yield_per_hectare)::NUMERIC, 2) AS yield_stddev,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY h.yield_per_hectare)::NUMERIC, 2) AS median_yield
FROM agri.harvests h
JOIN agri.districts d ON h.district_id = d.district_id
JOIN agri.regions r ON d.region_id = r.region_id
JOIN agri.crops c ON h.crop_id = c.crop_id
JOIN agri.seasons s ON h.season_id = s.season_id
GROUP BY r.region_name, d.district_name, c.crop_name, s.season_name
ORDER BY avg_yield_per_ha DESC;

-- 1.2 Regional ranking with window functions (User's requested query enhanced)
SELECT 
    r.region_name AS region,
    ROUND(AVG(h.yield_per_hectare)::NUMERIC, 2) AS avg_yield,
    ROUND(SUM(h.total_yield_kg) FILTER (WHERE s.season_type = 'season_a')::NUMERIC, 2) AS season_a_total,
    ROUND(SUM(h.total_yield_kg) FILTER (WHERE s.season_type = 'season_b')::NUMERIC, 2) AS season_b_total,
    ROUND(SUM(h.total_yield_kg)::NUMERIC, 2) AS annual_total,
    SUM(h.total_yield_kg) OVER (PARTITION BY s.season_id ORDER BY r.region_name) AS running_total,
    DENSE_RANK() OVER (ORDER BY AVG(h.yield_per_hectare) DESC) AS yield_rank
FROM agri.harvests h
JOIN agri.districts d ON h.district_id = d.district_id
JOIN agri.regions r ON d.region_id = r.region_id
JOIN agri.seasons s ON h.season_id = s.season_id
GROUP BY r.region_name, r.region_id, s.season_id
ORDER BY avg_yield DESC;

-- 1.3 Top performing districts per crop
WITH district_rankings AS (
    SELECT 
        c.crop_name,
        d.district_name,
        r.region_name,
        AVG(h.yield_per_hectare) AS avg_yield,
        COUNT(*) AS harvest_count,
        ROW_NUMBER() OVER (PARTITION BY c.crop_id ORDER BY AVG(h.yield_per_hectare) DESC) AS rank
    FROM agri.harvests h
    JOIN agri.crops c ON h.crop_id = c.crop_id
    JOIN agri.districts d ON h.district_id = d.district_id
    JOIN agri.regions r ON d.region_id = r.region_id
    WHERE h.harvest_date > CURRENT_DATE - INTERVAL '2 years'
    GROUP BY c.crop_id, c.crop_name, d.district_id, d.district_name, r.region_name
    HAVING COUNT(*) >= 5  -- Minimum sample size
)
SELECT * FROM district_rankings WHERE rank <= 10;

-- ============================================================================
-- SECTION 2: TREND ANALYSIS
-- ============================================================================

-- 2.1 Year-over-year yield growth by crop
WITH yearly_yields AS (
    SELECT 
        c.crop_name,
        s.year,
        AVG(h.yield_per_hectare) AS avg_yield,
        SUM(h.total_yield_kg) AS total_production
    FROM agri.harvests h
    JOIN agri.crops c ON h.crop_id = c.crop_id
    JOIN agri.seasons s ON h.season_id = s.season_id
    GROUP BY c.crop_name, s.year
)
SELECT 
    crop_name,
    year,
    ROUND(avg_yield::NUMERIC, 2) AS avg_yield,
    ROUND(total_production::NUMERIC, 0) AS total_production,
    ROUND(LAG(avg_yield) OVER (PARTITION BY crop_name ORDER BY year)::NUMERIC, 2) AS prev_year_yield,
    ROUND(((avg_yield - LAG(avg_yield) OVER (PARTITION BY crop_name ORDER BY year)) / 
           NULLIF(LAG(avg_yield) OVER (PARTITION BY crop_name ORDER BY year), 0) * 100)::NUMERIC, 2) AS yoy_growth_pct
FROM yearly_yields
ORDER BY crop_name, year;

-- 2.2 Moving average yield trends (3-season moving average)
WITH season_yields AS (
    SELECT 
        c.crop_name,
        s.season_code,
        s.start_date,
        AVG(h.yield_per_hectare) AS avg_yield
    FROM agri.harvests h
    JOIN agri.crops c ON h.crop_id = c.crop_id
    JOIN agri.seasons s ON h.season_id = s.season_id
    GROUP BY c.crop_name, s.season_code, s.start_date
)
SELECT 
    crop_name,
    season_code,
    ROUND(avg_yield::NUMERIC, 2) AS actual_yield,
    ROUND(AVG(avg_yield) OVER (
        PARTITION BY crop_name 
        ORDER BY start_date 
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    )::NUMERIC, 2) AS moving_avg_3_seasons,
    ROUND(AVG(avg_yield) OVER (
        PARTITION BY crop_name 
        ORDER BY start_date 
        ROWS BETWEEN 4 PRECEDING AND CURRENT ROW
    )::NUMERIC, 2) AS moving_avg_5_seasons
FROM season_yields
ORDER BY crop_name, start_date;

-- 2.3 Seasonal patterns - Compare Season A vs Season B performance
WITH seasonal_comparison AS (
    SELECT 
        c.crop_name,
        s.year,
        s.season_type,
        AVG(h.yield_per_hectare) AS avg_yield,
        SUM(h.total_yield_kg) AS total_yield
    FROM agri.harvests h
    JOIN agri.crops c ON h.crop_id = c.crop_id
    JOIN agri.seasons s ON h.season_id = s.season_id
    GROUP BY c.crop_name, s.year, s.season_type
)
SELECT 
    crop_name,
    year,
    ROUND(MAX(CASE WHEN season_type = 'season_a' THEN avg_yield END)::NUMERIC, 2) AS season_a_yield,
    ROUND(MAX(CASE WHEN season_type = 'season_b' THEN avg_yield END)::NUMERIC, 2) AS season_b_yield,
    ROUND(MAX(CASE WHEN season_type = 'season_a' THEN total_yield END)::NUMERIC, 0) AS season_a_production,
    ROUND(MAX(CASE WHEN season_type = 'season_b' THEN total_yield END)::NUMERIC, 0) AS season_b_production,
    CASE 
        WHEN MAX(CASE WHEN season_type = 'season_a' THEN avg_yield END) > 
             MAX(CASE WHEN season_type = 'season_b' THEN avg_yield END)
        THEN 'Season A'
        ELSE 'Season B'
    END AS better_season
FROM seasonal_comparison
GROUP BY crop_name, year
ORDER BY crop_name, year;

-- ============================================================================
-- SECTION 3: FORECASTING
-- ============================================================================

-- 3.1 Simple linear regression forecast
-- Calculate slope and intercept for yield trends
WITH yearly_data AS (
    SELECT 
        c.crop_id,
        c.crop_name,
        s.year,
        AVG(h.yield_per_hectare) AS avg_yield,
        ROW_NUMBER() OVER (PARTITION BY c.crop_id ORDER BY s.year) AS x
    FROM agri.harvests h
    JOIN agri.crops c ON h.crop_id = c.crop_id
    JOIN agri.seasons s ON h.season_id = s.season_id
    GROUP BY c.crop_id, c.crop_name, s.year
),
regression_stats AS (
    SELECT 
        crop_id,
        crop_name,
        COUNT(*) AS n,
        AVG(x) AS avg_x,
        AVG(avg_yield) AS avg_y,
        SUM((x - AVG(x) OVER (PARTITION BY crop_id)) * 
            (avg_yield - AVG(avg_yield) OVER (PARTITION BY crop_id))) AS sum_xy,
        SUM(POWER(x - AVG(x) OVER (PARTITION BY crop_id), 2)) AS sum_xx
    FROM yearly_data
    GROUP BY crop_id, crop_name
),
regression_params AS (
    SELECT 
        crop_id,
        crop_name,
        n,
        COALESCE(sum_xy / NULLIF(sum_xx, 0), 0) AS slope,
        avg_y - (COALESCE(sum_xy / NULLIF(sum_xx, 0), 0) * avg_x) AS intercept
    FROM regression_stats
)
SELECT 
    crop_name,
    ROUND(slope::NUMERIC, 2) AS annual_yield_trend,
    ROUND(intercept::NUMERIC, 2) AS base_yield,
    ROUND((intercept + slope * (n + 1))::NUMERIC, 2) AS forecast_next_year,
    ROUND((intercept + slope * (n + 2))::NUMERIC, 2) AS forecast_year_2,
    ROUND((intercept + slope * (n + 3))::NUMERIC, 2) AS forecast_year_3,
    CASE 
        WHEN slope > 0 THEN 'Increasing'
        WHEN slope < 0 THEN 'Decreasing'
        ELSE 'Stable'
    END AS trend_direction
FROM regression_params
ORDER BY slope DESC;

-- 3.2 District-level production forecast based on historical patterns
WITH historical_avg AS (
    SELECT 
        d.district_id,
        d.district_name,
        c.crop_id,
        c.crop_name,
        AVG(h.total_yield_kg) AS avg_production,
        STDDEV(h.total_yield_kg) AS stddev_production,
        AVG(h.area_harvested_hectares) AS avg_area,
        COUNT(*) AS seasons_count
    FROM agri.harvests h
    JOIN agri.districts d ON h.district_id = d.district_id
    JOIN agri.crops c ON h.crop_id = c.crop_id
    WHERE h.harvest_date > CURRENT_DATE - INTERVAL '3 years'
    GROUP BY d.district_id, d.district_name, c.crop_id, c.crop_name
    HAVING COUNT(*) >= 3
)
SELECT 
    district_name,
    crop_name,
    ROUND(avg_production::NUMERIC, 0) AS expected_production_kg,
    ROUND((avg_production - 1.96 * stddev_production / SQRT(seasons_count))::NUMERIC, 0) AS lower_95_ci,
    ROUND((avg_production + 1.96 * stddev_production / SQRT(seasons_count))::NUMERIC, 0) AS upper_95_ci,
    ROUND(avg_area::NUMERIC, 2) AS expected_area_ha,
    seasons_count AS data_points
FROM historical_avg
ORDER BY avg_production DESC;

-- ============================================================================
-- SECTION 4: PERFORMANCE ANALYSIS
-- ============================================================================

-- 4.1 Farmer performance percentiles
WITH farmer_performance AS (
    SELECT 
        f.farmer_id,
        f.first_name || ' ' || f.last_name AS farmer_name,
        d.district_name,
        COUNT(h.harvest_id) AS total_harvests,
        AVG(h.yield_per_hectare) AS avg_yield,
        SUM(h.total_yield_kg) AS total_production,
        SUM(h.profit) AS total_profit
    FROM agri.farmers f
    JOIN agri.harvests h ON f.farmer_id = h.farmer_id
    JOIN agri.districts d ON f.district_id = d.district_id
    GROUP BY f.farmer_id, f.first_name, f.last_name, d.district_name
)
SELECT 
    farmer_name,
    district_name,
    total_harvests,
    ROUND(avg_yield::NUMERIC, 2) AS avg_yield_per_ha,
    ROUND(total_production::NUMERIC, 0) AS total_production_kg,
    ROUND(total_profit::NUMERIC, 0) AS total_profit_ugx,
    NTILE(4) OVER (ORDER BY avg_yield) AS yield_quartile,  -- 1=Lowest 25%, 4=Top 25%
    PERCENT_RANK() OVER (ORDER BY avg_yield) AS yield_percentile,
    CASE 
        WHEN PERCENT_RANK() OVER (ORDER BY avg_yield) >= 0.9 THEN 'Top Performer'
        WHEN PERCENT_RANK() OVER (ORDER BY avg_yield) >= 0.5 THEN 'Above Average'
        WHEN PERCENT_RANK() OVER (ORDER BY avg_yield) >= 0.25 THEN 'Average'
        ELSE 'Needs Support'
    END AS performance_category
FROM farmer_performance
ORDER BY avg_yield DESC;

-- 4.2 Farm size class performance comparison
SELECT 
    fm.size_class,
    COUNT(DISTINCT fm.farm_id) AS farm_count,
    COUNT(h.harvest_id) AS harvest_count,
    ROUND(AVG(fm.total_area_hectares)::NUMERIC, 2) AS avg_farm_size_ha,
    ROUND(AVG(h.yield_per_hectare)::NUMERIC, 2) AS avg_yield_per_ha,
    ROUND(SUM(h.total_yield_kg)::NUMERIC, 0) AS total_production_kg,
    ROUND(SUM(h.profit)::NUMERIC, 0) AS total_profit_ugx,
    ROUND(AVG(h.profit / NULLIF(h.area_harvested_hectares, 0))::NUMERIC, 2) AS profit_per_hectare
FROM agri.farms fm
JOIN agri.harvests h ON fm.farm_id = h.farm_id
GROUP BY fm.size_class
ORDER BY 
    CASE fm.size_class 
        WHEN 'micro' THEN 1 
        WHEN 'small' THEN 2 
        WHEN 'medium' THEN 3 
        WHEN 'large' THEN 4 
        WHEN 'commercial' THEN 5 
    END;

-- ============================================================================
-- SECTION 5: QUALITY ANALYSIS
-- ============================================================================

-- 5.1 Quality grade distribution by region
SELECT 
    r.region_name,
    c.crop_name,
    COUNT(*) AS total_harvests,
    ROUND(100.0 * COUNT(*) FILTER (WHERE h.quality_grade = 'grade_a') / COUNT(*), 2) AS grade_a_pct,
    ROUND(100.0 * COUNT(*) FILTER (WHERE h.quality_grade = 'grade_b') / COUNT(*), 2) AS grade_b_pct,
    ROUND(100.0 * COUNT(*) FILTER (WHERE h.quality_grade = 'grade_c') / COUNT(*), 2) AS grade_c_pct,
    ROUND(100.0 * COUNT(*) FILTER (WHERE h.quality_grade = 'grade_d') / COUNT(*), 2) AS grade_d_pct,
    ROUND(AVG(CASE 
        WHEN h.quality_grade = 'grade_a' THEN 4
        WHEN h.quality_grade = 'grade_b' THEN 3
        WHEN h.quality_grade = 'grade_c' THEN 2
        WHEN h.quality_grade = 'grade_d' THEN 1
        ELSE 0
    END)::NUMERIC, 2) AS avg_quality_score
FROM agri.harvests h
JOIN agri.districts d ON h.district_id = d.district_id
JOIN agri.regions r ON d.region_id = r.region_id
JOIN agri.crops c ON h.crop_id = c.crop_id
GROUP BY r.region_name, c.crop_name
ORDER BY avg_quality_score DESC;

-- 5.2 Quality impact on revenue
SELECT 
    h.quality_grade,
    COUNT(*) AS harvest_count,
    ROUND(AVG(h.sale_price_per_kg)::NUMERIC, 2) AS avg_price_per_kg,
    ROUND(AVG(h.total_revenue)::NUMERIC, 0) AS avg_revenue,
    ROUND(AVG(h.profit)::NUMERIC, 0) AS avg_profit,
    ROUND(AVG(h.profit / NULLIF(h.area_harvested_hectares, 0))::NUMERIC, 0) AS profit_per_hectare,
    ROUND((AVG(h.sale_price_per_kg) / 
           (SELECT AVG(sale_price_per_kg) FROM agri.harvests WHERE quality_grade = 'grade_c') - 1) * 100::NUMERIC, 2
    ) AS price_premium_vs_grade_c_pct
FROM agri.harvests h
WHERE h.quality_grade IS NOT NULL
GROUP BY h.quality_grade
ORDER BY 
    CASE h.quality_grade 
        WHEN 'grade_a' THEN 1 
        WHEN 'grade_b' THEN 2 
        WHEN 'grade_c' THEN 3 
        WHEN 'grade_d' THEN 4 
        WHEN 'rejected' THEN 5 
    END;

-- ============================================================================
-- SECTION 6: FINANCIAL ANALYSIS
-- ============================================================================

-- 6.1 Cost structure analysis by crop
SELECT 
    c.crop_name,
    COUNT(h.harvest_id) AS sample_size,
    ROUND(AVG(h.seed_cost)::NUMERIC, 0) AS avg_seed_cost,
    ROUND(AVG(h.fertilizer_cost)::NUMERIC, 0) AS avg_fertilizer_cost,
    ROUND(AVG(h.pesticide_cost)::NUMERIC, 0) AS avg_pesticide_cost,
    ROUND(AVG(h.labor_cost)::NUMERIC, 0) AS avg_labor_cost,
    ROUND(AVG(h.total_cost)::NUMERIC, 0) AS avg_total_cost,
    ROUND(AVG(h.total_revenue)::NUMERIC, 0) AS avg_revenue,
    ROUND(AVG(h.profit)::NUMERIC, 0) AS avg_profit,
    ROUND(AVG(h.profit / NULLIF(h.total_cost, 0) * 100)::NUMERIC, 2) AS avg_roi_pct,
    ROUND(100.0 * AVG(h.seed_cost) / NULLIF(AVG(h.total_cost), 0), 1) AS seed_cost_share_pct,
    ROUND(100.0 * AVG(h.labor_cost) / NULLIF(AVG(h.total_cost), 0), 1) AS labor_cost_share_pct
FROM agri.harvests h
JOIN agri.crops c ON h.crop_id = c.crop_id
WHERE h.total_cost > 0
GROUP BY c.crop_name
ORDER BY avg_roi_pct DESC;

-- 6.2 Profitability by district and crop
SELECT 
    d.district_name,
    r.region_name,
    c.crop_name,
    COUNT(h.harvest_id) AS harvests,
    ROUND(SUM(h.total_yield_kg)::NUMERIC, 0) AS total_production_kg,
    ROUND(SUM(h.total_revenue)::NUMERIC, 0) AS total_revenue_ugx,
    ROUND(SUM(h.total_cost)::NUMERIC, 0) AS total_cost_ugx,
    ROUND(SUM(h.profit)::NUMERIC, 0) AS total_profit_ugx,
    ROUND(AVG(h.profit)::NUMERIC, 0) AS avg_profit_per_harvest,
    ROUND(SUM(h.profit) / NULLIF(SUM(h.area_harvested_hectares), 0)::NUMERIC, 0) AS profit_per_hectare
FROM agri.harvests h
JOIN agri.districts d ON h.district_id = d.district_id
JOIN agri.regions r ON d.region_id = r.region_id
JOIN agri.crops c ON h.crop_id = c.crop_id
GROUP BY d.district_name, r.region_name, c.crop_name
HAVING COUNT(h.harvest_id) >= 3
ORDER BY total_profit_ugx DESC;

-- ============================================================================
-- SECTION 7: COMPARATIVE ANALYSIS
-- ============================================================================

-- 7.1 Actual vs expected yield comparison
SELECT 
    c.crop_name,
    c.avg_national_yield AS national_benchmark,
    d.district_name,
    COUNT(h.harvest_id) AS sample_size,
    ROUND(AVG(h.yield_per_hectare)::NUMERIC, 2) AS actual_avg_yield,
    ROUND((AVG(h.yield_per_hectare) - c.avg_national_yield)::NUMERIC, 2) AS variance_from_benchmark,
    ROUND(((AVG(h.yield_per_hectare) / NULLIF(c.avg_national_yield, 0) - 1) * 100)::NUMERIC, 2) AS pct_vs_benchmark,
    CASE 
        WHEN AVG(h.yield_per_hectare) >= c.avg_national_yield * 1.2 THEN 'Excellent (120%+)'
        WHEN AVG(h.yield_per_hectare) >= c.avg_national_yield THEN 'Above Average'
        WHEN AVG(h.yield_per_hectare) >= c.avg_national_yield * 0.8 THEN 'Average (-20%)'
        ELSE 'Below Average (<80%)'
    END AS performance_rating
FROM agri.harvests h
JOIN agri.crops c ON h.crop_id = c.crop_id
JOIN agri.districts d ON h.district_id = d.district_id
GROUP BY c.crop_name, c.avg_national_yield, d.district_name
HAVING COUNT(h.harvest_id) >= 3
ORDER BY pct_vs_benchmark DESC;

-- 7.2 Season-over-season comparison
WITH current_season AS (
    SELECT season_id FROM agri.seasons WHERE is_current = TRUE
),
previous_season AS (
    SELECT season_id 
    FROM agri.seasons 
    WHERE start_date < (SELECT start_date FROM agri.seasons WHERE is_current = TRUE)
    ORDER BY start_date DESC 
    LIMIT 1
)
SELECT 
    c.crop_name,
    d.district_name,
    -- Current season
    SUM(h.total_yield_kg) FILTER (WHERE h.season_id = (SELECT season_id FROM current_season)) AS current_production,
    AVG(h.yield_per_hectare) FILTER (WHERE h.season_id = (SELECT season_id FROM current_season)) AS current_yield,
    -- Previous season
    SUM(h.total_yield_kg) FILTER (WHERE h.season_id = (SELECT season_id FROM previous_season)) AS previous_production,
    AVG(h.yield_per_hectare) FILTER (WHERE h.season_id = (SELECT season_id FROM previous_season)) AS previous_yield,
    -- Comparison
    ROUND(((SUM(h.total_yield_kg) FILTER (WHERE h.season_id = (SELECT season_id FROM current_season)) /
            NULLIF(SUM(h.total_yield_kg) FILTER (WHERE h.season_id = (SELECT season_id FROM previous_season)), 0) - 1) * 100)::NUMERIC, 2) AS production_change_pct
FROM agri.harvests h
JOIN agri.crops c ON h.crop_id = c.crop_id
JOIN agri.districts d ON h.district_id = d.district_id
GROUP BY c.crop_name, d.district_name
HAVING SUM(h.total_yield_kg) FILTER (WHERE h.season_id = (SELECT season_id FROM previous_season)) > 0;

-- ============================================================================
-- SECTION 8: COHORT ANALYSIS
-- ============================================================================

-- 8.1 Farmer cohort analysis by registration year
WITH farmer_cohorts AS (
    SELECT 
        f.farmer_id,
        EXTRACT(YEAR FROM f.registered_at) AS registration_year,
        s.year AS harvest_year,
        COUNT(h.harvest_id) AS harvests,
        AVG(h.yield_per_hectare) AS avg_yield,
        SUM(h.profit) AS total_profit
    FROM agri.farmers f
    JOIN agri.harvests h ON f.farmer_id = h.farmer_id
    JOIN agri.seasons s ON h.season_id = s.season_id
    GROUP BY f.farmer_id, EXTRACT(YEAR FROM f.registered_at), s.year
)
SELECT 
    registration_year AS cohort,
    harvest_year,
    harvest_year - registration_year AS years_in_system,
    COUNT(DISTINCT farmer_id) AS active_farmers,
    ROUND(AVG(avg_yield)::NUMERIC, 2) AS avg_yield_per_ha,
    ROUND(AVG(total_profit)::NUMERIC, 0) AS avg_profit
FROM farmer_cohorts
GROUP BY registration_year, harvest_year
ORDER BY registration_year, harvest_year;

-- ============================================================================
-- SECTION 9: ADVANCED WINDOW FUNCTION ANALYTICS
-- ============================================================================

-- 9.1 Cumulative production over time
SELECT 
    c.crop_name,
    s.season_code,
    SUM(h.total_yield_kg) AS season_production,
    SUM(SUM(h.total_yield_kg)) OVER (
        PARTITION BY c.crop_id 
        ORDER BY s.start_date 
        ROWS UNBOUNDED PRECEDING
    ) AS cumulative_production,
    ROUND(AVG(SUM(h.total_yield_kg)) OVER (
        PARTITION BY c.crop_id 
        ORDER BY s.start_date 
        ROWS BETWEEN 3 PRECEDING AND CURRENT ROW
    )::NUMERIC, 2) AS rolling_4_season_avg
FROM agri.harvests h
JOIN agri.crops c ON h.crop_id = c.crop_id
JOIN agri.seasons s ON h.season_id = s.season_id
GROUP BY c.crop_id, c.crop_name, s.season_code, s.start_date
ORDER BY c.crop_name, s.start_date;

-- 9.2 Lead/Lag analysis for yield changes
WITH season_yields AS (
    SELECT 
        c.crop_name,
        s.season_code,
        s.start_date,
        AVG(h.yield_per_hectare) AS avg_yield
    FROM agri.harvests h
    JOIN agri.crops c ON h.crop_id = c.crop_id
    JOIN agri.seasons s ON h.season_id = s.season_id
    GROUP BY c.crop_name, c.crop_id, s.season_code, s.start_date
)
SELECT 
    crop_name,
    season_code,
    ROUND(avg_yield::NUMERIC, 2) AS current_yield,
    ROUND(LAG(avg_yield, 1) OVER w::NUMERIC, 2) AS prev_season_yield,
    ROUND(LEAD(avg_yield, 1) OVER w::NUMERIC, 2) AS next_season_yield,
    ROUND(((avg_yield / NULLIF(LAG(avg_yield, 1) OVER w, 0) - 1) * 100)::NUMERIC, 2) AS pct_change_from_prev,
    ROUND(FIRST_VALUE(avg_yield) OVER w::NUMERIC, 2) AS first_recorded_yield,
    ROUND(LAST_VALUE(avg_yield) OVER (
        PARTITION BY crop_name 
        ORDER BY start_date 
        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    )::NUMERIC, 2) AS last_recorded_yield
FROM season_yields
WINDOW w AS (PARTITION BY crop_name ORDER BY start_date)
ORDER BY crop_name, start_date;

-- ============================================================================
-- SECTION 10: DASHBOARD SUMMARY QUERIES
-- ============================================================================

-- 10.1 Executive dashboard summary
SELECT 
    -- Overall metrics
    COUNT(DISTINCT h.farmer_id) AS total_farmers,
    COUNT(DISTINCT h.farm_id) AS total_farms,
    COUNT(h.harvest_id) AS total_harvests,
    ROUND(SUM(h.area_harvested_hectares)::NUMERIC, 2) AS total_area_ha,
    ROUND(SUM(h.total_yield_kg)::NUMERIC, 0) AS total_production_kg,
    ROUND(SUM(h.total_revenue)::NUMERIC, 0) AS total_revenue_ugx,
    ROUND(SUM(h.profit)::NUMERIC, 0) AS total_profit_ugx,
    -- Averages
    ROUND(AVG(h.yield_per_hectare)::NUMERIC, 2) AS avg_yield_per_ha,
    ROUND(AVG(h.profit / NULLIF(h.area_harvested_hectares, 0))::NUMERIC, 0) AS avg_profit_per_ha,
    -- Quality distribution
    ROUND(100.0 * COUNT(*) FILTER (WHERE h.quality_grade IN ('grade_a', 'grade_b')) / COUNT(*), 2) AS high_quality_pct
FROM agri.harvests h
WHERE h.harvest_date > CURRENT_DATE - INTERVAL '1 year';

-- 10.2 Key performance indicators by region
SELECT 
    r.region_name,
    COUNT(DISTINCT h.farmer_id) AS farmers,
    ROUND(SUM(h.total_yield_kg) / 1000000::NUMERIC, 2) AS production_tonnes,
    ROUND(AVG(h.yield_per_hectare)::NUMERIC, 0) AS avg_yield_kg_ha,
    ROUND(SUM(h.profit) / 1000000::NUMERIC, 2) AS profit_millions_ugx,
    RANK() OVER (ORDER BY SUM(h.total_yield_kg) DESC) AS production_rank,
    RANK() OVER (ORDER BY AVG(h.yield_per_hectare) DESC) AS efficiency_rank
FROM agri.harvests h
JOIN agri.districts d ON h.district_id = d.district_id
JOIN agri.regions r ON d.region_id = r.region_id
WHERE h.harvest_date > CURRENT_DATE - INTERVAL '1 year'
GROUP BY r.region_name
ORDER BY production_tonnes DESC;

-- ============================================================================
-- VERIFICATION
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE '=====================================';
    RAISE NOTICE 'ANALYTICS QUERIES LOADED SUCCESSFULLY';
    RAISE NOTICE '=====================================';
    RAISE NOTICE 'Sections available:';
    RAISE NOTICE '  1. Regional Yield Analysis';
    RAISE NOTICE '  2. Trend Analysis';
    RAISE NOTICE '  3. Forecasting';
    RAISE NOTICE '  4. Performance Analysis';
    RAISE NOTICE '  5. Quality Analysis';
    RAISE NOTICE '  6. Financial Analysis';
    RAISE NOTICE '  7. Comparative Analysis';
    RAISE NOTICE '  8. Cohort Analysis';
    RAISE NOTICE '  9. Advanced Window Analytics';
    RAISE NOTICE ' 10. Dashboard Summaries';
    RAISE NOTICE '=====================================';
END $$;
