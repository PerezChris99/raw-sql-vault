-- Purpose: deterministic synthetic market, commodity and pending price fixtures.
-- Engine: PostgreSQL 15+. Prerequisite: 01_schema.sql. Safe to rerun.
INSERT INTO ug_market_price.measurement_units(unit_code,unit_name,description) VALUES
 ('KG','kilogram','Price per kilogram'),
 ('L','litre','Price per litre'),
 ('BUNCH','bunch','Price per declared bunch; sizes may vary and must be documented')
ON CONFLICT(unit_code) DO NOTHING;

INSERT INTO ug_market_price.markets(market_code,market_name,locality_ref,source_reference) VALUES
 ('DEMO-MKT-01','Synthetic Market Alpha','DEMO-LOCALITY-01','SYNTHETIC-MARKET-FIXTURE'),
 ('DEMO-MKT-02','Synthetic Market Beta','DEMO-LOCALITY-02','SYNTHETIC-MARKET-FIXTURE')
ON CONFLICT(market_code) DO NOTHING;

INSERT INTO ug_market_price.commodities(commodity_code,commodity_name,category_code) VALUES
 ('DEMO-MAIZE','Synthetic maize','GRAIN'),
 ('DEMO-BEANS','Synthetic beans','PULSE'),
 ('DEMO-COFFEE','Synthetic coffee','CASH_CROP'),
 ('DEMO-TOMATO','Synthetic tomato','HORTICULTURE')
ON CONFLICT(commodity_code) DO NOTHING;

INSERT INTO ug_market_price.observations(observation_ref,idempotency_key,market_id,commodity_id,unit_code,observed_on,
    price_amount,currency_code,collection_method,source_record_ref,collector_ref)
SELECT v.ref,v.idempotency_key,m.market_id,c.commodity_id,v.unit_code,DATE '2026-02-10',
       v.price,'UGX','field_visit',v.source_ref,'SYNTHETIC-COLLECTOR-01'
FROM (VALUES
 ('UGMP-DEMO-0001','demo-price-key-0001','DEMO-MKT-01','DEMO-MAIZE','KG',1200.0000::numeric,'SRC-DEMO-001'),
 ('UGMP-DEMO-0002','demo-price-key-0002','DEMO-MKT-01','DEMO-BEANS','KG',4500.0000::numeric,'SRC-DEMO-002'),
 ('UGMP-DEMO-0003','demo-price-key-0003','DEMO-MKT-02','DEMO-COFFEE','KG',8500.0000::numeric,'SRC-DEMO-003')
) AS v(ref,idempotency_key,market_code,commodity_code,unit_code,price,source_ref)
JOIN ug_market_price.markets m ON m.market_code=v.market_code
JOIN ug_market_price.commodities c ON c.commodity_code=v.commodity_code
ON CONFLICT(observation_ref) DO NOTHING;

INSERT INTO ug_market_price.review_events(observation_id,event_type,from_status,to_status,actor_ref,reason,evidence_reference)
SELECT o.observation_id,'submitted',NULL,o.status,o.collector_ref,'Synthetic observation submitted',o.source_record_ref
FROM ug_market_price.observations o
WHERE o.observation_ref LIKE 'UGMP-DEMO-%'
AND NOT EXISTS (SELECT 1 FROM ug_market_price.review_events e WHERE e.observation_id=o.observation_id AND e.event_type='submitted');
