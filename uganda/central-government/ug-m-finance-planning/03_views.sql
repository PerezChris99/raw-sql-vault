CREATE OR REPLACE VIEW finance_demo.v_budget_execution AS
SELECT b.budget_line_code,b.vote_code,b.programme_code,b.fiscal_year_start,b.approved_ceiling_ugx,b.line_status,
 COALESCE(r.released_ugx,0)::NUMERIC(20,2) AS released_ugx,
 COALESCE(e.spent_ugx,0)::NUMERIC(20,2) AS spent_ugx,
 COALESCE(r.released_ugx,0)-COALESCE(e.spent_ugx,0) AS released_unspent_ugx,
 b.approved_ceiling_ugx-COALESCE(r.released_ugx,0) AS unreleased_ceiling_ugx,
 COALESCE(e.spent_ugx,0)/NULLIF(b.approved_ceiling_ugx,0)*100 AS ceiling_spend_pct
FROM finance_demo.budget_lines b
LEFT JOIN (SELECT budget_line_id,SUM(amount_ugx) released_ugx FROM finance_demo.releases GROUP BY budget_line_id) r USING(budget_line_id)
LEFT JOIN (SELECT budget_line_id,SUM(amount_ugx) spent_ugx FROM finance_demo.expenditures GROUP BY budget_line_id) e USING(budget_line_id);
CREATE OR REPLACE VIEW finance_demo.v_budget_reconciliation AS
SELECT *,released_ugx-spent_ugx AS release_to_spend_gap_ugx,
 CASE WHEN released_ugx>approved_ceiling_ugx THEN 'release_over_ceiling'
      WHEN spent_ugx>released_ugx THEN 'spend_over_release'
      ELSE 'within_recorded_limits' END AS reconciliation_status
FROM finance_demo.v_budget_execution;
COMMENT ON VIEW finance_demo.v_budget_reconciliation IS 'Highlights aggregate limit inconsistencies; not an audit conclusion.';