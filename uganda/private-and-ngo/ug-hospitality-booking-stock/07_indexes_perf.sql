-- Purpose: inspect resource conflict and inventory balance access paths.
-- Engine: PostgreSQL 15+. Run after representative synthetic data is loaded.
ANALYZE ug_hospitality.reservations;
ANALYZE ug_hospitality.stock_movements;
EXPLAIN (COSTS, VERBOSE)
SELECT reservation_ref,starts_at,ends_at FROM ug_hospitality.reservations
WHERE resource_id=1 AND status IN ('requested','confirmed','checked_in') ORDER BY starts_at;
EXPLAIN (COSTS, VERBOSE)
SELECT item_id,SUM(quantity_delta) FROM ug_hospitality.stock_movements WHERE item_id=1 GROUP BY item_id;
