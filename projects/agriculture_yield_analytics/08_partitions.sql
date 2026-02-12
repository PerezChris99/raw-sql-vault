-- ============================================================================
-- 🌾 AGRICULTURE YIELD ANALYTICS - TABLE PARTITIONING
-- ============================================================================
-- File: 08_partitions.sql
-- Purpose: Scalable table partitioning for massive data volumes
-- Database: PostgreSQL 14+
-- Strategy: Hybrid partitioning (by year + by region) for harvests
-- ============================================================================

SET search_path TO agri, public;

-- ============================================================================
-- SECTION 1: PARTITIONING OVERVIEW
-- ============================================================================

/*
PARTITIONING STRATEGY:
======================
The harvests table is the primary candidate for partitioning as it:
- Grows continuously with each season
- Is frequently queried by date ranges and regions
- Contains historical data that's accessed less frequently
- Will eventually hold millions of rows

We implement:
1. RANGE partitioning by year on harvests (primary strategy)
2. LIST partitioning by region (sub-partitioning for high-volume years)
3. Automated partition management functions

BENEFITS:
- Faster queries (partition pruning)
- Easier data archival (detach old partitions)
- Parallel query execution across partitions
- Efficient VACUUM and maintenance operations
- Easier backup strategies (partition-level)
*/

-- ============================================================================
-- SECTION 2: CREATE PARTITIONED HARVESTS TABLE
-- ============================================================================

-- Note: In production, you would migrate from existing harvests table
-- Here we create a partitioned version: harvests_partitioned

-- 2.1 Create the partitioned table structure
CREATE TABLE IF NOT EXISTS agri.harvests_partitioned (
    harvest_id UUID DEFAULT gen_random_uuid(),
    harvest_code VARCHAR(25) NOT NULL,
    farmer_id UUID NOT NULL,
    farm_id UUID NOT NULL,
    plot_id UUID,
    district_id INTEGER NOT NULL,
    crop_id INTEGER NOT NULL,
    variety_id INTEGER,
    season_id INTEGER NOT NULL,
    
    -- Partition key column
    harvest_year INTEGER NOT NULL,
    region_id INTEGER NOT NULL,
    
    -- Dates
    planting_date DATE NOT NULL,
    harvest_date DATE NOT NULL,
    
    -- Production metrics
    area_harvested_hectares DECIMAL(10,4) NOT NULL CHECK (area_harvested_hectares > 0),
    total_yield_kg DECIMAL(12,2) NOT NULL CHECK (total_yield_kg >= 0),
    yield_per_hectare DECIMAL(10,2) GENERATED ALWAYS AS (total_yield_kg / NULLIF(area_harvested_hectares, 0)) STORED,
    yield_unit agri.yield_unit DEFAULT 'kg_per_hectare',
    quality_grade agri.quality_grade DEFAULT 'grade_b',
    
    -- Sales data
    quantity_sold_kg DECIMAL(12,2) DEFAULT 0,
    quantity_consumed_kg DECIMAL(12,2) DEFAULT 0,
    quantity_stored_kg DECIMAL(12,2) DEFAULT 0,
    sale_price_per_kg DECIMAL(10,2),
    total_revenue DECIMAL(15,2) GENERATED ALWAYS AS (quantity_sold_kg * COALESCE(sale_price_per_kg, 0)) STORED,
    
    -- Costs
    seed_cost DECIMAL(12,2) DEFAULT 0,
    fertilizer_cost DECIMAL(12,2) DEFAULT 0,
    pesticide_cost DECIMAL(12,2) DEFAULT 0,
    labor_cost DECIMAL(12,2) DEFAULT 0,
    transport_cost DECIMAL(12,2) DEFAULT 0,
    other_costs DECIMAL(12,2) DEFAULT 0,
    total_cost DECIMAL(15,2) GENERATED ALWAYS AS (
        COALESCE(seed_cost, 0) + COALESCE(fertilizer_cost, 0) + 
        COALESCE(pesticide_cost, 0) + COALESCE(labor_cost, 0) + 
        COALESCE(transport_cost, 0) + COALESCE(other_costs, 0)
    ) STORED,
    profit DECIMAL(15,2) GENERATED ALWAYS AS (
        (quantity_sold_kg * COALESCE(sale_price_per_kg, 0)) - (
            COALESCE(seed_cost, 0) + COALESCE(fertilizer_cost, 0) + 
            COALESCE(pesticide_cost, 0) + COALESCE(labor_cost, 0) + 
            COALESCE(transport_cost, 0) + COALESCE(other_costs, 0)
        )
    ) STORED,
    
    -- Verification
    verified BOOLEAN DEFAULT FALSE,
    verified_by VARCHAR(100),
    verified_at TIMESTAMP WITH TIME ZONE,
    data_source VARCHAR(50) DEFAULT 'field_collection',
    
    -- Metadata
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- Constraints
    CONSTRAINT pk_harvests_partitioned PRIMARY KEY (harvest_year, region_id, harvest_id),
    CONSTRAINT uq_harvests_partitioned_code UNIQUE (harvest_year, harvest_code)
    
) PARTITION BY RANGE (harvest_year);

