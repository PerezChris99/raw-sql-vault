-- Purpose: aggregate reader, operations recorder and route manager role separation.
-- Engine: PostgreSQL 15+. Run as controlled schema owner.
DO $roles$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='ug_transport_reader') THEN CREATE ROLE ug_transport_reader NOLOGIN; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='ug_transport_recorder') THEN CREATE ROLE ug_transport_recorder NOLOGIN; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='ug_transport_manager') THEN CREATE ROLE ug_transport_manager NOLOGIN; END IF;
END; $roles$;
REVOKE ALL ON SCHEMA ug_transport FROM PUBLIC;
GRANT USAGE ON SCHEMA ug_transport TO ug_transport_reader,ug_transport_recorder,ug_transport_manager;
REVOKE ALL ON ALL TABLES IN SCHEMA ug_transport FROM PUBLIC;
GRANT SELECT ON ug_transport.v_departure_performance,ug_transport.v_open_disruptions TO ug_transport_reader;
GRANT SELECT ON ALL TABLES IN SCHEMA ug_transport TO ug_transport_recorder,ug_transport_manager;
GRANT EXECUTE ON FUNCTION ug_transport.fn_record_observation(TEXT,TEXT,TEXT,TEXT,TIMESTAMPTZ,INTEGER,TEXT,TEXT,TEXT,TEXT) TO ug_transport_recorder;
REVOKE ALL ON FUNCTION ug_transport.fn_record_observation(TEXT,TEXT,TEXT,TEXT,TIMESTAMPTZ,INTEGER,TEXT,TEXT,TEXT,TEXT) FROM PUBLIC;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA ug_transport FROM PUBLIC;
-- Use route-level aggregate disclosure and keep passenger-level data out of this package.
