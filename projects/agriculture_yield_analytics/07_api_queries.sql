-- ============================================================================
-- 🌾 AGRICULTURE YIELD ANALYTICS - API-READY FUNCTIONS
-- ============================================================================
-- File: 07_api_queries.sql
-- Purpose: Optimized, parameterized functions for application/API integration
-- Database: PostgreSQL 14+
-- Integration: FastAPI, REST APIs, GraphQL backends
-- ============================================================================

SET search_path TO agri, public;

-- ============================================================================
-- SECTION 1: JSON RESPONSE FUNCTIONS
-- ============================================================================

/*
All API functions return JSONB for easy integration with web frameworks.
Consistent response format:
{
    "success": true/false,
    "data": [...],
    "meta": {
        "total_count": n,
        "page": n,
        "page_size": n,
        "timestamp": "..."
    }
}
*/

-- 1.1 Generic paginated response builder
CREATE OR REPLACE FUNCTION agri.api_build_response(
    p_data JSONB,
    p_total_count INTEGER,
    p_page INTEGER,
    p_page_size INTEGER
)
RETURNS JSONB
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
    RETURN jsonb_build_object(
        'success', TRUE,
        'data', p_data,
        'meta', jsonb_build_object(
            'total_count', p_total_count,
            'page', p_page,
            'page_size', p_page_size,
            'total_pages', CEIL(p_total_count::DECIMAL / p_page_size),
            'has_next', (p_page * p_page_size) < p_total_count,
            'has_previous', p_page > 1,
            'timestamp', CURRENT_TIMESTAMP
        )
    );
END;
$$;

-- ============================================================================
-- SECTION 2: DASHBOARD API ENDPOINTS
-- ============================================================================

-- 2.1 GET /api/dashboard/summary
CREATE OR REPLACE FUNCTION agri.api_get_dashboard_summary()
RETURNS JSONB
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_result JSONB;
    v_current_season RECORD;
BEGIN
    SELECT * INTO v_current_season FROM agri.seasons WHERE is_current = TRUE;
    
    SELECT jsonb_build_object(
        'success', TRUE,
        'data', jsonb_build_object(
            'current_season', jsonb_build_object(
                'code', v_current_season.season_code,
                'name', v_current_season.season_name,
                'start_date', v_current_season.start_date,
                'end_date', v_current_season.end_date
            ),
            'metrics', jsonb_build_object(
                'total_farmers', COUNT(DISTINCT h.farmer_id),
                'total_farms', COUNT(DISTINCT h.farm_id),
                'total_harvests', COUNT(h.harvest_id),
                'total_area_ha', ROUND(SUM(h.area_harvested_hectares)::NUMERIC, 2),
                'total_production_kg', ROUND(SUM(h.total_yield_kg)::NUMERIC, 0),
                'total_production_tonnes', ROUND(SUM(h.total_yield_kg) / 1000::NUMERIC, 2),
                'total_revenue_ugx', ROUND(SUM(h.total_revenue)::NUMERIC, 0),
                'total_profit_ugx', ROUND(SUM(h.profit)::NUMERIC, 0),
                'avg_yield_per_ha', ROUND(AVG(h.yield_per_hectare)::NUMERIC, 2),
                'high_quality_pct', ROUND(100.0 * COUNT(*) FILTER (WHERE h.quality_grade IN ('grade_a', 'grade_b')) / NULLIF(COUNT(*), 0), 2)
            ),
            'top_crops', (
                SELECT jsonb_agg(crop_data)
                FROM (
                    SELECT jsonb_build_object(
                        'crop_name', c.crop_name,
                        'production_kg', SUM(h2.total_yield_kg),
                        'farmer_count', COUNT(DISTINCT h2.farmer_id)
                    ) AS crop_data
                    FROM agri.harvests h2
                    JOIN agri.crops c ON h2.crop_id = c.crop_id
                    WHERE h2.season_id = v_current_season.season_id
                    GROUP BY c.crop_name
                    ORDER BY SUM(h2.total_yield_kg) DESC
                    LIMIT 5
                ) t
            ),
            'top_regions', (
                SELECT jsonb_agg(region_data)
                FROM (
                    SELECT jsonb_build_object(
                        'region_name', r.region_name,
                        'production_kg', SUM(h2.total_yield_kg),
                        'avg_yield', ROUND(AVG(h2.yield_per_hectare)::NUMERIC, 2)
                    ) AS region_data
                    FROM agri.harvests h2
                    JOIN agri.districts d ON h2.district_id = d.district_id
                    JOIN agri.regions r ON d.region_id = r.region_id
                    WHERE h2.season_id = v_current_season.season_id
                    GROUP BY r.region_name
                    ORDER BY SUM(h2.total_yield_kg) DESC
                ) t
            )
        ),
        'meta', jsonb_build_object('timestamp', CURRENT_TIMESTAMP)
    ) INTO v_result
    FROM agri.harvests h
    WHERE h.season_id = v_current_season.season_id;
    
    RETURN v_result;
