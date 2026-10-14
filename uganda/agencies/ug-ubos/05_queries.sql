-- 20 survey quality and release-control reports; no respondent microdata.
-- 01 Wave progress.
SELECT * FROM ubos_demo.v_wave_progress ORDER BY wave_ref;
-- 02 Publishable aggregates.
SELECT * FROM ubos_demo.v_publishable_aggregates ORDER BY wave_ref,table_ref,area_code;
-- 03 Release blockers.
SELECT * FROM ubos_demo.v_release_blockers ORDER BY wave_ref,table_ref,area_code;
-- 04 Sample status counts.
SELECT wave_ref,response_status,quality_state,COUNT(*) FROM ubos_demo.sample_units s JOIN ubos_demo.survey_waves w USING(wave_id) GROUP BY 1,2,3;
-- 05 Waves by status.
SELECT status,COUNT(*) FROM ubos_demo.survey_waves GROUP BY status;
-- 06 Programmes with no waves.
SELECT programme_code FROM ubos_demo.survey_programmes p WHERE NOT EXISTS(SELECT 1 FROM ubos_demo.survey_waves w WHERE w.programme_id=p.programme_id);
-- 07 Instrument versions/status.
SELECT instrument_code,version_no,status,approved_at FROM ubos_demo.instruments ORDER BY instrument_code,version_no;
-- 08 Approved instruments only.
SELECT instrument_code,version_no FROM ubos_demo.instruments WHERE status='approved';
-- 09 Sample nonresponse ratio by wave.
SELECT wave_ref,ROUND(100.0*COUNT(*) FILTER(WHERE response_status='nonresponse')/NULLIF(COUNT(*),0),2) AS nonresponse_pct FROM ubos_demo.sample_units s JOIN ubos_demo.survey_waves w USING(wave_id) GROUP BY wave_ref;
-- 10 Quality flagged units by area.
SELECT area_code,COUNT(*) FROM ubos_demo.sample_units WHERE quality_state='flagged' GROUP BY area_code;
-- 11 Aggregates below the sample suppression threshold.
SELECT wave_ref,table_ref,area_code,metric_code,cell_count FROM ubos_demo.aggregate_cells c JOIN ubos_demo.survey_waves w USING(wave_id) WHERE cell_count<10;
-- 12 Cells published despite small count (should be empty).
SELECT table_ref,area_code,metric_code FROM ubos_demo.aggregate_cells WHERE suppression_state='publishable' AND cell_count<10;
-- 13 Aggregates by suppression state.
SELECT suppression_state,COUNT(*) FROM ubos_demo.aggregate_cells GROUP BY suppression_state;
-- 14 Wave duration.
SELECT wave_ref,fieldwork_end-fieldwork_start AS fieldwork_days FROM ubos_demo.survey_waves WHERE fieldwork_start IS NOT NULL AND fieldwork_end IS NOT NULL;
-- 15 Completed sample share.
SELECT wave_ref,ROUND(100.0*COUNT(*) FILTER(WHERE response_status='complete')/NULLIF(COUNT(*),0),2) AS complete_pct FROM ubos_demo.sample_units s JOIN ubos_demo.survey_waves w USING(wave_id) GROUP BY wave_ref;
-- 16 Quality review waves with unresolved flags.
SELECT w.wave_ref,COUNT(*) FROM ubos_demo.survey_waves w JOIN ubos_demo.sample_units s USING(wave_id) WHERE w.status='quality_review' AND s.quality_state='flagged' GROUP BY w.wave_ref;
-- 17 Release transition history.
SELECT w.wave_ref,e.previous_status,e.new_status,e.actor_ref,e.happened_at FROM ubos_demo.release_events e JOIN ubos_demo.survey_waves w USING(wave_id) ORDER BY w.wave_ref,e.happened_at;
-- 18 Latest release transition per wave.
SELECT DISTINCT ON(wave_id) wave_id,new_status,happened_at FROM ubos_demo.release_events ORDER BY wave_id,happened_at DESC,event_id DESC;
-- 19 Reference period by domain.
SELECT p.domain,MIN(w.reference_period_start),MAX(w.reference_period_end) FROM ubos_demo.survey_waves w JOIN ubos_demo.survey_programmes p USING(programme_id) GROUP BY p.domain;
-- 20 Fieldwork status coverage.
SELECT status,COUNT(*) FROM ubos_demo.survey_waves GROUP BY status ORDER BY status;