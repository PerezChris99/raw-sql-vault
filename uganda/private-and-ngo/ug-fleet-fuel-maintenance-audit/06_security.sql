-- Purpose: aggregate reader, fleet clerk and maintenance manager role groups.
-- Engine: PostgreSQL 15+. Run as controlled schema owner.
DO $roles$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='ug_fleet_reader') THEN CREATE ROLE ug_fleet_reader NOLOGIN; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='ug_fleet_clerk') THEN CREATE ROLE ug_fleet_clerk NOLOGIN; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='ug_fleet_manager') THEN CREATE ROLE ug_fleet_manager NOLOGIN; END IF;
END; $roles$;
REVOKE ALL ON SCHEMA ug_fleet FROM PUBLIC;
GRANT USAGE ON SCHEMA ug_fleet TO ug_fleet_reader,ug_fleet_clerk,ug_fleet_manager;
REVOKE ALL ON ALL TABLES IN SCHEMA ug_fleet FROM PUBLIC;
GRANT SELECT ON ug_fleet.v_fuel_summary,ug_fleet.v_maintenance_queue TO ug_fleet_reader;
GRANT SELECT ON ALL TABLES IN SCHEMA ug_fleet TO ug_fleet_clerk,ug_fleet_manager;
GRANT EXECUTE ON FUNCTION ug_fleet.fn_record_fuel(TEXT,TEXT,TEXT,TEXT,TIMESTAMPTZ,NUMERIC,NUMERIC,NUMERIC,TEXT,TEXT,TEXT) TO ug_fleet_clerk;
REVOKE ALL ON FUNCTION ug_fleet.fn_record_fuel(TEXT,TEXT,TEXT,TEXT,TIMESTAMPTZ,NUMERIC,NUMERIC,NUMERIC,TEXT,TEXT,TEXT) FROM PUBLIC;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA ug_fleet FROM PUBLIC;
-- Apply assignment scope and restricted vehicle-location policy in a real deployment.
