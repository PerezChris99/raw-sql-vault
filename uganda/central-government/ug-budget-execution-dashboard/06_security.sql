-- Purpose: budget reader, finance clerk and independent oversight role groups.
-- Engine: PostgreSQL 15+. Run as controlled schema owner.
DO $roles$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='ug_budget_reader') THEN CREATE ROLE ug_budget_reader NOLOGIN; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='ug_budget_finance_clerk') THEN CREATE ROLE ug_budget_finance_clerk NOLOGIN; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='ug_budget_oversight') THEN CREATE ROLE ug_budget_oversight NOLOGIN; END IF;
END; $roles$;
REVOKE ALL ON SCHEMA ug_budget_exec FROM PUBLIC;
GRANT USAGE ON SCHEMA ug_budget_exec TO ug_budget_reader,ug_budget_finance_clerk,ug_budget_oversight;
REVOKE ALL ON ALL TABLES IN SCHEMA ug_budget_exec FROM PUBLIC;
GRANT SELECT ON ug_budget_exec.v_execution_summary,ug_budget_exec.v_budget_exceptions,ug_budget_exec.v_output_performance TO ug_budget_reader,ug_budget_oversight;
GRANT SELECT ON ALL TABLES IN SCHEMA ug_budget_exec TO ug_budget_finance_clerk;
GRANT EXECUTE ON FUNCTION ug_budget_exec.fn_record_expenditure(TEXT,TEXT,TEXT,NUMERIC,TEXT,DATE,TEXT,TEXT) TO ug_budget_finance_clerk;
REVOKE ALL ON FUNCTION ug_budget_exec.fn_record_expenditure(TEXT,TEXT,TEXT,NUMERIC,TEXT,DATE,TEXT,TEXT) FROM PUBLIC;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA ug_budget_exec FROM PUBLIC;
-- Real systems require user-level office scoping, maker-checker controls and integration reconciliation.
