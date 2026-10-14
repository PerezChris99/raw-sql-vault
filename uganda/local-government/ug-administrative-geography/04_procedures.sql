-- Purpose: controlled retirement and hierarchy lookup routines.
-- Engine: PostgreSQL 15+. Prerequisite: 01_schema.sql. Rerunnable: yes.
CREATE OR REPLACE FUNCTION ug_admin_ref.fn_retire_unit(
    p_unit_code TEXT,p_effective_to DATE,p_reason TEXT,p_source_reference TEXT,p_recorded_by TEXT
) RETURNS BIGINT
LANGUAGE plpgsql
SET search_path=pg_catalog,ug_admin_ref
AS $$
DECLARE v_unit ug_admin_ref.admin_units%ROWTYPE;
BEGIN
    IF p_effective_to IS NULL OR length(btrim(COALESCE(p_reason,'')))=0
       OR length(btrim(COALESCE(p_source_reference,'')))=0
       OR length(btrim(COALESCE(p_recorded_by,'')))=0 THEN
        RAISE EXCEPTION 'Retirement date, reason, source and actor are required'
            USING ERRCODE='invalid_parameter_value';
    END IF;
    SELECT * INTO v_unit FROM ug_admin_ref.admin_units
    WHERE unit_code=p_unit_code AND valid_to IS NULL FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'Current unit code % not found',p_unit_code USING ERRCODE='no_data_found'; END IF;
    IF p_effective_to<v_unit.valid_from THEN
        RAISE EXCEPTION 'Retirement date cannot precede valid-from date' USING ERRCODE='check_violation';
    END IF;
    IF EXISTS (SELECT 1 FROM ug_admin_ref.admin_units c
               WHERE c.parent_admin_unit_id=v_unit.admin_unit_id AND c.valid_to IS NULL) THEN
        RAISE EXCEPTION 'Retire current child units before retiring their parent' USING ERRCODE='check_violation';
    END IF;
    UPDATE ug_admin_ref.admin_units SET valid_to=p_effective_to WHERE admin_unit_id=v_unit.admin_unit_id;
    INSERT INTO ug_admin_ref.admin_unit_changes(admin_unit_id,change_kind,old_values,new_values,change_reason,source_reference,recorded_by)
    VALUES(v_unit.admin_unit_id,'retired',to_jsonb(v_unit),
           jsonb_build_object('valid_to',p_effective_to),p_reason,p_source_reference,p_recorded_by);
    RETURN v_unit.admin_unit_id;
END;
$$;

CREATE OR REPLACE FUNCTION ug_admin_ref.fn_get_ancestors(p_admin_unit_id BIGINT)
RETURNS TABLE(depth INTEGER,admin_unit_id BIGINT,unit_code TEXT,unit_name TEXT,unit_level TEXT)
LANGUAGE sql STABLE
SET search_path=pg_catalog,ug_admin_ref
AS $$
WITH RECURSIVE ancestors AS (
    SELECT u.admin_unit_id,u.unit_code,u.unit_name,u.unit_level,u.parent_admin_unit_id,0 AS depth,
           ARRAY[u.admin_unit_id] AS path
    FROM ug_admin_ref.admin_units u WHERE u.admin_unit_id=p_admin_unit_id AND u.valid_to IS NULL
    UNION ALL
    SELECT p.admin_unit_id,p.unit_code,p.unit_name,p.unit_level,p.parent_admin_unit_id,a.depth+1,a.path||p.admin_unit_id
    FROM ug_admin_ref.admin_units p JOIN ancestors a ON p.admin_unit_id=a.parent_admin_unit_id
    WHERE p.valid_to IS NULL AND NOT p.admin_unit_id=ANY(a.path)
)
SELECT depth,admin_unit_id,unit_code,unit_name,unit_level FROM ancestors ORDER BY depth DESC;
$$;
