-- Purpose: role separation for cooperative settlement reporting and payment allocation.
-- Engine: PostgreSQL 15+. Prerequisite: controlled schema administrator.
DO $roles$
BEGIN
 IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='ug_coop_pay_reader') THEN CREATE ROLE ug_coop_pay_reader NOLOGIN; END IF;
 IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='ug_coop_pay_clerk') THEN CREATE ROLE ug_coop_pay_clerk NOLOGIN; END IF;
 IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='ug_coop_pay_settlement') THEN CREATE ROLE ug_coop_pay_settlement NOLOGIN; END IF;
END;
$roles$;
REVOKE ALL ON SCHEMA ug_coop_pay FROM PUBLIC;
GRANT USAGE ON SCHEMA ug_coop_pay TO ug_coop_pay_reader,ug_coop_pay_clerk,ug_coop_pay_settlement;
REVOKE ALL ON ALL TABLES IN SCHEMA ug_coop_pay FROM PUBLIC;
GRANT SELECT ON ug_coop_pay.v_delivery_valuation,ug_coop_pay.v_delivery_settlement,
                ug_coop_pay.v_member_settlement_summary TO ug_coop_pay_reader;
GRANT SELECT ON ug_coop_pay.members,ug_coop_pay.produce_types,ug_coop_pay.price_rates,
                ug_coop_pay.deliveries,ug_coop_pay.deductions,ug_coop_pay.payments,
                ug_coop_pay.payment_allocations,ug_coop_pay.delivery_events
TO ug_coop_pay_clerk,ug_coop_pay_settlement;
GRANT INSERT ON ug_coop_pay.deductions,ug_coop_pay.payments TO ug_coop_pay_clerk;
GRANT EXECUTE ON FUNCTION ug_coop_pay.fn_allocate_payment(TEXT,TEXT,NUMERIC,TEXT,TEXT) TO ug_coop_pay_settlement;
REVOKE ALL ON FUNCTION ug_coop_pay.fn_allocate_payment(TEXT,TEXT,NUMERIC,TEXT,TEXT) FROM PUBLIC;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA ug_coop_pay FROM PUBLIC;
GRANT USAGE,SELECT ON ALL SEQUENCES IN SCHEMA ug_coop_pay TO ug_coop_pay_clerk;
-- Payment allocation is SECURITY DEFINER: retain trusted ownership, fixed search_path and
-- no runtime CREATE privilege on the schema. Real identity memberships require separate review.
