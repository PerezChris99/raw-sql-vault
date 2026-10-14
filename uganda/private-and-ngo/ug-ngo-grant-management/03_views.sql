CREATE OR REPLACE VIEW ngo_demo.v_grant_balance AS
SELECT g.grant_ref,d.donor_code,p.project_code,p.project_label,g.grant_currency,g.award_ceiling,
 COALESCE(e.spent,0)::NUMERIC(20,2) AS spent_amount,g.award_ceiling-COALESCE(e.spent,0) AS remaining_amount,
 g.status,g.start_date,g.end_date
FROM ngo_demo.grants g JOIN ngo_demo.donors d USING(donor_id) JOIN ngo_demo.projects p USING(project_id)
LEFT JOIN(SELECT grant_id,SUM(amount) spent FROM ngo_demo.expenditures GROUP BY grant_id)e USING(grant_id);
CREATE OR REPLACE VIEW ngo_demo.v_milestone_exceptions AS
SELECT m.milestone_ref,p.project_code,p.project_label,m.milestone_title,m.due_date,m.status,m.evidence_ref
FROM ngo_demo.milestones m JOIN ngo_demo.projects p USING(project_id)
WHERE (m.due_date<CURRENT_DATE AND m.status NOT IN('verified','waived')) OR m.status='delayed';
CREATE OR REPLACE VIEW ngo_demo.v_outcome_summary AS
SELECT p.project_code,o.indicator_code,o.period_start,o.period_end,o.observed_value,o.unit_label,o.disaggregation_code,o.source_ref
FROM ngo_demo.outcome_observations o JOIN ngo_demo.projects p USING(project_id);
COMMENT ON VIEW ngo_demo.v_grant_balance IS 'Amounts represent synthetic recorded expenditure, not an audited financial statement.';