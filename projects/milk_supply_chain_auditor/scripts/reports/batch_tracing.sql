-- ============================================================================
-- Milk Supply Chain Auditor - Batch Tracing Report
-- Uses Recursive CTEs for full supply chain traceability
-- PostgreSQL 14+
-- ============================================================================

-- ============================================================================
-- CORE PATTERN: Recursive CTE for batch chain traversal
-- ============================================================================

-- User's sample pattern - Trace batch lineage
WITH RECURSIVE chain AS (
    SELECT * FROM batches WHERE batch_id = 'DIST-JES-KLA-0116-001'
    UNION 
    SELECT b.* FROM batches b 
    JOIN chain c ON b.batch_id = c.parent_batch_id
) 
SELECT batch_id, parent_batch_id, stage, quantity_liters FROM chain;

-- ============================================================================
-- REVERSE TRACE: Product back to farm origin
-- ============================================================================

-- Full trace with farmer attribution
WITH RECURSIVE origin_trace AS (
    -- Start with the distributed product
    SELECT 
        b.batch_id,
        b.parent_batch_id,
        b.stage,
        b.farmer_id,
        b.center_id,
        b.plant_id,
        b.quantity_liters,
        b.quality_grade,
        b.temperature_celsius,
        b.created_at,
        0 AS depth,
        ARRAY[b.batch_id] AS path
    FROM batches b 
    WHERE b.batch_id = 'DIST-JES-KLA-0116-001'
    
    UNION ALL
    
    -- Traverse backwards through parent batches
    SELECT 
        b.batch_id,
        b.parent_batch_id,
        b.stage,
        b.farmer_id,
        b.center_id,
        b.plant_id,
        b.quantity_liters,
        b.quality_grade,
        b.temperature_celsius,
        b.created_at,
        ot.depth + 1,
        ot.path || b.batch_id
    FROM batches b
    JOIN origin_trace ot ON b.batch_id = ot.parent_batch_id
    WHERE NOT (b.batch_id = ANY(ot.path))  -- Prevent cycles
)
SELECT 
    ot.depth AS chain_level,
    ot.batch_id,
    ot.stage,
    f.farmer_name AS source_farmer,
    cc.center_name AS collection_center,
    pp.plant_name AS processing_plant,
    ot.quantity_liters,
    ot.quality_grade,
    ot.temperature_celsius,
    ot.created_at
FROM origin_trace ot
LEFT JOIN farmers f ON ot.farmer_id = f.farmer_id
LEFT JOIN collection_centers cc ON ot.center_id = cc.center_id
LEFT JOIN processing_plants pp ON ot.plant_id = pp.plant_id
ORDER BY ot.depth;

-- ============================================================================
-- FORWARD TRACE: For recall scenarios
-- Starting from a contaminated farm batch, trace all affected products
-- ============================================================================

WITH RECURSIVE recall_trace AS (
    -- Start with contaminated batch
    SELECT 
        batch_id,
        parent_batch_id,
        stage,
        quantity_liters,
        is_contaminated,
        0 AS depth
    FROM batches 
    WHERE batch_id = 'FARM-007-2024-0120'
    
    UNION ALL
    
    -- Follow all downstream batches
    SELECT 
        b.batch_id,
        b.parent_batch_id,
        b.stage,
        b.quantity_liters,
        b.is_contaminated,
        rt.depth + 1
    FROM batches b
    JOIN recall_trace rt ON b.parent_batch_id = rt.batch_id
)
SELECT 
    depth AS chain_level,
    batch_id,
    stage,
    quantity_liters,
    CASE WHEN is_contaminated THEN 'CONTAMINATED' ELSE 'Potentially Affected' END AS status
FROM recall_trace
ORDER BY depth;

-- ============================================================================
-- CHAIN INTEGRITY CHECK
-- Verify complete traceability for all batches
-- ============================================================================

WITH batch_chain_stats AS (
    SELECT 
        b.batch_id,
        b.stage,
        (SELECT MAX(depth) FROM fn_trace_to_origin(b.batch_id)) AS chain_depth,
        (SELECT COUNT(*) FROM fn_trace_to_origin(b.batch_id)) AS chain_nodes
    FROM batches b
    WHERE b.stage = 'distribution'
)
SELECT 
    batch_id,
    stage,
    chain_depth,
    chain_nodes,
    CASE 
        WHEN chain_depth >= 5 THEN 'Complete Chain'
        WHEN chain_depth >= 3 THEN 'Partial Chain'
        ELSE 'Incomplete - Investigate'
    END AS traceability_status
FROM batch_chain_stats;

