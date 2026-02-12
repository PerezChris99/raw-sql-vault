-- ============================================================================
-- 🌾 AGRICULTURE YIELD ANALYTICS - PERFORMANCE INDEXES
-- ============================================================================
-- File: 02_indexes.sql
-- Purpose: High-performance indexes for enterprise-scale queries
-- Database: PostgreSQL 14+
-- ============================================================================

SET search_path TO agri, public;

-- ============================================================================
-- PRIMARY KEY INDEXES (Created automatically, documented here)
-- ============================================================================

/*
Auto-created with PRIMARY KEY:
- regions_pkey (region_id)
- districts_pkey (district_id)
- sub_counties_pkey (sub_county_id)
- crops_pkey (crop_id)
- crop_varieties_pkey (variety_id)
- farmers_pkey (farmer_id)
- farms_pkey (farm_id)
- farm_plots_pkey (plot_id)
- seasons_pkey (season_id)
- harvests_pkey (harvest_id)
*/

-- ============================================================================
-- GEOGRAPHIC HIERARCHY INDEXES
-- ============================================================================

-- Regions
CREATE INDEX IF NOT EXISTS idx_regions_code ON agri.regions(region_code);
CREATE INDEX IF NOT EXISTS idx_regions_active ON agri.regions(is_active) WHERE is_active = TRUE;

-- Districts
CREATE INDEX IF NOT EXISTS idx_districts_region ON agri.districts(region_id);
CREATE INDEX IF NOT EXISTS idx_districts_code ON agri.districts(district_code);
CREATE INDEX IF NOT EXISTS idx_districts_name ON agri.districts(district_name);
CREATE INDEX IF NOT EXISTS idx_districts_active ON agri.districts(is_active) WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_districts_location ON agri.districts(latitude, longitude) 
    WHERE latitude IS NOT NULL AND longitude IS NOT NULL;

-- Sub-counties
CREATE INDEX IF NOT EXISTS idx_subcounties_district ON agri.sub_counties(district_id);
CREATE INDEX IF NOT EXISTS idx_subcounties_code ON agri.sub_counties(sub_county_code);
CREATE INDEX IF NOT EXISTS idx_subcounties_active ON agri.sub_counties(is_active) WHERE is_active = TRUE;

-- ============================================================================
-- CROP INDEXES
-- ============================================================================

-- Crops
CREATE INDEX IF NOT EXISTS idx_crops_code ON agri.crops(crop_code);
CREATE INDEX IF NOT EXISTS idx_crops_category ON agri.crops(category);
CREATE INDEX IF NOT EXISTS idx_crops_export ON agri.crops(is_export_crop) WHERE is_export_crop = TRUE;
CREATE INDEX IF NOT EXISTS idx_crops_food ON agri.crops(is_food_crop) WHERE is_food_crop = TRUE;
CREATE INDEX IF NOT EXISTS idx_crops_active ON agri.crops(is_active) WHERE is_active = TRUE;

-- Crop varieties
CREATE INDEX IF NOT EXISTS idx_varieties_crop ON agri.crop_varieties(crop_id);
CREATE INDEX IF NOT EXISTS idx_varieties_code ON agri.crop_varieties(variety_code);
CREATE INDEX IF NOT EXISTS idx_varieties_hybrid ON agri.crop_varieties(crop_id, is_hybrid);
CREATE INDEX IF NOT EXISTS idx_varieties_drought ON agri.crop_varieties(is_drought_resistant) 
    WHERE is_drought_resistant = TRUE;

-- ============================================================================
-- FARMER & FARM INDEXES
-- ============================================================================

-- Farmers
CREATE INDEX IF NOT EXISTS idx_farmers_code ON agri.farmers(farmer_code);
CREATE INDEX IF NOT EXISTS idx_farmers_district ON agri.farmers(district_id);
CREATE INDEX IF NOT EXISTS idx_farmers_subcounty ON agri.farmers(sub_county_id);
CREATE INDEX IF NOT EXISTS idx_farmers_phone ON agri.farmers(phone_primary);
CREATE INDEX IF NOT EXISTS idx_farmers_active ON agri.farmers(is_active) WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_farmers_cooperative ON agri.farmers(cooperative_member) 
    WHERE cooperative_member = TRUE;
CREATE INDEX IF NOT EXISTS idx_farmers_registered ON agri.farmers(registered_at);

-- Full-text search on farmers
CREATE INDEX IF NOT EXISTS idx_farmers_search ON agri.farmers USING GIN(search_vector);

