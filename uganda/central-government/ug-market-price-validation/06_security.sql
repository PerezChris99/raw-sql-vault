-- Purpose: least-privilege data collection and reviewer role groups.
-- Engine: PostgreSQL 15+. Prerequisite: controlled schema administrator.
DO $roles$
BEGIN
 IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='ug_market_price_reader') THEN CREATE ROLE ug_market_price_reader NOLOGIN; END IF;
 IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='ug_market_price_collector') THEN CREATE ROLE ug_market_price_collector NOLOGIN; END IF;
 IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='ug_market_price_reviewer') THEN CREATE ROLE ug_market_price_reviewer NOLOGIN; END IF;
END;
$roles$;
REVOKE ALL ON SCHEMA ug_market_price FROM PUBLIC;
GRANT USAGE ON SCHEMA ug_market_price TO ug_market_price_reader,ug_market_price_collector,ug_market_price_reviewer;
REVOKE ALL ON ALL TABLES IN SCHEMA ug_market_price FROM PUBLIC;
GRANT SELECT ON ug_market_price.markets,ug_market_price.commodities,ug_market_price.measurement_units,
                ug_market_price.v_daily_price_summary TO ug_market_price_reader;
GRANT SELECT ON ug_market_price.markets,ug_market_price.commodities,ug_market_price.measurement_units,
                ug_market_price.observations,ug_market_price.review_events TO ug_market_price_collector,ug_market_price_reviewer;
GRANT INSERT ON ug_market_price.observations TO ug_market_price_collector;
GRANT EXECUTE ON FUNCTION ug_market_price.fn_review_observation(TEXT,TEXT,TEXT,TEXT,TEXT) TO ug_market_price_reviewer;
REVOKE ALL ON FUNCTION ug_market_price.fn_review_observation(TEXT,TEXT,TEXT,TEXT,TEXT) FROM PUBLIC;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA ug_market_price FROM PUBLIC;
GRANT USAGE,SELECT ON ALL SEQUENCES IN SCHEMA ug_market_price TO ug_market_price_collector;
-- Keep SECURITY DEFINER routines owned by a trusted schema owner. Runtime roles must not
-- have CREATE privilege on this schema. Review decisions require authenticated assignment
-- outside this example; no price is automatically accepted or rejected based on outlier score.
