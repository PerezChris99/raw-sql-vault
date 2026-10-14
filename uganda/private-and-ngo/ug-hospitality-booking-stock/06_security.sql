-- Purpose: reservation clerk, stock clerk and aggregate manager role groups.
-- Engine: PostgreSQL 15+. Run as controlled schema owner.
DO $roles$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='ug_hospitality_reader') THEN CREATE ROLE ug_hospitality_reader NOLOGIN; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='ug_hospitality_booking_clerk') THEN CREATE ROLE ug_hospitality_booking_clerk NOLOGIN; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='ug_hospitality_stock_clerk') THEN CREATE ROLE ug_hospitality_stock_clerk NOLOGIN; END IF;
END; $roles$;
REVOKE ALL ON SCHEMA ug_hospitality FROM PUBLIC;
GRANT USAGE ON SCHEMA ug_hospitality TO ug_hospitality_reader,ug_hospitality_booking_clerk,ug_hospitality_stock_clerk;
REVOKE ALL ON ALL TABLES IN SCHEMA ug_hospitality FROM PUBLIC;
GRANT SELECT ON ug_hospitality.v_reservation_calendar,ug_hospitality.v_stock_on_hand,ug_hospitality.v_order_totals TO ug_hospitality_reader;
GRANT SELECT ON ug_hospitality.resources,ug_hospitality.reservations TO ug_hospitality_booking_clerk;
GRANT EXECUTE ON FUNCTION ug_hospitality.fn_book_resource(TEXT,TEXT,TEXT,TEXT,TIMESTAMPTZ,TIMESTAMPTZ,INTEGER,TEXT,TEXT) TO ug_hospitality_booking_clerk;
GRANT SELECT ON ug_hospitality.inventory_items,ug_hospitality.stock_movements TO ug_hospitality_stock_clerk;
GRANT EXECUTE ON FUNCTION ug_hospitality.fn_consume_stock(TEXT,TEXT,TEXT,NUMERIC,TEXT,TEXT,TEXT) TO ug_hospitality_stock_clerk;
REVOKE ALL ON FUNCTION ug_hospitality.fn_book_resource(TEXT,TEXT,TEXT,TEXT,TIMESTAMPTZ,TIMESTAMPTZ,INTEGER,TEXT,TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION ug_hospitality.fn_consume_stock(TEXT,TEXT,TEXT,NUMERIC,TEXT,TEXT,TEXT) FROM PUBLIC;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA ug_hospitality FROM PUBLIC;
-- Keep customer tokens opaque and never store raw card numbers, security codes or authentication secrets.
