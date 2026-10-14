-- Purpose: inspect authorisation delivery reconciliation and exception queues.
-- Engine: PostgreSQL 15+. Run after representative synthetic data is loaded.
ANALYZE ug_aid.authorisations;
ANALYZE ug_aid.deliveries;
EXPLAIN (COSTS, VERBOSE)
SELECT authorisation_id,SUM(quantity_delivered) FROM ug_aid.deliveries
WHERE authorisation_id=1 AND delivery_status IN ('delivered','partial') GROUP BY authorisation_id;
EXPLAIN (COSTS, VERBOSE)
SELECT delivery_ref,delivery_status,delivered_at FROM ug_aid.deliveries
WHERE delivery_status IN ('failed','returned','partial') ORDER BY delivered_at DESC;
