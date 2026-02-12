-- ============================================================================
-- 🌾 AGRICULTURE YIELD ANALYTICS - STORED PROCEDURES & FUNCTIONS
-- ============================================================================
-- File: 05_procedures.sql
-- Purpose: Reusable business logic functions and procedures
-- Database: PostgreSQL 14+
-- ============================================================================

SET search_path TO agri, public;

-- ============================================================================
-- SECTION 1: DATA ENTRY PROCEDURES
-- ============================================================================

-- 1.1 Register a new farmer
CREATE OR REPLACE FUNCTION agri.register_farmer(
    p_first_name VARCHAR(100),
    p_last_name VARCHAR(100),
    p_gender CHAR(1),
    p_phone VARCHAR(20),
    p_district_code VARCHAR(10),
    p_village VARCHAR(100) DEFAULT NULL,
    p_years_farming INTEGER DEFAULT 0
)
RETURNS UUID
LANGUAGE plpgsql
AS $$
DECLARE
    v_farmer_id UUID;
    v_district_id INTEGER;
    v_farmer_code VARCHAR(20);
BEGIN
    -- Get district ID
    SELECT district_id INTO v_district_id
    FROM agri.districts WHERE district_code = p_district_code;
    
    IF v_district_id IS NULL THEN
        RAISE EXCEPTION 'District code % not found', p_district_code;
    END IF;
    
    -- Generate farmer code
    v_farmer_code := 'FRM-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' || 
                     LPAD(nextval('agri.farmer_seq')::TEXT, 4, '0');
    
    -- Insert farmer
    INSERT INTO agri.farmers (
        farmer_code, first_name, last_name, gender, 
        phone_primary, district_id, village, years_farming
    )
    VALUES (
        v_farmer_code, p_first_name, p_last_name, p_gender,
        p_phone, v_district_id, p_village, p_years_farming
    )
    RETURNING farmer_id INTO v_farmer_id;
    
    RETURN v_farmer_id;
END;
$$;

-- Create sequence for farmer codes
CREATE SEQUENCE IF NOT EXISTS agri.farmer_seq START 1;

