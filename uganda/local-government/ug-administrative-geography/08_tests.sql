-- Purpose: executable assertions for hierarchy constraints and retirement invariants.
-- Engine: PostgreSQL 15+. Prerequisites: 01_schema.sql, 02_seed.sql, 04_procedures.sql.
-- All test mutations roll back. Run against a disposable database.
BEGIN;
DO $test$
DECLARE v_parent BIGINT; v_id BIGINT; v_count BIGINT;
BEGIN
 SELECT admin_unit_id INTO v_parent FROM ug_admin_ref.admin_units WHERE unit_code='DEMO-DIST-A';
 IF v_parent IS NULL THEN RAISE EXCEPTION 'ASSERT synthetic district fixture missing'; END IF;

 BEGIN
   INSERT INTO ug_admin_ref.admin_units(unit_code,unit_name,unit_level,parent_admin_unit_id,valid_from,source_reference)
   VALUES('TEST-BAD-ROOT','Invalid root parish','parish',NULL,DATE '2020-01-01','TEST');
   RAISE EXCEPTION 'ASSERT root parish without parent was accepted';
 EXCEPTION WHEN check_violation THEN NULL; END;

 BEGIN
   INSERT INTO ug_admin_ref.admin_units(unit_code,unit_name,unit_level,parent_admin_unit_id,valid_from,source_reference)
   VALUES('TEST-BAD-PARENT','Invalid parent relationship','village',v_parent,DATE '2020-01-01','TEST');
   RAISE EXCEPTION 'ASSERT village directly under district was accepted';
 EXCEPTION WHEN check_violation THEN NULL; END;

 SELECT admin_unit_id INTO v_id FROM ug_admin_ref.admin_units WHERE unit_code='DEMO-VILLAGE-A';
 SELECT COUNT(*) INTO v_count FROM ug_admin_ref.fn_get_ancestors(v_id);
 IF v_count < 4 THEN RAISE EXCEPTION 'ASSERT expected village, parish, sub-county and district ancestors; got %',v_count; END IF;

 BEGIN
   PERFORM ug_admin_ref.fn_retire_unit('DEMO-DIST-A',DATE '2026-01-01','test parent retirement','TEST-SOURCE','test-suite');
   RAISE EXCEPTION 'ASSERT parent with active children was retired';
 EXCEPTION WHEN check_violation THEN NULL; END;

 IF NOT EXISTS (SELECT 1 FROM ug_admin_ref.v_current_units WHERE unit_code='DEMO-CITY-A' AND unit_level='city') THEN
   RAISE EXCEPTION 'ASSERT synthetic city root missing';
 END IF;
END;
$test$;
ROLLBACK;
