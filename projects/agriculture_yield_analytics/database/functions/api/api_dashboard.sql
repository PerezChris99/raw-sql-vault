-- ============================================================================
-- API: Dashboard Endpoints
-- Purpose: JSONB API functions for dashboard integration
-- ============================================================================

SET search_path TO agri, public;

-- ============================================================================
-- NATIONAL DASHBOARD
-- ============================================================================

CREATE OR REPLACE FUNCTION agri.api_get_dashboard()
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
    v_result JSONB;
BEGIN
    SELECT jsonb_build_object(
        'summary', (
            SELECT jsonb_build_object(
                'total_farmers', COUNT(DISTINCT farmer_id),
                'total_farms', COUNT(DISTINCT farm_id),
                'total_harvests_this_year', COUNT(*) FILTER (
                    WHERE h.harvest_date >= DATE_TRUNC('year', CURRENT_DATE)
                ),
                'total_area_ha', ROUND(SUM(area_harvested_hectares)::NUMERIC, 0),
                'total_production_tonnes', ROUND(SUM(total_yield_kg / 1000)::NUMERIC, 0),
                'avg_yield_kg_ha', ROUND(AVG(yield_per_hectare)::NUMERIC, 0)
            )
            FROM agri.harvests h
            WHERE h.harvest_date >= CURRENT_DATE - INTERVAL '1 year'
        ),
        'top_crops', (
            SELECT COALESCE(jsonb_agg(crop_data), '[]'::JSONB)
            FROM (
                SELECT jsonb_build_object(
                    'crop_name', c.crop_name,
                    'total_production_tonnes', ROUND(SUM(h.total_yield_kg / 1000)::NUMERIC, 0),
                    'avg_yield', ROUND(AVG(h.yield_per_hectare)::NUMERIC, 0),
                    'farmer_count', COUNT(DISTINCT h.farmer_id)
                ) AS crop_data
                FROM agri.harvests h
                JOIN agri.crops c ON h.crop_id = c.crop_id
                WHERE h.harvest_date >= CURRENT_DATE - INTERVAL '1 year'
                GROUP BY c.crop_name
                ORDER BY SUM(h.total_yield_kg) DESC
                LIMIT 10
            ) top
        ),
        'regional_comparison', (
            SELECT COALESCE(jsonb_agg(region_data), '[]'::JSONB)
            FROM (
                SELECT jsonb_build_object(
                    'region', r.region_name,
                    'total_production_tonnes', ROUND(SUM(h.total_yield_kg / 1000)::NUMERIC, 0),
                    'avg_yield', ROUND(AVG(h.yield_per_hectare)::NUMERIC, 0),
                    'farmer_count', COUNT(DISTINCT h.farmer_id)
                ) AS region_data
                FROM agri.harvests h
                JOIN agri.districts d ON h.district_id = d.district_id
                JOIN agri.regions r ON d.region_id = r.region_id
                WHERE h.harvest_date >= CURRENT_DATE - INTERVAL '1 year'
                GROUP BY r.region_name
                ORDER BY SUM(h.total_yield_kg) DESC
            ) regions
        ),
        'seasonal_summary', (
            SELECT jsonb_build_object(
                'season_a_production', ROUND(SUM(h.total_yield_kg) FILTER (
                    WHERE s.season_type = 'season_a'
                ) / 1000, 0),
                'season_b_production', ROUND(SUM(h.total_yield_kg) FILTER (
                    WHERE s.season_type = 'season_b'
                ) / 1000, 0)
            )
            FROM agri.harvests h
            JOIN agri.seasons s ON h.season_id = s.season_id
            WHERE s.year = EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER
        ),
        'generated_at', CURRENT_TIMESTAMP
    ) INTO v_result;
    
    RETURN v_result;
END;
$$;

-- ============================================================================
-- FARMER DASHBOARD
-- ============================================================================

CREATE OR REPLACE FUNCTION agri.api_get_farmer_dashboard(p_farmer_code VARCHAR(20))
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
    v_result JSONB;
    v_farmer_id UUID;
BEGIN
    SELECT farmer_id INTO v_farmer_id FROM agri.farmers WHERE farmer_code = p_farmer_code;
    
    IF v_farmer_id IS NULL THEN
        RETURN jsonb_build_object('error', 'Farmer not found', 'code', p_farmer_code);
    END IF;
    
    SELECT jsonb_build_object(
        'farmer', (
            SELECT jsonb_build_object(
                'farmer_code', farmer_code,
                'name', first_name || ' ' || last_name,
                'district', (SELECT district_name FROM agri.districts WHERE district_id = f.district_id),
                'years_farming', years_farming,
                'registration_date', registration_date
            )
            FROM agri.farmers f
            WHERE farmer_id = v_farmer_id
        ),
        'farms', (
            SELECT COALESCE(jsonb_agg(jsonb_build_object(
                'farm_code', farm_code,
                'farm_name', farm_name,
                'total_area_ha', total_area_hectares,
                'size_class', size_class
            )), '[]'::JSONB)
            FROM agri.farms
            WHERE farmer_id = v_farmer_id
        ),
        'recent_harvests', (
            SELECT COALESCE(jsonb_agg(harvest_data), '[]'::JSONB)
            FROM (
                SELECT jsonb_build_object(
                    'harvest_code', h.harvest_code,
                    'crop', c.crop_name,
                    'harvest_date', h.harvest_date,
                    'area_ha', h.area_harvested_hectares,
                    'yield_kg', h.total_yield_kg,
                    'yield_per_ha', h.yield_per_hectare,
                    'quality', h.quality_grade,
                    'revenue', h.total_revenue
                ) AS harvest_data
                FROM agri.harvests h
                JOIN agri.crops c ON h.crop_id = c.crop_id
                WHERE h.farmer_id = v_farmer_id
                ORDER BY h.harvest_date DESC
                LIMIT 10
            ) recent
        ),
        'performance', (
            SELECT jsonb_build_object(
                'total_harvests', COUNT(*),
                'total_area_ha', ROUND(SUM(area_harvested_hectares)::NUMERIC, 2),
                'total_production_kg', ROUND(SUM(total_yield_kg)::NUMERIC, 0),
                'avg_yield_kg_ha', ROUND(AVG(yield_per_hectare)::NUMERIC, 0),
                'total_revenue', ROUND(SUM(total_revenue)::NUMERIC, 0),
                'best_crop', (
                    SELECT c.crop_name
                    FROM agri.harvests h2
                    JOIN agri.crops c ON h2.crop_id = c.crop_id
                    WHERE h2.farmer_id = v_farmer_id
                    GROUP BY c.crop_name
                    ORDER BY AVG(h2.yield_per_hectare) DESC
                    LIMIT 1
                )
            )
            FROM agri.harvests
            WHERE farmer_id = v_farmer_id
        ),
        'generated_at', CURRENT_TIMESTAMP
    ) INTO v_result;
    
    RETURN v_result;
