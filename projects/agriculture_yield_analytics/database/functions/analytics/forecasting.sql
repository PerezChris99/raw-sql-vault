-- ============================================================================
-- Analytics: Yield Forecasting Functions
-- Purpose: Predictive analytics for crop yields
-- ============================================================================

SET search_path TO agri, public;

-- ============================================================================
-- LINEAR REGRESSION FORECAST
-- ============================================================================

CREATE OR REPLACE FUNCTION agri.forecast_yield(
    p_crop_code VARCHAR(20),
    p_district_code VARCHAR(10) DEFAULT NULL,
    p_forecast_years INTEGER DEFAULT 2
)
RETURNS TABLE (
    crop_name VARCHAR(100),
    district_name VARCHAR(100),
    forecast_year INTEGER,
    predicted_yield DECIMAL,
    lower_bound DECIMAL,
    upper_bound DECIMAL,
    confidence_pct DECIMAL,
    trend_direction TEXT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_slope DECIMAL;
    v_intercept DECIMAL;
    v_r_squared DECIMAL;
    v_stddev DECIMAL;
    v_max_year INTEGER;
BEGIN
    -- Calculate linear regression parameters
    WITH historical AS (
        SELECT 
            s.year::DECIMAL AS x,
            AVG(h.yield_per_hectare)::DECIMAL AS y
        FROM agri.harvests h
        JOIN agri.crops c ON h.crop_id = c.crop_id
        JOIN agri.seasons s ON h.season_id = s.season_id
        JOIN agri.districts d ON h.district_id = d.district_id
        WHERE c.crop_code = p_crop_code
          AND (p_district_code IS NULL OR d.district_code = p_district_code)
        GROUP BY s.year
        HAVING COUNT(*) >= 3
    ),
    regression AS (
        SELECT 
            REGR_SLOPE(y, x) AS slope,
            REGR_INTERCEPT(y, x) AS intercept,
            REGR_R2(y, x) AS r2,
            STDDEV(y) AS std,
            MAX(x)::INTEGER AS max_yr
        FROM historical
    )
    SELECT slope, intercept, r2, std, max_yr
    INTO v_slope, v_intercept, v_r_squared, v_stddev, v_max_year
    FROM regression;
    
    IF v_slope IS NULL THEN
        RAISE NOTICE 'Insufficient data for forecasting';
        RETURN;
    END IF;
    
    RETURN QUERY
    SELECT 
        c.crop_name,
        COALESCE(d.district_name, 'All Districts'::VARCHAR(100)),
        (v_max_year + generate_series)::INTEGER,
        ROUND((v_intercept + v_slope * (v_max_year + generate_series))::NUMERIC, 2),
        ROUND(((v_intercept + v_slope * (v_max_year + generate_series)) - 1.96 * v_stddev)::NUMERIC, 2),
        ROUND(((v_intercept + v_slope * (v_max_year + generate_series)) + 1.96 * v_stddev)::NUMERIC, 2),
        ROUND((COALESCE(v_r_squared, 0) * 100)::NUMERIC, 1),
        CASE 
            WHEN v_slope > 0 THEN 'Increasing'
            WHEN v_slope < 0 THEN 'Decreasing'
            ELSE 'Stable'
        END
    FROM generate_series(1, p_forecast_years)
    CROSS JOIN agri.crops c
    LEFT JOIN agri.districts d ON d.district_code = p_district_code
    WHERE c.crop_code = p_crop_code;
END;
$$;

-- ============================================================================
-- WEATHER-BASED YIELD PREDICTION
-- ============================================================================

CREATE OR REPLACE FUNCTION agri.predict_yield_by_weather(
    p_crop_code VARCHAR(20),
    p_district_code VARCHAR(10),
    p_expected_rainfall_mm DECIMAL
)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
    v_result JSONB;
    v_correlation DECIMAL;
    v_predicted_yield DECIMAL;
BEGIN
    -- Calculate rainfall-yield correlation
    WITH crop_weather AS (
        SELECT 
            h.yield_per_hectare,
            COALESCE(s.actual_rainfall_mm, s.expected_rainfall_mm) AS rainfall
        FROM agri.harvests h
        JOIN agri.crops c ON h.crop_id = c.crop_id
        JOIN agri.districts d ON h.district_id = d.district_id
        JOIN agri.seasons s ON h.season_id = s.season_id
        WHERE c.crop_code = p_crop_code
          AND d.district_code = p_district_code
          AND s.actual_rainfall_mm IS NOT NULL
    )
    SELECT 
        CORR(rainfall, yield_per_hectare),
        AVG(yield_per_hectare) + 
            CORR(rainfall, yield_per_hectare) * STDDEV(yield_per_hectare) / STDDEV(rainfall) *
            (p_expected_rainfall_mm - AVG(rainfall))
    INTO v_correlation, v_predicted_yield
    FROM crop_weather;
    
    SELECT jsonb_build_object(
        'crop_code', p_crop_code,
        'district_code', p_district_code,
        'expected_rainfall_mm', p_expected_rainfall_mm,
        'rainfall_yield_correlation', ROUND(COALESCE(v_correlation, 0)::NUMERIC, 3),
        'predicted_yield_kg_per_ha', ROUND(COALESCE(v_predicted_yield, 0)::NUMERIC, 2),
        'confidence_level', CASE 
            WHEN ABS(v_correlation) > 0.7 THEN 'High'
            WHEN ABS(v_correlation) > 0.4 THEN 'Medium'
            ELSE 'Low'
        END,
        'generated_at', CURRENT_TIMESTAMP
    ) INTO v_result;
    
    RETURN v_result;
END;
$$;

-- ============================================================================
-- PRODUCTION FORECAST
-- ============================================================================

CREATE OR REPLACE FUNCTION agri.forecast_production(
    p_year INTEGER,
    p_region_code VARCHAR(10) DEFAULT NULL
)
RETURNS TABLE (
    crop_name VARCHAR(100),
    region_name VARCHAR(100),
    expected_area_ha DECIMAL,
    expected_yield_kg_ha DECIMAL,
    expected_production_tonnes DECIMAL,
    growth_vs_last_year_pct DECIMAL
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    WITH last_year AS (
        SELECT 
            c.crop_id,
            r.region_id,
            SUM(h.area_harvested_hectares) AS area,
            AVG(h.yield_per_hectare) AS yield,
            SUM(h.total_yield_kg) AS production
        FROM agri.harvests h
        JOIN agri.crops c ON h.crop_id = c.crop_id
        JOIN agri.districts d ON h.district_id = d.district_id
        JOIN agri.regions r ON d.region_id = r.region_id
        JOIN agri.seasons s ON h.season_id = s.season_id
        WHERE s.year = p_year - 1
          AND (p_region_code IS NULL OR r.region_code = p_region_code)
        GROUP BY c.crop_id, r.region_id
    ),
    growth_rate AS (
        SELECT 
            c.crop_id,
            r.region_id,
            AVG(h.yield_per_hectare / NULLIF(ly.yield, 0) - 1) AS yield_growth
        FROM agri.harvests h
        JOIN agri.crops c ON h.crop_id = c.crop_id
        JOIN agri.districts d ON h.district_id = d.district_id
        JOIN agri.regions r ON d.region_id = r.region_id
        JOIN agri.seasons s ON h.season_id = s.season_id
        JOIN last_year ly ON c.crop_id = ly.crop_id AND r.region_id = ly.region_id
        WHERE s.year = p_year - 1
        GROUP BY c.crop_id, r.region_id
    )
    SELECT 
        c.crop_name,
        r.region_name,
        ROUND(ly.area * 1.02, 2),  -- Assume 2% area growth
        ROUND((ly.yield * (1 + COALESCE(gr.yield_growth, 0.03)))::NUMERIC, 2),
        ROUND((ly.area * 1.02 * ly.yield * (1 + COALESCE(gr.yield_growth, 0.03)) / 1000)::NUMERIC, 2),
        ROUND((COALESCE(gr.yield_growth, 0.03) * 100)::NUMERIC, 1)
    FROM last_year ly
    JOIN agri.crops c ON ly.crop_id = c.crop_id
    JOIN agri.regions r ON ly.region_id = r.region_id
    LEFT JOIN growth_rate gr ON ly.crop_id = gr.crop_id AND ly.region_id = gr.region_id
    ORDER BY r.region_name, c.crop_name;
END;
$$;

COMMENT ON FUNCTION agri.forecast_yield IS 'Linear regression-based yield forecast';
COMMENT ON FUNCTION agri.predict_yield_by_weather IS 'Weather-correlated yield prediction';
COMMENT ON FUNCTION agri.forecast_production IS 'Regional production forecast for upcoming year';
