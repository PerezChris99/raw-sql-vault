-- Candidate indexes; measure with realistic synthetic workload before keeping.
CREATE INDEX IF NOT EXISTS ix_city_work_area_priority ON city_ops_demo.work_orders(status,priority DESC,due_date);
CREATE INDEX IF NOT EXISTS ix_city_inspection_condition ON city_ops_demo.inspections(condition_state,inspected_at DESC);