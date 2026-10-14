-- Purpose: prevent overlapping placements for the same trainee and keep placement changes evidenced.
-- Engine: PostgreSQL 15+. Prerequisite: 01_schema.sql. Rerunnable.
CREATE OR REPLACE FUNCTION ug_tvet.fn_record_placement(
 p_placement_ref TEXT,p_enrolment_ref TEXT,p_employer_ref TEXT,p_type TEXT,p_starts_on DATE,p_ends_on DATE,p_outcome_ref TEXT
) RETURNS BIGINT LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ug_tvet AS $$
DECLARE e ug_tvet.enrolments%ROWTYPE; v_id BIGINT;
BEGIN
 IF p_type NOT IN ('apprenticeship','internship','employment','self_employment','further_training')
 OR length(btrim(COALESCE(p_employer_ref,'')))=0 OR p_starts_on IS NULL OR (p_ends_on IS NOT NULL AND p_ends_on<p_starts_on) THEN
  RAISE EXCEPTION 'Valid placement type, employer reference and dates are required' USING ERRCODE='invalid_parameter_value';
 END IF;
 SELECT * INTO e FROM ug_tvet.enrolments WHERE enrolment_ref=p_enrolment_ref FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Enrolment not found' USING ERRCODE='no_data_found'; END IF;
 IF e.status='withdrawn' THEN RAISE EXCEPTION 'Withdrawn trainee cannot receive a new placement' USING ERRCODE='check_violation'; END IF;
 IF EXISTS(SELECT 1 FROM ug_tvet.placements p WHERE p.enrolment_id=e.enrolment_id
  AND p.status IN ('planned','active')
  AND daterange(p.starts_on,COALESCE(p.ends_on,'infinity'::date),'[]') &&
      daterange(p_starts_on,COALESCE(p_ends_on,'infinity'::date),'[]')) THEN
  RAISE EXCEPTION 'Placement overlaps an existing active/planned placement' USING ERRCODE='exclusion_violation';
 END IF;
 INSERT INTO ug_tvet.placements(placement_ref,enrolment_id,employer_ref,placement_type,starts_on,ends_on,status,outcome_ref)
 VALUES(p_placement_ref,e.enrolment_id,p_employer_ref,p_type,p_starts_on,p_ends_on,
   CASE WHEN p_starts_on>CURRENT_DATE THEN 'planned' WHEN p_ends_on IS NOT NULL AND p_ends_on<CURRENT_DATE THEN 'completed' ELSE 'active' END,p_outcome_ref)
 RETURNING placement_id INTO v_id;
 RETURN v_id;
END; $$;
