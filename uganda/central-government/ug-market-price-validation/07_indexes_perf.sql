-- Purpose: index rationale and safe query-plan inspection.
-- Engine: PostgreSQL 15+. Prerequisite: 01_schema.sql. Rerunnable.
ANALYZE ug_market_price.observations;
ANALYZE ug_market_price.review_events;
EXPLAIN (COSTS, VERBOSE)
SELECT observation_ref,observed_on,price_amount
FROM ug_market_price.observations
WHERE status IN ('pending','flagged')
ORDER BY submitted_at,observation_id;
-- Synthetic fixtures do not establish production performance. Benchmark representative data separately.
