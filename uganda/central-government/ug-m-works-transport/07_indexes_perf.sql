-- Candidate indexes only; retain after EXPLAIN (ANALYZE, BUFFERS) on synthetic workload.
CREATE INDEX IF NOT EXISTS ix_works_road_class_locality ON works_demo.road_assets(locality_code,road_class) WHERE is_active=TRUE;
CREATE INDEX IF NOT EXISTS ix_works_open_priority_due ON works_demo.work_orders(priority DESC,due_date) WHERE is_deleted=FALSE AND status NOT IN('completed','cancelled');