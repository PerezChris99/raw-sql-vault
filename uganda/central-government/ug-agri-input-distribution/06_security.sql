-- Purpose: least-privilege warehouse, distribution and reporting role groups.
-- Engine: PostgreSQL 15+. Prerequisite: controlled schema administrator.
DO $roles$
BEGIN
 IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='ug_agri_inputs_reader') THEN CREATE ROLE ug_agri_inputs_reader NOLOGIN; END IF;
 IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='ug_agri_inputs_clerk') THEN CREATE ROLE ug_agri_inputs_clerk NOLOGIN; END IF;
 IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='ug_agri_inputs_warehouse') THEN CREATE ROLE ug_agri_inputs_warehouse NOLOGIN; END IF;
END;
$roles$;
REVOKE ALL ON SCHEMA ug_agri_inputs FROM PUBLIC;
GRANT USAGE ON SCHEMA ug_agri_inputs TO ug_agri_inputs_reader,ug_agri_inputs_clerk,ug_agri_inputs_warehouse;
REVOKE ALL ON ALL TABLES IN SCHEMA ug_agri_inputs FROM PUBLIC;
GRANT SELECT ON ug_agri_inputs.v_lot_balance,ug_agri_inputs.v_expiry_risk,ug_agri_inputs.v_distribution_reconciliation TO ug_agri_inputs_reader;
GRANT SELECT ON ug_agri_inputs.suppliers,ug_agri_inputs.input_products,ug_agri_inputs.lots,
                ug_agri_inputs.stock_movements,ug_agri_inputs.distribution_receipts
TO ug_agri_inputs_clerk,ug_agri_inputs_warehouse;
GRANT EXECUTE ON FUNCTION ug_agri_inputs.fn_record_movement(TEXT,TEXT,TEXT,TEXT,NUMERIC,TEXT,TIMESTAMPTZ,TEXT,TEXT,TEXT)
TO ug_agri_inputs_warehouse;
REVOKE ALL ON FUNCTION ug_agri_inputs.fn_record_movement(TEXT,TEXT,TEXT,TEXT,NUMERIC,TEXT,TIMESTAMPTZ,TEXT,TEXT,TEXT) FROM PUBLIC;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA ug_agri_inputs FROM PUBLIC;
-- SECURITY DEFINER function must remain trusted-owner; runtime roles must not own schema or create objects.
