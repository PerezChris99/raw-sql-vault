-- 20 read-only allocation reports. No student-level data is included.
-- 01 allocation balance and fulfillment.
SELECT * FROM education_demo.v_allocation_status ORDER BY locality_code,school_code,asset_code;
-- 02 allocation exceptions.
SELECT * FROM education_demo.v_allocation_exceptions ORDER BY planned_dispatch_date;
-- 03 dispatched quantity by school/category.
SELECT school_code,category,SUM(dispatched_quantity) AS dispatched FROM education_demo.v_allocation_status GROUP BY school_code,category;
-- 04 received quantity by locality.
SELECT locality_code,category,SUM(received_quantity) AS received FROM education_demo.v_allocation_status GROUP BY locality_code,category;
-- 05 open allocation counts by status.
SELECT status,COUNT(*) FROM education_demo.v_allocation_status GROUP BY status ORDER BY status;
-- 06 schools with no allocations.
SELECT s.school_code FROM education_demo.schools s WHERE NOT EXISTS(SELECT 1 FROM education_demo.allocations a WHERE a.school_id=s.school_id AND a.is_deleted=FALSE);
-- 07 active schools by level.
SELECT school_level,COUNT(*) FROM education_demo.schools WHERE is_active GROUP BY school_level;
-- 08 allocation workflow history.
SELECT a.allocation_ref,e.previous_status,e.new_status,e.actor_ref,e.happened_at FROM education_demo.allocation_events e JOIN education_demo.allocations a USING(allocation_id) ORDER BY a.allocation_ref,e.happened_at;
-- 09 latest event per allocation.
SELECT DISTINCT ON(allocation_id) allocation_id,new_status,happened_at FROM education_demo.allocation_events ORDER BY allocation_id,happened_at DESC,event_id DESC;
-- 10 items never allocated.
SELECT c.asset_code FROM education_demo.asset_catalog c WHERE NOT EXISTS(SELECT 1 FROM education_demo.allocations a WHERE a.asset_id=c.asset_id AND a.is_deleted=FALSE);
-- 11 planned allocations with no dispatch reference.
SELECT allocation_ref FROM education_demo.allocations WHERE status='planned' AND dispatch_reference IS NULL AND is_deleted=FALSE;
-- 12 disputed allocations.
SELECT allocation_ref,planned_quantity,dispatched_quantity,received_quantity FROM education_demo.v_allocation_status WHERE status='disputed';
-- 13 short receipt quantities.
SELECT allocation_ref,dispatched_quantity-received_quantity AS difference FROM education_demo.v_allocation_status WHERE status IN('received','disputed') AND dispatched_quantity>received_quantity;
-- 14 pending dispatches in next 30 days.
SELECT allocation_ref,planned_dispatch_date FROM education_demo.v_allocation_status WHERE status='planned' AND planned_dispatch_date>=CURRENT_DATE AND planned_dispatch_date<CURRENT_DATE+30;
-- 15 category fulfillment ratio (aggregate only).
SELECT category,SUM(received_quantity)::numeric/NULLIF(SUM(planned_quantity),0) AS received_to_planned_ratio FROM education_demo.v_allocation_status GROUP BY category;
-- 16 asset allocations ranked by planned quantity.
SELECT allocation_ref,planned_quantity,DENSE_RANK() OVER(ORDER BY planned_quantity DESC) AS quantity_rank FROM education_demo.v_allocation_status;
-- 17 allocations by dispatch month.
SELECT date_trunc('month',created_at AT TIME ZONE 'UTC') AS created_month,COUNT(*) FROM education_demo.allocations GROUP BY 1 ORDER BY 1;
-- 18 missing receipt reference on received allocation (data quality).
SELECT allocation_ref FROM education_demo.allocations WHERE status='received' AND receipt_reference IS NULL;
-- 19 categories by locality.
SELECT locality_code,category,COUNT(*) FROM education_demo.v_allocation_status GROUP BY locality_code,category;
-- 20 over-dispatch guard check (should be empty due to constraints).
SELECT allocation_ref FROM education_demo.allocations WHERE dispatched_quantity>planned_quantity OR received_quantity>dispatched_quantity;