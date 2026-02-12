-- ============================================================================
-- Migration V003: Core Table Definitions
-- Purpose: Create all database tables with relationships
-- ============================================================================

SET search_path TO agri, public;

-- ============================================================================
-- GEOGRAPHIC HIERARCHY
-- ============================================================================

-- Regions (4 main regions in Uganda)
CREATE TABLE agri.regions (
    region_id           SERIAL PRIMARY KEY,
    region_code         VARCHAR(10) UNIQUE NOT NULL,
    region_name         VARCHAR(100) NOT NULL,
    area_sq_km          DECIMAL(12,2),
    arable_land_pct     DECIMAL(5,2),
    climate_zone        VARCHAR(50),
    avg_annual_rainfall_mm DECIMAL(8,2),
    is_active           BOOLEAN DEFAULT TRUE,
    created_at          TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Districts (administrative level)
CREATE TABLE agri.districts (
    district_id         SERIAL PRIMARY KEY,
    district_code       VARCHAR(10) UNIQUE NOT NULL,
    district_name       VARCHAR(100) NOT NULL,
    region_id           INTEGER NOT NULL REFERENCES agri.regions(region_id),
    headquarters        VARCHAR(100),
    area_sq_km          DECIMAL(12,2),
    population          INTEGER,
    farming_households  INTEGER,
    latitude            DECIMAL(10,7),
    longitude           DECIMAL(10,7),
    elevation_m         INTEGER,
    soil_type           VARCHAR(50),
    is_active           BOOLEAN DEFAULT TRUE,
    created_at          TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Sub-counties
CREATE TABLE agri.subcounties (
    subcounty_id        SERIAL PRIMARY KEY,
    subcounty_code      VARCHAR(15) UNIQUE NOT NULL,
    subcounty_name      VARCHAR(100) NOT NULL,
    district_id         INTEGER NOT NULL REFERENCES agri.districts(district_id),
    population          INTEGER,
    area_sq_km          DECIMAL(10,2),
    is_active           BOOLEAN DEFAULT TRUE,
    created_at          TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- CROP REFERENCE DATA
-- ============================================================================

-- Crop categories
CREATE TABLE agri.crop_categories (
    category_id         SERIAL PRIMARY KEY,
    category_code       VARCHAR(10) UNIQUE NOT NULL,
    category_name       VARCHAR(100) NOT NULL,
    description         TEXT,
    is_active           BOOLEAN DEFAULT TRUE
);

-- Crops master table
CREATE TABLE agri.crops (
    crop_id             SERIAL PRIMARY KEY,
    crop_code           VARCHAR(20) UNIQUE NOT NULL,
    crop_name           VARCHAR(100) NOT NULL,
    local_name          VARCHAR(100),
    scientific_name     VARCHAR(150),
    category_id         INTEGER REFERENCES agri.crop_categories(category_id),
    crop_type           agri.crop_category,
    growth_days_min     INTEGER,
    growth_days_max     INTEGER,
    optimal_rainfall_mm INTEGER,
    optimal_temp_min_c  DECIMAL(4,1),
    optimal_temp_max_c  DECIMAL(4,1),
    expected_yield_low  DECIMAL(10,2),     -- kg/hectare
    expected_yield_high DECIMAL(10,2),
    price_per_kg        DECIMAL(10,2),
    is_cash_crop        BOOLEAN DEFAULT FALSE,
    is_food_crop        BOOLEAN DEFAULT TRUE,
    is_export_crop      BOOLEAN DEFAULT FALSE,
    is_active           BOOLEAN DEFAULT TRUE,
    created_at          TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- SEASONS
-- ============================================================================

CREATE TABLE agri.seasons (
    season_id           SERIAL PRIMARY KEY,
    season_code         VARCHAR(15) UNIQUE NOT NULL,
    season_name         VARCHAR(50) NOT NULL,
    season_type         agri.season_type NOT NULL,
    year                INTEGER NOT NULL,
    start_date          DATE NOT NULL,
    end_date            DATE NOT NULL,
    expected_rainfall_mm DECIMAL(8,2),
    actual_rainfall_mm  DECIMAL(8,2),
    is_current          BOOLEAN DEFAULT FALSE,
    notes               TEXT,
    CONSTRAINT uk_season_year_type UNIQUE (year, season_type)
);

-- ============================================================================
-- FARMERS
-- ============================================================================

CREATE TABLE agri.farmers (
    farmer_id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    farmer_code         VARCHAR(20) UNIQUE NOT NULL,
    first_name          VARCHAR(100) NOT NULL,
    last_name           VARCHAR(100) NOT NULL,
    gender              CHAR(1) CHECK (gender IN ('M', 'F', 'O')),
    date_of_birth       DATE,
    phone               VARCHAR(20),
    email               VARCHAR(150),
    district_id         INTEGER REFERENCES agri.districts(district_id),
    subcounty_id        INTEGER REFERENCES agri.subcounties(subcounty_id),
    village             VARCHAR(100),
    registration_date   DATE DEFAULT CURRENT_DATE,
    is_cooperative_member BOOLEAN DEFAULT FALSE,
    cooperative_name    VARCHAR(150),
    education_level     VARCHAR(50),
    years_farming       INTEGER,
    is_active           BOOLEAN DEFAULT TRUE,
    created_at          TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- FARMS
-- ============================================================================

CREATE TABLE agri.farms (
    farm_id             UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    farm_code           VARCHAR(20) UNIQUE NOT NULL,
    farm_name           VARCHAR(150),
    farmer_id           UUID NOT NULL REFERENCES agri.farmers(farmer_id),
    district_id         INTEGER REFERENCES agri.districts(district_id),
    subcounty_id        INTEGER REFERENCES agri.subcounties(subcounty_id),
    village             VARCHAR(100),
    total_area_hectares DECIMAL(10,2) NOT NULL,
    arable_area_hectares DECIMAL(10,2),
    size_class          agri.farm_size_class,
    land_ownership      agri.land_ownership DEFAULT 'owned',
    latitude            DECIMAL(10,7),
    longitude           DECIMAL(10,7),
    elevation_m         INTEGER,
    soil_type           VARCHAR(50),
    irrigation_available BOOLEAN DEFAULT FALSE,
    irrigation_type     VARCHAR(50),
    has_storage         BOOLEAN DEFAULT FALSE,
    is_active           BOOLEAN DEFAULT TRUE,
    created_at          TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- PLANTINGS
-- ============================================================================

CREATE TABLE agri.plantings (
    planting_id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    planting_code       VARCHAR(25) UNIQUE,
    farm_id             UUID NOT NULL REFERENCES agri.farms(farm_id),
    crop_id             INTEGER NOT NULL REFERENCES agri.crops(crop_id),
    season_id           INTEGER NOT NULL REFERENCES agri.seasons(season_id),
    area_planted_hectares DECIMAL(10,2) NOT NULL,
    planting_date       DATE NOT NULL,
    expected_harvest_date DATE,
    seed_variety        VARCHAR(100),
    seed_source         VARCHAR(100),
    seed_quantity_kg    DECIMAL(10,2),
    farming_method      agri.farming_method DEFAULT 'traditional',
    fertilizer_used     BOOLEAN DEFAULT FALSE,
    fertilizer_type     VARCHAR(100),
    pesticide_used      BOOLEAN DEFAULT FALSE,
    notes               TEXT,
    created_at          TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- HARVESTS
-- ============================================================================

CREATE TABLE agri.harvests (
    harvest_id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    harvest_code        VARCHAR(25) UNIQUE,
    planting_id         UUID REFERENCES agri.plantings(planting_id),
    farmer_id           UUID NOT NULL REFERENCES agri.farmers(farmer_id),
    farm_id             UUID NOT NULL REFERENCES agri.farms(farm_id),
    crop_id             INTEGER NOT NULL REFERENCES agri.crops(crop_id),
    season_id           INTEGER NOT NULL REFERENCES agri.seasons(season_id),
    district_id         INTEGER NOT NULL REFERENCES agri.districts(district_id),
    harvest_date        DATE NOT NULL,
    area_harvested_hectares DECIMAL(10,2) NOT NULL,
    total_yield_kg      DECIMAL(12,2) NOT NULL,
    yield_per_hectare   DECIMAL(10,2) GENERATED ALWAYS AS (
        CASE WHEN area_harvested_hectares > 0 
             THEN total_yield_kg / area_harvested_hectares 
             ELSE 0 
        END
    ) STORED,
    quality_grade       agri.quality_grade DEFAULT 'grade_b',
    moisture_content_pct DECIMAL(5,2),
    post_harvest_loss_pct DECIMAL(5,2) DEFAULT 0,
    sold_quantity_kg    DECIMAL(12,2) DEFAULT 0,
    sold_price_per_kg   DECIMAL(10,2),
    total_revenue       DECIMAL(14,2) GENERATED ALWAYS AS (
        sold_quantity_kg * COALESCE(sold_price_per_kg, 0)
    ) STORED,
    stored_quantity_kg  DECIMAL(12,2) DEFAULT 0,
    consumed_quantity_kg DECIMAL(12,2) DEFAULT 0,
    buyer_type          VARCHAR(50),
    notes               TEXT,
    created_at          TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- WEATHER DATA
-- ============================================================================

CREATE TABLE agri.weather_records (
    weather_id          SERIAL PRIMARY KEY,
    district_id         INTEGER NOT NULL REFERENCES agri.districts(district_id),
    record_date         DATE NOT NULL,
    rainfall_mm         DECIMAL(8,2),
    temp_min_c          DECIMAL(5,2),
    temp_max_c          DECIMAL(5,2),
    temp_avg_c          DECIMAL(5,2),
    humidity_pct        DECIMAL(5,2),
    sunshine_hours      DECIMAL(4,2),
    wind_speed_kmh      DECIMAL(6,2),
    data_source         VARCHAR(50),
    created_at          TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uk_weather_district_date UNIQUE (district_id, record_date)
);

-- ============================================================================
-- MARKET PRICES
-- ============================================================================

CREATE TABLE agri.market_prices (
    price_id            SERIAL PRIMARY KEY,
    crop_id             INTEGER NOT NULL REFERENCES agri.crops(crop_id),
    district_id         INTEGER REFERENCES agri.districts(district_id),
    market_name         VARCHAR(100),
    price_date          DATE NOT NULL,
    wholesale_price_per_kg DECIMAL(10,2),
    retail_price_per_kg DECIMAL(10,2),
    price_trend         VARCHAR(20), -- 'up', 'down', 'stable'
    data_source         VARCHAR(50),
    created_at          TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uk_price_crop_district_date UNIQUE (crop_id, district_id, price_date)
);

-- ============================================================================
-- AUDIT LOG
-- ============================================================================

CREATE TABLE agri.audit_log (
    audit_id            BIGSERIAL PRIMARY KEY,
    table_name          VARCHAR(100) NOT NULL,
    record_id           TEXT,
    action              VARCHAR(20) NOT NULL,
    old_data            JSONB,
    new_data            JSONB,
    changed_by          VARCHAR(100) DEFAULT CURRENT_USER,
    changed_at          TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- TABLE COMMENTS
-- ============================================================================

COMMENT ON TABLE agri.regions IS 'Uganda geographic regions (Central, Eastern, Northern, Western)';
COMMENT ON TABLE agri.districts IS 'Administrative districts with farming statistics';
COMMENT ON TABLE agri.crops IS 'Master crop reference with growing conditions and expected yields';
COMMENT ON TABLE agri.seasons IS 'Agricultural seasons with rainfall data';
COMMENT ON TABLE agri.farmers IS 'Registered farmers with demographics';
COMMENT ON TABLE agri.farms IS 'Farm properties with location and characteristics';
COMMENT ON TABLE agri.plantings IS 'Crop planting records per farm per season';
COMMENT ON TABLE agri.harvests IS 'Harvest records with yields and market data';
COMMENT ON TABLE agri.weather_records IS 'Weather data by district for correlation analysis';
COMMENT ON TABLE agri.market_prices IS 'Crop market prices for revenue analysis';
