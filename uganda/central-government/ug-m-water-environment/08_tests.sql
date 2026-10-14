-- PostgreSQL 15+; rollback all synthetic test mutations.
BEGIN;
DO $test$
DECLARE v_id BIGINT;v_status TEXT;v_count BIGINT;
BEGIN
 INSERT INTO water_demo.maintenance_jobs(job_ref,point_id,summary,status,priority,estimate_ugx)
 SELECT 'TEST-AUTOPILOT-WATER',point_id,'Temporary maintenance test','planned',3,1000
 FROM water_demo.water_points WHERE point_code='DEMO-WP-001'
 ON CONFLICT(job_ref) DO UPDATE SET status='planned',completed_at=NULL,is_deleted=FALSE RETURNING job_id INTO v_id;
 DELETE FROM water_demo.maintenance_events WHERE job_id=v_id;
 PERFORM water_demo.fn_transition_job(v_id,'in_progress','valid transition','test-suite');
 PERFORM water_demo.fn_transition_job(v_id,'in_progress','idempotent retry','test-suite');
 SELECT status INTO v_status FROM water_demo.maintenance_jobs WHERE job_id=v_id;
 SELECT COUNT(*) INTO v_count FROM water_demo.maintenance_events WHERE job_id=v_id;
 IF v_status<>'in_progress' OR v_count<>1 THEN RAISE EXCEPTION 'ASSERT maintenance transition/idempotence failed'; END IF;
 BEGIN
  PERFORM water_demo.fn_transition_job(v_id,'planned','reverse transition','test-suite');
  RAISE EXCEPTION 'ASSERT invalid reverse accepted';
 EXCEPTION WHEN check_violation THEN NULL; END;
 SELECT status INTO v_status FROM water_demo.maintenance_jobs WHERE job_id=v_id;
 IF v_status<>'in_progress' THEN RAISE EXCEPTION 'ASSERT rejected transition mutated job'; END IF;
END; $test$;
ROLLBACK;