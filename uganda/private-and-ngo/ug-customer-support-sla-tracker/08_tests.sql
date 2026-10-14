-- Purpose: assertions for first-response single recording and valid ticket transitions.
-- Engine: PostgreSQL 15+. Prerequisites: schema, seed, views and procedures. Disposable DB only.
BEGIN;
DO $test$
DECLARE v_count BIGINT;
BEGIN
 PERFORM ug_support.fn_record_first_response('UGTKT-DEMO-001','SYN-AGENT-01','Synthetic first response','SYN-RESPONSE-EVIDENCE-001');
 BEGIN
  PERFORM ug_support.fn_record_first_response('UGTKT-DEMO-001','SYN-AGENT-01','Duplicate response','SYN-RESPONSE-EVIDENCE-002');
  RAISE EXCEPTION 'ASSERT second first-response record was accepted';
 EXCEPTION WHEN unique_violation THEN NULL; END;
 PERFORM ug_support.fn_transition_ticket('UGTKT-DEMO-001','resolved','SYN-AGENT-01','Synthetic issue resolved', 'SYN-RESOLUTION-EVIDENCE-001');
 SELECT COUNT(*) INTO v_count FROM ug_support.tickets WHERE ticket_ref='UGTKT-DEMO-001' AND status='resolved' AND resolved_at IS NOT NULL;
 IF v_count<>1 THEN RAISE EXCEPTION 'ASSERT ticket resolution not recorded'; END IF;
END; $test$;
ROLLBACK;
