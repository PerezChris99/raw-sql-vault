-- Purpose: separate public-safe disclosure from restricted operational oversight.
-- Engine: PostgreSQL 15+. Prerequisite: 01_schema.sql. Rerunnable.
CREATE OR REPLACE VIEW ug_procurement.v_public_award_register AS
SELECT p.fiscal_year,p.procuring_entity_ref,n.notice_ref,n.notice_title,a.award_ref,a.awarded_amount,a.currency_code,
       a.decision_at,a.contract_ref
FROM ug_procurement.awards a
JOIN ug_procurement.notices n USING(notice_id)
JOIN ug_procurement.procurement_plans p USING(plan_id)
WHERE n.status IN ('closed','published') AND a.disclosure_status='publishable';

CREATE OR REPLACE VIEW ug_procurement.v_deliverable_exceptions AS
SELECT p.procuring_entity_ref,n.notice_ref,a.award_ref,a.contract_ref,d.deliverable_code,d.description,d.due_on,d.status
FROM ug_procurement.contract_deliverables d
JOIN ug_procurement.awards a USING(award_id)
JOIN ug_procurement.notices n USING(notice_id)
JOIN ug_procurement.procurement_plans p USING(plan_id)
WHERE d.status NOT IN ('accepted','waived') AND d.due_on<CURRENT_DATE;

CREATE OR REPLACE VIEW ug_procurement.v_variation_review_queue AS
SELECT v.variation_ref,a.award_ref,a.contract_ref,v.value_delta,v.reason,v.requested_by_ref,v.status
FROM ug_procurement.contract_variations v JOIN ug_procurement.awards a USING(award_id)
WHERE v.status='requested';
