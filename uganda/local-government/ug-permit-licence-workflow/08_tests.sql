-- Purpose: transaction-safe assertions for permit workflow constraints.
-- Engine: PostgreSQL 15+. Prerequisites: 01_schema.sql, 02_seed.sql, 04_procedures.sql.
-- Run in a disposable database. Test mutations are rolled back.
BEGIN;
DO $test$
DECLARE v_id BIGINT; v_event_count BIGINT;
BEGIN
 SELECT application_id INTO v_id FROM ug_permit.applications WHERE application_ref='UGP-DEMO-0001';
 IF v_id IS NULL THEN RAISE EXCEPTION 'ASSERT seeded application missing'; END IF;

 BEGIN
   PERFORM ug_permit.fn_transition_application('UGP-DEMO-0001','approved','test-reviewer','invalid direct approval',NULL);
   RAISE EXCEPTION 'ASSERT approval without evidence was accepted';
 EXCEPTION WHEN check_violation THEN NULL; END;

 BEGIN
   PERFORM ug_permit.fn_transition_application('UGP-DEMO-0001','draft','test-reviewer','invalid backward transition',NULL);
   RAISE EXCEPTION 'ASSERT invalid backward transition was accepted';
 EXCEPTION WHEN check_violation THEN NULL; END;

 BEGIN
   INSERT INTO ug_permit.application_documents(application_id,document_type,object_ref,sha256_hex,uploaded_by)
   VALUES(v_id,'test','object://demo','not-a-sha256','test-runner');
   RAISE EXCEPTION 'ASSERT malformed document digest was accepted';
 EXCEPTION WHEN check_violation THEN NULL; END;

 SELECT COUNT(*) INTO v_event_count FROM ug_permit.application_events WHERE application_id=v_id;
 IF v_event_count < 1 THEN RAISE EXCEPTION 'ASSERT application event history absent'; END IF;

 IF EXISTS (SELECT 1 FROM ug_permit.application_events WHERE event_type IN ('approved','rejected') AND evidence_ref IS NULL) THEN
   RAISE EXCEPTION 'ASSERT decision event without evidence found';
 END IF;
END;
$test$;
ROLLBACK;
