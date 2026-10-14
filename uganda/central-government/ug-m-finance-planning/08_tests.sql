-- PostgreSQL 15+; all writes occur within a transaction and are rolled back.
BEGIN;
DO $test$
DECLARE v_line_id BIGINT;v_ra BIGINT;v_rb BIGINT;v_ea BIGINT;v_eb BIGINT;v_count BIGINT;
BEGIN
 INSERT INTO finance_demo.budget_lines(budget_line_code,vote_code,programme_code,fiscal_year_start,approved_ceiling_ugx)
 VALUES('TEST-AUTOPILOT-FIN','TEST-VOTE','TEST-PROG',2026,100000)
 ON CONFLICT(budget_line_code) DO UPDATE SET approved_ceiling_ugx=100000,line_status='active'
 RETURNING budget_line_id INTO v_line_id;
 DELETE FROM finance_demo.expenditures WHERE budget_line_id=v_line_id;
 DELETE FROM finance_demo.releases WHERE budget_line_id=v_line_id;
 v_ra:=finance_demo.fn_record_release('TEST-REL-A','TEST-AUTOPILOT-FIN',DATE '2026-08-01',50000,'TEST-AUTH-A','TEST-REL-KEY');
 v_rb:=finance_demo.fn_record_release('TEST-REL-A','TEST-AUTOPILOT-FIN',DATE '2026-08-01',50000,'TEST-AUTH-A','TEST-REL-KEY');
 IF v_ra<>v_rb THEN RAISE EXCEPTION 'ASSERT release idempotency failed'; END IF;
 v_ea:=finance_demo.fn_record_expenditure('TEST-EXP-A','TEST-AUTOPILOT-FIN',DATE '2026-08-10',20000,'goods','TEST-VOUCHER-A','TEST-EXP-KEY');
 v_eb:=finance_demo.fn_record_expenditure('TEST-EXP-A','TEST-AUTOPILOT-FIN',DATE '2026-08-10',20000,'goods','TEST-VOUCHER-A','TEST-EXP-KEY');
 IF v_ea<>v_eb THEN RAISE EXCEPTION 'ASSERT expenditure idempotency failed'; END IF;
 SELECT COUNT(*) INTO v_count FROM finance_demo.expenditures WHERE budget_line_id=v_line_id;
 IF v_count<>1 THEN RAISE EXCEPTION 'ASSERT duplicate expenditure recorded'; END IF;
 BEGIN
  PERFORM finance_demo.fn_record_expenditure('TEST-EXP-OVER','TEST-AUTOPILOT-FIN',DATE '2026-08-11',40000,'goods','TEST-VOUCHER-OVER','TEST-EXP-OVER-KEY');
  RAISE EXCEPTION 'ASSERT spend beyond release accepted';
 EXCEPTION WHEN check_violation THEN NULL; END;
 BEGIN
  PERFORM finance_demo.fn_record_release('TEST-REL-OVER','TEST-AUTOPILOT-FIN',DATE '2026-08-12',60000,'TEST-AUTH-OVER','TEST-REL-OVER-KEY');
  RAISE EXCEPTION 'ASSERT release beyond ceiling accepted';
 EXCEPTION WHEN check_violation THEN NULL; END;
 BEGIN
  PERFORM finance_demo.fn_record_release('TEST-REL-WRONG','TEST-BUD-NONEXIST',DATE '2026-08-12',1000,'TEST-AUTH','TEST-REL-KEY');
  RAISE EXCEPTION 'ASSERT reused idempotency key accepted with altered payload';
 EXCEPTION WHEN unique_violation THEN NULL; END;
END; $test$;
ROLLBACK;