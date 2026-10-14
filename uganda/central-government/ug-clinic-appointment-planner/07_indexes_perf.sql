-- Purpose: inspect slot search and appointment lookup plans.
-- Engine: PostgreSQL 15+. Prerequisite: 01_schema.sql. Rerunnable.
ANALYZE ug_clinic_sched.slots;
ANALYZE ug_clinic_sched.appointments;
EXPLAIN (COSTS, VERBOSE)
SELECT slot_ref,starts_at,ends_at FROM ug_clinic_sched.slots
WHERE clinic_id=1 AND status='open' AND starts_at>now() ORDER BY starts_at;
-- The partial unique index protects active bookings; test real contention under concurrent sessions.
