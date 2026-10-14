-- 20 read-only PostgreSQL 15+ reporting patterns; all fixtures are synthetic.
-- 01. Latest condition by road.
SELECT * FROM works_demo.v_latest_road_condition ORDER BY locality_code,road_code;
-- 02. Open work queue.
SELECT * FROM works_demo.v_open_work_orders ORDER BY priority DESC,due_date NULLS LAST;
-- 03. Overdue work.
SELECT * FROM works_demo.v_overdue_work_orders ORDER BY due_date,priority DESC;
-- 04. Backlog cost estimate by locality.
SELECT locality_code,SUM(estimated_cost_ugx) AS estimated_backlog_ugx FROM works_demo.v_open_work_orders GROUP BY locality_code;
-- 05. Orders by workflow status.
SELECT status,COUNT(*) FROM works_demo.work_orders WHERE is_deleted=FALSE GROUP BY status ORDER BY status;
-- 06. Critical observations without any open work order.
SELECT c.road_code,c.condition_rating FROM works_demo.v_latest_road_condition c
WHERE c.condition_rating='critical' AND NOT EXISTS(SELECT 1 FROM works_demo.work_orders w JOIN works_demo.road_assets r USING(road_id) WHERE r.road_code=c.road_code AND w.status NOT IN('completed','cancelled') AND w.is_deleted=FALSE);
-- 07. Inspection history.
SELECT r.road_code,i.observed_at,i.condition_rating,i.safety_priority,i.observation_note FROM works_demo.road_inspections i JOIN works_demo.road_assets r USING(road_id) ORDER BY r.road_code,i.observed_at;
-- 08. Work-order event history.
SELECT w.work_order_ref,e.previous_status,e.new_status,e.actor_ref,e.happened_at FROM works_demo.work_order_events e JOIN works_demo.work_orders w USING(work_order_id) ORDER BY w.work_order_ref,e.happened_at;
-- 09. Latest event per work order.
SELECT DISTINCT ON(work_order_id) work_order_id,new_status,happened_at FROM works_demo.work_order_events ORDER BY work_order_id,happened_at DESC,event_id DESC;
-- 10. Roads never inspected.
SELECT r.road_code FROM works_demo.road_assets r WHERE NOT EXISTS(SELECT 1 FROM works_demo.road_inspections i WHERE i.road_id=r.road_id);
-- 11. Average estimate by road class.
SELECT r.road_class,AVG(w.estimated_cost_ugx) AS average_estimate_ugx FROM works_demo.work_orders w JOIN works_demo.road_assets r USING(road_id) GROUP BY r.road_class;
-- 12. Estimate versus actual cost gap.
SELECT work_order_ref,estimated_cost_ugx,actual_cost_ugx,actual_cost_ugx-estimated_cost_ugx AS variance_ugx FROM works_demo.work_orders WHERE actual_cost_ugx IS NOT NULL;
-- 13. Work rank by urgency.
SELECT work_order_ref,priority,due_date,ROW_NUMBER() OVER(ORDER BY priority DESC,due_date NULLS LAST) AS urgency_rank FROM works_demo.v_open_work_orders;
-- 14. Length under inspection by condition.
SELECT condition_rating,SUM(length_metres) AS road_length_metres FROM works_demo.v_latest_road_condition c JOIN works_demo.road_assets r USING(road_code) GROUP BY condition_rating;
-- 15. Open work with no linked inspection.
SELECT work_order_ref FROM works_demo.work_orders WHERE inspection_id IS NULL AND status NOT IN('completed','cancelled');
-- 16. Due in next 30 days.
SELECT work_order_ref,due_date FROM works_demo.v_open_work_orders WHERE due_date>=CURRENT_DATE AND due_date<CURRENT_DATE+30 ORDER BY due_date;
-- 17. Work created by UTC month.
SELECT date_trunc('month',created_at AT TIME ZONE 'UTC') AS utc_month,COUNT(*) FROM works_demo.work_orders GROUP BY 1 ORDER BY 1;
-- 18. Inspection count by inspector reference.
SELECT inspector_ref,COUNT(*) FROM works_demo.road_inspections GROUP BY inspector_ref ORDER BY 2 DESC;
-- 19. Roads grouped by locality and class.
SELECT locality_code,road_class,COUNT(*) FROM works_demo.road_assets GROUP BY locality_code,road_class ORDER BY 1,2;
-- 20. Data quality scan: completed orders must have completion timestamps.
SELECT work_order_ref FROM works_demo.work_orders WHERE status='completed' AND completed_at IS NULL;