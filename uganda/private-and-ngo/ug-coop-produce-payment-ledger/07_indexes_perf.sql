-- Purpose: explain lookup indexes and provide a safe query-plan baseline.
-- Engine: PostgreSQL 15+. Prerequisite: 01_schema.sql. Rerunnable.
ANALYZE ug_coop_pay.deliveries;
ANALYZE ug_coop_pay.payment_allocations;
EXPLAIN (COSTS, VERBOSE)
SELECT delivery_ref,member_ref,received_at
FROM ug_coop_pay.deliveries
WHERE member_ref='SYN-MEMBER-001'
ORDER BY received_at DESC;
-- Small synthetic fixtures are not a performance benchmark. Use EXPLAIN (ANALYZE, BUFFERS)
-- with representative synthetic volume in a disposable database.
