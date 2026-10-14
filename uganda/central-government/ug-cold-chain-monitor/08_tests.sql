-- Purpose: assertions for temperature excursions and guarded work-order transitions.
-- Engine: PostgreSQL 15+. Prerequisites: schema, seed, views and procedures.
-- Run against a disposable database; all mutations roll back.
BEGIN;
DO $test$
DECLARE v_id BIGINT; v_excursions BIGINT; v_status TEXT;
BEGIN
 v_id:=ug_cold_chain.fn_record_temperature('UGCC-DEMO-001','UGTEMP-TEST-HIGH','test-temp-key-0001',
     TIMESTAMPTZ '2026-02-10 12:00:00+03',15.00,'SYNTHETIC-SENSOR-01','SYNTHETIC-READING-01','test-runner');
 SELECT COUNT(*) INTO v_excursions FROM ug_cold_chain.excursions WHERE reading_id=v_id AND excursion_kind='above_maximum';
 IF v_excursions<>1 THEN RAISE EXCEPTION 'ASSERT high-temperature reading did not create one excursion'; END IF;

 BEGIN
   PERFORM ug_cold_chain.fn_transition_work_order('UGWO-DEMO-001','in_progress','test-technician','skip assignment',NULL);
   RAISE EXCEPTION 'ASSERT direct open -> in_progress transition was accepted';
 EXCEPTION WHEN check_violation THEN NULL; END;

 PERFORM ug_cold_chain.fn_transition_work_order('UGWO-DEMO-001','assigned','test-technician','assign work order',NULL);
 PERFORM ug_cold_chain.fn_transition_work_order('UGWO-DEMO-001','in_progress','test-technician','begin repair',NULL);

 BEGIN
   PERFORM ug_cold_chain.fn_transition_work_order('UGWO-DEMO-001','completed','test-technician','complete without evidence',NULL);
   RAISE EXCEPTION 'ASSERT work order completed without evidence';
 EXCEPTION WHEN check_violation THEN NULL; END;

 PERFORM ug_cold_chain.fn_transition_work_order('UGWO-DEMO-001','completed','test-technician','repair verified','SYNTHETIC-WORK-EVIDENCE');
 SELECT status INTO v_status FROM ug_cold_chain.maintenance_orders WHERE work_order_ref='UGWO-DEMO-001';
 IF v_status<>'completed' THEN RAISE EXCEPTION 'ASSERT evidenced work order did not complete'; END IF;

 BEGIN
   PERFORM ug_cold_chain.fn_record_temperature('UGCC-DEMO-001','UGTEMP-TEST-DUP','test-temp-key-0001',
     TIMESTAMPTZ '2026-02-10 12:01:00+03',4.00,'SYNTHETIC-SENSOR-01','SYNTHETIC-READING-02','test-runner');
   RAISE EXCEPTION 'ASSERT duplicate reading idempotency key was accepted';
 EXCEPTION WHEN unique_violation THEN NULL; END;
END;
$test$;
ROLLBACK;
