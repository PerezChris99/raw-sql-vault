-- ============================================================================
-- Migration V005: Performance Indexes
-- Purpose: Optimize query performance for analytics workloads
-- ============================================================================

SET search_path TO agri, public;

-- ============================================================================
-- PRIMARY LOOKUP INDEXES
-- ============================================================================

-- Regions
CREATE INDEX IF NOT EXISTS idx_regions_code ON agri.regions(region_code);
CREATE INDEX IF NOT EXISTS idx_regions_active ON agri.regions(is_active) WHERE is_active = TRUE;

-- Districts
CREATE INDEX IF NOT EXISTS idx_districts_code ON agri.districts(district_code);
CREATE INDEX IF NOT EXISTS idx_districts_region ON agri.districts(region_id);
CREATE INDEX IF NOT EXISTS idx_districts_active ON agri.districts(is_active) WHERE is_active = TRUE;

-- Subcounties
CREATE INDEX IF NOT EXISTS idx_subcounties_district ON agri.subcounties(district_id);

-- Crops
CREATE INDEX IF NOT EXISTS idx_crops_code ON agri.crops(crop_code);
CREATE INDEX IF NOT EXISTS idx_crops_category ON agri.crops(category_id);
CREATE INDEX IF NOT EXISTS idx_crops_type ON agri.crops(crop_type);
CREATE INDEX IF NOT EXISTS idx_crops_cash ON agri.crops(is_cash_crop) WHERE is_cash_crop = TRUE;
CREATE INDEX IF NOT EXISTS idx_crops_export ON agri.crops(is_export_crop) WHERE is_export_crop = TRUE;

-- Seasons
CREATE INDEX IF NOT EXISTS idx_seasons_code ON agri.seasons(season_code);
CREATE INDEX IF NOT EXISTS idx_seasons_year ON agri.seasons(year);
CREATE INDEX IF NOT EXISTS idx_seasons_type ON agri.seasons(season_type);
CREATE INDEX IF NOT EXISTS idx_seasons_current ON agri.seasons(is_current) WHERE is_current = TRUE;
CREATE INDEX IF NOT EXISTS idx_seasons_dates ON agri.seasons(start_date, end_date);

-- ============================================================================
-- FARMER INDEXES
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_farmers_code ON agri.farmers(farmer_code);
CREATE INDEX IF NOT EXISTS idx_farmers_district ON agri.farmers(district_id);
CREATE INDEX IF NOT EXISTS idx_farmers_subcounty ON agri.farmers(subcounty_id);
CREATE INDEX IF NOT EXISTS idx_farmers_cooperative ON agri.farmers(is_cooperative_member) WHERE is_cooperative_member = TRUE;
CREATE INDEX IF NOT EXISTS idx_farmers_active ON agri.farmers(is_active) WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_farmers_registration ON agri.farmers(registration_date);
CREATE INDEX IF NOT EXISTS idx_farmers_name ON agri.farmers USING gin ((first_name || ' ' || last_name) gin_trgm_ops);

-- ============================================================================
-- FARM INDEXES
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_farms_code ON agri.farms(farm_code);
CREATE INDEX IF NOT EXISTS idx_farms_farmer ON agri.farms(farmer_id);
CREATE INDEX IF NOT EXISTS idx_farms_district ON agri.farms(district_id);
CREATE INDEX IF NOT EXISTS idx_farms_size_class ON agri.farms(size_class);
CREATE INDEX IF NOT EXISTS idx_farms_area ON agri.farms(total_area_hectares);
CREATE INDEX IF NOT EXISTS idx_farms_irrigation ON agri.farms(irrigation_available) WHERE irrigation_available = TRUE;
CREATE INDEX IF NOT EXISTS idx_farms_location ON agri.farms(latitude, longitude) WHERE latitude IS NOT NULL;

-- ============================================================================
-- PLANTING INDEXES
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_plantings_farm ON agri.plantings(farm_id);
CREATE INDEX IF NOT EXISTS idx_plantings_crop ON agri.plantings(crop_id);
CREATE INDEX IF NOT EXISTS idx_plantings_season ON agri.plantings(season_id);
CREATE INDEX IF NOT EXISTS idx_plantings_date ON agri.plantings(planting_date);
CREATE INDEX IF NOT EXISTS idx_plantings_method ON agri.plantings(farming_method);
CREATE INDEX IF NOT EXISTS idx_plantings_composite ON agri.plantings(farm_id, crop_id, season_id);

-- ============================================================================
-- HARVEST INDEXES (Most critical for analytics)
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_harvests_farmer ON agri.harvests(farmer_id);
CREATE INDEX IF NOT EXISTS idx_harvests_farm ON agri.harvests(farm_id);
CREATE INDEX IF NOT EXISTS idx_harvests_crop ON agri.harvests(crop_id);
CREATE INDEX IF NOT EXISTS idx_harvests_season ON agri.harvests(season_id);
CREATE INDEX IF NOT EXISTS idx_harvests_district ON agri.harvests(district_id);
CREATE INDEX IF NOT EXISTS idx_harvests_date ON agri.harvests(harvest_date);
CREATE INDEX IF NOT EXISTS idx_harvests_quality ON agri.harvests(quality_grade);
CREATE INDEX IF NOT EXISTS idx_harvests_yield ON agri.harvests(yield_per_hectare);

-- Composite indexes for common query patterns
CREATE INDEX IF NOT EXISTS idx_harvests_crop_season ON agri.harvests(crop_id, season_id);
CREATE INDEX IF NOT EXISTS idx_harvests_district_crop ON agri.harvests(district_id, crop_id);
CREATE INDEX IF NOT EXISTS idx_harvests_district_season ON agri.harvests(district_id, season_id);
CREATE INDEX IF NOT EXISTS idx_harvests_farmer_crop ON agri.harvests(farmer_id, crop_id);
CREATE INDEX IF NOT EXISTS idx_harvests_analytics ON agri.harvests(harvest_date, crop_id, district_id, yield_per_hectare);

-- ============================================================================
-- WEATHER INDEXES
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_weather_district ON agri.weather_records(district_id);
CREATE INDEX IF NOT EXISTS idx_weather_date ON agri.weather_records(record_date);
CREATE INDEX IF NOT EXISTS idx_weather_district_date ON agri.weather_records(district_id, record_date);

-- ============================================================================
-- MARKET PRICE INDEXES
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_prices_crop ON agri.market_prices(crop_id);
CREATE INDEX IF NOT EXISTS idx_prices_district ON agri.market_prices(district_id);
CREATE INDEX IF NOT EXISTS idx_prices_date ON agri.market_prices(price_date);
CREATE INDEX IF NOT EXISTS idx_prices_composite ON agri.market_prices(crop_id, price_date);

-- ============================================================================
-- AUDIT LOG INDEXES
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_audit_table ON agri.audit_log(table_name);
CREATE INDEX IF NOT EXISTS idx_audit_action ON agri.audit_log(action);
CREATE INDEX IF NOT EXISTS idx_audit_timestamp ON agri.audit_log(changed_at);
CREATE INDEX IF NOT EXISTS idx_audit_user ON agri.audit_log(changed_by);
