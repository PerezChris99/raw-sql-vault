-- Purpose: assertions for placement overlap and valid cohort reporting.
-- Engine: PostgreSQL 15+. Prerequisites: schema, seed, views and procedures. Disposable DB only.
BEGIN;
DO $test$
DECLARE v_count BIGINT;
BEGIN
 PERFORM ug_tvet.fn_record_placement('UGTVET-PL-DEMO-001','UGTVET-E-DEMO-01','SYN-EMPLOYER-01','apprenticeship',DATE '2026-10-01',DATE '2026-12-01','SYN-PLACEMENT-OUTCOME-001');
 BEGIN
  PERFORM ug_tvet.fn_record_placement('UGTVET-PL-DEMO-002','UGTVET-E-DEMO-01','SYN-EMPLOYER-02','internship',DATE '2026-11-01',DATE '2027-01-01','SYN-PLACEMENT-OUTCOME-002');
  RAISE EXCEPTION 'ASSERT overlapping placement was accepted';
 EXCEPTION WHEN exclusion_violation THEN NULL; END;
 SELECT COUNT(*) INTO v_count FROM ug_tvet.v_cohort_outcomes WHERE cohort_ref='UGTVET-C-DEMO-01' AND completions=1;
 IF v_count<>1 THEN RAISE EXCEPTION 'ASSERT cohort completion summary incorrect'; END IF;
END; $test$;
ROLLBACK;
