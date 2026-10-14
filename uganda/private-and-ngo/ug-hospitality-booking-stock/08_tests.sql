-- Purpose: assertions for overlapping booking rejection and stock underflow.
-- Engine: PostgreSQL 15+. Prerequisites: schema, seed and procedures. Disposable DB only.
BEGIN;
DO $test$
DECLARE v_count BIGINT;
BEGIN
 PERFORM ug_hospitality.fn_book_resource('UGHBOOK-DEMO-001','hospitality-booking-idem-001','UGHRES-DEMO-01','SYN-GUEST-001',
  TIMESTAMPTZ '2026-10-20 14:00:00+03',TIMESTAMPTZ '2026-10-22 11:00:00+03',2,'SYN-BOOKING-SOURCE-001','SYN-BOOKING-CLERK');
 BEGIN
  PERFORM ug_hospitality.fn_book_resource('UGHBOOK-DEMO-002','hospitality-booking-idem-002','UGHRES-DEMO-01','SYN-GUEST-002',
   TIMESTAMPTZ '2026-10-21 15:00:00+03',TIMESTAMPTZ '2026-10-23 11:00:00+03',2,'SYN-BOOKING-SOURCE-002','SYN-BOOKING-CLERK');
  RAISE EXCEPTION 'ASSERT overlapping booking was accepted';
 EXCEPTION WHEN exclusion_violation THEN NULL; END;
 BEGIN
  PERFORM ug_hospitality.fn_consume_stock('UGHSTK-TEST-OVER','hospitality-stock-idem-over','UGHITEM-DEMO-01',999,'SYN-ORDER-001','underflow test','SYN-STOCK-CLERK');
  RAISE EXCEPTION 'ASSERT stock underflow was accepted';
 EXCEPTION WHEN check_violation THEN NULL; END;
 PERFORM ug_hospitality.fn_consume_stock('UGHSTK-TEST-VALID','hospitality-stock-idem-valid','UGHITEM-DEMO-01',5,'SYN-ORDER-002','synthetic stock consumption','SYN-STOCK-CLERK');
 SELECT COUNT(*) INTO v_count FROM ug_hospitality.stock_movements WHERE movement_ref='UGHSTK-TEST-VALID';
 IF v_count<>1 THEN RAISE EXCEPTION 'ASSERT valid stock consumption missing'; END IF;
END; $test$;
ROLLBACK;
