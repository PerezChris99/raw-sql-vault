-- Purpose: executable assertions for source idempotency and human review controls.
-- Engine: PostgreSQL 15+. Prerequisites: 01_schema.sql, 02_seed.sql and 04_procedures.sql.
-- Run in a disposable database. All test mutations roll back.
BEGIN;
DO $test$
DECLARE v_id BIGINT;
BEGIN
 SELECT observation_id INTO v_id FROM ug_market_price.observations WHERE observation_ref='UGMP-DEMO-0001';
 IF v_id IS NULL THEN RAISE EXCEPTION 'ASSERT synthetic observation missing'; END IF;

 BEGIN
   INSERT INTO ug_market_price.observations(observation_ref,idempotency_key,market_id,commodity_id,unit_code,observed_on,
      price_amount,currency_code,collection_method,source_record_ref,collector_ref)
   SELECT 'UGMP-TEST-NEG','negative-price-key',market_id,commodity_id,'KG',CURRENT_DATE,-1,'UGX',
          'field_visit','TEST-SOURCE','test-collector'
   FROM ug_market_price.observations WHERE observation_ref='UGMP-DEMO-0001';
   RAISE EXCEPTION 'ASSERT negative price was accepted';
 EXCEPTION WHEN check_violation THEN NULL; END;

 BEGIN
   PERFORM ug_market_price.fn_review_observation('UGMP-DEMO-0001','accepted','reviewer-test','accepted without evidence',NULL);
   RAISE EXCEPTION 'ASSERT decision without evidence was accepted';
 EXCEPTION WHEN check_violation THEN NULL; END;

 BEGIN
   PERFORM ug_market_price.fn_review_observation('UGMP-DEMO-0001','accepted','','blank reviewer','SYNTHETIC-EVIDENCE');
   RAISE EXCEPTION 'ASSERT blank reviewer was accepted';
 EXCEPTION WHEN invalid_parameter_value THEN NULL; END;

 BEGIN
   PERFORM ug_market_price.fn_review_observation('UGMP-DEMO-0001','pending','reviewer-test','invalid target','SYNTHETIC-EVIDENCE');
   RAISE EXCEPTION 'ASSERT unsupported review target was accepted';
 EXCEPTION WHEN check_violation THEN NULL; END;

 BEGIN
   INSERT INTO ug_market_price.observations(observation_ref,idempotency_key,market_id,commodity_id,unit_code,observed_on,
      price_amount,currency_code,collection_method,source_record_ref,collector_ref)
   SELECT 'UGMP-TEST-DUP','demo-price-key-0001',market_id,commodity_id,'KG',CURRENT_DATE,100,'UGX',
          'field_visit','TEST-DUP','test-collector'
   FROM ug_market_price.observations WHERE observation_ref='UGMP-DEMO-0001';
   RAISE EXCEPTION 'ASSERT duplicate idempotency key was accepted';
 EXCEPTION WHEN unique_violation THEN NULL; END;
END;
$test$;
ROLLBACK;
