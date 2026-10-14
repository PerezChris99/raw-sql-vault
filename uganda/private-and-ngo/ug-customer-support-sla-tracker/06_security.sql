-- Purpose: reporting, agent and supervisor role separation.
-- Engine: PostgreSQL 15+. Run as controlled schema owner.
DO $roles$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='ug_support_report_reader') THEN CREATE ROLE ug_support_report_reader NOLOGIN; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='ug_support_agent') THEN CREATE ROLE ug_support_agent NOLOGIN; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='ug_support_supervisor') THEN CREATE ROLE ug_support_supervisor NOLOGIN; END IF;
END; $roles$;
REVOKE ALL ON SCHEMA ug_support FROM PUBLIC;
GRANT USAGE ON SCHEMA ug_support TO ug_support_report_reader,ug_support_agent,ug_support_supervisor;
REVOKE ALL ON ALL TABLES IN SCHEMA ug_support FROM PUBLIC;
GRANT SELECT ON ug_support.v_monthly_sla_summary TO ug_support_report_reader;
GRANT SELECT ON ug_support.tickets,ug_support.ticket_events TO ug_support_agent,ug_support_supervisor;
GRANT EXECUTE ON FUNCTION ug_support.fn_transition_ticket(TEXT,TEXT,TEXT,TEXT,TEXT) TO ug_support_agent,ug_support_supervisor;
GRANT EXECUTE ON FUNCTION ug_support.fn_record_first_response(TEXT,TEXT,TEXT,TEXT) TO ug_support_agent;
REVOKE ALL ON FUNCTION ug_support.fn_transition_ticket(TEXT,TEXT,TEXT,TEXT,TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION ug_support.fn_record_first_response(TEXT,TEXT,TEXT,TEXT) FROM PUBLIC;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA ug_support FROM PUBLIC;
-- Redact customer narratives and apply account/tenant scope before connecting real support channels.
