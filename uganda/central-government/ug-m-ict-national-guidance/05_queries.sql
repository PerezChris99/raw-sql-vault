-- Twenty read-only ICT catalogue/workflow queries; never include secrets in these records.
-- 01 Service register.
SELECT * FROM ict_demo.v_service_register ORDER BY service_tier,service_code;
-- 02 Open work queue.
SELECT * FROM ict_demo.v_open_work_queue ORDER BY priority,due_at NULLS LAST;
-- 03 Overdue work.
SELECT * FROM ict_demo.v_overdue_work ORDER BY due_at;
-- 04 Service count by tier/state.
SELECT service_tier,status,COUNT(*) FROM ict_demo.services GROUP BY 1,2;
-- 05 Assets by environment/lifecycle.
SELECT * FROM ict_demo.v_asset_lifecycle ORDER BY 1,2,3;
-- 06 Services without assets.
SELECT service_code FROM ict_demo.services s WHERE NOT EXISTS(SELECT 1 FROM ict_demo.assets a WHERE a.service_id=s.service_id);
-- 07 Owners and number of services.
SELECT o.owner_code,COUNT(s.service_id) FROM ict_demo.service_owners o LEFT JOIN ict_demo.services s USING(owner_id) GROUP BY o.owner_code;
-- 08 Work items by type and status.
SELECT item_type,status,COUNT(*) FROM ict_demo.work_items GROUP BY 1,2;
-- 09 High priority open work.
SELECT item_ref,service_code,priority,due_at FROM ict_demo.v_open_work_queue WHERE priority<=2 ORDER BY priority,due_at;
-- 10 Work events.
SELECT w.item_ref,e.previous_status,e.new_status,e.actor_ref,e.happened_at FROM ict_demo.work_events e JOIN ict_demo.work_items w USING(item_id) ORDER BY 1,5;
-- 11 Latest event per work item.
SELECT DISTINCT ON(item_id) item_id,new_status,happened_at FROM ict_demo.work_events ORDER BY item_id,happened_at DESC,event_id DESC;
-- 12 Unresolved incidents by service.
SELECT service_code,COUNT(*) FROM ict_demo.v_open_work_queue WHERE item_type='incident' GROUP BY service_code;
-- 13 Assets nearing retirement.
SELECT asset_ref,retire_on FROM ict_demo.assets WHERE retire_on<CURRENT_DATE+INTERVAL '180 days' AND lifecycle<>'retired';
-- 14 Planned/degraded services.
SELECT service_code,status FROM ict_demo.services WHERE status IN('planned','degraded');
-- 15 Work age in hours.
SELECT item_ref,ROUND(EXTRACT(EPOCH FROM(now()-opened_at))/3600,1) AS age_hours FROM ict_demo.v_open_work_queue;
-- 16 Work due over next week.
SELECT item_ref,due_at FROM ict_demo.v_open_work_queue WHERE due_at>=now() AND due_at<now()+INTERVAL '7 days';
-- 17 Critical/high services with no owner (FK should prevent this).
SELECT service_code FROM ict_demo.services WHERE owner_id IS NULL;
-- 18 Work volume by UTC month.
SELECT date_trunc('month',opened_at AT TIME ZONE 'UTC') AS month_utc,COUNT(*) FROM ict_demo.work_items GROUP BY 1 ORDER BY 1;
-- 19 Assets by service and sensitivity.
SELECT s.service_code,a.sensitivity,COUNT(*) FROM ict_demo.assets a JOIN ict_demo.services s USING(service_id) GROUP BY 1,2;
-- 20 Resolved items without timestamp (should be empty).
SELECT item_ref FROM ict_demo.work_items WHERE status='resolved' AND resolved_at IS NULL;