END;
$$;

-- 2.2 GET /api/dashboard/regional-performance
CREATE OR REPLACE FUNCTION agri.api_get_regional_performance(
    p_season_code VARCHAR(15) DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_season_id INTEGER;
BEGIN
    -- Get season ID
    IF p_season_code IS NULL THEN
        SELECT season_id INTO v_season_id FROM agri.seasons WHERE is_current = TRUE;
    ELSE
        SELECT season_id INTO v_season_id FROM agri.seasons WHERE season_code = p_season_code;
    END IF;
    
    RETURN jsonb_build_object(
        'success', TRUE,
        'data', (
            SELECT jsonb_agg(region_data ORDER BY production_rank)
            FROM (
                SELECT 
                    jsonb_build_object(
                        'region_name', r.region_name,
                        'district_count', COUNT(DISTINCT d.district_id),
                        'farmer_count', COUNT(DISTINCT h.farmer_id),
                        'production_kg', ROUND(SUM(h.total_yield_kg)::NUMERIC, 0),
                        'production_tonnes', ROUND(SUM(h.total_yield_kg) / 1000::NUMERIC, 2),
                        'avg_yield_per_ha', ROUND(AVG(h.yield_per_hectare)::NUMERIC, 2),
                        'total_area_ha', ROUND(SUM(h.area_harvested_hectares)::NUMERIC, 2),
                        'total_profit_ugx', ROUND(SUM(h.profit)::NUMERIC, 0),
                        'production_rank', RANK() OVER (ORDER BY SUM(h.total_yield_kg) DESC),
                        'efficiency_rank', RANK() OVER (ORDER BY AVG(h.yield_per_hectare) DESC)
                    ) AS region_data,
                    RANK() OVER (ORDER BY SUM(h.total_yield_kg) DESC) AS production_rank
                FROM agri.harvests h
                JOIN agri.districts d ON h.district_id = d.district_id
                JOIN agri.regions r ON d.region_id = r.region_id
                WHERE (v_season_id IS NULL OR h.season_id = v_season_id)
                GROUP BY r.region_id, r.region_name
            ) t
        ),
        'meta', jsonb_build_object('timestamp', CURRENT_TIMESTAMP)
    );
END;
$$;

-- ============================================================================
-- SECTION 3: HARVEST API ENDPOINTS
-- ============================================================================

-- 3.1 GET /api/harvests
CREATE OR REPLACE FUNCTION agri.api_get_harvests(
    p_page INTEGER DEFAULT 1,
    p_page_size INTEGER DEFAULT 20,
    p_farmer_code VARCHAR(20) DEFAULT NULL,
    p_district_code VARCHAR(10) DEFAULT NULL,
    p_crop_code VARCHAR(10) DEFAULT NULL,
    p_season_code VARCHAR(15) DEFAULT NULL,
    p_date_from DATE DEFAULT NULL,
    p_date_to DATE DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_total_count INTEGER;
    v_offset INTEGER;
    v_data JSONB;
BEGIN
    v_offset := (p_page - 1) * p_page_size;
    
    -- Get total count
    SELECT COUNT(*) INTO v_total_count
    FROM agri.harvests h
    JOIN agri.farmers f ON h.farmer_id = f.farmer_id
    JOIN agri.districts d ON h.district_id = d.district_id
    JOIN agri.crops c ON h.crop_id = c.crop_id
    JOIN agri.seasons s ON h.season_id = s.season_id
    WHERE (p_farmer_code IS NULL OR f.farmer_code = p_farmer_code)
    AND (p_district_code IS NULL OR d.district_code = p_district_code)
    AND (p_crop_code IS NULL OR c.crop_code = p_crop_code)
    AND (p_season_code IS NULL OR s.season_code = p_season_code)
    AND (p_date_from IS NULL OR h.harvest_date >= p_date_from)
    AND (p_date_to IS NULL OR h.harvest_date <= p_date_to);
    
    -- Get data
    SELECT jsonb_agg(harvest_row)
    INTO v_data
    FROM (
        SELECT jsonb_build_object(
            'harvest_id', h.harvest_id,
            'harvest_code', h.harvest_code,
            'farmer', jsonb_build_object(
                'code', f.farmer_code,
                'name', f.first_name || ' ' || f.last_name
            ),
            'location', jsonb_build_object(
                'district', d.district_name,
                'region', r.region_name
            ),
            'crop', jsonb_build_object(
                'code', c.crop_code,
                'name', c.crop_name,
                'category', c.category
            ),
            'season', jsonb_build_object(
                'code', s.season_code,
                'name', s.season_name
            ),
            'metrics', jsonb_build_object(
                'planting_date', h.planting_date,
                'harvest_date', h.harvest_date,
                'area_ha', h.area_harvested_hectares,
                'total_yield_kg', h.total_yield_kg,
                'yield_per_ha', h.yield_per_hectare,
                'quality_grade', h.quality_grade
            ),
            'financials', jsonb_build_object(
                'revenue', h.total_revenue,
                'cost', h.total_cost,
                'profit', h.profit
            )
        ) AS harvest_row
        FROM agri.harvests h
        JOIN agri.farmers f ON h.farmer_id = f.farmer_id
        JOIN agri.districts d ON h.district_id = d.district_id
        JOIN agri.regions r ON d.region_id = r.region_id
        JOIN agri.crops c ON h.crop_id = c.crop_id
        JOIN agri.seasons s ON h.season_id = s.season_id
        WHERE (p_farmer_code IS NULL OR f.farmer_code = p_farmer_code)
        AND (p_district_code IS NULL OR d.district_code = p_district_code)
        AND (p_crop_code IS NULL OR c.crop_code = p_crop_code)
        AND (p_season_code IS NULL OR s.season_code = p_season_code)
        AND (p_date_from IS NULL OR h.harvest_date >= p_date_from)
        AND (p_date_to IS NULL OR h.harvest_date <= p_date_to)
        ORDER BY h.harvest_date DESC
        LIMIT p_page_size OFFSET v_offset
    ) t;
    
    RETURN agri.api_build_response(COALESCE(v_data, '[]'::JSONB), v_total_count, p_page, p_page_size);
END;
$$;

-- 3.2 GET /api/harvests/:id
CREATE OR REPLACE FUNCTION agri.api_get_harvest_by_id(
    p_harvest_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
    RETURN jsonb_build_object(
        'success', TRUE,
        'data', (
            SELECT jsonb_build_object(
                'harvest_id', h.harvest_id,
                'harvest_code', h.harvest_code,
                'farmer', jsonb_build_object(
                    'farmer_id', f.farmer_id,
                    'code', f.farmer_code,
                    'name', f.first_name || ' ' || f.last_name,
                    'phone', f.phone_primary
                ),
                'farm', jsonb_build_object(
                    'farm_id', fm.farm_id,
                    'code', fm.farm_code,
                    'name', fm.farm_name,
                    'size_class', fm.size_class
                ),
                'location', jsonb_build_object(
                    'district_code', d.district_code,
                    'district', d.district_name,
                    'region_code', r.region_code,
                    'region', r.region_name
                ),
                'crop', jsonb_build_object(
                    'crop_id', c.crop_id,
                    'code', c.crop_code,
                    'name', c.crop_name,
                    'category', c.category,
                    'variety', cv.variety_name
                ),
                'season', jsonb_build_object(
                    'season_id', s.season_id,
                    'code', s.season_code,
                    'name', s.season_name,
                    'year', s.year
                ),
                'dates', jsonb_build_object(
                    'planting_date', h.planting_date,
                    'harvest_date', h.harvest_date,
                    'growth_days', h.harvest_date - h.planting_date
                ),
                'production', jsonb_build_object(
                    'area_hectares', h.area_harvested_hectares,
                    'total_yield_kg', h.total_yield_kg,
                    'yield_per_hectare', h.yield_per_hectare,
                    'quality_grade', h.quality_grade,
                    'benchmark_yield', c.avg_national_yield,
                    'vs_benchmark_pct', ROUND((h.yield_per_hectare / NULLIF(c.avg_national_yield, 0) - 1) * 100, 2)
                ),
                'sales', jsonb_build_object(
                    'quantity_sold_kg', h.quantity_sold_kg,
                    'quantity_consumed_kg', h.quantity_consumed_kg,
                    'quantity_stored_kg', h.quantity_stored_kg,
                    'price_per_kg', h.sale_price_per_kg,
                    'total_revenue', h.total_revenue
                ),
                'costs', jsonb_build_object(
                    'seed_cost', h.seed_cost,
                    'fertilizer_cost', h.fertilizer_cost,
                    'pesticide_cost', h.pesticide_cost,
                    'labor_cost', h.labor_cost,
                    'transport_cost', h.transport_cost,
                    'other_costs', h.other_costs,
                    'total_cost', h.total_cost
                ),
                'profit', jsonb_build_object(
                    'total_profit', h.profit,
                    'profit_per_hectare', ROUND((h.profit / NULLIF(h.area_harvested_hectares, 0))::NUMERIC, 2),
                    'roi_percent', ROUND((h.profit / NULLIF(h.total_cost, 0) * 100)::NUMERIC, 2)
                ),
                'metadata', jsonb_build_object(
                    'verified', h.verified,
                    'verified_by', h.verified_by,
                    'verified_at', h.verified_at,
                    'data_source', h.data_source,
                    'created_at', h.created_at,
                    'updated_at', h.updated_at
                )
            )
            FROM agri.harvests h
            JOIN agri.farmers f ON h.farmer_id = f.farmer_id
            JOIN agri.farms fm ON h.farm_id = fm.farm_id
            JOIN agri.districts d ON h.district_id = d.district_id
            JOIN agri.regions r ON d.region_id = r.region_id
            JOIN agri.crops c ON h.crop_id = c.crop_id
            LEFT JOIN agri.crop_varieties cv ON h.variety_id = cv.variety_id
            JOIN agri.seasons s ON h.season_id = s.season_id
            WHERE h.harvest_id = p_harvest_id
        ),
        'meta', jsonb_build_object('timestamp', CURRENT_TIMESTAMP)
    );
END;
$$;

-- 3.3 POST /api/harvests (Create via function)
CREATE OR REPLACE FUNCTION agri.api_create_harvest(
    p_data JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
    v_harvest_id UUID;
BEGIN
    -- Validate required fields
    IF NOT (p_data ? 'farmer_code' AND p_data ? 'farm_code' AND p_data ? 'crop_code' 
            AND p_data ? 'season_code' AND p_data ? 'planting_date' 
            AND p_data ? 'harvest_date' AND p_data ? 'area_hectares' AND p_data ? 'total_yield_kg') THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'error', 'Missing required fields: farmer_code, farm_code, crop_code, season_code, planting_date, harvest_date, area_hectares, total_yield_kg'
        );
    END IF;
    
    -- Create harvest using existing function
    BEGIN
        v_harvest_id := agri.record_harvest(
            p_farmer_code := p_data->>'farmer_code',
            p_farm_code := p_data->>'farm_code',
            p_crop_code := p_data->>'crop_code',
            p_season_code := p_data->>'season_code',
            p_planting_date := (p_data->>'planting_date')::DATE,
            p_harvest_date := (p_data->>'harvest_date')::DATE,
            p_area_hectares := (p_data->>'area_hectares')::DECIMAL,
            p_total_yield_kg := (p_data->>'total_yield_kg')::DECIMAL,
            p_quality_grade := COALESCE((p_data->>'quality_grade')::agri.quality_grade, 'grade_b'),
            p_seed_cost := COALESCE((p_data->>'seed_cost')::DECIMAL, 0),
            p_fertilizer_cost := COALESCE((p_data->>'fertilizer_cost')::DECIMAL, 0),
            p_labor_cost := COALESCE((p_data->>'labor_cost')::DECIMAL, 0),
            p_sale_price_per_kg := (p_data->>'sale_price_per_kg')::DECIMAL,
            p_quantity_sold_kg := (p_data->>'quantity_sold_kg')::DECIMAL
        );
        
        RETURN jsonb_build_object(
            'success', TRUE,
            'data', jsonb_build_object('harvest_id', v_harvest_id),
            'meta', jsonb_build_object('timestamp', CURRENT_TIMESTAMP)
        );
    EXCEPTION WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'error', SQLERRM
        );
    END;
END;
$$;

-- ============================================================================
-- SECTION 4: ANALYTICS API ENDPOINTS
-- ============================================================================

-- 4.1 GET /api/analytics/yield-trends
CREATE OR REPLACE FUNCTION agri.api_get_yield_trends(
    p_crop_code VARCHAR(10) DEFAULT NULL,
    p_district_code VARCHAR(10) DEFAULT NULL,
    p_years INTEGER DEFAULT 5
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
    RETURN jsonb_build_object(
        'success', TRUE,
        'data', (
            SELECT jsonb_agg(trend_row ORDER BY year, season_type)
            FROM (
                SELECT jsonb_build_object(
                    'crop', c.crop_name,
                    'year', s.year,
                    'season_type', s.season_type,
                    'avg_yield', ROUND(AVG(h.yield_per_hectare)::NUMERIC, 2),
                    'total_production', ROUND(SUM(h.total_yield_kg)::NUMERIC, 0),
                    'sample_count', COUNT(*),
                    'prev_yield', ROUND(LAG(AVG(h.yield_per_hectare)) OVER (PARTITION BY c.crop_id ORDER BY s.year, s.season_type)::NUMERIC, 2),
                    'yoy_change_pct', ROUND(((AVG(h.yield_per_hectare) / NULLIF(LAG(AVG(h.yield_per_hectare)) OVER (PARTITION BY c.crop_id ORDER BY s.year, s.season_type), 0) - 1) * 100)::NUMERIC, 2)
                ) AS trend_row,
                s.year,
                s.season_type
                FROM agri.harvests h
                JOIN agri.crops c ON h.crop_id = c.crop_id
                JOIN agri.seasons s ON h.season_id = s.season_id
                LEFT JOIN agri.districts d ON h.district_id = d.district_id
                WHERE s.year >= EXTRACT(YEAR FROM CURRENT_DATE) - p_years
                AND (p_crop_code IS NULL OR c.crop_code = p_crop_code)
                AND (p_district_code IS NULL OR d.district_code = p_district_code)
                GROUP BY c.crop_id, c.crop_name, s.year, s.season_type
                ORDER BY s.year, s.season_type
            ) t
        ),
        'meta', jsonb_build_object(
            'years_analyzed', p_years,
            'crop_filter', p_crop_code,
            'district_filter', p_district_code,
            'timestamp', CURRENT_TIMESTAMP
        )
    );
END;
$$;

-- 4.2 GET /api/analytics/forecast
CREATE OR REPLACE FUNCTION agri.api_get_forecast(
    p_crop_code VARCHAR(10),
    p_district_code VARCHAR(10) DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
    RETURN jsonb_build_object(
        'success', TRUE,
        'data', (
            SELECT jsonb_agg(forecast_row)
            FROM (
                SELECT jsonb_build_object(
                    'crop_name', crop_name,
                    'district_name', COALESCE(district_name, 'National'),
                    'forecast_yield_per_ha', forecast_yield_per_ha,
                    'lower_bound_95', lower_bound,
                    'upper_bound_95', upper_bound,
                    'confidence_level', confidence_level,
                    'data_points', data_points,
                    'trend', trend
                ) AS forecast_row
                FROM agri.forecast_yield(p_crop_code, p_district_code, 0.95)
            ) t
        ),
        'meta', jsonb_build_object(
            'crop_code', p_crop_code,
            'district_code', p_district_code,
            'timestamp', CURRENT_TIMESTAMP
        )
    );
END;
$$;

-- 4.3 GET /api/analytics/rankings
CREATE OR REPLACE FUNCTION agri.api_get_farmer_rankings(
    p_page INTEGER DEFAULT 1,
    p_page_size INTEGER DEFAULT 20,
    p_district_code VARCHAR(10) DEFAULT NULL,
    p_performance_tier VARCHAR(20) DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_total_count INTEGER;
    v_offset INTEGER;
BEGIN
    v_offset := (p_page - 1) * p_page_size;
    
    SELECT COUNT(*) INTO v_total_count
    FROM agri.mv_farmer_leaderboard fl
    WHERE (p_district_code IS NULL OR fl.district_name = (
        SELECT district_name FROM agri.districts WHERE district_code = p_district_code
    ))
    AND (p_performance_tier IS NULL OR fl.performance_tier = p_performance_tier);
    
    RETURN agri.api_build_response(
        (
            SELECT jsonb_agg(farmer_row)
            FROM (
                SELECT jsonb_build_object(
                    'rank', ROW_NUMBER() OVER (ORDER BY fl.avg_yield_per_ha DESC),
                    'farmer_code', fl.farmer_code,
                    'farmer_name', fl.farmer_name,
                    'district', fl.district_name,
                    'region', fl.region_name,
                    'metrics', jsonb_build_object(
                        'seasons_active', fl.seasons_active,
                        'total_harvests', fl.total_harvests,
                        'crops_grown', fl.crops_grown,
                        'total_area_ha', ROUND(fl.total_area_ha::NUMERIC, 2),
                        'total_production_kg', ROUND(fl.total_production_kg::NUMERIC, 0),
                        'avg_yield_per_ha', ROUND(fl.avg_yield_per_ha::NUMERIC, 2)
                    ),
                    'financials', jsonb_build_object(
                        'total_revenue', ROUND(fl.total_revenue::NUMERIC, 0),
                        'total_profit', ROUND(fl.total_profit::NUMERIC, 0),
                        'profit_per_ha', ROUND(fl.profit_per_ha::NUMERIC, 0)
                    ),
                    'performance_tier', fl.performance_tier,
                    'yield_percentile', ROUND((fl.yield_percentile * 100)::NUMERIC, 1)
                ) AS farmer_row
                FROM agri.mv_farmer_leaderboard fl
                WHERE (p_district_code IS NULL OR fl.district_name = (
                    SELECT district_name FROM agri.districts WHERE district_code = p_district_code
                ))
                AND (p_performance_tier IS NULL OR fl.performance_tier = p_performance_tier)
                ORDER BY fl.avg_yield_per_ha DESC
                LIMIT p_page_size OFFSET v_offset
            ) t
        ),
        v_total_count,
        p_page,
        p_page_size
    );
END;
$$;

-- ============================================================================
-- SECTION 5: LOOKUP API ENDPOINTS
-- ============================================================================

-- 5.1 GET /api/lookups/regions
CREATE OR REPLACE FUNCTION agri.api_get_regions()
RETURNS JSONB
LANGUAGE sql
STABLE
AS $$
    SELECT jsonb_build_object(
        'success', TRUE,
        'data', jsonb_agg(
            jsonb_build_object(
                'region_id', region_id,
                'region_code', region_code,
                'region_name', region_name,
                'climate_zone', climate_zone
            ) ORDER BY region_name
        )
    )
    FROM agri.regions WHERE is_active = TRUE;
$$;

-- 5.2 GET /api/lookups/districts
CREATE OR REPLACE FUNCTION agri.api_get_districts(
    p_region_code VARCHAR(10) DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
    RETURN jsonb_build_object(
        'success', TRUE,
        'data', (
            SELECT jsonb_agg(
                jsonb_build_object(
                    'district_id', d.district_id,
                    'district_code', d.district_code,
                    'district_name', d.district_name,
                    'region_code', r.region_code,
                    'region_name', r.region_name,
                    'farming_households', d.farming_households
                ) ORDER BY d.district_name
            )
            FROM agri.districts d
            JOIN agri.regions r ON d.region_id = r.region_id
            WHERE d.is_active = TRUE
            AND (p_region_code IS NULL OR r.region_code = p_region_code)
        )
    );
END;
$$;

-- 5.3 GET /api/lookups/crops
CREATE OR REPLACE FUNCTION agri.api_get_crops(
    p_category agri.crop_category DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
    RETURN jsonb_build_object(
        'success', TRUE,
        'data', (
            SELECT jsonb_agg(
                jsonb_build_object(
                    'crop_id', c.crop_id,
                    'crop_code', c.crop_code,
                    'crop_name', c.crop_name,
                    'category', c.category,
                    'growth_period_days', c.growth_period_days,
                    'is_export_crop', c.is_export_crop,
                    'avg_national_yield', c.avg_national_yield,
                    'varieties', (
                        SELECT jsonb_agg(
                            jsonb_build_object(
                                'variety_id', cv.variety_id,
                                'variety_code', cv.variety_code,
                                'variety_name', cv.variety_name,
                                'is_hybrid', cv.is_hybrid,
                                'is_drought_resistant', cv.is_drought_resistant
                            )
                        )
                        FROM agri.crop_varieties cv
                        WHERE cv.crop_id = c.crop_id AND cv.is_active = TRUE
                    )
                ) ORDER BY c.crop_name
            )
            FROM agri.crops c
            WHERE c.is_active = TRUE
            AND (p_category IS NULL OR c.category = p_category)
        )
    );
END;
$$;

-- 5.4 GET /api/lookups/seasons
CREATE OR REPLACE FUNCTION agri.api_get_seasons(
    p_year INTEGER DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
    RETURN jsonb_build_object(
        'success', TRUE,
        'data', (
            SELECT jsonb_agg(
                jsonb_build_object(
                    'season_id', s.season_id,
                    'season_code', s.season_code,
                    'season_name', s.season_name,
                    'season_type', s.season_type,
                    'year', s.year,
                    'start_date', s.start_date,
                    'end_date', s.end_date,
                    'is_current', s.is_current
                ) ORDER BY s.year DESC, s.season_type DESC
            )
            FROM agri.seasons s
            WHERE (p_year IS NULL OR s.year = p_year)
        )
    );
END;
$$;

-- ============================================================================
-- SECTION 6: SEARCH API ENDPOINTS
-- ============================================================================

-- 6.1 GET /api/search/farmers
CREATE OR REPLACE FUNCTION agri.api_search_farmers(
    p_query TEXT,
    p_limit INTEGER DEFAULT 20
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
    RETURN jsonb_build_object(
        'success', TRUE,
        'data', (
            SELECT jsonb_agg(farmer_row)
            FROM (
                SELECT jsonb_build_object(
                    'farmer_id', f.farmer_id,
                    'farmer_code', f.farmer_code,
                    'farmer_name', f.first_name || ' ' || f.last_name,
                    'phone', f.phone_primary,
                    'district', d.district_name,
                    'region', r.region_name,
                    'village', f.village
                ) AS farmer_row
                FROM agri.farmers f
                JOIN agri.districts d ON f.district_id = d.district_id
                JOIN agri.regions r ON d.region_id = r.region_id
                WHERE f.search_vector @@ plainto_tsquery('english', p_query)
                OR f.farmer_code ILIKE '%' || p_query || '%'
                OR f.phone_primary LIKE '%' || p_query || '%'
                ORDER BY ts_rank(f.search_vector, plainto_tsquery('english', p_query)) DESC
                LIMIT p_limit
            ) t
        ),
        'meta', jsonb_build_object(
            'query', p_query,
            'timestamp', CURRENT_TIMESTAMP
        )
    );
END;
$$;

-- ============================================================================
-- VERIFICATION
-- ============================================================================

DO $$
DECLARE
    api_func_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO api_func_count
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'agri' AND p.proname LIKE 'api_%';
    
    RAISE NOTICE '=====================================';
    RAISE NOTICE 'API FUNCTIONS CREATED SUCCESSFULLY';
    RAISE NOTICE '=====================================';
    RAISE NOTICE 'API functions: %', api_func_count;
    RAISE NOTICE '';
    RAISE NOTICE 'Available endpoints:';
    RAISE NOTICE '  - api_get_dashboard_summary()';
    RAISE NOTICE '  - api_get_regional_performance(season_code)';
    RAISE NOTICE '  - api_get_harvests(page, filters...)';
    RAISE NOTICE '  - api_get_harvest_by_id(harvest_id)';
    RAISE NOTICE '  - api_create_harvest(json_data)';
    RAISE NOTICE '  - api_get_yield_trends(crop, district, years)';
    RAISE NOTICE '  - api_get_forecast(crop, district)';
    RAISE NOTICE '  - api_get_farmer_rankings(page, filters...)';
    RAISE NOTICE '  - api_get_regions()';
    RAISE NOTICE '  - api_get_districts(region)';
    RAISE NOTICE '  - api_get_crops(category)';
    RAISE NOTICE '  - api_get_seasons(year)';
    RAISE NOTICE '  - api_search_farmers(query)';
    RAISE NOTICE '=====================================';
END $$;
