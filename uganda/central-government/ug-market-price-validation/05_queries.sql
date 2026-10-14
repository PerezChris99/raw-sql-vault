-- Purpose: safe reporting and review queries for market-price observations.
-- Engine: PostgreSQL 15+. Prerequisites: schema, seeds and views.
-- Use bound parameters in applications; all included codes are synthetic.

-- 01. Review queue, oldest first.
SELECT observation_ref,market_code,commodity_code,unit_code,observed_on,price_amount,currency_code,source_record_ref
FROM ug_market_price.v_review_queue ORDER BY submitted_at,observation_ref;

-- 02. Accepted daily price summaries.
SELECT market_code,commodity_code,unit_code,observed_on,accepted_observations,
       minimum_price,median_price,average_price,maximum_price
FROM ug_market_price.v_daily_price_summary
ORDER BY observed_on,market_code,commodity_code;

-- 03. Potential outliers for human review, not automatic rejection.
SELECT * FROM ug_market_price.v_outlier_candidates
ORDER BY ABS(price_to_median_ratio-1) DESC;

-- 04. Source coverage by market and commodity.
SELECT m.market_code,c.commodity_code,COUNT(o.observation_id) AS submitted_observations,
       COUNT(*) FILTER (WHERE o.status='accepted') AS accepted_count,
       COUNT(*) FILTER (WHERE o.status='rejected') AS rejected_count,
       COUNT(*) FILTER (WHERE o.status IN ('pending','flagged')) AS awaiting_review
FROM ug_market_price.markets m CROSS JOIN ug_market_price.commodities c
LEFT JOIN ug_market_price.observations o ON o.market_id=m.market_id AND o.commodity_id=c.commodity_id
GROUP BY m.market_code,c.commodity_code ORDER BY m.market_code,c.commodity_code;

-- 05. Observations missing a linked source record (should return zero).
SELECT observation_ref FROM ug_market_price.observations
WHERE source_record_ref IS NULL OR length(btrim(source_record_ref))=0;

-- 06. Accepted prices with inconsistent unit/currency for the same date and market/commodity.
SELECT market_id,commodity_id,observed_on,COUNT(DISTINCT unit_code) AS units,COUNT(DISTINCT currency_code) AS currencies
FROM ug_market_price.observations WHERE status='accepted'
GROUP BY market_id,commodity_id,observed_on
HAVING COUNT(DISTINCT unit_code)>1 OR COUNT(DISTINCT currency_code)>1;

-- 07. Review event timeline.
SELECT e.occurred_at,e.event_type,e.from_status,e.to_status,e.actor_ref,e.reason,e.evidence_reference
FROM ug_market_price.review_events e
JOIN ug_market_price.observations o USING(observation_id)
WHERE o.observation_ref='UGMP-DEMO-0001'
ORDER BY e.occurred_at,e.review_event_id;

-- 08. Observation counts by collection method.
SELECT collection_method,COUNT(*) AS observation_count
FROM ug_market_price.observations GROUP BY collection_method ORDER BY collection_method;

-- 09. Latest accepted observation per market/commodity/unit.
SELECT DISTINCT ON (market_id,commodity_id,unit_code)
       market_id,commodity_id,unit_code,observed_on,price_amount,currency_code,source_record_ref
FROM ug_market_price.observations
WHERE status='accepted'
ORDER BY market_id,commodity_id,unit_code,observed_on DESC,observation_id DESC;

-- 10. Rejected observations for quality review and retraining.
SELECT observation_ref,observed_on,price_amount,reviewed_by,review_reason
FROM ug_market_price.observations WHERE status='rejected'
ORDER BY reviewed_at DESC;
