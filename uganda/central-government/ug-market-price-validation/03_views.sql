-- Purpose: review queue, accepted price summaries and reviewable outlier candidates.
-- Engine: PostgreSQL 15+. Prerequisite: 01_schema.sql. Rerunnable.
CREATE OR REPLACE VIEW ug_market_price.v_review_queue AS
SELECT o.observation_id,o.observation_ref,m.market_code,m.market_name,c.commodity_code,c.commodity_name,
       o.unit_code,o.observed_on,o.price_amount,o.currency_code,o.collection_method,o.source_record_ref,
       o.collector_ref,o.status,o.submitted_at
FROM ug_market_price.observations o
JOIN ug_market_price.markets m USING(market_id)
JOIN ug_market_price.commodities c USING(commodity_id)
WHERE o.status IN ('pending','flagged');

CREATE OR REPLACE VIEW ug_market_price.v_daily_price_summary AS
SELECT m.market_code,c.commodity_code,o.unit_code,o.currency_code,o.observed_on,
       COUNT(*) AS accepted_observations,
       MIN(o.price_amount) AS minimum_price,
       percentile_cont(0.5) WITHIN GROUP (ORDER BY o.price_amount) AS median_price,
       AVG(o.price_amount)::NUMERIC(14,4) AS average_price,
       MAX(o.price_amount) AS maximum_price
FROM ug_market_price.observations o
JOIN ug_market_price.markets m USING(market_id)
JOIN ug_market_price.commodities c USING(commodity_id)
WHERE o.status='accepted'
GROUP BY m.market_code,c.commodity_code,o.unit_code,o.currency_code,o.observed_on;

CREATE OR REPLACE VIEW ug_market_price.v_outlier_candidates AS
WITH baseline AS (
 SELECT o.market_id,o.commodity_id,o.unit_code,o.currency_code,
        percentile_cont(0.5) WITHIN GROUP (ORDER BY o.price_amount) AS median_price,
        COUNT(*) AS accepted_sample_size
 FROM ug_market_price.observations o
 WHERE o.status='accepted' AND o.observed_on>=CURRENT_DATE-30
 GROUP BY o.market_id,o.commodity_id,o.unit_code,o.currency_code
 HAVING COUNT(*)>=3
)
SELECT o.observation_ref,m.market_code,c.commodity_code,o.unit_code,o.observed_on,o.price_amount,
       b.median_price,b.accepted_sample_size,
       ROUND(o.price_amount/NULLIF(b.median_price,0),3) AS price_to_median_ratio
FROM ug_market_price.observations o
JOIN baseline b USING(market_id,commodity_id,unit_code,currency_code)
JOIN ug_market_price.markets m USING(market_id)
JOIN ug_market_price.commodities c USING(commodity_id)
WHERE o.status IN ('pending','flagged')
  AND (o.price_amount>b.median_price*2.0 OR o.price_amount<b.median_price*0.5);
