-- Purpose: aggregate programme reporting and restricted trainee assessment access.
-- Engine: PostgreSQL 15+. Run as controlled schema owner.
DO $roles$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='ug_tvet_aggregate_reader') THEN CREATE ROLE ug_tvet_aggregate_reader NOLOGIN; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='ug_tvet_assessor') THEN CREATE ROLE ug_tvet_assessor NOLOGIN; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='ug_tvet_placement_officer') THEN CREATE ROLE ug_tvet_placement_officer NOLOGIN; END IF;
END; $roles$;
REVOKE ALL ON SCHEMA ug_tvet FROM PUBLIC;
GRANT USAGE ON SCHEMA ug_tvet TO ug_tvet_aggregate_reader,ug_tvet_assessor,ug_tvet_placement_officer;
REVOKE ALL ON ALL TABLES IN SCHEMA ug_tvet FROM PUBLIC;
GRANT SELECT ON ug_tvet.v_cohort_outcomes TO ug_tvet_aggregate_reader;
GRANT SELECT ON ug_tvet.enrolments,ug_tvet.assessments,ug_tvet.skills TO ug_tvet_assessor;
GRANT SELECT ON ug_tvet.placements,ug_tvet.employer_feedback,ug_tvet.enrolments TO ug_tvet_placement_officer;
GRANT EXECUTE ON FUNCTION ug_tvet.fn_record_placement(TEXT,TEXT,TEXT,TEXT,DATE,DATE,TEXT) TO ug_tvet_placement_officer;
REVOKE ALL ON FUNCTION ug_tvet.fn_record_placement(TEXT,TEXT,TEXT,TEXT,DATE,DATE,TEXT) FROM PUBLIC;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA ug_tvet FROM PUBLIC;
-- Use explicit trainee-consent, school/employer agreements and row-scoped access before operational use.
