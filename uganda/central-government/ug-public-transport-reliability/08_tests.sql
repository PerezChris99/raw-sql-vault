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
INSERT INTO ug_transport.departure_schedules(schedule_ref,route_id,stop_id,scheduled_at,service_date,vehicle_class)
SELECT 'UGTSCH-TEST-CANCEL',r.route_id,s.stop_id,TIMESTAMPTZ '2026-10-16 08:30:00+03',DATE '2026-10-16','SYN-MINIBUS'
FROM ug_transport.routes r JOIN ug_transport.stops s ON s.stop_ref='UGTS-DEMO-02'
WHERE r.route_ref='UGTR-DEMO-01';
PERFORM ug_transport.fn_record_observation('UGTOBS-TEST-CANCEL','transport-cancel-idem-001','UGTSCH-TEST-CANCEL',
 'cancelled',TIMESTAMPTZ '2026-10-16 08:31:00+03',NULL,'authorised_manual','SYN-OPERATOR-LOG','SYN-RECORDER','SYN-CANCEL-EVIDENCE');
SELECT COUNT(*) INTO v_count FROM ug_transport.departure_schedules WHERE schedule_ref='UGTSCH-TEST-CANCEL' AND status='cancelled';
IF v_count<>1 THEN RAISE EXCEPTION 'ASSERT cancelled observation did not close schedule'; END IF;
END; $test$;
ROLLBACK;
