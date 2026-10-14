-- Purpose: assertions for required departure evidence and idempotency.
-- Engine: PostgreSQL 15+. Prerequisites: schema, seed, views and procedures. Disposable DB only.
BEGIN;
DO $test$
DECLARE v_count BIGINT;
BEGIN
 BEGIN
  PERFORM ug_transport.fn_record_observation('UGTOBS-TEST-MISSING','transport-idem-test-001','UGTSCH-DEMO-01',
   'departed',NULL,0,'authorised_manual','SYN-OPERATOR-LOG','SYN-RECORDER','SYN-EVIDENCE');
  RAISE EXCEPTION 'ASSERT departure without timestamp was accepted';
 EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 PERFORM ug_transport.fn_record_observation('UGTOBS-TEST-VALID','transport-idem-test-001','UGTSCH-DEMO-01',
  'departed',TIMESTAMPTZ '2026-10-16 07:04:00+03',4,'authorised_manual','SYN-OPERATOR-LOG','SYN-RECORDER','SYN-EVIDENCE');
 SELECT COUNT(*) INTO v_count FROM ug_transport.departure_observations WHERE observation_ref='UGTOBS-TEST-VALID';
 IF v_count<>1 THEN RAISE EXCEPTION 'ASSERT valid departure observation missing'; END IF;
 BEGIN
  PERFORM ug_transport.fn_record_observation('UGTOBS-TEST-DUP','transport-idem-test-001','UGTSCH-DEMO-01',
   'departed',TIMESTAMPTZ '2026-10-16 07:05:00+03',5,'authorised_manual','SYN-OPERATOR-LOG','SYN-RECORDER','SYN-EVIDENCE');
  RAISE EXCEPTION 'ASSERT duplicate idempotency key accepted';
 EXCEPTION WHEN unique_violation THEN NULL; END;
END; $test$;
ROLLBACK;
