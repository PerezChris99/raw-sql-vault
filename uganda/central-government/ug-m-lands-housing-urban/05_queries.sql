-- Read-only reporting examples; no real parcel/owner data.
-- 01 Application register.
SELECT * FROM urban_demo.v_application_register ORDER BY submitted_at DESC;
-- 02 Permit expiry watch.
SELECT * FROM urban_demo.v_permit_expiry_watch ORDER BY expires_on;
-- 03 Open actions.
SELECT * FROM urban_demo.v_open_actions ORDER BY due_date NULLS LAST;
-- 04 Overdue actions.
SELECT * FROM urban_demo.v_overdue_actions ORDER BY due_date;
-- 05 Applications by locality/status.
SELECT locality_code,status,COUNT(*) FROM urban_demo.applications GROUP BY 1,2;
-- 06 Application count by development type.
SELECT development_type,COUNT(*) FROM urban_demo.applications GROUP BY development_type;
-- 07 Applications without permits.
SELECT application_ref FROM urban_demo.applications a WHERE NOT EXISTS(SELECT 1 FROM urban_demo.permits p WHERE p.application_id=a.application_id);
-- 08 Applications never inspected.
SELECT application_ref FROM urban_demo.applications a WHERE NOT EXISTS(SELECT 1 FROM urban_demo.inspections i WHERE i.application_id=a.application_id);
-- 09 Inspections by outcome.
SELECT outcome,COUNT(*) FROM urban_demo.inspections GROUP BY outcome;
-- 10 Inspection follow-ups without actions.
SELECT inspection_ref FROM urban_demo.inspections i WHERE outcome='follow_up_required' AND NOT EXISTS(SELECT 1 FROM urban_demo.actions a WHERE a.inspection_id=i.inspection_id);
-- 11 Action history.
SELECT a.action_ref,e.previous_status,e.new_status,e.actor_ref,e.happened_at FROM urban_demo.action_events e JOIN urban_demo.actions a USING(action_id) ORDER BY 1,5;
-- 12 Latest event per action.
SELECT DISTINCT ON(action_id) action_id,new_status,happened_at FROM urban_demo.action_events ORDER BY action_id,happened_at DESC,event_id DESC;
-- 13 Closed actions without timestamp.
SELECT action_ref FROM urban_demo.actions WHERE status='closed' AND closed_at IS NULL;
-- 14 Permits by status and type.
SELECT status,permit_type,COUNT(*) FROM urban_demo.permits GROUP BY 1,2;
-- 15 Active permits due in thirty days.
SELECT permit_ref,expires_on FROM urban_demo.permits WHERE status='active' AND expires_on>=CURRENT_DATE AND expires_on<CURRENT_DATE+30;
-- 16 Applications by month.
SELECT date_trunc('month',submitted_at AT TIME ZONE 'UTC') AS month_utc,COUNT(*) FROM urban_demo.applications GROUP BY 1 ORDER BY 1;
-- 17 Open action count by owner.
SELECT owner_ref,COUNT(*) FROM urban_demo.actions WHERE status NOT IN('closed','cancelled') GROUP BY owner_ref;
-- 18 Applications by locality and type.
SELECT locality_code,development_type,COUNT(*) FROM urban_demo.applications GROUP BY 1,2;
-- 19 Inspections timeline.
SELECT application_ref,inspected_at,inspection_type,outcome FROM urban_demo.inspections i JOIN urban_demo.applications a USING(application_id) ORDER BY inspected_at;
-- 20 Expired permits with open actions.
SELECT DISTINCT p.permit_ref FROM urban_demo.permits p JOIN urban_demo.applications a USING(application_id) JOIN urban_demo.inspections i USING(application_id) JOIN urban_demo.actions x USING(inspection_id) WHERE p.status='expired' AND x.status NOT IN('closed','cancelled');