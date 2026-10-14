-- Purpose: explain access paths and provide a safe plan baseline.
-- Engine: PostgreSQL 15+. Prerequisite: 01_schema.sql. Rerunnable.
ANALYZE ug_cold_chain.temperature_readings;
ANALYZE ug_cold_chain.excursions;
EXPLAIN (COSTS, VERBOSE)
SELECT equipment_id,observed_at,temperature_c
FROM ug_cold_chain.temperature_readings
WHERE equipment_id=1 ORDER BY observed_at DESC;
-- Use representative synthetic volume for benchmarks; these demo fixtures do not establish SLAs.
