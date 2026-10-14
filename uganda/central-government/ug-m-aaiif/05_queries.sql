-- Twenty read-only examples over synthetic references.
-- 01 Delivery fulfilment.
SELECT * FROM agriculture_demo.v_delivery_fulfilment ORDER BY area_code,farm_token,input_type;
-- 02 Delivery exceptions.
SELECT * FROM agriculture_demo.v_delivery_exceptions ORDER BY delivery_ref;
-- 03 Extension follow-ups.
SELECT * FROM agriculture_demo.v_extension_followups ORDER BY follow_up_due;
-- 04 Visits by crop/outcome.
SELECT f.primary_crop,v.outcome,COUNT(*) FROM agriculture_demo.extension_visits v JOIN agriculture_demo.farm_refs f USING(farm_id) GROUP BY f.primary_crop,v.outcome;
-- 05 Deliveries by input and state.
SELECT input_type,status,COUNT(*) FROM agriculture_demo.input_deliveries GROUP BY 1,2 ORDER BY 1,2;
-- 06 Farms without visits.
SELECT farm_token FROM agriculture_demo.farm_refs f WHERE NOT EXISTS(SELECT 1 FROM agriculture_demo.extension_visits v WHERE v.farm_id=f.farm_id);
-- 07 Inactive areas with active farm references.
SELECT area_code FROM agriculture_demo.service_areas a WHERE NOT a.is_active AND EXISTS(SELECT 1 FROM agriculture_demo.farm_refs f WHERE f.area_id=a.area_id AND f.is_active);
-- 08 Visit history.
SELECT f.farm_token,v.visit_at,v.topic,v.outcome,v.officer_ref FROM agriculture_demo.extension_visits v JOIN agriculture_demo.farm_refs f USING(farm_id) ORDER BY 1,2;
-- 09 Past-due follow-ups.
SELECT * FROM agriculture_demo.v_extension_followups WHERE follow_up_due<CURRENT_DATE;
-- 10 Delivery state history.
SELECT d.delivery_ref,e.previous_status,e.new_status,e.actor_ref,e.happened_at FROM agriculture_demo.delivery_events e JOIN agriculture_demo.input_deliveries d USING(delivery_id) ORDER BY 1,5;
-- 11 Latest event per delivery.
SELECT DISTINCT ON(delivery_id) delivery_id,new_status,happened_at FROM agriculture_demo.delivery_events ORDER BY delivery_id,happened_at DESC,event_id DESC;
-- 12 Planned deliveries.
SELECT delivery_ref,planned_qty,unit_code FROM agriculture_demo.input_deliveries WHERE status='planned' ORDER BY created_at;
-- 13 Quantity received by area/type.
SELECT area_code,input_type,SUM(received_qty) received FROM agriculture_demo.v_delivery_fulfilment GROUP BY area_code,input_type;
-- 14 Dispatch versus receipt difference.
SELECT delivery_ref,dispatched_qty-received_qty AS difference,unit_code FROM agriculture_demo.v_delivery_fulfilment WHERE dispatched_qty>received_qty;
-- 15 Visit volume by UTC month.
SELECT date_trunc('month',visit_at AT TIME ZONE 'UTC') AS month_utc,topic,COUNT(*) FROM agriculture_demo.extension_visits GROUP BY 1,2 ORDER BY 1,2;
-- 16 Visit volume by service area.
SELECT a.area_code,COUNT(*) visits FROM agriculture_demo.extension_visits v JOIN agriculture_demo.farm_refs f USING(farm_id) JOIN agriculture_demo.service_areas a USING(area_id) GROUP BY a.area_code;
-- 17 Received deliveries without receipt reference.
SELECT delivery_ref FROM agriculture_demo.input_deliveries WHERE status='received' AND receipt_ref IS NULL;
-- 18 Follow-ups by officer reference.
SELECT officer_ref,COUNT(*) FROM agriculture_demo.extension_visits WHERE outcome='follow_up' GROUP BY officer_ref;
-- 19 Deliveries with no visit context.
SELECT d.delivery_ref FROM agriculture_demo.input_deliveries d WHERE NOT EXISTS(SELECT 1 FROM agriculture_demo.extension_visits v WHERE v.farm_id=d.farm_id);
-- 20 Received versus planned by area.
SELECT area_code,ROUND(100*SUM(received_qty)/NULLIF(SUM(planned_qty),0),2) received_vs_planned_pct FROM agriculture_demo.v_delivery_fulfilment GROUP BY area_code;