-- 20 read-only examples; no live permit or infrastructure details.
-- 01 Register.
SELECT * FROM energy_demo.v_licence_register ORDER BY region_code,sector,licence_ref;
-- 02 Expiry watch.
SELECT * FROM energy_demo.v_expiry_watch ORDER BY days_until_expiry;
-- 03 Open corrective actions.
SELECT * FROM energy_demo.v_open_corrective_actions ORDER BY due_date NULLS LAST;
-- 04 Overdue actions.
SELECT * FROM energy_demo.v_overdue_actions ORDER BY due_date;
-- 05 Licence counts by sector/status.
SELECT sector,status,COUNT(*) FROM energy_demo.licences GROUP BY sector,status ORDER BY 1,2;
-- 06 Active licences expiring in 30 days.
SELECT licence_ref,expires_on FROM energy_demo.licences WHERE status='active' AND expires_on>=CURRENT_DATE AND expires_on<CURRENT_DATE+30;
-- 07 Licences without expiry.
SELECT licence_ref FROM energy_demo.licences WHERE status='active' AND expires_on IS NULL;
-- 08 Inspections by outcome.
SELECT outcome,COUNT(*) FROM energy_demo.inspections GROUP BY outcome ORDER BY outcome;
-- 09 Inspections per licence.
SELECT l.licence_ref,COUNT(i.inspection_id) FROM energy_demo.licences l LEFT JOIN energy_demo.inspections i USING(licence_id) GROUP BY l.licence_ref;
-- 10 Licences never inspected.
SELECT licence_ref FROM energy_demo.licences l WHERE NOT EXISTS(SELECT 1 FROM energy_demo.inspections i WHERE i.licence_id=l.licence_id);
-- 11 Corrective event history.
SELECT a.action_ref,e.previous_status,e.new_status,e.actor_ref,e.happened_at FROM energy_demo.action_events e JOIN energy_demo.corrective_actions a USING(action_id) ORDER BY 1,5;
-- 12 Latest event per corrective action.
SELECT DISTINCT ON(action_id) action_id,new_status,happened_at FROM energy_demo.action_events ORDER BY action_id,happened_at DESC,event_id DESC;
-- 13 Closed actions without close timestamp (should be empty).
SELECT action_ref FROM energy_demo.corrective_actions WHERE status='closed' AND closed_at IS NULL;
-- 14 Open action counts by owner.
SELECT owner_ref,COUNT(*) FROM energy_demo.corrective_actions WHERE status NOT IN('closed','cancelled') GROUP BY owner_ref;
-- 15 Inspections by month UTC.
SELECT date_trunc('month',inspected_at AT TIME ZONE 'UTC') AS month_utc,COUNT(*) FROM energy_demo.inspections GROUP BY 1 ORDER BY 1;
-- 16 Average days to expiry of active licences.
SELECT AVG(expires_on-CURRENT_DATE) FROM energy_demo.licences WHERE status='active' AND expires_on IS NOT NULL;
-- 17 Follow-up-required inspections without actions.
SELECT i.inspection_ref FROM energy_demo.inspections i WHERE outcome='follow_up_required' AND NOT EXISTS(SELECT 1 FROM energy_demo.corrective_actions a WHERE a.inspection_id=i.inspection_id);
-- 18 Licence distribution by synthetic region.
SELECT region_code,sector,COUNT(*) FROM energy_demo.licences GROUP BY region_code,sector;
-- 19 Expired licences with open actions.
SELECT DISTINCT l.licence_ref FROM energy_demo.licences l JOIN energy_demo.inspections i USING(licence_id) JOIN energy_demo.corrective_actions a USING(inspection_id) WHERE l.status='expired' AND a.status NOT IN('closed','cancelled');
-- 20 Finding review queue.
SELECT inspection_ref,licence_ref,outcome,inspected_at FROM energy_demo.inspections i JOIN energy_demo.licences l USING(licence_id) WHERE outcome IN('pending','follow_up_required','refer_for_review') ORDER BY inspected_at;
