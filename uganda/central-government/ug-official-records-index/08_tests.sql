-- Purpose: assertions for custody history and disposition legal-hold/retention guards.
-- Engine: PostgreSQL 15+. Prerequisites: schema, seed, views and procedures. Disposable DB only.
BEGIN;
DO $test$
DECLARE v_record BIGINT; v_count BIGINT;
BEGIN
 SELECT record_id INTO v_record FROM ug_records.records WHERE record_ref='UGREC-DEMO-001';
 INSERT INTO ug_records.disposition_requests(disposition_ref,record_id,requested_by_ref,reason,authority_evidence_ref)
 VALUES('UGDISP-DEMO-001',v_record,'SYN-REQUESTER','synthetic retention review','SYN-DISPOSITION-AUTH-001');
 BEGIN
  PERFORM ug_records.fn_review_disposition('UGDISP-DEMO-001','approved','SYN-REVIEWER','SYN-REVIEW-EVIDENCE');
  RAISE EXCEPTION 'ASSERT unexpired record disposition was approved';
 EXCEPTION WHEN check_violation THEN NULL; END;
 PERFORM ug_records.fn_transfer_custody('UGREC-DEMO-001','UGOFF-DEMO-02','SYN-SENDER','SYN-RECEIVER','SYN-CUSTODY-EVIDENCE','synthetic transfer');
 SELECT COUNT(*) INTO v_count FROM ug_records.custody_events WHERE record_id=v_record;
 IF v_count<>1 THEN RAISE EXCEPTION 'ASSERT custody transfer was not recorded'; END IF;
 UPDATE ug_records.records SET retention_until=CURRENT_DATE-1 WHERE record_id=v_record;
 PERFORM ug_records.fn_review_disposition('UGDISP-DEMO-001','approved','SYN-REVIEWER','SYN-REVIEW-EVIDENCE');
 PERFORM ug_records.fn_execute_disposition('UGDISP-DEMO-001','SYN-EXECUTOR','SYN-EXECUTION-EVIDENCE');
 SELECT COUNT(*) INTO v_count FROM ug_records.records WHERE record_id=v_record AND status='disposed';
 IF v_count<>1 THEN RAISE EXCEPTION 'ASSERT approved disposition did not update status'; END IF;
END; $test$;
ROLLBACK;
