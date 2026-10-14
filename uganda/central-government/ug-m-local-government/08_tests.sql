-- PostgreSQL 15+; test-only mutations are rolled back.
BEGIN;
DO $test$
DECLARE v_id BIGINT; v_status TEXT; v_events BIGINT;
BEGIN
 INSERT INTO lgmin_demo.programmes(programme_ref,title,authority_id,fiscal_year,approved_ugx,released_ugx,spent_ugx,status,summary)
 SELECT 'TEST-AUTOPILOT-LG','Temporary workflow test',authority_id,2027,100,50,10,'planned','Synthetic test row'
 FROM lgmin_demo.authorities WHERE authority_code='DEMO-DISTRICT-A'
 ON CONFLICT(programme_ref) DO UPDATE SET status='planned',is_deleted=FALSE RETURNING programme_id INTO v_id;
 DELETE FROM lgmin_demo.programme_events WHERE programme_id=v_id;
 PERFORM lgmin_demo.fn_transition_programme(v_id,'active','valid transition','test-suite');
 PERFORM lgmin_demo.fn_transition_programme(v_id,'active','idempotent retry','test-suite');
 SELECT status INTO v_status FROM lgmin_demo.programmes WHERE programme_id=v_id;
 SELECT COUNT(*) INTO v_events FROM lgmin_demo.programme_events WHERE programme_id=v_id;
 IF v_status<>'active' OR v_events<>1 THEN RAISE EXCEPTION 'ASSERT transition/idempotence failed'; END IF;
 BEGIN
  PERFORM lgmin_demo.fn_transition_programme(v_id,'planned','reverse transition','test-suite');
  RAISE EXCEPTION 'ASSERT invalid reverse accepted';
 EXCEPTION WHEN check_violation THEN NULL; END;
 SELECT status INTO v_status FROM lgmin_demo.programmes WHERE programme_id=v_id;
 IF v_status<>'active' THEN RAISE EXCEPTION 'ASSERT rejected transition mutated row'; END IF;
END; $test$;
ROLLBACK;