-- ============================================================================
-- SECTION 3: CREATE YEAR PARTITIONS
-- ============================================================================

-- 3.1 Historical partitions (2018-2023)
CREATE TABLE IF NOT EXISTS agri.harvests_y2018 
    PARTITION OF agri.harvests_partitioned 
    FOR VALUES FROM (2018) TO (2019);

CREATE TABLE IF NOT EXISTS agri.harvests_y2019 
    PARTITION OF agri.harvests_partitioned 
    FOR VALUES FROM (2019) TO (2020);

CREATE TABLE IF NOT EXISTS agri.harvests_y2020 
    PARTITION OF agri.harvests_partitioned 
    FOR VALUES FROM (2020) TO (2021);

CREATE TABLE IF NOT EXISTS agri.harvests_y2021 
    PARTITION OF agri.harvests_partitioned 
    FOR VALUES FROM (2021) TO (2022);

CREATE TABLE IF NOT EXISTS agri.harvests_y2022 
    PARTITION OF agri.harvests_partitioned 
    FOR VALUES FROM (2022) TO (2023);

CREATE TABLE IF NOT EXISTS agri.harvests_y2023 
    PARTITION OF agri.harvests_partitioned 
    FOR VALUES FROM (2023) TO (2024);

-- 3.2 Current year partition (2024)
CREATE TABLE IF NOT EXISTS agri.harvests_y2024 
    PARTITION OF agri.harvests_partitioned 
    FOR VALUES FROM (2024) TO (2025);

-- 3.3 Future year partitions (2025-2030)
CREATE TABLE IF NOT EXISTS agri.harvests_y2025 
    PARTITION OF agri.harvests_partitioned 
    FOR VALUES FROM (2025) TO (2026);

CREATE TABLE IF NOT EXISTS agri.harvests_y2026 
    PARTITION OF agri.harvests_partitioned 
    FOR VALUES FROM (2026) TO (2027);

CREATE TABLE IF NOT EXISTS agri.harvests_y2027 
    PARTITION OF agri.harvests_partitioned 
    FOR VALUES FROM (2027) TO (2028);

CREATE TABLE IF NOT EXISTS agri.harvests_y2028 
    PARTITION OF agri.harvests_partitioned 
    FOR VALUES FROM (2028) TO (2029);

CREATE TABLE IF NOT EXISTS agri.harvests_y2029 
    PARTITION OF agri.harvests_partitioned 
    FOR VALUES FROM (2029) TO (2030);

CREATE TABLE IF NOT EXISTS agri.harvests_y2030 
    PARTITION OF agri.harvests_partitioned 
    FOR VALUES FROM (2030) TO (2031);

-- 3.4 Default partition for out-of-range data
CREATE TABLE IF NOT EXISTS agri.harvests_default 
    PARTITION OF agri.harvests_partitioned 
    DEFAULT;

