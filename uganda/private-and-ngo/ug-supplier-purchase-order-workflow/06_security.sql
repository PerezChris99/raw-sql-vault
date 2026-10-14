-- Purpose: separate request, receiving and invoice approval roles.
-- Engine: PostgreSQL 15+. Run as controlled schema owner.
DO $roles$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='ug_sme_procure_reader') THEN CREATE ROLE ug_sme_procure_reader NOLOGIN; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='ug_sme_procure_clerk') THEN CREATE ROLE ug_sme_procure_clerk NOLOGIN; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='ug_sme_procure_invoice_reviewer') THEN CREATE ROLE ug_sme_procure_invoice_reviewer NOLOGIN; END IF;
END; $roles$;
REVOKE ALL ON SCHEMA ug_sme_procure FROM PUBLIC;
GRANT USAGE ON SCHEMA ug_sme_procure TO ug_sme_procure_reader,ug_sme_procure_clerk,ug_sme_procure_invoice_reviewer;
REVOKE ALL ON ALL TABLES IN SCHEMA ug_sme_procure FROM PUBLIC;
GRANT SELECT ON ug_sme_procure.v_purchase_order_value,ug_sme_procure.v_receipt_progress TO ug_sme_procure_reader;
GRANT SELECT ON ALL TABLES IN SCHEMA ug_sme_procure TO ug_sme_procure_clerk,ug_sme_procure_invoice_reviewer;
GRANT EXECUTE ON FUNCTION ug_sme_procure.fn_review_invoice(TEXT,TEXT,TEXT,TEXT) TO ug_sme_procure_invoice_reviewer;
REVOKE ALL ON FUNCTION ug_sme_procure.fn_review_invoice(TEXT,TEXT,TEXT,TEXT) FROM PUBLIC;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA ug_sme_procure FROM PUBLIC;
-- Enforce requester/approver separation, supplier due diligence and protected invoice storage at deployment.