-- Farms
CREATE INDEX IF NOT EXISTS idx_farms_code ON agri.farms(farm_code);
CREATE INDEX IF NOT EXISTS idx_farms_farmer ON agri.farms(farmer_id);
CREATE INDEX IF NOT EXISTS idx_farms_district ON agri.farms(district_id);
CREATE INDEX IF NOT EXISTS idx_farms_subcounty ON agri.farms(sub_county_id);
CREATE INDEX IF NOT EXISTS idx_farms_size_class ON agri.farms(size_class);
CREATE INDEX IF NOT EXISTS idx_farms_area ON agri.farms(total_area_hectares);
CREATE INDEX IF NOT EXISTS idx_farms_irrigated ON agri.farms(irrigation_available) 
    WHERE irrigation_available = TRUE;
CREATE INDEX IF NOT EXISTS idx_farms_active ON agri.farms(is_active) WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_farms_location ON agri.farms(latitude, longitude) 
    WHERE latitude IS NOT NULL AND longitude IS NOT NULL;

-- Farm plots
CREATE INDEX IF NOT EXISTS idx_plots_farm ON agri.farm_plots(farm_id);
CREATE INDEX IF NOT EXISTS idx_plots_crop ON agri.farm_plots(current_crop_id);
CREATE INDEX IF NOT EXISTS idx_plots_active ON agri.farm_plots(is_active) WHERE is_active = TRUE;

-- ============================================================================
-- SEASON INDEXES
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_seasons_code ON agri.seasons(season_code);
CREATE INDEX IF NOT EXISTS idx_seasons_year ON agri.seasons(year);
CREATE INDEX IF NOT EXISTS idx_seasons_type ON agri.seasons(season_type);
CREATE INDEX IF NOT EXISTS idx_seasons_current ON agri.seasons(is_current) WHERE is_current = TRUE;
CREATE INDEX IF NOT EXISTS idx_seasons_dates ON agri.seasons(start_date, end_date);
CREATE INDEX IF NOT EXISTS idx_seasons_year_type ON agri.seasons(year, season_type);

-- ============================================================================
-- HARVEST INDEXES (CRITICAL - HIGH VOLUME TABLE)
-- ============================================================================

-- Primary lookup indexes
CREATE INDEX IF NOT EXISTS idx_harvests_code ON agri.harvests(harvest_code);
CREATE INDEX IF NOT EXISTS idx_harvests_farmer ON agri.harvests(farmer_id);
CREATE INDEX IF NOT EXISTS idx_harvests_farm ON agri.harvests(farm_id);
CREATE INDEX IF NOT EXISTS idx_harvests_crop ON agri.harvests(crop_id);
CREATE INDEX IF NOT EXISTS idx_harvests_variety ON agri.harvests(variety_id);
CREATE INDEX IF NOT EXISTS idx_harvests_season ON agri.harvests(season_id);
CREATE INDEX IF NOT EXISTS idx_harvests_district ON agri.harvests(district_id);

-- Date-based indexes for time-series queries
CREATE INDEX IF NOT EXISTS idx_harvests_harvest_date ON agri.harvests(harvest_date);
CREATE INDEX IF NOT EXISTS idx_harvests_planting_date ON agri.harvests(planting_date);
CREATE INDEX IF NOT EXISTS idx_harvests_dates ON agri.harvests(planting_date, harvest_date);

-- Analytics composite indexes (MOST IMPORTANT)
CREATE INDEX IF NOT EXISTS idx_harvests_region_crop_season 
    ON agri.harvests(district_id, crop_id, season_id);

CREATE INDEX IF NOT EXISTS idx_harvests_season_crop 
    ON agri.harvests(season_id, crop_id);

CREATE INDEX IF NOT EXISTS idx_harvests_district_season 
    ON agri.harvests(district_id, season_id);

CREATE INDEX IF NOT EXISTS idx_harvests_crop_district_date 
    ON agri.harvests(crop_id, district_id, harvest_date);

-- Yield analysis indexes
CREATE INDEX IF NOT EXISTS idx_harvests_yield 
    ON agri.harvests(yield_per_hectare);

CREATE INDEX IF NOT EXISTS idx_harvests_crop_yield 
    ON agri.harvests(crop_id, yield_per_hectare);

CREATE INDEX IF NOT EXISTS idx_harvests_district_yield 
    ON agri.harvests(district_id, yield_per_hectare);

-- Quality and verification indexes
CREATE INDEX IF NOT EXISTS idx_harvests_quality ON agri.harvests(quality_grade);
CREATE INDEX IF NOT EXISTS idx_harvests_verified ON agri.harvests(verified) WHERE verified = TRUE;
CREATE INDEX IF NOT EXISTS idx_harvests_unverified ON agri.harvests(verified) WHERE verified = FALSE;

