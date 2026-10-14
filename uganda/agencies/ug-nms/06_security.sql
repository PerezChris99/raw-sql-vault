-- Run as trusted DBA; NOLOGIN roles require approved identity mapping.
DO $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='nms_demo_reader') THEN CREATE ROLE nms_demo_reader NOLOGIN; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='nms_demo_operator') THEN CREATE ROLE nms_demo_operator NOLOGIN; END IF;
END $$;
REVOKE ALL ON SCHEMA nms_demo FROM PUBLIC;
GRANT USAGE ON SCHEMA nms_demo TO nms_demo_reader,nms_demo_operator;
REVOKE ALL ON ALL TABLES IN SCHEMA nms_demo FROM PUBLIC;
GRANT SELECT ON ALL TABLES IN SCHEMA nms_demo TO nms_demo_reader,nms_demo_operator;
GRANT EXECUTE ON FUNCTION nms_demo.fn_record_receipt(TEXT,TEXT,TEXT,INTEGER,TEXT,TEXT,BOOLEAN) TO nms_demo_operator;