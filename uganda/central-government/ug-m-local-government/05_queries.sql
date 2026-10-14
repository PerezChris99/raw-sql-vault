-- PostgreSQL 15+; read-only examples; synthetic data only.
-- 01 Budget execution.
SELECT * FROM lgmin_demo.v_budget_execution ORDER BY fiscal_year,authority_code,programme_ref;
-- 02 Overdue programmes.
SELECT * FROM lgmin_demo.v_overdue_programmes ORDER BY programme_ref;
-- 03 Budget by authority/year.
SELECT authority_code,fiscal_year,SUM(approved_ugx) AS approved,SUM(released_ugx) AS released,SUM(spent_ugx) AS spent
FROM lgmin_demo.v_budget_execution GROUP BY authority_code,fiscal_year ORDER BY 1,2;
-- 04 Utilisation by status.
SELECT status,AVG(release_utilisation_pct) AS average_utilisation_pct FROM lgmin_demo.v_budget_execution GROUP BY status;
-- 05 Unspent releases.
SELECT programme_ref,released_unspent_ugx FROM lgmin_demo.v_budget_execution WHERE released_unspent_ugx>0;
-- 06 Missing target dates.
SELECT programme_ref,title FROM lgmin_demo.programmes WHERE target_date IS NULL AND status NOT IN('completed','cancelled') AND is_deleted=FALSE;
-- 07 Authorities without programmes.
SELECT authority_code FROM lgmin_demo.authorities a WHERE NOT EXISTS(SELECT 1 FROM lgmin_demo.programmes p WHERE p.authority_id=a.authority_id AND p.is_deleted=FALSE);
-- 08 Programme history.
SELECT p.programme_ref,e.previous_status,e.new_status,e.actor_ref,e.happened_at,e.note FROM lgmin_demo.programme_events e JOIN lgmin_demo.programmes p USING(programme_id) ORDER BY 1,5;
-- 09 Latest event per programme.
SELECT DISTINCT ON(programme_id) programme_id,new_status,happened_at FROM lgmin_demo.programme_events ORDER BY programme_id,happened_at DESC,event_id DESC;
-- 10 Non-planned programmes without event history.
SELECT programme_ref FROM lgmin_demo.programmes p WHERE status<>'planned' AND NOT EXISTS(SELECT 1 FROM lgmin_demo.programme_events e WHERE e.programme_id=p.programme_id);
-- 11 Budget ranked within authority.
SELECT authority_code,programme_ref,approved_ugx,DENSE_RANK() OVER(PARTITION BY authority_code ORDER BY approved_ugx DESC) AS budget_rank FROM lgmin_demo.v_budget_execution;
-- 12 Release rate.
SELECT programme_ref,ROUND(100*released_ugx/NULLIF(approved_ugx,0),2) AS release_pct FROM lgmin_demo.v_budget_execution;
-- 13 Events by UTC month.
SELECT date_trunc('month',happened_at AT TIME ZONE 'UTC') AS utc_month,COUNT(*) FROM lgmin_demo.programme_events GROUP BY 1 ORDER BY 1;
-- 14 Late open programmes.
SELECT programme_ref,target_date,CURRENT_DATE-target_date AS days_late FROM lgmin_demo.programmes WHERE target_date<CURRENT_DATE AND status NOT IN('completed','cancelled') AND is_deleted=FALSE;
-- 15 Completed programmes with unspent released amount.
SELECT programme_ref,released_unspent_ugx FROM lgmin_demo.v_budget_execution WHERE status='completed' AND released_unspent_ugx>0;
-- 16 Budget invariant scan (should be empty due to constraints).
SELECT programme_ref FROM lgmin_demo.programmes WHERE spent_ugx>released_ugx OR released_ugx>approved_ugx;
-- 17 Counts by programme status.
SELECT status,COUNT(*) FROM lgmin_demo.programmes WHERE is_deleted=FALSE GROUP BY status ORDER BY status;
-- 18 Programme creation trend.
SELECT date_trunc('month',created_at AT TIME ZONE 'UTC') AS month_utc,COUNT(*) FROM lgmin_demo.programmes GROUP BY 1 ORDER BY 1;
-- 19 Due in next thirty days.
SELECT programme_ref,title,target_date FROM lgmin_demo.programmes WHERE target_date>=CURRENT_DATE AND target_date<CURRENT_DATE+30 AND status NOT IN('completed','cancelled') AND is_deleted=FALSE ORDER BY target_date;
-- 20 Counts by fiscal year and status.
SELECT fiscal_year,status,COUNT(*) FROM lgmin_demo.programmes WHERE is_deleted=FALSE GROUP BY fiscal_year,status ORDER BY 1,2;