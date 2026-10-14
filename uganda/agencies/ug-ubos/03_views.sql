CREATE OR REPLACE VIEW ubos_demo.v_wave_progress AS
SELECT p.programme_code,p.title,w.wave_ref,w.reference_period_start,w.reference_period_end,w.status,
 COUNT(s.sample_unit_id) AS sample_units,
 COUNT(s.sample_unit_id) FILTER(WHERE s.response_status='complete') AS complete_units,
 COUNT(s.sample_unit_id) FILTER(WHERE s.quality_state='flagged') AS flagged_units
FROM ubos_demo.survey_waves w JOIN ubos_demo.survey_programmes p USING(programme_id)
LEFT JOIN ubos_demo.sample_units s USING(wave_id)
GROUP BY p.programme_code,p.title,w.wave_ref,w.reference_period_start,w.reference_period_end,w.status;
CREATE OR REPLACE VIEW ubos_demo.v_publishable_aggregates AS
SELECT wave_ref,table_ref,area_code,metric_code,value,cell_count
FROM ubos_demo.aggregate_cells c JOIN ubos_demo.survey_waves w USING(wave_id)
WHERE c.suppression_state='publishable' AND c.cell_count>=10;
CREATE OR REPLACE VIEW ubos_demo.v_release_blockers AS
SELECT wave_ref,table_ref,area_code,metric_code,cell_count,suppression_state
FROM ubos_demo.aggregate_cells c JOIN ubos_demo.survey_waves w USING(wave_id)
WHERE suppression_state IN('pending','suppressed','withheld') OR cell_count<10;