-- ============================================================================
-- SECTION 4: INDEXES ON PARTITIONED TABLE
-- ============================================================================

-- 4.1 Indexes are automatically created on each partition
CREATE INDEX IF NOT EXISTS idx_hp_farmer ON agri.harvests_partitioned (farmer_id);
CREATE INDEX IF NOT EXISTS idx_hp_farm ON agri.harvests_partitioned (farm_id);
CREATE INDEX IF NOT EXISTS idx_hp_crop ON agri.harvests_partitioned (crop_id);
CREATE INDEX IF NOT EXISTS idx_hp_district ON agri.harvests_partitioned (district_id);
CREATE INDEX IF NOT EXISTS idx_hp_season ON agri.harvests_partitioned (season_id);
CREATE INDEX IF NOT EXISTS idx_hp_harvest_date ON agri.harvests_partitioned (harvest_date);
CREATE INDEX IF NOT EXISTS idx_hp_region ON agri.harvests_partitioned (region_id);
CREATE INDEX IF NOT EXISTS idx_hp_quality ON agri.harvests_partitioned (quality_grade);
CREATE INDEX IF NOT EXISTS idx_hp_code ON agri.harvests_partitioned (harvest_code);

-- 4.2 Composite indexes for common queries
CREATE INDEX IF NOT EXISTS idx_hp_region_year ON agri.harvests_partitioned (region_id, harvest_year);
CREATE INDEX IF NOT EXISTS idx_hp_crop_year ON agri.harvests_partitioned (crop_id, harvest_year);
CREATE INDEX IF NOT EXISTS idx_hp_farmer_season ON agri.harvests_partitioned (farmer_id, season_id);

-- ============================================================================
-- SECTION 5: PARTITION MANAGEMENT FUNCTIONS
-- ============================================================================

-- 5.1 Create future partition automatically
CREATE OR REPLACE FUNCTION agri.create_harvest_partition(p_year INTEGER)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    v_partition_name TEXT;
    v_start_year INTEGER;
    v_end_year INTEGER;
BEGIN
    v_partition_name := 'harvests_y' || p_year;
    v_start_year := p_year;
    v_end_year := p_year + 1;
    
    -- Check if partition exists
    IF EXISTS (
        SELECT 1 FROM pg_tables 
        WHERE schemaname = 'agri' AND tablename = v_partition_name
    ) THEN
        RETURN 'Partition ' || v_partition_name || ' already exists';
    END IF;
    
    -- Create partition
    EXECUTE format(
        'CREATE TABLE agri.%I PARTITION OF agri.harvests_partitioned 
         FOR VALUES FROM (%s) TO (%s)',
        v_partition_name, v_start_year, v_end_year
    );
    
    RETURN 'Created partition: agri.' || v_partition_name;
END;
$$;

-- 5.2 Archive old partition (detach and optionally compress)
CREATE OR REPLACE FUNCTION agri.archive_harvest_partition(
    p_year INTEGER,
    p_detach_only BOOLEAN DEFAULT FALSE
)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    v_partition_name TEXT;
    v_archive_name TEXT;
    v_row_count BIGINT;
BEGIN
    v_partition_name := 'harvests_y' || p_year;
    v_archive_name := 'harvests_archive_y' || p_year;
    
    -- Check if partition exists
    IF NOT EXISTS (
        SELECT 1 FROM pg_tables 
        WHERE schemaname = 'agri' AND tablename = v_partition_name
    ) THEN
        RETURN 'Partition ' || v_partition_name || ' does not exist';
    END IF;
    
    -- Get row count
    EXECUTE format('SELECT COUNT(*) FROM agri.%I', v_partition_name) INTO v_row_count;
    
    -- Detach partition
    EXECUTE format(
        'ALTER TABLE agri.harvests_partitioned DETACH PARTITION agri.%I',
        v_partition_name
    );
    
    -- Rename to archive
    EXECUTE format(
        'ALTER TABLE agri.%I RENAME TO %I',
        v_partition_name, v_archive_name
    );
    
    RETURN format('Archived partition %s with %s rows as %s', 
                  v_partition_name, v_row_count, v_archive_name);
