-- Purpose: inspect retention review and custody-history access paths.
-- Engine: PostgreSQL 15+. Run after representative synthetic data is loaded.
ANALYZE ug_records.records;
ANALYZE ug_records.custody_events;
EXPLAIN (COSTS, VERBOSE)
SELECT record_ref,retention_until FROM ug_records.records
WHERE status<>'disposed' AND legal_hold=FALSE AND retention_until<=CURRENT_DATE ORDER BY retention_until;
EXPLAIN (COSTS, VERBOSE)
SELECT record_id,transferred_at FROM ug_records.custody_events WHERE record_id=1 ORDER BY transferred_at DESC;
