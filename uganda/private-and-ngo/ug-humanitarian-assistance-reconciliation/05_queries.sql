-- Purpose: restricted aid delivery reconciliation and exception review.
-- Engine: PostgreSQL 15+. Prerequisites: schema, seed and views.
-- 01. Approved aid quantity and delivery balance; recipient token view is restricted.
SELECT * FROM ug_aid.v_delivery_reconciliation ORDER BY programme_ref,assistance_period,authorisation_ref;
-- 02. Failed, partial or returned delivery events.
SELECT * FROM ug_aid.v_delivery_exceptions ORDER BY delivered_at DESC;
-- 03. Referral queue (restricted case-worker access).
SELECT * FROM ug_aid.v_referral_queue ORDER BY referred_at;
-- 04. Approved authorisations with no delivery attempt.
SELECT a.authorisation_ref,r.recipient_token,a.quantity,a.assistance_period
FROM ug_aid.authorisations a JOIN ug_aid.recipients r USING(recipient_id)
WHERE a.decision='approved' AND NOT EXISTS(SELECT 1 FROM ug_aid.deliveries d WHERE d.authorisation_id=a.authorisation_id);
-- 05. Delivery quantity exceeding authorisation (should return zero).
SELECT * FROM ug_aid.v_delivery_reconciliation WHERE outstanding_quantity<0;
