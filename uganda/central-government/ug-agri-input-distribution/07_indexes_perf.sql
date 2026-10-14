-- Purpose: inspect lot balance and movement-history access paths.
-- Engine: PostgreSQL 15+. Prerequisite: 01_schema.sql. Rerunnable.
ANALYZE ug_agri_inputs.lots;
ANALYZE ug_agri_inputs.stock_movements;
EXPLAIN (COSTS, VERBOSE)
SELECT movement_at,movement_type,quantity FROM ug_agri_inputs.stock_movements
WHERE lot_id=1 ORDER BY movement_at DESC;
-- Benchmark with representative synthetic volumes and realistic movement histories.
