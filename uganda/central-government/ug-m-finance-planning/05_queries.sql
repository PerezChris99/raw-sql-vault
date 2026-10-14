-- 20 read-only reports for synthetic aggregate budget lines.
-- 01 Budget execution.
SELECT * FROM finance_demo.v_budget_execution ORDER BY fiscal_year_start,budget_line_code;
-- 02 Reconciliation flags.
SELECT * FROM finance_demo.v_budget_reconciliation ORDER BY reconciliation_status,budget_line_code;
-- 03 Approved/released/spent by vote.
SELECT vote_code,SUM(approved_ceiling_ugx) approved,SUM(released_ugx) released,SUM(spent_ugx) spent FROM finance_demo.v_budget_execution GROUP BY vote_code;
-- 04 Approved ceiling remaining unreleased.
SELECT budget_line_code,unreleased_ceiling_ugx FROM finance_demo.v_budget_execution ORDER BY unreleased_ceiling_ugx DESC;
-- 05 Released but unspent.
SELECT budget_line_code,released_unspent_ugx FROM finance_demo.v_budget_execution WHERE released_unspent_ugx>0;
-- 06 Release activity by fiscal month.
SELECT date_trunc('month',release_date)::date AS month,COUNT(*) releases,SUM(amount_ugx) amount FROM finance_demo.releases GROUP BY 1 ORDER BY 1;
-- 07 Expenditure by type.
SELECT expenditure_type,COUNT(*),SUM(amount_ugx) amount FROM finance_demo.expenditures GROUP BY expenditure_type;
-- 08 Budget line with no releases.
SELECT budget_line_code FROM finance_demo.budget_lines b WHERE NOT EXISTS(SELECT 1 FROM finance_demo.releases r WHERE r.budget_line_id=b.budget_line_id);
-- 09 Budget line with no expenditure.
SELECT budget_line_code FROM finance_demo.budget_lines b WHERE NOT EXISTS(SELECT 1 FROM finance_demo.expenditures e WHERE e.budget_line_id=b.budget_line_id);
-- 10 Latest release per budget line.
SELECT DISTINCT ON(budget_line_id) budget_line_id,release_date,amount_ugx,release_ref FROM finance_demo.releases ORDER BY budget_line_id,release_date DESC,release_id DESC;
-- 11 Latest expenditure per line.
SELECT DISTINCT ON(budget_line_id) budget_line_id,expenditure_date,amount_ugx,expenditure_ref FROM finance_demo.expenditures ORDER BY budget_line_id,expenditure_date DESC,expenditure_id DESC;
-- 12 Releases ranked by amount.
SELECT release_ref,amount_ugx,DENSE_RANK() OVER(ORDER BY amount_ugx DESC) amount_rank FROM finance_demo.releases;
-- 13 Release utilisation percentages.
SELECT budget_line_code,ROUND(100*spent_ugx/NULLIF(released_ugx,0),2) spent_as_pct_of_release FROM finance_demo.v_budget_execution;
-- 14 Fiscal-year budget totals.
SELECT fiscal_year_start,SUM(approved_ceiling_ugx),SUM(released_ugx),SUM(spent_ugx) FROM finance_demo.v_budget_execution GROUP BY fiscal_year_start;
-- 15 Expenditure source-document duplicates.
SELECT source_document_ref,COUNT(*) FROM finance_demo.expenditures GROUP BY source_document_ref HAVING COUNT(*)>1;
-- 16 Release source-document duplicates.
SELECT source_document_ref,COUNT(*) FROM finance_demo.releases GROUP BY source_document_ref HAVING COUNT(*)>1;
-- 17 Largest expenditure entries.
SELECT expenditure_ref,amount_ugx FROM finance_demo.expenditures ORDER BY amount_ugx DESC LIMIT 10;
-- 18 Lines nearing ceiling, using >=90 percent released.
SELECT budget_line_code,ROUND(100*released_ugx/NULLIF(approved_ceiling_ugx,0),2) released_pct FROM finance_demo.v_budget_execution WHERE released_ugx>=approved_ceiling_ugx*0.9;
-- 19 Release month vs expenditure month.
SELECT date_trunc('month',release_date)::date month, SUM(amount_ugx) released FROM finance_demo.releases GROUP BY 1 ORDER BY 1;
-- 20 Data quality scan for unexpected exceedance (should be empty).
SELECT * FROM finance_demo.v_budget_reconciliation WHERE reconciliation_status<>'within_recorded_limits';