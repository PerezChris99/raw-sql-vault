-- 20 read-only trade-promotion reports; applicant references are synthetic.
-- 01 Application summary.
SELECT * FROM trade_demo.v_application_summary ORDER BY programme_code,submitted_at;
-- 02 Open milestones.
SELECT * FROM trade_demo.v_open_milestones ORDER BY due_date NULLS LAST;
-- 03 Overdue milestones.
SELECT * FROM trade_demo.v_overdue_milestones ORDER BY due_date;
-- 04 Applications by programme/status.
SELECT programme_code,status,COUNT(*) FROM trade_demo.v_application_summary GROUP BY 1,2;
-- 05 Applicants by sector/business size.
SELECT sector_code,business_type,COUNT(*) FROM trade_demo.applicant_refs WHERE is_active GROUP BY 1,2;
-- 06 Programmes without applications.
SELECT programme_code FROM trade_demo.programmes p WHERE NOT EXISTS(SELECT 1 FROM trade_demo.applications a WHERE a.programme_id=p.programme_id);
-- 07 Applications without milestones.
SELECT application_ref FROM trade_demo.applications a WHERE NOT EXISTS(SELECT 1 FROM trade_demo.milestones m WHERE m.application_id=a.application_id);
-- 08 Milestones by type and status.
SELECT milestone_type,status,COUNT(*) FROM trade_demo.milestones GROUP BY 1,2;
-- 09 Milestone event history.
SELECT m.milestone_ref,e.previous_status,e.new_status,e.actor_ref,e.happened_at FROM trade_demo.milestone_events e JOIN trade_demo.milestones m USING(milestone_id) ORDER BY 1,5;
-- 10 Latest event per milestone.
SELECT DISTINCT ON(milestone_id) milestone_id,new_status,happened_at FROM trade_demo.milestone_events ORDER BY milestone_id,happened_at DESC,event_id DESC;
-- 11 Completed milestones missing completion timestamp.
SELECT milestone_ref FROM trade_demo.milestones WHERE status='completed' AND completed_at IS NULL;
-- 12 Upcoming milestones due within 30 days.
SELECT milestone_ref,due_date FROM trade_demo.v_open_milestones WHERE due_date>=CURRENT_DATE AND due_date<CURRENT_DATE+30;
-- 13 Applications by submission month.
SELECT date_trunc('month',submitted_at AT TIME ZONE 'UTC') AS month_utc,COUNT(*) FROM trade_demo.applications GROUP BY 1 ORDER BY 1;
-- 14 Accept rate by programme.
SELECT programme_code,ROUND(100.0*COUNT(*) FILTER(WHERE status='accepted')/NULLIF(COUNT(*),0),2) AS accepted_pct FROM trade_demo.v_application_summary GROUP BY programme_code;
-- 15 Declined/withdrawn cases by programme.
SELECT programme_code,COUNT(*) FILTER(WHERE status IN('declined','withdrawn')) FROM trade_demo.v_application_summary GROUP BY programme_code;
-- 16 Average active milestones per programme.
SELECT programme_code,AVG(milestone_count) FROM (SELECT p.programme_code,a.application_id,COUNT(m.milestone_id) milestone_count FROM trade_demo.programmes p JOIN trade_demo.applications a USING(programme_id) LEFT JOIN trade_demo.milestones m USING(application_id) GROUP BY p.programme_code,a.application_id) x GROUP BY programme_code;
-- 17 Applicant references without applications.
SELECT applicant_token FROM trade_demo.applicant_refs a WHERE NOT EXISTS(SELECT 1 FROM trade_demo.applications x WHERE x.applicant_id=a.applicant_id);
-- 18 Open milestone workload by owner.
SELECT owner_ref,COUNT(*) FROM trade_demo.milestones WHERE status NOT IN('completed','cancelled') GROUP BY owner_ref;
-- 19 Applications within active programmes.
SELECT a.application_ref,p.programme_code FROM trade_demo.applications a JOIN trade_demo.programmes p USING(programme_id) WHERE p.status='active';
-- 20 Programme date integrity scan.
SELECT programme_code FROM trade_demo.programmes WHERE ends_on<starts_on;