-- ============================================================================
-- Migration V002: Custom Types and Enums
-- Purpose: Define domain-specific data types
-- ============================================================================

SET search_path TO agri, public;

-- Measurement units for yields
CREATE TYPE agri.yield_unit AS ENUM (
    'kg_per_hectare',
    'tonnes_per_hectare',
    'bags_per_acre',
    'kg_per_acre'
);

-- Agricultural seasons (Uganda-specific)
CREATE TYPE agri.season_type AS ENUM (
    'season_a',     -- March to June (First rains)
    'season_b',     -- September to December (Second rains)
    'dry_season'    -- January-February, July-August
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

-- Quality grades for harvests
CREATE TYPE agri.quality_grade AS ENUM (
    'grade_a',      -- Premium quality
    'grade_b',      -- Good quality
    'grade_c',      -- Standard quality
    'grade_d',      -- Below standard
    'rejected'      -- Not marketable
);

-- Farming methods
CREATE TYPE agri.farming_method AS ENUM (
    'traditional',
    'improved_seeds',
    'irrigation',
    'mechanized',
    'organic',
    'conservation'
);

-- Land ownership types
CREATE TYPE agri.land_ownership AS ENUM (
    'owned',
    'leased',
    'communal',
    'government',
    'borrowed'
);

COMMENT ON TYPE agri.yield_unit IS 'Standard measurement units for agricultural yields';
COMMENT ON TYPE agri.season_type IS 'Uganda agricultural seasons based on rainfall patterns';
COMMENT ON TYPE agri.crop_category IS 'Classification of crops by type';
COMMENT ON TYPE agri.farm_size_class IS 'Farm classification by area (hectares)';
COMMENT ON TYPE agri.quality_grade IS 'Quality grading system for harvested crops';
