CREATE OR REPLACE VIEW works_demo.v_latest_road_condition AS
SELECT DISTINCT ON(r.road_id) r.road_code,r.road_name,r.locality_code,r.road_class,
 i.condition_rating,i.safety_priority,i.observed_at,i.inspector_ref
FROM works_demo.road_assets r LEFT JOIN works_demo.road_inspections i USING(road_id)
WHERE r.is_active=TRUE ORDER BY r.road_id,i.observed_at DESC NULLS LAST,i.inspection_id DESC;
CREATE OR REPLACE VIEW works_demo.v_open_work_orders AS
SELECT w.work_order_ref,r.road_code,r.road_name,r.locality_code,w.summary,w.status,w.priority,
 w.estimated_cost_ugx,w.actual_cost_ugx,w.due_date,w.created_at
FROM works_demo.work_orders w JOIN works_demo.road_assets r USING(road_id)
WHERE w.is_deleted=FALSE AND w.status NOT IN('completed','cancelled');
CREATE OR REPLACE VIEW works_demo.v_overdue_work_orders AS
SELECT * FROM works_demo.v_open_work_orders WHERE due_date<CURRENT_DATE;
COMMENT ON VIEW works_demo.v_latest_road_condition IS 'Latest synthetic inspection observation by road; not a certified condition survey.';