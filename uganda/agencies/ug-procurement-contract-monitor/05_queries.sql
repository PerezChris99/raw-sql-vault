-- Purpose: procurement disclosure, delivery monitoring and audit exception queries.
-- Engine: PostgreSQL 15+. Prerequisites: schema, seeds and views.
-- 01. Public-safe awards approved for disclosure only.
SELECT * FROM ug_procurement.v_public_award_register ORDER BY fiscal_year,procuring_entity_ref,award_ref;
-- 02. Overdue deliverables.
SELECT * FROM ug_procurement.v_deliverable_exceptions ORDER BY due_on,award_ref;
-- 03. Contract variations awaiting independent review.
SELECT * FROM ug_procurement.v_variation_review_queue ORDER BY variation_ref;
-- 04. Award values compared with procurement-plan estimates.
SELECT p.plan_ref,p.estimated_value,a.award_ref,a.awarded_amount,
       a.awarded_amount-p.estimated_value AS variance_from_plan
FROM ug_procurement.procurement_plans p JOIN ug_procurement.notices n USING(plan_id)
JOIN ug_procurement.awards a USING(notice_id) ORDER BY p.plan_ref;
-- 05. Variations with missing review evidence (should return zero).
SELECT variation_ref,status FROM ug_procurement.contract_variations
WHERE status IN ('approved','rejected') AND (reviewed_at IS NULL OR review_evidence_ref IS NULL);
-- 06. Award/notice publication integrity check.
SELECT a.award_ref,n.notice_ref,n.status FROM ug_procurement.awards a JOIN ug_procurement.notices n USING(notice_id)
WHERE n.published_at IS NULL;
-- 07. Approved revised contract value, calculated from approved variations only.
SELECT a.award_ref,a.contract_ref,a.awarded_amount+COALESCE(SUM(v.value_delta) FILTER(WHERE v.status='approved'),0) AS revised_contract_value
FROM ug_procurement.awards a LEFT JOIN ug_procurement.contract_variations v USING(award_id)
GROUP BY a.award_id,a.award_ref,a.contract_ref,a.awarded_amount ORDER BY a.award_ref;
-- 08. Event trail for a contract award.
SELECT * FROM ug_procurement.audit_events WHERE entity_ref='UGPA-DEMO-001' OR entity_ref='UGPV-DEMO-001'
ORDER BY occurred_at,event_id;