END;
$$;

-- ============================================================================
-- CROP ANALYSIS API
-- ============================================================================

CREATE OR REPLACE FUNCTION agri.api_get_crop_analysis(p_crop_code VARCHAR(20))
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
    v_result JSONB;
BEGIN
    SELECT jsonb_build_object(
        'crop', (
            SELECT jsonb_build_object(
                'crop_code', crop_code,
                'crop_name', crop_name,
                'local_name', local_name,
                'scientific_name', scientific_name,
                'category', crop_type,
                'expected_yield_range', expected_yield_low || ' - ' || expected_yield_high || ' kg/ha',
                'current_price_per_kg', price_per_kg,
                'is_cash_crop', is_cash_crop,
                'is_export_crop', is_export_crop
            )
            FROM agri.crops
            WHERE crop_code = p_crop_code
        ),
        'top_districts', (
            SELECT COALESCE(jsonb_agg(district_data), '[]'::JSONB)
            FROM (
                SELECT jsonb_build_object(
                    'district', d.district_name,
                    'region', r.region_name,
                    'avg_yield', ROUND(AVG(h.yield_per_hectare)::NUMERIC, 0),
                    'total_production_tonnes', ROUND(SUM(h.total_yield_kg / 1000)::NUMERIC, 0),
                    'farmer_count', COUNT(DISTINCT h.farmer_id)
                ) AS district_data
                FROM agri.harvests h
                JOIN agri.crops c ON h.crop_id = c.crop_id
                JOIN agri.districts d ON h.district_id = d.district_id
                JOIN agri.regions r ON d.region_id = r.region_id
                WHERE c.crop_code = p_crop_code
                  AND h.harvest_date >= CURRENT_DATE - INTERVAL '2 years'
                GROUP BY d.district_name, r.region_name
                ORDER BY AVG(h.yield_per_hectare) DESC
                LIMIT 10
            ) top
        ),
        'yearly_trends', (
            SELECT COALESCE(jsonb_agg(trend_data ORDER BY year), '[]'::JSONB)
            FROM (
                SELECT jsonb_build_object(
                    'year', s.year,
                    'avg_yield', ROUND(AVG(h.yield_per_hectare)::NUMERIC, 0),
                    'total_production_tonnes', ROUND(SUM(h.total_yield_kg / 1000)::NUMERIC, 0)
                ) AS trend_data,
                s.year
                FROM agri.harvests h
                JOIN agri.crops c ON h.crop_id = c.crop_id
                JOIN agri.seasons s ON h.season_id = s.season_id
                WHERE c.crop_code = p_crop_code
                GROUP BY s.year
            ) trends
        ),
        'generated_at', CURRENT_TIMESTAMP
    ) INTO v_result;
    
    RETURN v_result;
END;
$$;

-- ============================================================================
-- HEALTH CHECK
-- ============================================================================

CREATE OR REPLACE FUNCTION agri.health_check()
RETURNS JSONB
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN jsonb_build_object(
        'status', 'healthy',
        'database', current_database(),
        'schema', 'agri',
        'timestamp', CURRENT_TIMESTAMP,
        'tables', (
            SELECT jsonb_object_agg(table_name, row_count)
            FROM (
                SELECT 'regions' AS table_name, COUNT(*)::BIGINT AS row_count FROM agri.regions
                UNION ALL SELECT 'districts', COUNT(*) FROM agri.districts
                UNION ALL SELECT 'crops', COUNT(*) FROM agri.crops
                UNION ALL SELECT 'farmers', COUNT(*) FROM agri.farmers
                UNION ALL SELECT 'farms', COUNT(*) FROM agri.farms
                UNION ALL SELECT 'harvests', COUNT(*) FROM agri.harvests
            ) counts
        )
    );
END;
$$;

COMMENT ON FUNCTION agri.api_get_dashboard IS 'National agricultural dashboard summary';
COMMENT ON FUNCTION agri.api_get_farmer_dashboard IS 'Individual farmer performance dashboard';
COMMENT ON FUNCTION agri.api_get_crop_analysis IS 'Detailed crop analysis with trends';
COMMENT ON FUNCTION agri.health_check IS 'System health check';