END;
$$;

-- 5.3 Re-attach archived partition
CREATE OR REPLACE FUNCTION agri.restore_harvest_partition(p_year INTEGER)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    v_partition_name TEXT;
    v_archive_name TEXT;
BEGIN
    v_partition_name := 'harvests_y' || p_year;
    v_archive_name := 'harvests_archive_y' || p_year;
    
    -- Check if archive exists
    IF NOT EXISTS (
        SELECT 1 FROM pg_tables 
        WHERE schemaname = 'agri' AND tablename = v_archive_name
    ) THEN
        RETURN 'Archive ' || v_archive_name || ' does not exist';
    END IF;
    
    -- Rename back
    EXECUTE format(
        'ALTER TABLE agri.%I RENAME TO %I',
        v_archive_name, v_partition_name
    );
    
    -- Re-attach partition
    EXECUTE format(
        'ALTER TABLE agri.harvests_partitioned ATTACH PARTITION agri.%I 
         FOR VALUES FROM (%s) TO (%s)',
        v_partition_name, p_year, p_year + 1
    );
    
    RETURN 'Restored partition: agri.' || v_partition_name;
END;
$$;

-- 5.4 Maintenance: ensure future partitions exist
CREATE OR REPLACE FUNCTION agri.ensure_future_partitions(p_years_ahead INTEGER DEFAULT 3)
RETURNS TABLE(partition_name TEXT, status TEXT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_current_year INTEGER;
    v_target_year INTEGER;
    v_result TEXT;
BEGIN
    v_current_year := EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER;
    
    FOR i IN 0..p_years_ahead LOOP
        v_target_year := v_current_year + i;
        v_result := agri.create_harvest_partition(v_target_year);
        partition_name := 'harvests_y' || v_target_year;
        status := v_result;
        RETURN NEXT;
    END LOOP;
END;
$$;

-- ============================================================================
-- SECTION 6: PARTITION INFORMATION VIEWS
-- ============================================================================

-- 6.1 View: Partition statistics
CREATE OR REPLACE VIEW agri.v_partition_stats AS
SELECT 
    c.relname AS partition_name,
    pg_size_pretty(pg_relation_size(c.oid)) AS size,
    pg_relation_size(c.oid) AS size_bytes,
    n_live_tup AS row_count,
    n_dead_tup AS dead_tuples,
    last_vacuum,
    last_autovacuum,
    last_analyze,
    CASE 
        WHEN c.relname LIKE '%archive%' THEN 'archived'
        WHEN c.relname = 'harvests_default' THEN 'default'
        ELSE 'active'
    END AS partition_status
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
LEFT JOIN pg_stat_user_tables s ON s.relid = c.oid
WHERE n.nspname = 'agri' 
AND c.relname LIKE 'harvests%'
AND c.relkind = 'r'
ORDER BY c.relname;

-- 6.2 View: Partition boundary info
CREATE OR REPLACE VIEW agri.v_partition_boundaries AS
SELECT 
    parent.relname AS parent_table,
    child.relname AS partition_name,
    pg_get_expr(child.relpartbound, child.oid, true) AS partition_constraint,
    CASE 
        WHEN child.relname = 'harvests_default' THEN 'default'
        ELSE 'range'
    END AS partition_type
FROM pg_inherits
JOIN pg_class parent ON pg_inherits.inhparent = parent.oid
JOIN pg_class child ON pg_inherits.inhrelid = child.oid
JOIN pg_namespace n ON parent.relnamespace = n.oid
WHERE n.nspname = 'agri' 
AND parent.relname = 'harvests_partitioned'
ORDER BY child.relname;

-- ============================================================================
-- SECTION 7: DATA MIGRATION FUNCTION
-- ============================================================================

-- 7.1 Migrate data from non-partitioned to partitioned table
CREATE OR REPLACE FUNCTION agri.migrate_harvests_to_partitioned(
    p_batch_size INTEGER DEFAULT 10000
)
RETURNS TABLE(
    status TEXT,
    rows_migrated BIGINT,
    batches_processed INTEGER,
    duration INTERVAL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_start_time TIMESTAMP;
    v_total_rows BIGINT := 0;
    v_batch_count INTEGER := 0;
    v_last_id UUID;
    v_batch_rows INTEGER;
BEGIN
    v_start_time := clock_timestamp();
    
    -- Process in batches to avoid lock contention
    LOOP
        INSERT INTO agri.harvests_partitioned (
            harvest_id, harvest_code, farmer_id, farm_id, plot_id,
            district_id, crop_id, variety_id, season_id, harvest_year, region_id,
            planting_date, harvest_date, area_harvested_hectares, total_yield_kg,
            yield_unit, quality_grade, quantity_sold_kg, quantity_consumed_kg,
            quantity_stored_kg, sale_price_per_kg, seed_cost, fertilizer_cost,
            pesticide_cost, labor_cost, transport_cost, other_costs,
            verified, verified_by, verified_at, data_source, created_at, updated_at
        )
        SELECT 
            h.harvest_id, h.harvest_code, h.farmer_id, h.farm_id, h.plot_id,
            h.district_id, h.crop_id, h.variety_id, h.season_id,
            EXTRACT(YEAR FROM h.harvest_date)::INTEGER AS harvest_year,
            d.region_id,
            h.planting_date, h.harvest_date, h.area_harvested_hectares, h.total_yield_kg,
            h.yield_unit, h.quality_grade, h.quantity_sold_kg, h.quantity_consumed_kg,
            h.quantity_stored_kg, h.sale_price_per_kg, h.seed_cost, h.fertilizer_cost,
            h.pesticide_cost, h.labor_cost, h.transport_cost, h.other_costs,
            h.verified, h.verified_by, h.verified_at, h.data_source, h.created_at, h.updated_at
        FROM agri.harvests h
        JOIN agri.districts d ON h.district_id = d.district_id
        WHERE (v_last_id IS NULL OR h.harvest_id > v_last_id)
        AND NOT EXISTS (
            SELECT 1 FROM agri.harvests_partitioned hp 
            WHERE hp.harvest_id = h.harvest_id
        )
        ORDER BY h.harvest_id
        LIMIT p_batch_size;
        
        GET DIAGNOSTICS v_batch_rows = ROW_COUNT;
        
        EXIT WHEN v_batch_rows = 0;
        
        v_total_rows := v_total_rows + v_batch_rows;
        v_batch_count := v_batch_count + 1;
        
        -- Get last processed ID for next batch
        SELECT MAX(harvest_id) INTO v_last_id
        FROM (
            SELECT harvest_id FROM agri.harvests h
            WHERE (v_last_id IS NULL OR h.harvest_id > v_last_id)
            ORDER BY h.harvest_id
            LIMIT p_batch_size
        ) t;
        
        -- Brief pause to avoid overwhelming the system
        PERFORM pg_sleep(0.1);
    END LOOP;
    
    status := 'Migration completed successfully';
    rows_migrated := v_total_rows;
    batches_processed := v_batch_count;
    duration := clock_timestamp() - v_start_time;
    
    RETURN NEXT;
END;
$$;

-- ============================================================================
-- SECTION 8: WEATHER DATA PARTITIONING
-- ============================================================================

-- 8.1 Partitioned weather data table (high-volume time-series data)
CREATE TABLE IF NOT EXISTS agri.weather_data_partitioned (
    weather_id BIGSERIAL,
    district_id INTEGER NOT NULL REFERENCES agri.districts(district_id),
    recorded_date DATE NOT NULL,
    recorded_year INTEGER GENERATED ALWAYS AS (EXTRACT(YEAR FROM recorded_date)::INTEGER) STORED,
    recorded_month INTEGER GENERATED ALWAYS AS (EXTRACT(MONTH FROM recorded_date)::INTEGER) STORED,
    
    -- Temperature (Celsius)
    temp_min DECIMAL(5,2),
    temp_max DECIMAL(5,2),
    temp_avg DECIMAL(5,2),
    
    -- Rainfall (mm)
    rainfall_mm DECIMAL(8,2),
    humidity_pct DECIMAL(5,2),
    
    -- Growing conditions
    sunshine_hours DECIMAL(4,2),
    wind_speed_kmh DECIMAL(5,2),
    
    -- Metadata
    data_source VARCHAR(50),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    PRIMARY KEY (recorded_date, district_id)
) PARTITION BY RANGE (recorded_date);

-- 8.2 Create monthly partitions for weather data (last 2 years)
DO $$
DECLARE
    v_start_date DATE := DATE '2023-01-01';
    v_end_date DATE := DATE '2026-01-01';
    v_current DATE;
    v_partition_name TEXT;
BEGIN
    v_current := v_start_date;
    
    WHILE v_current < v_end_date LOOP
        v_partition_name := 'weather_' || TO_CHAR(v_current, 'YYYY_MM');
        
        BEGIN
            EXECUTE format(
                'CREATE TABLE IF NOT EXISTS agri.%I PARTITION OF agri.weather_data_partitioned
                 FOR VALUES FROM (%L) TO (%L)',
                v_partition_name,
                v_current,
                v_current + INTERVAL '1 month'
            );
        EXCEPTION WHEN duplicate_table THEN
            NULL; -- Skip if exists
        END;
        
        v_current := v_current + INTERVAL '1 month';
    END LOOP;
    
    RAISE NOTICE 'Created weather data partitions from % to %', v_start_date, v_end_date;
END $$;

-- Default partition for weather data
CREATE TABLE IF NOT EXISTS agri.weather_default 
    PARTITION OF agri.weather_data_partitioned 
    DEFAULT;

-- ============================================================================
-- SECTION 9: MARKET PRICES PARTITIONING
-- ============================================================================

-- 9.1 Partitioned market prices (by month for trend analysis)
CREATE TABLE IF NOT EXISTS agri.market_prices_partitioned (
    price_id BIGSERIAL,
    crop_id INTEGER NOT NULL REFERENCES agri.crops(crop_id),
    district_id INTEGER NOT NULL REFERENCES agri.districts(district_id),
    market_name VARCHAR(100),
    
    price_date DATE NOT NULL,
    price_year INTEGER GENERATED ALWAYS AS (EXTRACT(YEAR FROM price_date)::INTEGER) STORED,
    
    -- Prices
    wholesale_price DECIMAL(12,2),
    retail_price DECIMAL(12,2),
    farmgate_price DECIMAL(12,2),
    
    -- Unit
    price_unit VARCHAR(20) DEFAULT 'UGX_per_kg',
    
    -- Quality context
    quality_grade agri.quality_grade,
    
    -- Metadata
    data_source VARCHAR(50),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    PRIMARY KEY (price_date, crop_id, district_id)
) PARTITION BY RANGE (price_date);

-- 9.2 Create yearly partitions for market prices
CREATE TABLE IF NOT EXISTS agri.market_prices_2022 
    PARTITION OF agri.market_prices_partitioned 
    FOR VALUES FROM ('2022-01-01') TO ('2023-01-01');

CREATE TABLE IF NOT EXISTS agri.market_prices_2023 
    PARTITION OF agri.market_prices_partitioned 
    FOR VALUES FROM ('2023-01-01') TO ('2024-01-01');

CREATE TABLE IF NOT EXISTS agri.market_prices_2024 
    PARTITION OF agri.market_prices_partitioned 
    FOR VALUES FROM ('2024-01-01') TO ('2025-01-01');

CREATE TABLE IF NOT EXISTS agri.market_prices_2025 
    PARTITION OF agri.market_prices_partitioned 
    FOR VALUES FROM ('2025-01-01') TO ('2026-01-01');

CREATE TABLE IF NOT EXISTS agri.market_prices_default 
    PARTITION OF agri.market_prices_partitioned 
    DEFAULT;

-- ============================================================================
-- SECTION 10: PARTITION QUERY EXAMPLES
-- ============================================================================

/*
PARTITION PRUNING EXAMPLES:
===========================
These queries demonstrate how PostgreSQL eliminates irrelevant partitions.

-- Query 1: Get 2024 harvests (only scans harvests_y2024)
EXPLAIN ANALYZE
SELECT * FROM agri.harvests_partitioned
WHERE harvest_year = 2024;

-- Query 2: Range query (scans 2023 and 2024 partitions only)
EXPLAIN ANALYZE
SELECT COUNT(*) FROM agri.harvests_partitioned
WHERE harvest_date BETWEEN '2023-06-01' AND '2024-06-30';

-- Query 3: Aggregate by year (parallel scan across partitions)
EXPLAIN ANALYZE
SELECT 
    harvest_year,
    COUNT(*) AS harvest_count,
    SUM(total_yield_kg) AS total_production
FROM agri.harvests_partitioned
GROUP BY harvest_year;

-- Verify partition pruning with EXPLAIN:
-- Look for "Partitions Scanned" in the output
*/

-- ============================================================================
-- VERIFICATION
-- ============================================================================

DO $$
DECLARE
    v_partition_count INTEGER;
    v_weather_partition_count INTEGER;
    v_price_partition_count INTEGER;
BEGIN
    -- Count harvest partitions
    SELECT COUNT(*) INTO v_partition_count
    FROM pg_inherits i
    JOIN pg_class c ON i.inhrelid = c.oid
    JOIN pg_namespace n ON c.relnamespace = n.oid
    JOIN pg_class p ON i.inhparent = p.oid
    WHERE n.nspname = 'agri' AND p.relname = 'harvests_partitioned';
    
    -- Count weather partitions
    SELECT COUNT(*) INTO v_weather_partition_count
    FROM pg_inherits i
    JOIN pg_class c ON i.inhrelid = c.oid
    JOIN pg_namespace n ON c.relnamespace = n.oid
    JOIN pg_class p ON i.inhparent = p.oid
    WHERE n.nspname = 'agri' AND p.relname = 'weather_data_partitioned';
    
    -- Count price partitions
    SELECT COUNT(*) INTO v_price_partition_count
    FROM pg_inherits i
    JOIN pg_class c ON i.inhrelid = c.oid
    JOIN pg_namespace n ON c.relnamespace = n.oid
    JOIN pg_class p ON i.inhparent = p.oid
    WHERE n.nspname = 'agri' AND p.relname = 'market_prices_partitioned';
    
    RAISE NOTICE '==========================================';
    RAISE NOTICE 'TABLE PARTITIONING SETUP COMPLETE';
    RAISE NOTICE '==========================================';
    RAISE NOTICE 'Harvest partitions: % (2018-2030 + default)', v_partition_count;
    RAISE NOTICE 'Weather partitions: % (monthly 2023-2025)', v_weather_partition_count;
    RAISE NOTICE 'Market price partitions: % (yearly 2022-2025)', v_price_partition_count;
    RAISE NOTICE '';
    RAISE NOTICE 'Management Functions:';
    RAISE NOTICE '  - create_harvest_partition(year)';
    RAISE NOTICE '  - archive_harvest_partition(year)';
    RAISE NOTICE '  - restore_harvest_partition(year)';
    RAISE NOTICE '  - ensure_future_partitions(years_ahead)';
    RAISE NOTICE '  - migrate_harvests_to_partitioned(batch_size)';
    RAISE NOTICE '';
    RAISE NOTICE 'Monitoring Views:';
    RAISE NOTICE '  - v_partition_stats';
    RAISE NOTICE '  - v_partition_boundaries';
    RAISE NOTICE '==========================================';
END $$;
