-- Trusted DBA only; NOLOGIN demonstration roles.
DO $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='subscription_demo_reader') THEN CREATE ROLE subscription_demo_reader NOLOGIN; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='subscription_demo_operator') THEN CREATE ROLE subscription_demo_operator NOLOGIN; END IF;
END $$;
REVOKE ALL ON SCHEMA subscription_demo FROM PUBLIC;
GRANT USAGE ON SCHEMA subscription_demo TO subscription_demo_reader,subscription_demo_operator;
REVOKE ALL ON ALL TABLES IN SCHEMA subscription_demo FROM PUBLIC;
GRANT SELECT ON ALL TABLES IN SCHEMA subscription_demo TO subscription_demo_reader,subscription_demo_operator;
GRANT EXECUTE ON FUNCTION subscription_demo.fn_transition_subscription(TEXT,TEXT,TEXT,TEXT) TO subscription_demo_operator;
GRANT EXECUTE ON FUNCTION subscription_demo.fn_record_payment(TEXT,TEXT,NUMERIC,CHAR,TEXT,TEXT) TO subscription_demo_operator;