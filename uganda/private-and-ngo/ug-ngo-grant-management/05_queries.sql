-- 20 read-only reports over synthetic grant and project data.
-- 01 Grant balance.
SELECT * FROM ngo_demo.v_grant_balance ORDER BY donor_code,grant_ref;
-- 02 Grant utilisation percent.
SELECT grant_ref,ROUND(100*spent_amount/NULLIF(award_ceiling,0),2) utilisation_pct FROM ngo_demo.v_grant_balance;
-- 03 Project totals by sector.
SELECT p.sector,COUNT(DISTINCT p.project_id),SUM(g.award_ceiling) award_total FROM ngo_demo.projects p JOIN ngo_demo.grants g USING(project_id) GROUP BY p.sector;
-- 04 Grant deadlines in next 90 days.
SELECT grant_ref,end_date,status FROM ngo_demo.grants WHERE end_date>=CURRENT_DATE AND end_date<CURRENT_DATE+90 ORDER BY end_date;
-- 05 Expired grants still active.
SELECT grant_ref,end_date FROM ngo_demo.grants WHERE status='active' AND end_date<CURRENT_DATE;
-- 06 Grant balances by donor and currency.
SELECT donor_code,grant_currency,SUM(award_ceiling) ceiling,SUM(spent_amount) spent,SUM(remaining_amount) remaining FROM ngo_demo.v_grant_balance GROUP BY donor_code,grant_currency;
-- 07 Milestone exception queue.
SELECT * FROM ngo_demo.v_milestone_exceptions ORDER BY due_date;
-- 08 Milestones by state.
SELECT status,COUNT(*) FROM ngo_demo.milestones GROUP BY status;
-- 09 Milestone event history.
SELECT m.milestone_ref,e.previous_status,e.new_status,e.actor_ref,e.happened_at FROM ngo_demo.milestone_events e JOIN ngo_demo.milestones m USING(milestone_id) ORDER BY m.milestone_ref,e.happened_at;
-- 10 Latest event per milestone.
SELECT DISTINCT ON(milestone_id) milestone_id,new_status,happened_at FROM ngo_demo.milestone_events ORDER BY milestone_id,happened_at DESC,event_id DESC;
-- 11 Projects with no milestone.
SELECT project_code FROM ngo_demo.projects p WHERE NOT EXISTS(SELECT 1 FROM ngo_demo.milestones m WHERE m.project_id=p.project_id);
-- 12 Grants with no spending entries.
SELECT grant_ref FROM ngo_demo.grants g WHERE NOT EXISTS(SELECT 1 FROM ngo_demo.expenditures e WHERE e.grant_id=g.grant_id);
-- 13 Expenditure by category and currency.
SELECT expense_category,currency,COUNT(*),SUM(amount) FROM ngo_demo.expenditures GROUP BY expense_category,currency;
-- 14 Monthly expenses.
SELECT date_trunc('month',expense_date)::date month_utc,currency,SUM(amount) FROM ngo_demo.expenditures GROUP BY 1,currency ORDER BY 1,currency;
-- 15 Highest grant ceiling ranks.
SELECT grant_ref,award_ceiling,DENSE_RANK() OVER(ORDER BY award_ceiling DESC) AS rank FROM ngo_demo.grants;
-- 16 Outcome values by indicator.
SELECT indicator_code,unit_label,period_end,observed_value FROM ngo_demo.v_outcome_summary ORDER BY indicator_code,period_end;
-- 17 Outcome observation history over time.
SELECT project_code,indicator_code,period_start,period_end,observed_value FROM ngo_demo.v_outcome_summary ORDER BY project_code,indicator_code,period_end;
-- 18 Budget ceiling cap scan (should be empty after guarded insertion).
SELECT g.grant_ref FROM ngo_demo.v_grant_balance g WHERE spent_amount>award_ceiling;
-- 19 Expense idempotency collision scan (should be empty).
SELECT idempotency_key,COUNT(*) FROM ngo_demo.expenditures GROUP BY idempotency_key HAVING COUNT(*)>1;
-- 20 Active projects with no grant award.
SELECT project_code FROM ngo_demo.projects p WHERE status='active' AND NOT EXISTS(SELECT 1 FROM ngo_demo.grants g WHERE g.project_id=p.project_id);