-- ============================================================================
-- 🌾 AGRICULTURE YIELD ANALYTICS - SCHEMA DEFINITION
-- ============================================================================
-- File: 01_schema.sql
-- Purpose: Core database schema with enterprise-grade table design
-- Database: PostgreSQL 14+
-- ============================================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";      -- UUID generation
CREATE EXTENSION IF NOT EXISTS "pgcrypto";       -- Cryptographic functions
CREATE EXTENSION IF NOT EXISTS "pg_trgm";        -- Trigram text search
CREATE EXTENSION IF NOT EXISTS "btree_gist";     -- GiST index support

-- ============================================================================
-- SCHEMA SETUP
-- ============================================================================

-- Create dedicated schema for organization
CREATE SCHEMA IF NOT EXISTS agri;
COMMENT ON SCHEMA agri IS 'Agriculture Yield Analytics - Core Schema';

-- Set search path
SET search_path TO agri, public;

-- ============================================================================
-- CUSTOM TYPES
-- ============================================================================

-- Measurement units for yields
CREATE TYPE agri.yield_unit AS ENUM (
    'kg_per_hectare',
    'tonnes_per_hectare',
    'bags_per_acre',
    'kg_per_acre'
);

-- Seasons in Uganda
CREATE TYPE agri.season_type AS ENUM (
    'season_a',     -- March to June (First rains)
    'season_b',     -- September to December (Second rains)
    'dry_season'    -- January to February, July to August
);

-- Crop categories
CREATE TYPE agri.crop_category AS ENUM (
    'cereals',
    'legumes',
    'root_tubers',
    'fruits',
    'vegetables',
    'cash_crops',
    'oilseeds',
    'spices'
);

-- Farm size classification
CREATE TYPE agri.farm_size_class AS ENUM (
    'micro',        -- < 0.5 hectares
    'small',        -- 0.5 - 2 hectares
    'medium',       -- 2 - 10 hectares
    'large',        -- 10 - 50 hectares
    'commercial'    -- > 50 hectares
);

-- Quality grades
CREATE TYPE agri.quality_grade AS ENUM (
    'grade_a',      -- Premium quality
    'grade_b',      -- Good quality
    'grade_c',      -- Standard quality
    'grade_d',      -- Below standard
    'rejected'      -- Not marketable
);

-- ============================================================================
-- REFERENCE TABLES - GEOGRAPHIC HIERARCHY
-- ============================================================================

