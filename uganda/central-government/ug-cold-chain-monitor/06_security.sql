-- Purpose: least-privilege reader, monitoring and maintenance role groups.
-- Engine: PostgreSQL 15+. Prerequisite: controlled schema administrator.
DO $roles$
BEGIN
 IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='ug_cold_chain_reader') THEN CREATE ROLE ug_cold_chain_reader NOLOGIN; END IF;
 IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='ug_cold_chain_monitor') THEN CREATE ROLE ug_cold_chain_monitor NOLOGIN; END IF;
 IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='ug_cold_chain_maintenance') THEN CREATE ROLE ug_cold_chain_maintenance NOLOGIN; END IF;
END;
$roles$;
REVOKE ALL ON SCHEMA ug_cold_chain FROM PUBLIC;
GRANT USAGE ON SCHEMA ug_cold_chain TO ug_cold_chain_reader,ug_cold_chain_monitor,ug_cold_chain_maintenance;
REVOKE ALL ON ALL TABLES IN SCHEMA ug_cold_chain FROM PUBLIC;
GRANT SELECT ON ug_cold_chain.facilities,ug_cold_chain.equipment,ug_cold_chain.v_latest_temperature,
                ug_cold_chain.v_open_excursions,ug_cold_chain.v_maintenance_queue TO ug_cold_chain_reader;
GRANT SELECT ON ug_cold_chain.facilities,ug_cold_chain.equipment,ug_cold_chain.temperature_readings,
                ug_cold_chain.excursions TO ug_cold_chain_monitor;
GRANT SELECT ON ug_cold_chain.maintenance_orders,ug_cold_chain.maintenance_events TO ug_cold_chain_maintenance;
GRANT EXECUTE ON FUNCTION ug_cold_chain.fn_record_temperature(TEXT,TEXT,TEXT,TIMESTAMPTZ,NUMERIC,TEXT,TEXT,TEXT)
TO ug_cold_chain_monitor;
GRANT EXECUTE ON FUNCTION ug_cold_chain.fn_transition_work_order(TEXT,TEXT,TEXT,TEXT,TEXT)
TO ug_cold_chain_maintenance;
REVOKE ALL ON FUNCTION ug_cold_chain.fn_record_temperature(TEXT,TEXT,TEXT,TIMESTAMPTZ,NUMERIC,TEXT,TEXT,TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION ug_cold_chain.fn_transition_work_order(TEXT,TEXT,TEXT,TEXT,TEXT) FROM PUBLIC;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA ug_cold_chain FROM PUBLIC;
-- Keep SECURITY DEFINER functions owned by a trusted schema owner and prevent runtime CREATE.
