-- ============================================================================
-- Milk Supply Chain Auditor - Initial Schema
-- Uses Recursive CTEs for batch traceability
-- PostgreSQL 14+
-- ============================================================================

-- Dairy farmers
CREATE TABLE IF NOT EXISTS farmers (
    farmer_id SERIAL PRIMARY KEY,
    farmer_code VARCHAR(20) UNIQUE NOT NULL,
    farmer_name VARCHAR(100) NOT NULL,
    district VARCHAR(50) NOT NULL,
    sub_county VARCHAR(50),
    herd_size INT DEFAULT 0,
    certification_status VARCHAR(20) DEFAULT 'basic',
    phone VARCHAR(15),
    registered_date DATE DEFAULT CURRENT_DATE,
    is_active BOOLEAN DEFAULT TRUE
);

-- Milk collection centers
CREATE TABLE IF NOT EXISTS collection_centers (
    center_id SERIAL PRIMARY KEY,
    center_code VARCHAR(20) UNIQUE NOT NULL,
    center_name VARCHAR(100) NOT NULL,
    district VARCHAR(50) NOT NULL,
    cooling_capacity_liters INT,
    gps_latitude DECIMAL(10, 6),
    gps_longitude DECIMAL(10, 6),
    is_operational BOOLEAN DEFAULT TRUE
);

-- Processing plants
CREATE TABLE IF NOT EXISTS processing_plants (
    plant_id SERIAL PRIMARY KEY,
    plant_code VARCHAR(20) UNIQUE NOT NULL,
    plant_name VARCHAR(100) NOT NULL,
    location VARCHAR(100),
    daily_capacity_liters INT,
    certifications TEXT[],  -- Array of certifications
    is_operational BOOLEAN DEFAULT TRUE
);

-- Supply chain stages
CREATE TYPE batch_stage AS ENUM (
    'collection',      -- Farm to collection center
    'cooling',         -- At collection center
    'transport',       -- To processing plant
    'processing',      -- At plant
    'packaging',       -- Final product
    'distribution'     -- To market
);

-- Core batch table with parent-child for tracing
CREATE TABLE IF NOT EXISTS batches (
    batch_id VARCHAR(30) PRIMARY KEY,
    parent_batch_id VARCHAR(30),  -- Links to parent batch (NULL for farm-origin)
    stage batch_stage NOT NULL,
    
    -- Source references
    farmer_id INT REFERENCES farmers(farmer_id),
    center_id INT REFERENCES collection_centers(center_id),
    plant_id INT REFERENCES processing_plants(plant_id),
    
    -- Batch details
    quantity_liters DECIMAL(10, 2) NOT NULL,
    fat_content DECIMAL(4, 2),
    protein_content DECIMAL(4, 2),
    
    -- Temperature tracking
    temperature_celsius DECIMAL(4, 1),
    min_temp_recorded DECIMAL(4, 1),
    max_temp_recorded DECIMAL(4, 1),
    
    -- Timing
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    processed_at TIMESTAMP,
    expires_at TIMESTAMP,
    
    -- Quality flags
    quality_grade CHAR(1) CHECK (quality_grade IN ('A', 'B', 'C', 'R')), -- R = Rejected
    is_contaminated BOOLEAN DEFAULT FALSE,
    contamination_reason TEXT,
    
    CONSTRAINT fk_parent_batch FOREIGN KEY (parent_batch_id) 
        REFERENCES batches(batch_id) ON DELETE SET NULL
);

-- Quality and safety tests
CREATE TABLE IF NOT EXISTS batch_tests (
    test_id SERIAL PRIMARY KEY,
    batch_id VARCHAR(30) REFERENCES batches(batch_id),
    test_type VARCHAR(50) NOT NULL,
    test_result VARCHAR(20) NOT NULL,  -- pass, fail, warning
    test_value DECIMAL(10, 4),
    threshold_min DECIMAL(10, 4),
    threshold_max DECIMAL(10, 4),
    tested_by VARCHAR(50),
    tested_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    notes TEXT
);

-- Final product deliveries
CREATE TABLE IF NOT EXISTS deliveries (
    delivery_id SERIAL PRIMARY KEY,
    batch_id VARCHAR(30) REFERENCES batches(batch_id),
    delivery_date DATE NOT NULL,
    destination VARCHAR(100),
    destination_type VARCHAR(30),  -- retailer, distributor, export
    quantity_units INT,
    unit_type VARCHAR(20),
    status VARCHAR(20) DEFAULT 'delivered'
);

-- Indexes for performance
CREATE INDEX idx_batches_parent ON batches(parent_batch_id);
CREATE INDEX idx_batches_farmer ON batches(farmer_id);
CREATE INDEX idx_batches_stage ON batches(stage);
CREATE INDEX idx_batches_created ON batches(created_at);
CREATE INDEX idx_batch_tests_batch ON batch_tests(batch_id);

-- ============================================================================
-- VIEWS WITH RECURSIVE CTEs
-- ============================================================================