-- Regions (Top level - Uganda has 4 main regions)
CREATE TABLE agri.regions (
    region_id       SERIAL PRIMARY KEY,
    region_code     VARCHAR(10) UNIQUE NOT NULL,
    region_name     VARCHAR(100) NOT NULL,
    area_sq_km      DECIMAL(12,2),
    arable_land_pct DECIMAL(5,2),
    climate_zone    VARCHAR(50),
    avg_annual_rainfall_mm DECIMAL(8,2),
    is_active       BOOLEAN DEFAULT TRUE,
    created_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE agri.regions IS 'Geographic regions (e.g., Central, Eastern, Northern, Western Uganda)';

-- Districts (Second level)
CREATE TABLE agri.districts (
    district_id     SERIAL PRIMARY KEY,
    district_code   VARCHAR(10) UNIQUE NOT NULL,
    district_name   VARCHAR(100) NOT NULL,
    region_id       INTEGER NOT NULL REFERENCES agri.regions(region_id),
    area_sq_km      DECIMAL(12,2),
    population      INTEGER,
    farming_households INTEGER,
    major_crops     TEXT[],
    latitude        DECIMAL(10,7),
    longitude       DECIMAL(10,7),
    is_active       BOOLEAN DEFAULT TRUE,
    created_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE agri.districts IS 'Administrative districts within regions';

-- Sub-counties (Third level)
CREATE TABLE agri.sub_counties (
    sub_county_id   SERIAL PRIMARY KEY,
    sub_county_code VARCHAR(15) UNIQUE NOT NULL,
    sub_county_name VARCHAR(100) NOT NULL,
    district_id     INTEGER NOT NULL REFERENCES agri.districts(district_id),
    area_sq_km      DECIMAL(10,2),
    farming_households INTEGER,
    is_active       BOOLEAN DEFAULT TRUE,
    created_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE agri.sub_counties IS 'Sub-counties within districts';

-- ============================================================================
-- REFERENCE TABLES - CROPS
-- ============================================================================

-- Crop types (Master list)
CREATE TABLE agri.crops (
    crop_id         SERIAL PRIMARY KEY,
    crop_code       VARCHAR(10) UNIQUE NOT NULL,
    crop_name       VARCHAR(100) NOT NULL,
    scientific_name VARCHAR(150),
    category        agri.crop_category NOT NULL,
    growth_period_days INTEGER,         -- Average days to harvest
    optimal_rainfall_mm DECIMAL(8,2),
    optimal_temp_min DECIMAL(4,1),
    optimal_temp_max DECIMAL(4,1),
    is_export_crop  BOOLEAN DEFAULT FALSE,
    is_food_crop    BOOLEAN DEFAULT TRUE,
    default_unit    agri.yield_unit DEFAULT 'kg_per_hectare',
    avg_national_yield DECIMAL(12,2),   -- National average yield
    is_active       BOOLEAN DEFAULT TRUE,
    created_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE agri.crops IS 'Master list of crops grown';

-- Crop varieties (Sub-types of crops)
CREATE TABLE agri.crop_varieties (
    variety_id      SERIAL PRIMARY KEY,
    variety_code    VARCHAR(20) UNIQUE NOT NULL,
    variety_name    VARCHAR(100) NOT NULL,
    crop_id         INTEGER NOT NULL REFERENCES agri.crops(crop_id),
    is_hybrid       BOOLEAN DEFAULT FALSE,
    is_drought_resistant BOOLEAN DEFAULT FALSE,
    is_disease_resistant BOOLEAN DEFAULT FALSE,
    maturity_days   INTEGER,
    expected_yield  DECIMAL(12,2),
    seed_source     VARCHAR(100),
    year_released   INTEGER,
    is_active       BOOLEAN DEFAULT TRUE,
    created_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE agri.crop_varieties IS 'Specific varieties/cultivars of crops';

-- ============================================================================
-- CORE TABLES - FARMERS & FARMS
-- ============================================================================

-- Farmers (Core entity)
CREATE TABLE agri.farmers (
    farmer_id       UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    farmer_code     VARCHAR(20) UNIQUE NOT NULL,
    first_name      VARCHAR(100) NOT NULL,
    last_name       VARCHAR(100) NOT NULL,
    gender          CHAR(1) CHECK (gender IN ('M', 'F', 'O')),
    date_of_birth   DATE,
    phone_primary   VARCHAR(20),
    phone_secondary VARCHAR(20),
    email           VARCHAR(150),
    national_id     VARCHAR(30),
    district_id     INTEGER REFERENCES agri.districts(district_id),
    sub_county_id   INTEGER REFERENCES agri.sub_counties(sub_county_id),
    village         VARCHAR(100),
    years_farming   INTEGER,
    education_level VARCHAR(50),
    cooperative_member BOOLEAN DEFAULT FALSE,
    cooperative_name VARCHAR(100),
    bank_account    VARCHAR(50),
    mobile_money_number VARCHAR(20),
    is_active       BOOLEAN DEFAULT TRUE,
    registered_at   TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    
    -- Full-text search support
    search_vector   TSVECTOR GENERATED ALWAYS AS (
        to_tsvector('english', coalesce(first_name, '') || ' ' || coalesce(last_name, '') || ' ' || coalesce(village, ''))
    ) STORED
);

COMMENT ON TABLE agri.farmers IS 'Registered farmers in the system';

-- Farms (Land parcels)
CREATE TABLE agri.farms (
    farm_id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    farm_code       VARCHAR(20) UNIQUE NOT NULL,
    farm_name       VARCHAR(100),
    farmer_id       UUID NOT NULL REFERENCES agri.farmers(farmer_id),
    district_id     INTEGER NOT NULL REFERENCES agri.districts(district_id),
    sub_county_id   INTEGER REFERENCES agri.sub_counties(sub_county_id),
    village         VARCHAR(100),
    total_area_hectares DECIMAL(10,2) NOT NULL,
    cultivated_area_hectares DECIMAL(10,2),
    size_class      agri.farm_size_class,
    latitude        DECIMAL(10,7),
    longitude       DECIMAL(10,7),
    elevation_meters INTEGER,
    soil_type       VARCHAR(50),
    irrigation_available BOOLEAN DEFAULT FALSE,
    irrigation_type VARCHAR(50),
    land_ownership  VARCHAR(50) DEFAULT 'owned', -- owned, leased, communal
    year_acquired   INTEGER,
    is_active       BOOLEAN DEFAULT TRUE,
    created_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE agri.farms IS 'Farm/land parcel information';

-- Farm plots (Subdivisions of farms for different crops)
CREATE TABLE agri.farm_plots (
    plot_id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    plot_code       VARCHAR(25) UNIQUE NOT NULL,
    farm_id         UUID NOT NULL REFERENCES agri.farms(farm_id),
    plot_name       VARCHAR(50),
    area_hectares   DECIMAL(8,2) NOT NULL,
    current_crop_id INTEGER REFERENCES agri.crops(crop_id),
    soil_ph         DECIMAL(3,1),
    last_soil_test  DATE,
    notes           TEXT,
    is_active       BOOLEAN DEFAULT TRUE,
    created_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE agri.farm_plots IS 'Individual plots within farms for crop rotation tracking';

-- ============================================================================
-- CORE TABLES - SEASONS & HARVESTS
-- ============================================================================

-- Agricultural seasons (Defined periods)
CREATE TABLE agri.seasons (
    season_id       SERIAL PRIMARY KEY,
    season_code     VARCHAR(15) UNIQUE NOT NULL,  -- e.g., '2024_A', '2024_B'
    season_name     VARCHAR(50) NOT NULL,         -- e.g., 'First Rains 2024'
    season_type     agri.season_type NOT NULL,
    year            INTEGER NOT NULL,
    start_date      DATE NOT NULL,
    end_date        DATE NOT NULL,
    planting_window_start DATE,
    planting_window_end DATE,
    expected_rainfall_mm DECIMAL(8,2),
    actual_rainfall_mm DECIMAL(8,2),
    notes           TEXT,
    is_current      BOOLEAN DEFAULT FALSE,
    created_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT chk_season_dates CHECK (end_date > start_date),
    CONSTRAINT chk_planting_window CHECK (planting_window_end > planting_window_start)
);

COMMENT ON TABLE agri.seasons IS 'Agricultural seasons/planting periods';

-- Harvests (Core transaction table - High volume)
CREATE TABLE agri.harvests (
    harvest_id      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    harvest_code    VARCHAR(30) UNIQUE NOT NULL,
    
    -- Relationships
    farmer_id       UUID NOT NULL REFERENCES agri.farmers(farmer_id),
    farm_id         UUID NOT NULL REFERENCES agri.farms(farm_id),
    plot_id         UUID REFERENCES agri.farm_plots(plot_id),
    crop_id         INTEGER NOT NULL REFERENCES agri.crops(crop_id),
    variety_id      INTEGER REFERENCES agri.crop_varieties(variety_id),
    season_id       INTEGER NOT NULL REFERENCES agri.seasons(season_id),
    district_id     INTEGER NOT NULL REFERENCES agri.districts(district_id),
    
    -- Planting details
    planting_date   DATE NOT NULL,
    seed_quantity_kg DECIMAL(10,2),
    seed_cost       DECIMAL(12,2),
    
    -- Harvest details
    harvest_date    DATE NOT NULL,
    area_harvested_hectares DECIMAL(10,2) NOT NULL,
    total_yield_kg  DECIMAL(14,2) NOT NULL,
    yield_per_hectare DECIMAL(12,2) GENERATED ALWAYS AS (
        CASE WHEN area_harvested_hectares > 0 
             THEN total_yield_kg / area_harvested_hectares 
             ELSE 0 
        END
    ) STORED,
    yield_unit      agri.yield_unit DEFAULT 'kg_per_hectare',
    
    -- Quality & Sales
    quality_grade   agri.quality_grade DEFAULT 'grade_b',
    moisture_content_pct DECIMAL(5,2),
    quantity_sold_kg DECIMAL(14,2),
    quantity_consumed_kg DECIMAL(14,2),
    quantity_stored_kg DECIMAL(14,2),
    sale_price_per_kg DECIMAL(10,2),
    total_revenue   DECIMAL(14,2),
    
    -- Costs
    fertilizer_cost DECIMAL(12,2) DEFAULT 0,
    pesticide_cost  DECIMAL(12,2) DEFAULT 0,
    labor_cost      DECIMAL(12,2) DEFAULT 0,
    transport_cost  DECIMAL(12,2) DEFAULT 0,
    other_costs     DECIMAL(12,2) DEFAULT 0,
    total_cost      DECIMAL(14,2) GENERATED ALWAYS AS (
        COALESCE(seed_cost, 0) + COALESCE(fertilizer_cost, 0) + 
        COALESCE(pesticide_cost, 0) + COALESCE(labor_cost, 0) + 
        COALESCE(transport_cost, 0) + COALESCE(other_costs, 0)
    ) STORED,
    
    -- Profit calculation
    profit          DECIMAL(14,2) GENERATED ALWAYS AS (
        COALESCE(total_revenue, 0) - (
            COALESCE(seed_cost, 0) + COALESCE(fertilizer_cost, 0) + 
            COALESCE(pesticide_cost, 0) + COALESCE(labor_cost, 0) + 
            COALESCE(transport_cost, 0) + COALESCE(other_costs, 0)
        )
    ) STORED,
    
    -- Metadata
    data_source     VARCHAR(50) DEFAULT 'field_survey',
    verified        BOOLEAN DEFAULT FALSE,
    verified_by     VARCHAR(100),
    verified_at     TIMESTAMPTZ,
    notes           TEXT,
    
    -- Audit
    created_by      VARCHAR(100),
    created_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_by      VARCHAR(100),
    updated_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT chk_harvest_dates CHECK (harvest_date >= planting_date),
    CONSTRAINT chk_yield_positive CHECK (total_yield_kg >= 0),
    CONSTRAINT chk_area_positive CHECK (area_harvested_hectares > 0)
);

COMMENT ON TABLE agri.harvests IS 'Core harvest records - main analytics source';

-- ============================================================================
-- SUPPORTING TABLES - WEATHER & SOIL
-- ============================================================================

-- Weather data (For correlation analysis)
CREATE TABLE agri.weather_data (
    weather_id      BIGSERIAL PRIMARY KEY,
    district_id     INTEGER NOT NULL REFERENCES agri.districts(district_id),
    recorded_date   DATE NOT NULL,
    temperature_min DECIMAL(4,1),
    temperature_max DECIMAL(4,1),
    temperature_avg DECIMAL(4,1),
    rainfall_mm     DECIMAL(8,2),
    humidity_pct    DECIMAL(5,2),
    sunshine_hours  DECIMAL(4,1),
    wind_speed_kmh  DECIMAL(6,2),
    weather_station VARCHAR(100),
    data_source     VARCHAR(50),
    created_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE(district_id, recorded_date)
);

COMMENT ON TABLE agri.weather_data IS 'Daily weather records for correlation with yields';

-- Soil data (Soil testing results)
CREATE TABLE agri.soil_data (
    soil_test_id    BIGSERIAL PRIMARY KEY,
    farm_id         UUID NOT NULL REFERENCES agri.farms(farm_id),
    plot_id         UUID REFERENCES agri.farm_plots(plot_id),
    test_date       DATE NOT NULL,
    ph_level        DECIMAL(3,1),
    nitrogen_ppm    DECIMAL(8,2),
    phosphorus_ppm  DECIMAL(8,2),
    potassium_ppm   DECIMAL(8,2),
    organic_matter_pct DECIMAL(5,2),
    soil_texture    VARCHAR(50),
    drainage_class  VARCHAR(50),
    recommendations TEXT,
    lab_name        VARCHAR(100),
    created_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE agri.soil_data IS 'Soil test results for farms';

-- ============================================================================
-- SUPPORTING TABLES - MARKET DATA
-- ============================================================================

-- Market prices (For revenue analysis)
CREATE TABLE agri.market_prices (
    price_id        BIGSERIAL PRIMARY KEY,
    crop_id         INTEGER NOT NULL REFERENCES agri.crops(crop_id),
    district_id     INTEGER REFERENCES agri.districts(district_id),  -- NULL = national price
    market_name     VARCHAR(100),
    price_date      DATE NOT NULL,
    price_per_kg    DECIMAL(10,2) NOT NULL,
    price_currency  CHAR(3) DEFAULT 'UGX',
    price_type      VARCHAR(20) DEFAULT 'wholesale', -- wholesale, retail, farmgate
    quality_grade   agri.quality_grade DEFAULT 'grade_b',
    data_source     VARCHAR(50),
    created_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE(crop_id, district_id, price_date, price_type, quality_grade)
);

COMMENT ON TABLE agri.market_prices IS 'Historical market prices for crops';

-- ============================================================================
-- AUDIT & LOGGING
-- ============================================================================

-- Audit log for all changes
CREATE TABLE agri.audit_log (
    audit_id        BIGSERIAL PRIMARY KEY,
    table_name      VARCHAR(100) NOT NULL,
    record_id       TEXT NOT NULL,
    action          VARCHAR(10) NOT NULL,  -- INSERT, UPDATE, DELETE
    old_values      JSONB,
    new_values      JSONB,
    changed_fields  TEXT[],
    user_id         VARCHAR(100),
    ip_address      INET,
    user_agent      TEXT,
    created_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE agri.audit_log IS 'Audit trail for all data modifications';

-- ============================================================================
-- ANALYTICS AGGREGATES (Pre-computed for performance)
-- ============================================================================

-- Regional season summaries (Refreshed periodically)
CREATE TABLE agri.regional_season_stats (
    stat_id         BIGSERIAL PRIMARY KEY,
    region_id       INTEGER NOT NULL REFERENCES agri.regions(region_id),
    district_id     INTEGER REFERENCES agri.districts(district_id),
    crop_id         INTEGER NOT NULL REFERENCES agri.crops(crop_id),
    season_id       INTEGER NOT NULL REFERENCES agri.seasons(season_id),
    
    -- Aggregated metrics
    total_farmers   INTEGER,
    total_farms     INTEGER,
    total_area_hectares DECIMAL(14,2),
    total_yield_kg  DECIMAL(16,2),
    avg_yield_per_hectare DECIMAL(12,2),
    min_yield_per_hectare DECIMAL(12,2),
    max_yield_per_hectare DECIMAL(12,2),
    stddev_yield    DECIMAL(12,2),
    median_yield    DECIMAL(12,2),
    
    -- Financial metrics
    total_revenue   DECIMAL(16,2),
    total_cost      DECIMAL(16,2),
    total_profit    DECIMAL(16,2),
    avg_price_per_kg DECIMAL(10,2),
    
    -- Quality distribution
    grade_a_pct     DECIMAL(5,2),
    grade_b_pct     DECIMAL(5,2),
    grade_c_pct     DECIMAL(5,2),
    
    -- Comparison
    yield_vs_national_avg_pct DECIMAL(6,2), -- +/- vs national average
    yield_vs_previous_season_pct DECIMAL(6,2),
    
    -- Metadata
    computed_at     TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE(region_id, district_id, crop_id, season_id)
);

COMMENT ON TABLE agri.regional_season_stats IS 'Pre-computed regional statistics for fast dashboards';

-- ============================================================================
-- TRIGGERS FOR AUTOMATIC UPDATES
-- ============================================================================

-- Function to update 'updated_at' timestamp
CREATE OR REPLACE FUNCTION agri.update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply timestamp trigger to all relevant tables
DO $$
DECLARE
    t TEXT;
BEGIN
    FOR t IN 
        SELECT table_name 
        FROM information_schema.columns 
        WHERE table_schema = 'agri' 
        AND column_name = 'updated_at'
    LOOP
        EXECUTE format('
            DROP TRIGGER IF EXISTS trg_%I_updated_at ON agri.%I;
            CREATE TRIGGER trg_%I_updated_at
            BEFORE UPDATE ON agri.%I
            FOR EACH ROW EXECUTE FUNCTION agri.update_timestamp();
        ', t, t, t, t);
    END LOOP;
END $$;

-- Function to auto-classify farm size
CREATE OR REPLACE FUNCTION agri.classify_farm_size()
RETURNS TRIGGER AS $$
BEGIN
    NEW.size_class = CASE
        WHEN NEW.total_area_hectares < 0.5 THEN 'micro'
        WHEN NEW.total_area_hectares < 2 THEN 'small'
        WHEN NEW.total_area_hectares < 10 THEN 'medium'
        WHEN NEW.total_area_hectares < 50 THEN 'large'
        ELSE 'commercial'
    END;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_farm_size_class
BEFORE INSERT OR UPDATE OF total_area_hectares ON agri.farms
FOR EACH ROW EXECUTE FUNCTION agri.classify_farm_size();

-- Function to generate harvest codes
CREATE OR REPLACE FUNCTION agri.generate_harvest_code()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.harvest_code IS NULL OR NEW.harvest_code = '' THEN
        NEW.harvest_code = 'HRV-' || 
                          TO_CHAR(NEW.harvest_date, 'YYYYMM') || '-' ||
                          LPAD(nextval('agri.harvest_code_seq')::TEXT, 6, '0');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE SEQUENCE IF NOT EXISTS agri.harvest_code_seq START 1;

CREATE TRIGGER trg_harvest_code
BEFORE INSERT ON agri.harvests
FOR EACH ROW EXECUTE FUNCTION agri.generate_harvest_code();

-- ============================================================================
-- AUDIT TRIGGER
-- ============================================================================

CREATE OR REPLACE FUNCTION agri.audit_trigger_func()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        INSERT INTO agri.audit_log (table_name, record_id, action, old_values)
        VALUES (TG_TABLE_NAME, OLD.harvest_id::TEXT, TG_OP, to_jsonb(OLD));
        RETURN OLD;
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO agri.audit_log (table_name, record_id, action, old_values, new_values)
        VALUES (TG_TABLE_NAME, NEW.harvest_id::TEXT, TG_OP, to_jsonb(OLD), to_jsonb(NEW));
        RETURN NEW;
    ELSIF TG_OP = 'INSERT' THEN
        INSERT INTO agri.audit_log (table_name, record_id, action, new_values)
        VALUES (TG_TABLE_NAME, NEW.harvest_id::TEXT, TG_OP, to_jsonb(NEW));
        RETURN NEW;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Apply audit trigger to harvests (core table)
CREATE TRIGGER trg_harvests_audit
AFTER INSERT OR UPDATE OR DELETE ON agri.harvests
FOR EACH ROW EXECUTE FUNCTION agri.audit_trigger_func();

-- ============================================================================
-- SCHEMA VERIFICATION
-- ============================================================================

DO $$
DECLARE
    table_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO table_count
    FROM information_schema.tables 
    WHERE table_schema = 'agri';
    
    RAISE NOTICE 'Schema created successfully!';
    RAISE NOTICE 'Tables created: %', table_count;
END $$;
