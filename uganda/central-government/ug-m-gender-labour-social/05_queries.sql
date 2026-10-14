-- 20 aggregate/query examples; do not expose subject-level case records in dashboards.
-- 01 Enrolment summary.
SELECT * FROM social_demo.v_enrolment_summary ORDER BY programme_code,status;
-- 02 Open milestone queue.
SELECT * FROM social_demo.v_open_milestones ORDER BY due_date NULLS LAST;
-- 03 Overdue milestone queue.
SELECT * FROM social_demo.v_overdue_milestones ORDER BY due_date;
-- 04 Programme counts by service type.
SELECT service_type,COUNT(*) FROM social_demo.programmes GROUP BY service_type;
-- 05 Milestones by type/status.
SELECT milestone_type,status,COUNT(*) FROM social_demo.service_milestones GROUP BY 1,2;
-- 06 Programmes without enrolments.
SELECT programme_code FROM social_demo.programmes p WHERE NOT EXISTS(SELECT 1 FROM social_demo.enrolments e WHERE e.programme_id=p.programme_id);
-- 07 Enrolments by programme.
SELECT programme_code,COUNT(*) FROM social_demo.enrolments e JOIN social_demo.programmes p USING(programme_id) GROUP BY programme_code;
-- 08 Completed enrolments lacking closure timestamp.
SELECT enrolment_ref FROM social_demo.enrolments WHERE status='completed' AND closed_at IS NULL;
-- 09 Open milestones by owner.
SELECT owner_ref,COUNT(*) FROM social_demo.service_milestones WHERE status NOT IN('completed','cancelled') GROUP BY owner_ref;
-- 10 Milestone event history.
SELECT m.milestone_ref,e.previous_status,e.new_status,e.actor_ref,e.happened_at FROM social_demo.milestone_events e JOIN social_demo.service_milestones m USING(milestone_id) ORDER BY m.milestone_ref,e.happened_at;
-- 11 Latest event per milestone.
SELECT DISTINCT ON(milestone_id) milestone_id,new_status,happened_at FROM social_demo.milestone_events ORDER BY milestone_id,happened_at DESC,event_id DESC;
-- 12 Due in next thirty days.
SELECT milestone_ref,due_date FROM social_demo.v_open_milestones WHERE due_date>=CURRENT_DATE AND due_date<CURRENT_DATE+30;
-- 13 Programmes by active/closed status.
SELECT status,COUNT(*) FROM social_demo.programmes GROUP BY status;
-- 14 Enrolments without any milestones.
SELECT enrolment_ref FROM social_demo.enrolments e WHERE NOT EXISTS(SELECT 1 FROM social_demo.service_milestones m WHERE m.enrolment_id=e.enrolment_id);
-- 15 Referrals still blocked.
SELECT * FROM social_demo.v_open_milestones WHERE milestone_type IN('referral_sent','referral_acknowledged') AND status='blocked';
-- 16 Completion rate by programme (aggregate).
SELECT programme_code,ROUND(100.0*COUNT(*) FILTER(WHERE status='completed')/NULLIF(COUNT(*),0),2) AS completion_pct FROM social_demo.enrolments e JOIN social_demo.programmes p USING(programme_id) GROUP BY programme_code;
-- 17 Milestones overdue count by service type.
SELECT p.service_type,COUNT(*) FROM social_demo.v_overdue_milestones m JOIN social_demo.enrolments e USING(enrolment_ref) JOIN social_demo.programmes p USING(programme_code) GROUP BY p.service_type;
-- 18 Monthly enrolment creation volume.
SELECT date_trunc('month',opened_at AT TIME ZONE 'UTC') AS month_utc,COUNT(*) FROM social_demo.enrolments GROUP BY 1 ORDER BY 1;
-- 19 Event volume by month.
SELECT date_trunc('month',happened_at AT TIME ZONE 'UTC') AS month_utc,COUNT(*) FROM social_demo.milestone_events GROUP BY 1 ORDER BY 1;
-- 20 Milestone integrity scan (should be empty).
SELECT milestone_ref FROM social_demo.service_milestones WHERE status='completed' AND completed_at IS NULL;