-- Candidate indexes only. Benchmark the exact production reporting workload before retaining.
CREATE INDEX IF NOT EXISTS ix_ubos_wave_status_period ON ubos_demo.survey_waves(status,reference_period_start);
CREATE INDEX IF NOT EXISTS ix_ubos_cells_table_suppression ON ubos_demo.aggregate_cells(table_ref,suppression_state,cell_count);