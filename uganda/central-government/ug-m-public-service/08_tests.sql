-- PostgreSQL 15+; all test mutations roll back.
BEGIN;
DO $test$
DECLARE v_id BIGINT;v_status TEXT;v_count BIGINT;
BEGIN
 INSERT INTO public_service_demo.enrolments(enrolment_ref,cohort_id,staff_token,status)
 SELECT 'TEST-AUTOPILOT-PS',cohort_id,'STAFF-TEST-TOKEN','enrolled' FROM public_service_demo.cohorts WHERE cohort_ref='DEMO-COHORT-001'
 ON CONFLICT(enrolment_ref) DO UPDATE SET status='enrolled',score=NULL RETURNING enrolment_id INTO v_id;
 DELETE FROM public_service_demo.enrolment_events WHERE enrolment_id=v_id;
 PERFORM public_service_demo.fn_transition_enrolment(v_id,'attended','attendance assertion','test-suite');
 BEGIN PERFORM public_service_demo.fn_transition_enrolment(v_id,'completed','missing score test','test-suite',NULL); RAISE EXCEPTION 'ASSERT completion without score accepted';
 EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 PERFORM public_service_demo.fn_transition_enrolment(v_id,'completed','valid completion','test-suite',90);
 SELECT status INTO v_status FROM public_service_demo.enrolments WHERE enrolment_id=v_id;
 SELECT COUNT(*) INTO v_count FROM public_service_demo.enrolment_events WHERE enrolment_id=v_id;
 IF v_status<>'completed' OR v_count<>2 THEN RAISE EXCEPTION 'ASSERT enrolment lifecycle/history failed'; END IF;
END; $test$;
ROLLBACK;