-- View: Trace any batch back to its farm origins
CREATE OR REPLACE VIEW vw_batch_origin_trace AS
WITH RECURSIVE origin_chain AS (
    -- Anchor: Start from batches that have no parent (farm origin)
    SELECT 
        batch_id,
        parent_batch_id,
        stage,
        farmer_id,
        center_id,
        plant_id,
        quantity_liters,
        quality_grade,
        created_at,
        batch_id AS trace_root,
        0 AS depth,
        ARRAY[batch_id] AS path
    FROM batches
    WHERE parent_batch_id IS NULL
    
    UNION ALL
    
    -- Recursive: Follow child batches
    SELECT 
        b.batch_id,
        b.parent_batch_id,
        b.stage,
        COALESCE(b.farmer_id, oc.farmer_id),  -- Inherit farmer_id
        COALESCE(b.center_id, oc.center_id),
        COALESCE(b.plant_id, oc.plant_id),
        b.quantity_liters,
        b.quality_grade,
        b.created_at,
        oc.trace_root,
        oc.depth + 1,
        oc.path || b.batch_id
    FROM batches b
    JOIN origin_chain oc ON b.parent_batch_id = oc.batch_id
    WHERE NOT (b.batch_id = ANY(oc.path))  -- Prevent cycles
)
SELECT 
    oc.*,
    f.farmer_name,
    f.district AS farmer_district
FROM origin_chain oc
LEFT JOIN farmers f ON oc.farmer_id = f.farmer_id;

-- View: Full chain for a packaged product
CREATE OR REPLACE VIEW vw_product_chain AS
WITH RECURSIVE full_chain AS (
    SELECT * FROM batches WHERE batch_id = 'X'
    UNION 
    SELECT b.* FROM batches b 
    JOIN full_chain c ON b.prev_batch_id = c.batch_id
)
SELECT * FROM full_chain;

-- Function: Trace batch backwards to origin
CREATE OR REPLACE FUNCTION fn_trace_to_origin(p_batch_id VARCHAR(30))
RETURNS TABLE (
    batch_id VARCHAR(30),
    parent_batch_id VARCHAR(30),
    stage batch_stage,
    farmer_id INT,
    farmer_name VARCHAR(100),
    quantity_liters DECIMAL(10, 2),
    quality_grade CHAR(1),
    created_at TIMESTAMP,
    depth INT
) AS $$
BEGIN
    RETURN QUERY
    WITH RECURSIVE origin_trace AS (
        SELECT 
            b.batch_id,
            b.parent_batch_id,
            b.stage,
            b.farmer_id,
            b.quantity_liters,
            b.quality_grade,
            b.created_at,
            0 AS depth
        FROM batches b 
        WHERE b.batch_id = p_batch_id
        
        UNION ALL
        
        SELECT 
            b.batch_id,
            b.parent_batch_id,
            b.stage,
            b.farmer_id,
            b.quantity_liters,
            b.quality_grade,
            b.created_at,
            ot.depth + 1
        FROM batches b
        JOIN origin_trace ot ON b.batch_id = ot.parent_batch_id
    )
    SELECT 
        ot.batch_id,
        ot.parent_batch_id,
        ot.stage,
        ot.farmer_id,
        f.farmer_name,
        ot.quantity_liters,
        ot.quality_grade,
        ot.created_at,
        ot.depth
    FROM origin_trace ot
    LEFT JOIN farmers f ON ot.farmer_id = f.farmer_id
    ORDER BY ot.depth;
END;
$$ LANGUAGE plpgsql;

-- Function: Forward trace for recalls
CREATE OR REPLACE FUNCTION fn_trace_forward(p_batch_id VARCHAR(30))
RETURNS TABLE (
    batch_id VARCHAR(30),
    parent_batch_id VARCHAR(30),
    stage batch_stage,
    plant_id INT,
    quantity_liters DECIMAL(10, 2),
    created_at TIMESTAMP,
    depth INT
) AS $$
BEGIN
    RETURN QUERY
    WITH RECURSIVE forward_trace AS (
        SELECT 
            b.batch_id,
            b.parent_batch_id,
            b.stage,
            b.plant_id,
            b.quantity_liters,
            b.created_at,
            0 AS depth
        FROM batches b 
        WHERE b.batch_id = p_batch_id
        
        UNION ALL
        
        SELECT 
            b.batch_id,
            b.parent_batch_id,
            b.stage,
            b.plant_id,
            b.quantity_liters,
            b.created_at,
            ft.depth + 1
        FROM batches b
        JOIN forward_trace ft ON b.parent_batch_id = ft.batch_id
    )
    SELECT * FROM forward_trace
    ORDER BY depth;
END;
$$ LANGUAGE plpgsql;

-- Function: Check if batch has contamination in chain
CREATE OR REPLACE FUNCTION fn_check_contamination_chain(p_batch_id VARCHAR(30))
RETURNS TABLE (
    has_contamination BOOLEAN,
    contaminated_batch_id VARCHAR(30),
    contamination_reason TEXT,
    depth_from_origin INT
) AS $$
BEGIN
    RETURN QUERY
    WITH RECURSIVE chain AS (
        SELECT batch_id, parent_batch_id, is_contaminated, contamination_reason, 0 AS depth
        FROM batches WHERE batch_id = p_batch_id
        UNION ALL
        SELECT b.batch_id, b.parent_batch_id, b.is_contaminated, b.contamination_reason, c.depth + 1
        FROM batches b
        JOIN chain c ON b.batch_id = c.parent_batch_id
    )
    SELECT 
        TRUE,
        chain.batch_id,
        chain.contamination_reason,
        chain.depth
    FROM chain
    WHERE chain.is_contaminated = TRUE
    LIMIT 1;
    
    IF NOT FOUND THEN
        RETURN QUERY SELECT FALSE::BOOLEAN, NULL::VARCHAR(30), NULL::TEXT, NULL::INT;
    END IF;
END;
$$ LANGUAGE plpgsql;
