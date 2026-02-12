-- ============================================================================
-- Analytics: Yield Analysis Functions
-- Purpose: Core yield calculation and comparison functions
-- ============================================================================

SET search_path TO agri, public;

-- ============================================================================
-- REGIONAL YIELD ANALYSIS
-- ============================================================================

-- Get regional yield summary
CREATE OR REPLACE FUNCTION agri.get_regional_yield_summary(
    p_crop_code VARCHAR(20) DEFAULT NULL,
    p_season_id INTEGER DEFAULT NULL,
    p_year INTEGER DEFAULT NULL
)
RETURNS TABLE (
    region_name VARCHAR(100),
    district_count BIGINT,
    farmer_count BIGINT,
    total_area_ha DECIMAL,
    total_yield_kg DECIMAL,
    avg_yield_per_ha DECIMAL,
    min_yield DECIMAL,
    max_yield DECIMAL,
    yield_stddev DECIMAL,
    yield_rank INTEGER
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    WITH regional_stats AS (
        SELECT 
            r.region_name AS rname,
            COUNT(DISTINCT d.district_id)::BIGINT AS dcount,
            COUNT(DISTINCT h.farmer_id)::BIGINT AS fcount,
            COALESCE(SUM(h.area_harvested_hectares), 0) AS total_area,
            COALESCE(SUM(h.total_yield_kg), 0) AS total_yield,
            ROUND(COALESCE(AVG(h.yield_per_hectare), 0)::NUMERIC, 2) AS avg_yield,
            ROUND(COALESCE(MIN(h.yield_per_hectare), 0)::NUMERIC, 2) AS min_yld,
            ROUND(COALESCE(MAX(h.yield_per_hectare), 0)::NUMERIC, 2) AS max_yld,
            ROUND(COALESCE(STDDEV(h.yield_per_hectare), 0)::NUMERIC, 2) AS stddev_yld
        FROM agri.regions r
        LEFT JOIN agri.districts d ON r.region_id = d.region_id
        LEFT JOIN agri.harvests h ON d.district_id = h.district_id
        LEFT JOIN agri.crops c ON h.crop_id = c.crop_id
        LEFT JOIN agri.seasons s ON h.season_id = s.season_id
        WHERE (p_crop_code IS NULL OR c.crop_code = p_crop_code)
          AND (p_season_id IS NULL OR h.season_id = p_season_id)
          AND (p_year IS NULL OR s.year = p_year)
        GROUP BY r.region_name
    )
    SELECT 
        rs.rname,
        rs.dcount,
        rs.fcount,
        rs.total_area,
        rs.total_yield,
        rs.avg_yield,
        rs.min_yld,
        rs.max_yld,
        rs.stddev_yld,
        DENSE_RANK() OVER (ORDER BY rs.avg_yield DESC)::INTEGER
    FROM regional_stats rs
    ORDER BY rs.avg_yield DESC;
END;
$$;

-- ============================================================================
-- CROP PERFORMANCE ANALYSIS
-- ============================================================================

-- Get crop performance by district
CREATE OR REPLACE FUNCTION agri.get_crop_performance(
    p_crop_code VARCHAR(20),
    p_limit INTEGER DEFAULT 20
)
RETURNS TABLE (
    crop_name VARCHAR(100),
    district_name VARCHAR(100),
    region_name VARCHAR(100),
    harvest_count BIGINT,
    total_area_ha DECIMAL,
    avg_yield_per_ha DECIMAL,
    vs_expected_pct DECIMAL,
    performance_rank INTEGER
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.crop_name,
        d.district_name,
        r.region_name,
        COUNT(h.harvest_id)::BIGINT,
        ROUND(SUM(h.area_harvested_hectares)::NUMERIC, 2),
        ROUND(AVG(h.yield_per_hectare)::NUMERIC, 2) AS avg_yield,
        ROUND(
            (AVG(h.yield_per_hectare) / NULLIF((c.expected_yield_high + c.expected_yield_low) / 2, 0) * 100)::NUMERIC, 1
        ) AS vs_expected,
        ROW_NUMBER() OVER (ORDER BY AVG(h.yield_per_hectare) DESC)::INTEGER
    FROM agri.harvests h
    JOIN agri.crops c ON h.crop_id = c.crop_id
    JOIN agri.districts d ON h.district_id = d.district_id
    JOIN agri.regions r ON d.region_id = r.region_id
    WHERE c.crop_code = p_crop_code
      AND h.harvest_date >= CURRENT_DATE - INTERVAL '2 years'
    GROUP BY c.crop_id, c.crop_name, c.expected_yield_low, c.expected_yield_high,
             d.district_id, d.district_name, r.region_name
    HAVING COUNT(h.harvest_id) >= 3  -- Minimum sample size
    ORDER BY avg_yield DESC
    LIMIT p_limit;
END;
$$;

-- ============================================================================
-- SEASONAL COMPARISON
-- ============================================================================

-- Compare Season A vs Season B yields
CREATE OR REPLACE FUNCTION agri.compare_seasons(
    p_year INTEGER DEFAULT NULL
)
RETURNS TABLE (
    crop_name VARCHAR(100),
    year INTEGER,
    season_a_yield DECIMAL,
    season_a_area DECIMAL,
    season_b_yield DECIMAL,
    season_b_area DECIMAL,
    yield_difference DECIMAL,
    better_season TEXT
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.crop_name,
        s.year,
        ROUND(AVG(h.yield_per_hectare) FILTER (WHERE s.season_type = 'season_a')::NUMERIC, 2) AS sea_a_yield,
        ROUND(SUM(h.area_harvested_hectares) FILTER (WHERE s.season_type = 'season_a')::NUMERIC, 2) AS sea_a_area,
        ROUND(AVG(h.yield_per_hectare) FILTER (WHERE s.season_type = 'season_b')::NUMERIC, 2) AS sea_b_yield,
        ROUND(SUM(h.area_harvested_hectares) FILTER (WHERE s.season_type = 'season_b')::NUMERIC, 2) AS sea_b_area,
        ROUND((
            AVG(h.yield_per_hectare) FILTER (WHERE s.season_type = 'season_a') -
            AVG(h.yield_per_hectare) FILTER (WHERE s.season_type = 'season_b')
        )::NUMERIC, 2) AS diff,
        CASE 
            WHEN AVG(h.yield_per_hectare) FILTER (WHERE s.season_type = 'season_a') >
                 AVG(h.yield_per_hectare) FILTER (WHERE s.season_type = 'season_b')
            THEN 'Season A'
            WHEN AVG(h.yield_per_hectare) FILTER (WHERE s.season_type = 'season_a') <
                 AVG(h.yield_per_hectare) FILTER (WHERE s.season_type = 'season_b')
            THEN 'Season B'
            ELSE 'Equal'
        END
    FROM agri.harvests h
    JOIN agri.crops c ON h.crop_id = c.crop_id
    JOIN agri.seasons s ON h.season_id = s.season_id
    WHERE (p_year IS NULL OR s.year = p_year)
    GROUP BY c.crop_name, s.year
    HAVING COUNT(*) FILTER (WHERE s.season_type = 'season_a') > 0
       AND COUNT(*) FILTER (WHERE s.season_type = 'season_b') > 0
    ORDER BY s.year DESC, c.crop_name;
END;
$$;

-- ============================================================================
-- YEAR-OVER-YEAR TRENDS
-- ============================================================================

CREATE OR REPLACE FUNCTION agri.get_yield_trends(
    p_crop_code VARCHAR(20)
)
RETURNS TABLE (
    crop_name VARCHAR(100),
    year INTEGER,
    avg_yield DECIMAL,
    total_production DECIMAL,
    prev_year_yield DECIMAL,
    yoy_change_pct DECIMAL,
    trend TEXT
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    WITH yearly AS (
        SELECT 
            c.crop_name AS cname,
            s.year AS yr,
            ROUND(AVG(h.yield_per_hectare)::NUMERIC, 2) AS ayield,
            ROUND(SUM(h.total_yield_kg)::NUMERIC, 0) AS total_prod
        FROM agri.harvests h
        JOIN agri.crops c ON h.crop_id = c.crop_id
        JOIN agri.seasons s ON h.season_id = s.season_id
        WHERE c.crop_code = p_crop_code
        GROUP BY c.crop_name, s.year
    )
    SELECT 
        y.cname,
        y.yr,
        y.ayield,
        y.total_prod,
        LAG(y.ayield) OVER (ORDER BY y.yr) AS prev_yield,
        ROUND(
            ((y.ayield - LAG(y.ayield) OVER (ORDER BY y.yr)) / 
             NULLIF(LAG(y.ayield) OVER (ORDER BY y.yr), 0) * 100)::NUMERIC, 1
        ) AS yoy_pct,
        CASE 
            WHEN y.ayield > LAG(y.ayield) OVER (ORDER BY y.yr) THEN 'Improving'
            WHEN y.ayield < LAG(y.ayield) OVER (ORDER BY y.yr) THEN 'Declining'
            ELSE 'Stable'
        END
    FROM yearly y
    ORDER BY y.yr;
END;
$$;

COMMENT ON FUNCTION agri.get_regional_yield_summary IS 'Regional yield summary with rankings';
COMMENT ON FUNCTION agri.get_crop_performance IS 'Crop performance by district with benchmarking';
COMMENT ON FUNCTION agri.compare_seasons IS 'Season A vs Season B yield comparison';
COMMENT ON FUNCTION agri.get_yield_trends IS 'Year-over-year yield trends for a crop';
