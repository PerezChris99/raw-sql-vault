-- Purpose: authorised delivery reconciliation and restricted referral queue.
-- Engine: PostgreSQL 15+. Prerequisite: 01_schema.sql. Rerunnable.
CREATE OR REPLACE VIEW ug_aid.v_delivery_reconciliation AS
SELECT p.programme_ref,p.assistance_type,a.authorisation_ref,r.recipient_token,a.assistance_period,a.quantity AS authorised_quantity,a.unit_code,
 COALESCE(SUM(d.quantity_delivered) FILTER(WHERE d.delivery_status IN ('delivered','partial')),0) AS delivered_quantity,
 a.quantity-COALESCE(SUM(d.quantity_delivered) FILTER(WHERE d.delivery_status IN ('delivered','partial')),0) AS outstanding_quantity,
 COUNT(d.delivery_id) AS delivery_attempts
FROM ug_aid.authorisations a JOIN ug_aid.programmes p USING(programme_id)
JOIN ug_aid.recipients r USING(recipient_id)
LEFT JOIN ug_aid.deliveries d USING(authorisation_id)
WHERE a.decision='approved'
GROUP BY p.programme_ref,p.assistance_type,a.authorisation_id,a.authorisation_ref,r.recipient_token,a.assistance_period,a.quantity,a.unit_code;

CREATE OR REPLACE VIEW ug_aid.v_delivery_exceptions AS
SELECT p.programme_ref,a.authorisation_ref,r.recipient_token,d.delivery_ref,d.delivery_status,d.quantity_delivered,d.exception_reason,d.delivered_at
FROM ug_aid.deliveries d JOIN ug_aid.authorisations a USING(authorisation_id)
JOIN ug_aid.programmes p USING(programme_id) JOIN ug_aid.recipients r USING(recipient_id)
WHERE d.delivery_status IN ('failed','returned','partial');

CREATE OR REPLACE VIEW ug_aid.v_referral_queue AS
SELECT referral_ref,recipient_id,referral_type,receiving_service_ref,reason_redacted,status,referred_at
FROM ug_aid.referrals WHERE status IN ('referred','accepted');