-- Financial indexes
CREATE INDEX IF NOT EXISTS idx_harvests_revenue ON agri.harvests(total_revenue) 
    WHERE total_revenue IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_harvests_profit ON agri.harvests(profit);

-- BRIN index for time-series data (Very efficient for large tables)
CREATE INDEX IF NOT EXISTS idx_harvests_date_brin 
    ON agri.harvests USING BRIN(harvest_date) WITH (pages_per_range = 32);

CREATE INDEX IF NOT EXISTS idx_harvests_created_brin 
    ON agri.harvests USING BRIN(created_at) WITH (pages_per_range = 32);

-- Covering indexes for common queries (Include columns to avoid table lookups)
CREATE INDEX IF NOT EXISTS idx_harvests_dashboard_cover 
    ON agri.harvests(district_id, crop_id, season_id) 
    INCLUDE (total_yield_kg, area_harvested_hectares, yield_per_hectare, quality_grade);

CREATE INDEX IF NOT EXISTS idx_harvests_farmer_summary 
    ON agri.harvests(farmer_id, season_id) 
    INCLUDE (crop_id, total_yield_kg, total_revenue, profit);

-- ============================================================================
-- WEATHER DATA INDEXES
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_weather_district ON agri.weather_data(district_id);
CREATE INDEX IF NOT EXISTS idx_weather_date ON agri.weather_data(recorded_date);
CREATE INDEX IF NOT EXISTS idx_weather_district_date ON agri.weather_data(district_id, recorded_date);
CREATE INDEX IF NOT EXISTS idx_weather_date_brin 
    ON agri.weather_data USING BRIN(recorded_date) WITH (pages_per_range = 32);

-- ============================================================================
-- SOIL DATA INDEXES
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_soil_farm ON agri.soil_data(farm_id);
CREATE INDEX IF NOT EXISTS idx_soil_plot ON agri.soil_data(plot_id);
CREATE INDEX IF NOT EXISTS idx_soil_date ON agri.soil_data(test_date);

-- ============================================================================
-- MARKET PRICES INDEXES
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_prices_crop ON agri.market_prices(crop_id);
CREATE INDEX IF NOT EXISTS idx_prices_district ON agri.market_prices(district_id);
CREATE INDEX IF NOT EXISTS idx_prices_date ON agri.market_prices(price_date);
CREATE INDEX IF NOT EXISTS idx_prices_crop_date ON agri.market_prices(crop_id, price_date);
CREATE INDEX IF NOT EXISTS idx_prices_crop_district_date 
    ON agri.market_prices(crop_id, district_id, price_date);
CREATE INDEX IF NOT EXISTS idx_prices_date_brin 
    ON agri.market_prices USING BRIN(price_date) WITH (pages_per_range = 32);

-- ============================================================================
-- REGIONAL STATS INDEXES
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_stats_region ON agri.regional_season_stats(region_id);
CREATE INDEX IF NOT EXISTS idx_stats_district ON agri.regional_season_stats(district_id);
CREATE INDEX IF NOT EXISTS idx_stats_crop ON agri.regional_season_stats(crop_id);
CREATE INDEX IF NOT EXISTS idx_stats_season ON agri.regional_season_stats(season_id);
CREATE INDEX IF NOT EXISTS idx_stats_composite 
    ON agri.regional_season_stats(region_id, crop_id, season_id);

