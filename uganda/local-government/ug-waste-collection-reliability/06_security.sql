-- Purpose: aggregate service reader, route clerk and operations manager roles.
-- Engine: PostgreSQL 15+. Run as controlled schema owner.
DO $roles$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='ug_waste_reader') THEN CREATE ROLE ug_waste_reader NOLOGIN; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='ug_waste_clerk') THEN CREATE ROLE ug_waste_clerk NOLOGIN; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='ug_waste_manager') THEN CREATE ROLE ug_waste_manager NOLOGIN; END IF;
END; $roles$;
REVOKE ALL ON SCHEMA ug_waste FROM PUBLIC;
GRANT USAGE ON SCHEMA ug_waste TO ug_waste_reader,ug_waste_clerk,ug_waste_manager;
REVOKE ALL ON ALL TABLES IN SCHEMA ug_waste FROM PUBLIC;
GRANT SELECT ON ug_waste.v_route_shift_summary,ug_waste.v_missed_service_queue TO ug_waste_reader;
GRANT SELECT ON ALL TABLES IN SCHEMA ug_waste TO ug_waste_clerk,ug_waste_manager;
GRANT EXECUTE ON FUNCTION ug_waste.fn_record_pickup(TEXT,TEXT,TEXT,TEXT,TEXT,NUMERIC,TEXT,TIMESTAMPTZ,TEXT,TEXT,TEXT) TO ug_waste_clerk;
REVOKE ALL ON FUNCTION ug_waste.fn_record_pickup(TEXT,TEXT,TEXT,TEXT,TEXT,NUMERIC,TEXT,TIMESTAMPTZ,TEXT,TEXT,TEXT) FROM PUBLIC;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA ug_waste FROM PUBLIC;
-- Restrict service point detail, vehicle routes and crew information by assigned locality in real deployments.
