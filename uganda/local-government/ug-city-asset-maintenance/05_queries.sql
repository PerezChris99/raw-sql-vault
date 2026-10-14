-- 20 read-only reporting examples.
-- 01 Latest asset condition.
SELECT * FROM city_ops_demo.v_latest_asset_condition ORDER BY area_code,asset_ref;
-- 02 Open work queue.
SELECT * FROM city_ops_demo.v_open_work_orders ORDER BY priority DESC,due_date NULLS LAST;
-- 03 Overdue work orders.
SELECT * FROM city_ops_demo.v_overdue_work_orders ORDER BY due_date;
-- 04 Backlog per area.
SELECT * FROM city_ops_demo.v_area_workload ORDER BY open_orders DESC;
-- 05 Work types by status.
SELECT work_type,status,COUNT(*) FROM city_ops_demo.work_orders GROUP BY 1,2;
-- 06 Assets without inspections.
SELECT asset_ref FROM city_ops_demo.assets a WHERE NOT EXISTS(SELECT 1 FROM city_ops_demo.inspections i WHERE i.asset_id=a.asset_id);
-- 07 Critical condition assets without open work.
SELECT v.asset_ref FROM city_ops_demo.v_latest_asset_condition v WHERE v.condition_state='critical' AND NOT EXISTS(SELECT 1 FROM city_ops_demo.work_orders w JOIN city_ops_demo.assets a USING(asset_id) WHERE a.asset_ref=v.asset_ref AND w.status NOT IN('completed','cancelled'));
-- 08 Inspection history.
SELECT a.asset_ref,i.inspected_at,i.condition_state,i.priority,i.summary FROM city_ops_demo.inspections i JOIN city_ops_demo.assets a USING(asset_id) ORDER BY 1,2;
-- 09 Work-event history.
SELECT w.work_ref,e.previous_status,e.new_status,e.actor_ref,e.happened_at FROM city_ops_demo.work_events e JOIN city_ops_demo.work_orders w USING(work_order_id) ORDER BY 1,5;
-- 10 Latest event per work order.
SELECT DISTINCT ON(work_order_id) work_order_id,new_status,happened_at FROM city_ops_demo.work_events ORDER BY work_order_id,happened_at DESC,event_id DESC;
-- 11 Cost estimates by work type.
SELECT work_type,SUM(estimated_cost_ugx) FROM city_ops_demo.work_orders WHERE status NOT IN('completed','cancelled') GROUP BY work_type;
-- 12 Work orders without due dates.
SELECT work_ref FROM city_ops_demo.work_orders WHERE due_date IS NULL AND status NOT IN('completed','cancelled');
-- 13 Due within next 14 days.
SELECT work_ref,due_date FROM city_ops_demo.v_open_work_orders WHERE due_date>=CURRENT_DATE AND due_date<CURRENT_DATE+14 ORDER BY due_date;
-- 14 Assets by type and area.
SELECT area_code,asset_type,COUNT(*) FROM city_ops_demo.assets WHERE is_active GROUP BY 1,2;
-- 15 Inspection priority mix.
SELECT priority,COUNT(*) FROM city_ops_demo.inspections GROUP BY priority ORDER BY priority;
-- 16 Average estimate by work type.
SELECT work_type,AVG(estimated_cost_ugx) FROM city_ops_demo.work_orders GROUP BY work_type;
-- 17 UTC inspection volume.
SELECT date_trunc('month',inspected_at AT TIME ZONE 'UTC') AS month_utc,COUNT(*) FROM city_ops_demo.inspections GROUP BY 1 ORDER BY 1;
-- 18 Completed orders missing timestamp.
SELECT work_ref FROM city_ops_demo.work_orders WHERE status='completed' AND completed_at IS NULL;
-- 19 Assets by latest condition.
SELECT condition_state,COUNT(*) FROM city_ops_demo.v_latest_asset_condition GROUP BY condition_state;
-- 20 Area-level work and average priority.
SELECT area_code,COUNT(*) AS work_count,AVG(priority) AS average_priority FROM city_ops_demo.v_open_work_orders GROUP BY area_code;