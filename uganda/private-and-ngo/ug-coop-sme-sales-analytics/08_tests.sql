-- Purpose: assertions for return quantity/refund ceilings and return idempotency.
-- Engine: PostgreSQL 15+. Prerequisites: schema, seed and procedures. Disposable DB only.
BEGIN;
DO $test$
DECLARE v_count BIGINT;
BEGIN
 PERFORM ug_sales_analytics.fn_record_return('UGSA-R-DEMO-001','sales-return-idem-001','UGSA-S-DEMO-001',1,2,10000,
 'Synthetic damaged goods return','SYN-RETURN-SOURCE-001','SYN-SALES-CLERK');
 BEGIN
  PERFORM ug_sales_analytics.fn_record_return('UGSA-R-DEMO-002','sales-return-idem-002','UGSA-S-DEMO-001',1,99,1000,
   'Return above sold quantity','SYN-RETURN-SOURCE-002','SYN-SALES-CLERK');
  RAISE EXCEPTION 'ASSERT return above original quantity was accepted';
 EXCEPTION WHEN check_violation THEN NULL; END;
 BEGIN
  PERFORM ug_sales_analytics.fn_record_return('UGSA-R-DEMO-003','sales-return-idem-001','UGSA-S-DEMO-001',1,1,1000,
   'Duplicate key','SYN-RETURN-SOURCE-003','SYN-SALES-CLERK');
  RAISE EXCEPTION 'ASSERT duplicate return idempotency key accepted';
 EXCEPTION WHEN unique_violation THEN NULL; END;
 SELECT COUNT(*) INTO v_count FROM ug_sales_analytics.returns WHERE return_ref='UGSA-R-DEMO-001';
 IF v_count<>1 THEN RAISE EXCEPTION 'ASSERT valid return missing'; END IF;
END; $test$;
ROLLBACK;