-- 1.2 Record a harvest
CREATE OR REPLACE FUNCTION agri.record_harvest(
    p_farmer_code VARCHAR(20),
    p_farm_code VARCHAR(20),
    p_crop_code VARCHAR(10),
    p_season_code VARCHAR(15),
    p_planting_date DATE,
    p_harvest_date DATE,
    p_area_hectares DECIMAL(10,2),
    p_total_yield_kg DECIMAL(14,2),
    p_quality_grade agri.quality_grade DEFAULT 'grade_b',
    p_seed_cost DECIMAL(12,2) DEFAULT 0,
    p_fertilizer_cost DECIMAL(12,2) DEFAULT 0,
    p_labor_cost DECIMAL(12,2) DEFAULT 0,
    p_sale_price_per_kg DECIMAL(10,2) DEFAULT NULL,
    p_quantity_sold_kg DECIMAL(14,2) DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
AS $$
DECLARE
    v_harvest_id UUID;
    v_farmer_id UUID;
    v_farm_id UUID;
    v_crop_id INTEGER;
    v_season_id INTEGER;
    v_district_id INTEGER;
    v_total_revenue DECIMAL(14,2);
BEGIN
    -- Validate and get IDs
    SELECT farmer_id INTO v_farmer_id FROM agri.farmers WHERE farmer_code = p_farmer_code;
    IF v_farmer_id IS NULL THEN
        RAISE EXCEPTION 'Farmer % not found', p_farmer_code;
    END IF;
    
    SELECT farm_id, district_id INTO v_farm_id, v_district_id 
    FROM agri.farms WHERE farm_code = p_farm_code;
    IF v_farm_id IS NULL THEN
        RAISE EXCEPTION 'Farm % not found', p_farm_code;
    END IF;
    
    SELECT crop_id INTO v_crop_id FROM agri.crops WHERE crop_code = p_crop_code;
    IF v_crop_id IS NULL THEN
        RAISE EXCEPTION 'Crop % not found', p_crop_code;
    END IF;
    
    SELECT season_id INTO v_season_id FROM agri.seasons WHERE season_code = p_season_code;
    IF v_season_id IS NULL THEN
        RAISE EXCEPTION 'Season % not found', p_season_code;
    END IF;
    
    -- Calculate revenue if sold
    v_total_revenue := COALESCE(p_quantity_sold_kg * p_sale_price_per_kg, 0);
    
    -- Insert harvest record
    INSERT INTO agri.harvests (
        farmer_id, farm_id, crop_id, season_id, district_id,
        planting_date, harvest_date, area_harvested_hectares, total_yield_kg,
        quality_grade, seed_cost, fertilizer_cost, labor_cost,
        quantity_sold_kg, sale_price_per_kg, total_revenue,
        created_at
    )
    VALUES (
        v_farmer_id, v_farm_id, v_crop_id, v_season_id, v_district_id,
        p_planting_date, p_harvest_date, p_area_hectares, p_total_yield_kg,
        p_quality_grade, p_seed_cost, p_fertilizer_cost, p_labor_cost,
        p_quantity_sold_kg, p_sale_price_per_kg, v_total_revenue,
        CURRENT_TIMESTAMP
    )
    RETURNING harvest_id INTO v_harvest_id;
    
    RETURN v_harvest_id;
END;
$$;

-- ============================================================================
-- SECTION 2: ANALYTICS FUNCTIONS
-- ============================================================================

-- 2.1 Get regional yield summary
CREATE OR REPLACE FUNCTION agri.get_regional_yield_summary(
    p_season_code VARCHAR(15) DEFAULT NULL,
    p_crop_code VARCHAR(10) DEFAULT NULL
)
RETURNS TABLE (
    region_name VARCHAR,
    crop_name VARCHAR,
    season_name VARCHAR,
    total_farmers BIGINT,
    total_harvests BIGINT,
    total_area_ha DECIMAL,
    total_yield_kg DECIMAL,
    avg_yield_per_ha DECIMAL,
    min_yield DECIMAL,
    max_yield DECIMAL
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        r.region_name,
        c.crop_name,
        s.season_name,
        COUNT(DISTINCT h.farmer_id)::BIGINT,
        COUNT(h.harvest_id)::BIGINT,
        ROUND(SUM(h.area_harvested_hectares)::DECIMAL, 2),
        ROUND(SUM(h.total_yield_kg)::DECIMAL, 2),
        ROUND(AVG(h.yield_per_hectare)::DECIMAL, 2),
        ROUND(MIN(h.yield_per_hectare)::DECIMAL, 2),
        ROUND(MAX(h.yield_per_hectare)::DECIMAL, 2)
    FROM agri.harvests h
    JOIN agri.districts d ON h.district_id = d.district_id
    JOIN agri.regions r ON d.region_id = r.region_id
    JOIN agri.crops c ON h.crop_id = c.crop_id
    JOIN agri.seasons s ON h.season_id = s.season_id
    WHERE (p_season_code IS NULL OR s.season_code = p_season_code)
    AND (p_crop_code IS NULL OR c.crop_code = p_crop_code)
    GROUP BY r.region_name, c.crop_name, s.season_name
    ORDER BY avg_yield_per_ha DESC;
END;
$$;

-- 2.2 Calculate yield trend for a crop
CREATE OR REPLACE FUNCTION agri.get_yield_trend(
    p_crop_code VARCHAR(10),
    p_district_code VARCHAR(10) DEFAULT NULL
)
RETURNS TABLE (
    year INTEGER,
    season_type agri.season_type,
    avg_yield DECIMAL,
    total_production DECIMAL,
    yoy_change_pct DECIMAL,
    trend_direction TEXT
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    WITH yearly_data AS (
        SELECT 
            s.year,
            s.season_type,
            AVG(h.yield_per_hectare) AS avg_yield,
            SUM(h.total_yield_kg) AS total_production
        FROM agri.harvests h
        JOIN agri.crops c ON h.crop_id = c.crop_id
        JOIN agri.seasons s ON h.season_id = s.season_id
        LEFT JOIN agri.districts d ON h.district_id = d.district_id
        WHERE c.crop_code = p_crop_code
        AND (p_district_code IS NULL OR d.district_code = p_district_code)
        GROUP BY s.year, s.season_type
    )
    SELECT 
        yd.year,
        yd.season_type,
        ROUND(yd.avg_yield::DECIMAL, 2),
        ROUND(yd.total_production::DECIMAL, 2),
        ROUND(((yd.avg_yield - LAG(yd.avg_yield) OVER (ORDER BY yd.year, yd.season_type)) / 
               NULLIF(LAG(yd.avg_yield) OVER (ORDER BY yd.year, yd.season_type), 0) * 100)::DECIMAL, 2),
        CASE 
            WHEN yd.avg_yield > LAG(yd.avg_yield) OVER (ORDER BY yd.year, yd.season_type) THEN 'UP'
            WHEN yd.avg_yield < LAG(yd.avg_yield) OVER (ORDER BY yd.year, yd.season_type) THEN 'DOWN'
            ELSE 'STABLE'
        END
    FROM yearly_data yd
    ORDER BY yd.year, yd.season_type;
END;
$$;

-- 2.3 Get farmer performance ranking
CREATE OR REPLACE FUNCTION agri.get_farmer_rankings(
    p_district_code VARCHAR(10) DEFAULT NULL,
    p_limit INTEGER DEFAULT 50
)
RETURNS TABLE (
    rank BIGINT,
    farmer_name TEXT,
    district_name VARCHAR,
    total_harvests BIGINT,
    avg_yield_per_ha DECIMAL,
    total_production_kg DECIMAL,
    total_profit DECIMAL,
    performance_tier TEXT
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    WITH farmer_stats AS (
        SELECT 
            f.farmer_id,
            f.first_name || ' ' || f.last_name AS farmer_name,
            d.district_name,
            COUNT(h.harvest_id) AS total_harvests,
            AVG(h.yield_per_hectare) AS avg_yield,
            SUM(h.total_yield_kg) AS total_production,
            SUM(h.profit) AS total_profit,
            PERCENT_RANK() OVER (ORDER BY AVG(h.yield_per_hectare)) AS percentile
        FROM agri.farmers f
        JOIN agri.harvests h ON f.farmer_id = h.farmer_id
        JOIN agri.districts d ON f.district_id = d.district_id
        WHERE (p_district_code IS NULL OR d.district_code = p_district_code)
        GROUP BY f.farmer_id, f.first_name, f.last_name, d.district_name
    )
    SELECT 
        ROW_NUMBER() OVER (ORDER BY fs.avg_yield DESC)::BIGINT,
        fs.farmer_name,
        fs.district_name,
        fs.total_harvests,
        ROUND(fs.avg_yield::DECIMAL, 2),
        ROUND(fs.total_production::DECIMAL, 2),
        ROUND(fs.total_profit::DECIMAL, 2),
        CASE 
            WHEN fs.percentile >= 0.9 THEN 'GOLD'
            WHEN fs.percentile >= 0.7 THEN 'SILVER'
            WHEN fs.percentile >= 0.5 THEN 'BRONZE'
            ELSE 'DEVELOPING'
        END
    FROM farmer_stats fs
    ORDER BY fs.avg_yield DESC
    LIMIT p_limit;
END;
$$;

-- 2.4 Simple yield forecast based on historical average
CREATE OR REPLACE FUNCTION agri.forecast_yield(
    p_crop_code VARCHAR(10),
    p_district_code VARCHAR(10) DEFAULT NULL,
    p_confidence_level DECIMAL DEFAULT 0.95
)
RETURNS TABLE (
    crop_name VARCHAR,
    district_name VARCHAR,
    forecast_yield_per_ha DECIMAL,
    lower_bound DECIMAL,
    upper_bound DECIMAL,
    confidence_level DECIMAL,
    data_points INTEGER,
    trend TEXT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_z_score DECIMAL;
BEGIN
    -- Z-score for confidence level (95% default = 1.96)
    v_z_score := CASE 
        WHEN p_confidence_level = 0.99 THEN 2.576
        WHEN p_confidence_level = 0.95 THEN 1.96
        WHEN p_confidence_level = 0.90 THEN 1.645
        ELSE 1.96
    END;

    RETURN QUERY
    WITH historical_data AS (
        SELECT 
            c.crop_name,
            COALESCE(d.district_name, 'All Districts') AS district_name,
            AVG(h.yield_per_hectare) AS mean_yield,
            STDDEV(h.yield_per_hectare) AS std_yield,
            COUNT(*) AS n,
            -- Simple trend calculation
            (MAX(h.yield_per_hectare) FILTER (WHERE h.harvest_date > CURRENT_DATE - INTERVAL '1 year') -
             AVG(h.yield_per_hectare)) AS recent_trend
        FROM agri.harvests h
        JOIN agri.crops c ON h.crop_id = c.crop_id
        LEFT JOIN agri.districts d ON h.district_id = d.district_id
        WHERE c.crop_code = p_crop_code
        AND (p_district_code IS NULL OR d.district_code = p_district_code)
        AND h.harvest_date > CURRENT_DATE - INTERVAL '5 years'
        GROUP BY c.crop_name, d.district_name
    )
    SELECT 
        hd.crop_name,
        hd.district_name,
        ROUND(hd.mean_yield::DECIMAL, 2),
        ROUND((hd.mean_yield - v_z_score * hd.std_yield / SQRT(hd.n))::DECIMAL, 2),
        ROUND((hd.mean_yield + v_z_score * hd.std_yield / SQRT(hd.n))::DECIMAL, 2),
        p_confidence_level,
        hd.n::INTEGER,
        CASE 
            WHEN hd.recent_trend > hd.std_yield * 0.5 THEN 'STRONG UP'
            WHEN hd.recent_trend > 0 THEN 'UP'
            WHEN hd.recent_trend < -hd.std_yield * 0.5 THEN 'STRONG DOWN'
            WHEN hd.recent_trend < 0 THEN 'DOWN'
            ELSE 'STABLE'
        END
    FROM historical_data hd
    WHERE hd.n >= 3;  -- Minimum data points
END;
$$;

-- ============================================================================
-- SECTION 3: AGGREGATION PROCEDURES
-- ============================================================================

-- 3.1 Refresh regional statistics table
CREATE OR REPLACE PROCEDURE agri.refresh_regional_stats(
    p_season_id INTEGER DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_season_id INTEGER;
BEGIN
    -- If no season specified, use current
    IF p_season_id IS NULL THEN
        SELECT season_id INTO v_season_id FROM agri.seasons WHERE is_current = TRUE;
    ELSE
        v_season_id := p_season_id;
    END IF;
    
    -- Delete existing stats for this season
    DELETE FROM agri.regional_season_stats 
    WHERE season_id = v_season_id;
    
    -- Insert fresh stats
    INSERT INTO agri.regional_season_stats (
        region_id, district_id, crop_id, season_id,
        total_farmers, total_farms, total_area_hectares,
        total_yield_kg, avg_yield_per_hectare, min_yield_per_hectare,
        max_yield_per_hectare, stddev_yield, median_yield,
        total_revenue, total_cost, total_profit, avg_price_per_kg,
        grade_a_pct, grade_b_pct, grade_c_pct,
        computed_at
    )
    SELECT 
        r.region_id,
        d.district_id,
        h.crop_id,
        h.season_id,
        COUNT(DISTINCT h.farmer_id),
        COUNT(DISTINCT h.farm_id),
        SUM(h.area_harvested_hectares),
        SUM(h.total_yield_kg),
        AVG(h.yield_per_hectare),
        MIN(h.yield_per_hectare),
        MAX(h.yield_per_hectare),
        STDDEV(h.yield_per_hectare),
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY h.yield_per_hectare),
        SUM(h.total_revenue),
        SUM(h.total_cost),
        SUM(h.profit),
        AVG(h.sale_price_per_kg),
        100.0 * COUNT(*) FILTER (WHERE h.quality_grade = 'grade_a') / NULLIF(COUNT(*), 0),
        100.0 * COUNT(*) FILTER (WHERE h.quality_grade = 'grade_b') / NULLIF(COUNT(*), 0),
        100.0 * COUNT(*) FILTER (WHERE h.quality_grade = 'grade_c') / NULLIF(COUNT(*), 0),
        CURRENT_TIMESTAMP
    FROM agri.harvests h
    JOIN agri.districts d ON h.district_id = d.district_id
    JOIN agri.regions r ON d.region_id = r.region_id
    WHERE h.season_id = v_season_id
    GROUP BY r.region_id, d.district_id, h.crop_id, h.season_id;
    
    RAISE NOTICE 'Regional stats refreshed for season %', v_season_id;
END;
$$;

-- 3.2 Calculate yield vs national average
CREATE OR REPLACE PROCEDURE agri.update_yield_comparisons()
LANGUAGE plpgsql
AS $$
BEGIN
    -- Update yield comparison against national average
    UPDATE agri.regional_season_stats rss
    SET yield_vs_national_avg_pct = (
        (rss.avg_yield_per_hectare / NULLIF(c.avg_national_yield, 0) - 1) * 100
    )
    FROM agri.crops c
    WHERE rss.crop_id = c.crop_id;
    
    -- Update comparison vs previous season
    WITH prev_season AS (
        SELECT 
            rss.region_id, rss.district_id, rss.crop_id, rss.season_id,
            LAG(rss.avg_yield_per_hectare) OVER (
                PARTITION BY rss.region_id, rss.district_id, rss.crop_id 
                ORDER BY s.start_date
            ) AS prev_yield
        FROM agri.regional_season_stats rss
        JOIN agri.seasons s ON rss.season_id = s.season_id
    )
    UPDATE agri.regional_season_stats rss
    SET yield_vs_previous_season_pct = (
        (rss.avg_yield_per_hectare / NULLIF(ps.prev_yield, 0) - 1) * 100
    )
    FROM prev_season ps
    WHERE rss.region_id = ps.region_id
    AND rss.district_id = ps.district_id
    AND rss.crop_id = ps.crop_id
    AND rss.season_id = ps.season_id;
    
    RAISE NOTICE 'Yield comparisons updated';
END;
$$;

-- ============================================================================
-- SECTION 4: VALIDATION FUNCTIONS
-- ============================================================================

-- 4.1 Validate harvest data
CREATE OR REPLACE FUNCTION agri.validate_harvest(
    p_harvest_id UUID
)
RETURNS TABLE (
    is_valid BOOLEAN,
    validation_errors TEXT[]
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_errors TEXT[] := ARRAY[]::TEXT[];
    v_harvest agri.harvests%ROWTYPE;
    v_expected_yield DECIMAL;
BEGIN
    -- Get harvest record
    SELECT * INTO v_harvest FROM agri.harvests WHERE harvest_id = p_harvest_id;
    
    IF v_harvest IS NULL THEN
        RETURN QUERY SELECT FALSE, ARRAY['Harvest not found'];
        RETURN;
    END IF;
    
    -- Validation rules
    
    -- Rule 1: Harvest date must be after planting date
    IF v_harvest.harvest_date < v_harvest.planting_date THEN
        v_errors := array_append(v_errors, 'Harvest date before planting date');
    END IF;
    
    -- Rule 2: Growth period check
    IF v_harvest.harvest_date - v_harvest.planting_date < 30 THEN
        v_errors := array_append(v_errors, 'Growth period too short (< 30 days)');
    END IF;
    
    -- Rule 3: Yield reasonability check
    SELECT avg_national_yield INTO v_expected_yield 
    FROM agri.crops WHERE crop_id = v_harvest.crop_id;
    
    IF v_harvest.yield_per_hectare > v_expected_yield * 5 THEN
        v_errors := array_append(v_errors, 'Yield suspiciously high (> 5x national average)');
    END IF;
    
    IF v_harvest.yield_per_hectare < v_expected_yield * 0.05 THEN
        v_errors := array_append(v_errors, 'Yield suspiciously low (< 5% national average)');
    END IF;
    
    -- Rule 4: Area check
    IF v_harvest.area_harvested_hectares <= 0 THEN
        v_errors := array_append(v_errors, 'Invalid area (must be > 0)');
    END IF;
    
    -- Rule 5: Revenue consistency
    IF v_harvest.quantity_sold_kg IS NOT NULL AND v_harvest.sale_price_per_kg IS NOT NULL THEN
        IF ABS(v_harvest.total_revenue - (v_harvest.quantity_sold_kg * v_harvest.sale_price_per_kg)) > 1 THEN
            v_errors := array_append(v_errors, 'Revenue calculation mismatch');
        END IF;
    END IF;
    
    -- Return result
    RETURN QUERY SELECT (array_length(v_errors, 1) IS NULL OR array_length(v_errors, 1) = 0), v_errors;
END;
$$;

-- 4.2 Data quality report
CREATE OR REPLACE FUNCTION agri.get_data_quality_report(
    p_season_code VARCHAR(15) DEFAULT NULL
)
RETURNS TABLE (
    metric TEXT,
    value BIGINT,
    percentage DECIMAL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_total_harvests BIGINT;
BEGIN
    SELECT COUNT(*) INTO v_total_harvests 
    FROM agri.harvests h
    JOIN agri.seasons s ON h.season_id = s.season_id
    WHERE (p_season_code IS NULL OR s.season_code = p_season_code);
    
    RETURN QUERY
    SELECT * FROM (
        VALUES
        ('Total Harvests', v_total_harvests, 100.0::DECIMAL),
        ('With Quality Grade', 
            (SELECT COUNT(*) FROM agri.harvests h 
             JOIN agri.seasons s ON h.season_id = s.season_id
             WHERE h.quality_grade IS NOT NULL
             AND (p_season_code IS NULL OR s.season_code = p_season_code))::BIGINT,
            ROUND(100.0 * (SELECT COUNT(*) FROM agri.harvests h 
             JOIN agri.seasons s ON h.season_id = s.season_id
             WHERE h.quality_grade IS NOT NULL
             AND (p_season_code IS NULL OR s.season_code = p_season_code)) / NULLIF(v_total_harvests, 0), 2)),
        ('With Revenue Data',
            (SELECT COUNT(*) FROM agri.harvests h 
             JOIN agri.seasons s ON h.season_id = s.season_id
             WHERE h.total_revenue IS NOT NULL AND h.total_revenue > 0
             AND (p_season_code IS NULL OR s.season_code = p_season_code))::BIGINT,
            ROUND(100.0 * (SELECT COUNT(*) FROM agri.harvests h 
             JOIN agri.seasons s ON h.season_id = s.season_id
             WHERE h.total_revenue IS NOT NULL AND h.total_revenue > 0
             AND (p_season_code IS NULL OR s.season_code = p_season_code)) / NULLIF(v_total_harvests, 0), 2)),
        ('Verified Records',
            (SELECT COUNT(*) FROM agri.harvests h 
             JOIN agri.seasons s ON h.season_id = s.season_id
             WHERE h.verified = TRUE
             AND (p_season_code IS NULL OR s.season_code = p_season_code))::BIGINT,
            ROUND(100.0 * (SELECT COUNT(*) FROM agri.harvests h 
             JOIN agri.seasons s ON h.season_id = s.season_id
             WHERE h.verified = TRUE
             AND (p_season_code IS NULL OR s.season_code = p_season_code)) / NULLIF(v_total_harvests, 0), 2))
    ) AS t(metric, value, percentage);
END;
$$;

-- ============================================================================
-- SECTION 5: UTILITY FUNCTIONS
-- ============================================================================

-- 5.1 Get current season
CREATE OR REPLACE FUNCTION agri.get_current_season()
RETURNS TABLE (
    season_id INTEGER,
    season_code VARCHAR,
    season_name VARCHAR,
    start_date DATE,
    end_date DATE
)
LANGUAGE sql
AS $$
    SELECT season_id, season_code, season_name, start_date, end_date
    FROM agri.seasons
    WHERE is_current = TRUE;
$$;

-- 5.2 Convert yield units
CREATE OR REPLACE FUNCTION agri.convert_yield(
    p_value DECIMAL,
    p_from_unit agri.yield_unit,
    p_to_unit agri.yield_unit
)
RETURNS DECIMAL
LANGUAGE plpgsql
AS $$
DECLARE
    v_kg_per_ha DECIMAL;
BEGIN
    -- Convert to kg/ha first
    v_kg_per_ha := CASE p_from_unit
        WHEN 'kg_per_hectare' THEN p_value
        WHEN 'tonnes_per_hectare' THEN p_value * 1000
        WHEN 'bags_per_acre' THEN p_value * 100 * 2.471  -- Assume 100kg bags
        WHEN 'kg_per_acre' THEN p_value * 2.471
    END;
    
    -- Convert to target unit
    RETURN CASE p_to_unit
        WHEN 'kg_per_hectare' THEN v_kg_per_ha
        WHEN 'tonnes_per_hectare' THEN v_kg_per_ha / 1000
        WHEN 'bags_per_acre' THEN v_kg_per_ha / 100 / 2.471
        WHEN 'kg_per_acre' THEN v_kg_per_ha / 2.471
    END;
END;
$$;

-- 5.3 Search farmers
CREATE OR REPLACE FUNCTION agri.search_farmers(
    p_search_term TEXT,
    p_limit INTEGER DEFAULT 20
)
RETURNS TABLE (
    farmer_id UUID,
    farmer_code VARCHAR,
    farmer_name TEXT,
    phone VARCHAR,
    district_name VARCHAR,
    village VARCHAR
)
LANGUAGE sql
AS $$
    SELECT 
        f.farmer_id,
        f.farmer_code,
        f.first_name || ' ' || f.last_name,
        f.phone_primary,
        d.district_name,
        f.village
    FROM agri.farmers f
    JOIN agri.districts d ON f.district_id = d.district_id
    WHERE f.search_vector @@ plainto_tsquery('english', p_search_term)
    OR f.farmer_code ILIKE '%' || p_search_term || '%'
    OR f.phone_primary LIKE '%' || p_search_term || '%'
    ORDER BY ts_rank(f.search_vector, plainto_tsquery('english', p_search_term)) DESC
    LIMIT p_limit;
$$;

-- 5.4 Get district by coordinates
CREATE OR REPLACE FUNCTION agri.get_district_by_location(
    p_latitude DECIMAL,
    p_longitude DECIMAL
)
RETURNS TABLE (
    district_id INTEGER,
    district_name VARCHAR,
    region_name VARCHAR,
    distance_km DECIMAL
)
LANGUAGE sql
AS $$
    SELECT 
        d.district_id,
        d.district_name,
        r.region_name,
        ROUND((
            6371 * acos(
                cos(radians(p_latitude)) * cos(radians(d.latitude)) * 
                cos(radians(d.longitude) - radians(p_longitude)) + 
                sin(radians(p_latitude)) * sin(radians(d.latitude))
            )
        )::DECIMAL, 2) AS distance_km
    FROM agri.districts d
    JOIN agri.regions r ON d.region_id = r.region_id
    WHERE d.latitude IS NOT NULL AND d.longitude IS NOT NULL
    ORDER BY 
        (d.latitude - p_latitude)^2 + (d.longitude - p_longitude)^2
    LIMIT 5;
$$;

-- ============================================================================
-- SECTION 6: BATCH OPERATIONS
-- ============================================================================

-- 6.1 Bulk insert harvests from staging
CREATE OR REPLACE PROCEDURE agri.bulk_import_harvests(
    p_batch_size INTEGER DEFAULT 1000
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_processed INTEGER := 0;
    v_errors INTEGER := 0;
BEGIN
    -- This would typically read from a staging table
    -- For now, just log the action
    RAISE NOTICE 'Bulk import started with batch size %', p_batch_size;
    
    -- Placeholder for actual bulk logic
    -- In production, this would:
    -- 1. Read from staging table
    -- 2. Validate each record
    -- 3. Insert in batches
    -- 4. Log errors
    -- 5. Update staging status
    
    RAISE NOTICE 'Bulk import complete. Processed: %, Errors: %', v_processed, v_errors;
END;
$$;

-- 6.2 Archive old data
CREATE OR REPLACE PROCEDURE agri.archive_old_data(
    p_years_to_keep INTEGER DEFAULT 5
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_cutoff_date DATE;
    v_archived_count INTEGER;
BEGIN
    v_cutoff_date := CURRENT_DATE - (p_years_to_keep || ' years')::INTERVAL;
    
    -- Create archive tables if not exist
    CREATE TABLE IF NOT EXISTS agri.harvests_archive (LIKE agri.harvests INCLUDING ALL);
    
    -- Move old records to archive
    WITH moved AS (
        DELETE FROM agri.harvests
        WHERE harvest_date < v_cutoff_date
        RETURNING *
    )
    INSERT INTO agri.harvests_archive SELECT * FROM moved;
    
    GET DIAGNOSTICS v_archived_count = ROW_COUNT;
    
    RAISE NOTICE 'Archived % harvest records older than %', v_archived_count, v_cutoff_date;
END;
$$;

-- ============================================================================
-- VERIFICATION
-- ============================================================================

DO $$
DECLARE
    func_count INTEGER;
    proc_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO func_count
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'agri' AND p.prokind = 'f';
    
    SELECT COUNT(*) INTO proc_count
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'agri' AND p.prokind = 'p';
    
    RAISE NOTICE '=====================================';
    RAISE NOTICE 'PROCEDURES & FUNCTIONS LOADED';
    RAISE NOTICE '=====================================';
    RAISE NOTICE 'Functions created: %', func_count;
    RAISE NOTICE 'Procedures created: %', proc_count;
    RAISE NOTICE '=====================================';
END $$;
