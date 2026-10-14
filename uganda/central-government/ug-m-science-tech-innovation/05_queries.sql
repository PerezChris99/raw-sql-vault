-- 20 read-only research/grant metadata reports; all references are synthetic.
-- 01 Call pipeline.
SELECT * FROM innovation_demo.v_call_pipeline ORDER BY call_code;
-- 02 Milestone tracker.
SELECT * FROM innovation_demo.v_milestone_tracker ORDER BY project_ref,due_date;
-- 03 Overdue milestone tracker.
SELECT * FROM innovation_demo.v_overdue_milestones ORDER BY due_date;
-- 04 Proposal count by status.
SELECT status,COUNT(*) FROM innovation_demo.proposals GROUP BY status;
-- 05 Proposed budget by call.
SELECT c.call_code,SUM(p.requested_budget_ugx) requested FROM innovation_demo.calls c LEFT JOIN innovation_demo.proposals p USING(call_id) GROUP BY c.call_code;
-- 06 Accepted requests by focus area.
SELECT c.focus_area,COUNT(*) FILTER(WHERE p.status='accepted') accepted FROM innovation_demo.calls c LEFT JOIN innovation_demo.proposals p USING(call_id) GROUP BY c.focus_area;
-- 07 Calls with no proposals.
SELECT call_code FROM innovation_demo.calls c WHERE NOT EXISTS(SELECT 1 FROM innovation_demo.proposals p WHERE p.call_id=c.call_id);
-- 08 Accepted proposals without projects.
SELECT proposal_ref FROM innovation_demo.proposals p WHERE status='accepted' AND NOT EXISTS(SELECT 1 FROM innovation_demo.projects x WHERE x.proposal_id=p.proposal_id);
-- 09 Milestones without evidence reference.
SELECT milestone_ref FROM innovation_demo.milestones WHERE evidence_ref IS NULL;
-- 10 Completed milestones missing evidence (should be empty after controlled transitions).
SELECT milestone_ref FROM innovation_demo.milestones WHERE status='completed' AND evidence_ref IS NULL;
-- 11 Milestone transition history.
SELECT m.milestone_ref,e.previous_status,e.new_status,e.actor_ref,e.happened_at FROM innovation_demo.milestone_events e JOIN innovation_demo.milestones m USING(milestone_id) ORDER BY 1,5;
-- 12 Latest event per milestone.
SELECT DISTINCT ON(milestone_id) milestone_id,new_status,happened_at FROM innovation_demo.milestone_events ORDER BY milestone_id,happened_at DESC,event_id DESC;
-- 13 Project budget by status.
SELECT status,SUM(approved_budget_ugx) FROM innovation_demo.projects GROUP BY status;
-- 14 Projects nearing end date.
SELECT project_ref,end_date FROM innovation_demo.projects WHERE status IN('active','blocked') AND end_date<CURRENT_DATE+60;
-- 15 Calls by scheduled close month.
SELECT date_trunc('month',closes_on)::date AS close_month,COUNT(*) FROM innovation_demo.calls GROUP BY 1 ORDER BY 1;
-- 16 Submission volume by UTC month.
SELECT date_trunc('month',submitted_at AT TIME ZONE 'UTC') AS month_utc,COUNT(*) FROM innovation_demo.proposals GROUP BY 1 ORDER BY 1;
-- 17 Proposals above the call budget ceiling (aggregate signal, needs review).
SELECT c.call_code,SUM(p.requested_budget_ugx) requested,c.budget_ceiling_ugx FROM innovation_demo.calls c JOIN innovation_demo.proposals p USING(call_id) GROUP BY c.call_code,c.budget_ceiling_ugx HAVING SUM(p.requested_budget_ugx)>c.budget_ceiling_ugx;
-- 18 Milestone completion share by project.
SELECT project_ref,ROUND(100.0*COUNT(*) FILTER(WHERE status='completed')/NULLIF(COUNT(*),0),2) complete_pct FROM innovation_demo.v_milestone_tracker GROUP BY project_ref;
-- 19 Call dates inconsistent.
SELECT call_code FROM innovation_demo.calls WHERE closes_on<opens_on;
-- 20 Projects without milestones.
SELECT project_ref FROM innovation_demo.projects p WHERE NOT EXISTS(SELECT 1 FROM innovation_demo.milestones m WHERE m.project_id=p.project_id);