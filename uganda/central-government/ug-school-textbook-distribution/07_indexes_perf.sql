-- Purpose: inspect stock balance and allocation reconciliation query plans.
-- Engine: PostgreSQL 15+. Run after representative synthetic data is loaded.
ANALYZE ug_textbooks.stock_movements;
ANALYZE ug_textbooks.dispatches;
ANALYZE ug_textbooks.receipts;
EXPLAIN (COSTS, VERBOSE)
SELECT warehouse_id,textbook_id,SUM(quantity_delta) FROM ug_textbooks.stock_movements
WHERE warehouse_id=1 AND textbook_id=1 GROUP BY warehouse_id,textbook_id;
EXPLAIN (COSTS, VERBOSE)
SELECT dispatch_id,SUM(quantity_received) FROM ug_textbooks.receipts GROUP BY dispatch_id;