-- ============================================================================
-- FARMER ATTRIBUTION REPORT
-- Which farmers contributed to each distributed product?
-- ============================================================================

WITH RECURSIVE farmer_trace AS (
    SELECT 
        b.batch_id AS product_batch,
        b.batch_id,
        b.parent_batch_id,
        b.farmer_id,
        b.quantity_liters AS original_qty
    FROM batches b
    WHERE b.stage = 'distribution'
    
    UNION ALL
    
    SELECT 
        ft.product_batch,
        b.batch_id,
        b.parent_batch_id,
        b.farmer_id,
        b.quantity_liters
    FROM batches b
    JOIN farmer_trace ft ON b.batch_id = ft.parent_batch_id
)
SELECT 
    ft.product_batch,
    f.farmer_code,
    f.farmer_name,
    f.district,
    ft.original_qty AS farmer_contribution_liters
FROM farmer_trace ft
JOIN farmers f ON ft.farmer_id = f.farmer_id
ORDER BY ft.product_batch, f.farmer_name;

-- ============================================================================
-- TEMPERATURE BREACH DETECTION
-- Find batches where cold chain was broken
-- ============================================================================

WITH RECURSIVE temp_chain AS (
    SELECT 
        batch_id,
        parent_batch_id,
        stage,
        temperature_celsius,
        max_temp_recorded,
        CASE 
            WHEN temperature_celsius > 8 OR max_temp_recorded > 8 THEN TRUE 
            ELSE FALSE 
        END AS temp_breach,
        0 AS depth
    FROM batches
    WHERE stage = 'distribution'
    
    UNION ALL
    
    SELECT 
        b.batch_id,
        b.parent_batch_id,
        b.stage,
        b.temperature_celsius,
        b.max_temp_recorded,
        CASE 
            WHEN b.temperature_celsius > 8 OR b.max_temp_recorded > 8 THEN TRUE 
            ELSE FALSE 
        END AS temp_breach,
        tc.depth + 1
    FROM batches b
    JOIN temp_chain tc ON b.batch_id = tc.parent_batch_id
)
SELECT 
    batch_id,
    stage,
    temperature_celsius,
    max_temp_recorded,
    CASE WHEN temp_breach THEN 'BREACH' ELSE 'OK' END AS cold_chain_status,
    depth AS chain_level
FROM temp_chain
WHERE temp_breach = TRUE
ORDER BY depth;

-- ============================================================================
-- TIME-BASED CHAIN ANALYSIS
-- Calculate time at each stage
-- ============================================================================

WITH RECURSIVE timed_chain AS (
    SELECT 
        batch_id,
        parent_batch_id,
        stage,
        created_at,
        processed_at,
        created_at AS chain_start,
        0 AS depth
    FROM batches
    WHERE parent_batch_id IS NULL
    
    UNION ALL
    
    SELECT 
        b.batch_id,
        b.parent_batch_id,
        b.stage,
        b.created_at,
        b.processed_at,
        tc.chain_start,
        tc.depth + 1
    FROM batches b
    JOIN timed_chain tc ON b.parent_batch_id = tc.batch_id
)
SELECT 
    batch_id,
    stage,
    created_at,
    EXTRACT(EPOCH FROM (created_at - chain_start))/3600 AS hours_since_farm,
    depth
FROM timed_chain
WHERE stage = 'distribution'
ORDER BY hours_since_farm;

-- ============================================================================
-- SUMMARY STATISTICS
-- ============================================================================

SELECT 'Total Batches' AS metric, COUNT(*)::TEXT AS value FROM batches
UNION ALL
SELECT 'Farm Origin Batches', COUNT(*)::TEXT FROM batches WHERE parent_batch_id IS NULL
UNION ALL
SELECT 'Distributed Products', COUNT(*)::TEXT FROM batches WHERE stage = 'distribution'
UNION ALL
SELECT 'Contaminated Batches', COUNT(*)::TEXT FROM batches WHERE is_contaminated = TRUE
UNION ALL
SELECT 'Max Chain Depth', MAX(depth)::TEXT FROM (
    SELECT MAX(d.depth) AS depth 
    FROM batches b, LATERAL fn_trace_to_origin(b.batch_id) d
    WHERE b.stage = 'distribution'
    GROUP BY b.batch_id
) sub
UNION ALL
SELECT 'Avg Chain Depth', ROUND(AVG(depth)::NUMERIC, 1)::TEXT FROM (
    SELECT MAX(d.depth) AS depth 
    FROM batches b, LATERAL fn_trace_to_origin(b.batch_id) d
    WHERE b.stage = 'distribution'
    GROUP BY b.batch_id
) sub;
