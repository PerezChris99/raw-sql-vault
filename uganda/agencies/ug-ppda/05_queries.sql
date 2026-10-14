-- 20 read-only reports over synthetic procurement metadata.
-- 01 Plan and tender pipeline.
SELECT * FROM ppda_demo.v_procurement_pipeline ORDER BY plan_ref;
-- 02 Milestone exceptions.
SELECT * FROM ppda_demo.v_milestone_exceptions ORDER BY due_date;
-- 03 Contract value by entity reference.
SELECT p.entity_ref,SUM(c.contract_value_ugx) FROM ppda_demo.contracts c JOIN ppda_demo.tenders t USING(tender_id) JOIN ppda_demo.procurement_plans p USING(plan_id) GROUP BY p.entity_ref;
-- 04 Contracts approaching end date.
SELECT contract_ref,end_date FROM ppda_demo.contracts WHERE contract_status='active' AND end_date<CURRENT_DATE+60 ORDER BY end_date;
-- 05 Tender close dates already passed while still advertised.
SELECT tender_ref,closing_at FROM ppda_demo.tenders WHERE tender_status='advertised' AND closing_at<CURRENT_DATE;
-- 06 Milestones by status.
SELECT status,COUNT(*) FROM ppda_demo.contract_milestones GROUP BY status;
-- 07 Events by milestone.
SELECT m.milestone_ref,e.previous_status,e.new_status,e.actor_ref,e.happened_at FROM ppda_demo.milestone_events e JOIN ppda_demo.contract_milestones m USING(milestone_id) ORDER BY m.milestone_ref,e.happened_at;
-- 08 Latest event per milestone.
SELECT DISTINCT ON(milestone_id) milestone_id,new_status,happened_at FROM ppda_demo.milestone_events ORDER BY milestone_id,happened_at DESC,event_id DESC;
-- 09 Contract milestones without an evidence reference.
SELECT milestone_ref FROM ppda_demo.contract_milestones WHERE status='verified' AND evidence_ref IS NULL;
-- 10 Approved plans without a tender.
SELECT plan_ref FROM ppda_demo.procurement_plans p WHERE status='approved' AND NOT EXISTS(SELECT 1 FROM ppda_demo.tenders t WHERE t.plan_id=p.plan_id);
-- 11 Contracts without milestone rows.
SELECT contract_ref FROM ppda_demo.contracts c WHERE NOT EXISTS(SELECT 1 FROM ppda_demo.contract_milestones m WHERE m.contract_id=c.contract_id);
-- 12 Planned milestone value by contract.
SELECT contract_ref,SUM(planned_value_ugx) FROM ppda_demo.v_milestone_status GROUP BY contract_ref;
-- 13 Milestones due in next 30 days.
SELECT milestone_ref,due_date,status FROM ppda_demo.contract_milestones WHERE due_date>=CURRENT_DATE AND due_date<CURRENT_DATE+30 ORDER BY due_date;
-- 14 Milestones ranked by planned value.
SELECT milestone_ref,planned_value_ugx,DENSE_RANK() OVER(ORDER BY planned_value_ugx DESC) value_rank FROM ppda_demo.contract_milestones;
-- 15 Plans by procurement method and fiscal year.
SELECT procurement_method,fiscal_year_start,COUNT(*) FROM ppda_demo.procurement_plans GROUP BY procurement_method,fiscal_year_start;
-- 16 Contract values by status.
SELECT contract_status,COUNT(*),SUM(contract_value_ugx) FROM ppda_demo.contracts GROUP BY contract_status;
-- 17 Source notice references reused.
SELECT source_notice_ref,COUNT(*) FROM ppda_demo.tenders WHERE source_notice_ref IS NOT NULL GROUP BY source_notice_ref HAVING COUNT(*)>1;
-- 18 Event volume by UTC month.
SELECT date_trunc('month',happened_at AT TIME ZONE 'UTC') month_utc,COUNT(*) FROM ppda_demo.milestone_events GROUP BY 1 ORDER BY 1;
-- 19 Disputed milestones grouped by entity.
SELECT entity_ref,COUNT(*) FROM ppda_demo.v_milestone_status WHERE status='disputed' GROUP BY entity_ref;
-- 20 Milestone data-quality scan.
SELECT milestone_ref FROM ppda_demo.contract_milestones WHERE status='verified' AND (evidence_ref IS NULL OR verified_by_ref IS NULL OR verified_at IS NULL);