-- 20 read-only queries using synthetic metadata.
-- 01 Permit register.
SELECT * FROM tourism_demo.v_permit_register ORDER BY locality_code,permit_ref;
-- 02 Expiry watch.
SELECT * FROM tourism_demo.v_expiry_watch ORDER BY expires_on;
-- 03 Open actions.
SELECT * FROM tourism_demo.v_open_actions ORDER BY due_date NULLS LAST;
-- 04 Overdue actions.
SELECT * FROM tourism_demo.v_overdue_actions ORDER BY due_date;
-- 05 Establishments by category and locality.
SELECT category,locality_code,COUNT(*) FROM tourism_demo.establishments WHERE is_active GROUP BY 1,2;
-- 06 Permit volume by type/status.
SELECT permit_type,status,COUNT(*) FROM tourism_demo.permits GROUP BY 1,2;
-- 07 Active permits with no expiration date.
SELECT permit_ref FROM tourism_demo.permits WHERE status='active' AND expires_on IS NULL;
-- 08 Establishments without permits.
SELECT establishment_ref FROM tourism_demo.establishments e WHERE NOT EXISTS(SELECT 1 FROM tourism_demo.permits p WHERE p.establishment_id=e.establishment_id);
-- 09 Inspections by outcome.
SELECT outcome,COUNT(*) FROM tourism_demo.inspections GROUP BY outcome;
-- 10 Inspections per establishment.
SELECT e.establishment_ref,COUNT(i.inspection_id) FROM tourism_demo.establishments e LEFT JOIN tourism_demo.inspections i USING(establishment_id) GROUP BY e.establishment_ref;
-- 11 Establishments never inspected.
SELECT establishment_ref FROM tourism_demo.establishments e WHERE NOT EXISTS(SELECT 1 FROM tourism_demo.inspections i WHERE i.establishment_id=e.establishment_id);
-- 12 Action event timeline.
SELECT a.action_ref,x.previous_status,x.new_status,x.actor_ref,x.happened_at FROM tourism_demo.action_events x JOIN tourism_demo.actions a USING(action_id) ORDER BY a.action_ref,x.happened_at;
-- 13 Latest action event.
SELECT DISTINCT ON(action_id) action_id,new_status,happened_at FROM tourism_demo.action_events ORDER BY action_id,happened_at DESC,event_id DESC;
-- 14 Closed actions missing close timestamp.
SELECT action_ref FROM tourism_demo.actions WHERE status='closed' AND closed_at IS NULL;
-- 15 Follow-up inspections without action.
SELECT inspection_ref FROM tourism_demo.inspections i WHERE outcome='follow_up_required' AND NOT EXISTS(SELECT 1 FROM tourism_demo.actions a WHERE a.inspection_id=i.inspection_id);
-- 16 Inspection counts by UTC month.
SELECT date_trunc('month',inspected_at AT TIME ZONE 'UTC') AS month_utc,COUNT(*) FROM tourism_demo.inspections GROUP BY 1 ORDER BY 1;
-- 17 Upcoming permit expiry within 30 days.
SELECT permit_ref,expires_on FROM tourism_demo.v_permit_register WHERE status='active' AND expires_on>=CURRENT_DATE AND expires_on<CURRENT_DATE+30;
-- 18 Open actions by owner.
SELECT owner_ref,COUNT(*) FROM tourism_demo.actions WHERE status NOT IN('closed','cancelled') GROUP BY owner_ref;
-- 19 Action due-date gaps.
SELECT action_ref FROM tourism_demo.actions WHERE due_date IS NULL AND status NOT IN('closed','cancelled');
-- 20 Historic expired permit with open action.
SELECT DISTINCT p.permit_ref FROM tourism_demo.permits p JOIN tourism_demo.inspections i USING(establishment_id) JOIN tourism_demo.actions a USING(inspection_id) WHERE p.status='expired' AND a.status NOT IN('closed','cancelled');