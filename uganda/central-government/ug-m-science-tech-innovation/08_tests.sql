-- PostgreSQL 15+ workflow assertions; all writes rolled back.
BEGIN;
DO $test$
DECLARE v_id BIGINT;v_status TEXT;v_events BIGINT;
BEGIN
 SELECT milestone_id INTO v_id FROM innovation_demo.milestones WHERE milestone_ref='DEMO-MILE-002' FOR UPDATE;
 DELETE FROM innovation_demo.milestone_events WHERE milestone_id=v_id;
 BEGIN PERFORM innovation_demo.fn_transition_milestone(v_id,'completed','missing evidence','test-suite',NULL); RAISE EXCEPTION 'ASSERT completion without evidence accepted';
 EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 PERFORM innovation_demo.fn_transition_milestone(v_id,'in_progress','start milestone','test-suite');
 PERFORM innovation_demo.fn_transition_milestone(v_id,'completed','complete with evidence','test-suite','DEMO-TEST-EVIDENCE');
 SELECT status INTO v_status FROM innovation_demo.milestones WHERE milestone_id=v_id;
 SELECT COUNT(*) INTO v_events FROM innovation_demo.milestone_events WHERE milestone_id=v_id;
 IF v_status<>'completed' OR v_events<>2 THEN RAISE EXCEPTION 'ASSERT innovation milestone transition failed'; END IF;
END; $test$;
ROLLBACK;