-- ============================================================================
-- AUDIT LOG INDEXES
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_audit_table ON agri.audit_log(table_name);
CREATE INDEX IF NOT EXISTS idx_audit_record ON agri.audit_log(record_id);
CREATE INDEX IF NOT EXISTS idx_audit_action ON agri.audit_log(action);
CREATE INDEX IF NOT EXISTS idx_audit_user ON agri.audit_log(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_created ON agri.audit_log(created_at);
CREATE INDEX IF NOT EXISTS idx_audit_created_brin 
    ON agri.audit_log USING BRIN(created_at) WITH (pages_per_range = 64);

-- ============================================================================
-- EXPRESSION INDEXES (For computed values)
-- ============================================================================

-- Index for year extraction from harvest date
CREATE INDEX IF NOT EXISTS idx_harvests_year 
    ON agri.harvests(EXTRACT(YEAR FROM harvest_date));

-- Index for month extraction
CREATE INDEX IF NOT EXISTS idx_harvests_month 
    ON agri.harvests(EXTRACT(MONTH FROM harvest_date));

-- Index for lowercase farmer search
CREATE INDEX IF NOT EXISTS idx_farmers_name_lower 
    ON agri.farmers(LOWER(first_name), LOWER(last_name));

-- ============================================================================
-- PARTIAL INDEXES (For common filtered queries)
-- ============================================================================

-- High yield harvests (for best practices analysis)
CREATE INDEX IF NOT EXISTS idx_harvests_high_yield 
    ON agri.harvests(crop_id, district_id, yield_per_hectare) 
    WHERE yield_per_hectare > 1000;  -- Above 1 tonne/hectare

-- Recent harvests (last 2 years)
CREATE INDEX IF NOT EXISTS idx_harvests_recent 
    ON agri.harvests(district_id, crop_id, harvest_date) 
    WHERE harvest_date > CURRENT_DATE - INTERVAL '2 years';

-- Premium quality harvests
CREATE INDEX IF NOT EXISTS idx_harvests_premium 
    ON agri.harvests(crop_id, district_id) 
    WHERE quality_grade = 'grade_a';

-- Profitable harvests
CREATE INDEX IF NOT EXISTS idx_harvests_profitable 
    ON agri.harvests(crop_id, district_id, profit) 
    WHERE profit > 0;

-- ============================================================================
-- INDEX STATISTICS & MAINTENANCE
-- ============================================================================

-- Function to analyze index usage
CREATE OR REPLACE FUNCTION agri.get_index_usage()
RETURNS TABLE (
    schema_name TEXT,
    table_name TEXT,
    index_name TEXT,
    index_size TEXT,
    idx_scan BIGINT,
    idx_tup_read BIGINT,
    idx_tup_fetch BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        schemaname::TEXT,
        relname::TEXT,
        indexrelname::TEXT,
        pg_size_pretty(pg_relation_size(indexrelid)) AS index_size,
        idx_scan,
        idx_tup_read,
        idx_tup_fetch
    FROM pg_stat_user_indexes
    WHERE schemaname = 'agri'
    ORDER BY idx_scan DESC;
END;
$$ LANGUAGE plpgsql;

-- Function to find unused indexes
CREATE OR REPLACE FUNCTION agri.get_unused_indexes()
RETURNS TABLE (
    table_name TEXT,
    index_name TEXT,
    index_size TEXT,
    idx_scan BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        relname::TEXT,
        indexrelname::TEXT,
        pg_size_pretty(pg_relation_size(indexrelid)),
        idx_scan
    FROM pg_stat_user_indexes
    WHERE schemaname = 'agri'
    AND idx_scan = 0
    AND indexrelname NOT LIKE '%_pkey'
    ORDER BY pg_relation_size(indexrelid) DESC;
END;
$$ LANGUAGE plpgsql;

-- Function to get index bloat estimate
CREATE OR REPLACE FUNCTION agri.check_index_bloat()
RETURNS TABLE (
    schema_name TEXT,
    table_name TEXT,
    index_name TEXT,
    bloat_ratio NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        schemaname::TEXT,
        tablename::TEXT,
        indexname::TEXT,
        ROUND(100 * (bs*(relpages)::BIGINT - real_size)::NUMERIC / 
              NULLIF(bs*(relpages)::BIGINT, 0), 2) AS bloat_ratio
    FROM (
        SELECT
            nspname AS schemaname,
            tblname AS tablename,
            idxname AS indexname,
            relpages,
            bs,
            CASE WHEN avg_leaf_density = 0 THEN 0
                 ELSE ceil(reltuples / NULLIF(avg_leaf_density, 0)) * bs
            END AS real_size
        FROM (
            SELECT
                n.nspname,
                ci.relname AS idxname,
                ct.relname AS tblname,
                ci.relpages,
                ci.reltuples,
                8192 AS bs,
                COALESCE(
                    (SELECT AVG(CASE WHEN leaf_count = 0 THEN 0 
                        ELSE tuple_count / leaf_count END)
                     FROM pg_stat_user_indexes WHERE indexrelid = ci.oid),
                    0
                ) AS avg_leaf_density
            FROM pg_class ci
            JOIN pg_index i ON ci.oid = i.indexrelid
            JOIN pg_class ct ON i.indrelid = ct.oid
            JOIN pg_namespace n ON n.oid = ci.relnamespace
            WHERE n.nspname = 'agri'
            AND ci.relkind = 'i'
        ) AS sub
    ) AS idx_data
    WHERE bs*(relpages)::BIGINT > 0
    ORDER BY bloat_ratio DESC NULLS LAST;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- VERIFICATION
-- ============================================================================

DO $$
DECLARE
    idx_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO idx_count
    FROM pg_indexes
    WHERE schemaname = 'agri';
    
    RAISE NOTICE 'Index creation complete!';
    RAISE NOTICE 'Total indexes created: %', idx_count;
END $$;
