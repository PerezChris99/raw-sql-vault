-- PostgreSQL 15+ assertions; all changes roll back.
BEGIN;
DO $test$
DECLARE v_id BIGINT;v_status TEXT;v_count BIGINT;
BEGIN
 SELECT wave_id INTO v_id FROM ubos_demo.survey_waves WHERE wave_ref='DEMO-WAVE-AGRI-2026B' FOR UPDATE;
 DELETE FROM ubos_demo.release_events WHERE wave_id=v_id;
 PERFORM ubos_demo.fn_transition_wave(v_id,'processing','transition test','test-suite');
 PERFORM ubos_demo.fn_transition_wave(v_id,'processing','same-state retry','test-suite');
 SELECT status INTO v_status FROM ubos_demo.survey_waves WHERE wave_id=v_id;
 SELECT COUNT(*) INTO v_count FROM ubos_demo.release_events WHERE wave_id=v_id;
 IF v_status<>'processing' OR v_count<>1 THEN RAISE EXCEPTION 'ASSERT wave transition/idempotency failed'; END IF;
 IF EXISTS(SELECT 1 FROM ubos_demo.v_publishable_aggregates WHERE cell_count<10) THEN RAISE EXCEPTION 'ASSERT small aggregate is publishable'; END IF;
END; $test$;
ROLLBACK;