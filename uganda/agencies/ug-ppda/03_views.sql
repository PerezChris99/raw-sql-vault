CREATE OR REPLACE VIEW ppda_demo.v_procurement_pipeline AS
SELECT p.plan_ref,p.entity_ref,p.procurement_title,p.procurement_method,p.estimated_value_ugx,p.status AS plan_status,
 t.tender_ref,t.tender_status,t.advertised_at,t.closing_at
FROM ppda_demo.procurement_plans p LEFT JOIN ppda_demo.tenders t USING(plan_id);
CREATE OR REPLACE VIEW ppda_demo.v_milestone_status AS
SELECT m.milestone_ref,m.milestone_title,m.due_date,m.planned_value_ugx,m.status,m.evidence_ref,m.verified_by_ref,m.verified_at,
 c.contract_ref,c.contract_value_ugx,c.contract_status,c.end_date,t.tender_ref,p.entity_ref
FROM ppda_demo.contract_milestones m JOIN ppda_demo.contracts c USING(contract_id)
JOIN ppda_demo.tenders t USING(tender_id) JOIN ppda_demo.procurement_plans p USING(plan_id);
CREATE OR REPLACE VIEW ppda_demo.v_milestone_exceptions AS
SELECT * FROM ppda_demo.v_milestone_status
WHERE (due_date<CURRENT_DATE AND status NOT IN('verified','waived')) OR status='disputed';
COMMENT ON VIEW ppda_demo.v_milestone_exceptions IS 'Follow-up candidates; no finding of wrongdoing is implied.';