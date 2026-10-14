-- Purpose: reservation calendar, stock on hand, reorder and order value summaries.
-- Engine: PostgreSQL 15+. Prerequisite: 01_schema.sql. Rerunnable.
CREATE OR REPLACE VIEW ug_hospitality.v_reservation_calendar AS
SELECT p.property_ref,r.resource_ref,r.resource_type,b.reservation_ref,b.customer_token,b.starts_at,b.ends_at,b.party_size,b.status
FROM ug_hospitality.reservations b JOIN ug_hospitality.resources r USING(resource_id)
JOIN ug_hospitality.properties p USING(property_id)
WHERE b.status IN ('requested','confirmed','checked_in');

CREATE OR REPLACE VIEW ug_hospitality.v_stock_on_hand AS
SELECT p.property_ref,i.item_ref,i.item_name,i.unit_code,i.reorder_level,
 COALESCE(SUM(m.quantity_delta),0)::NUMERIC(14,3) AS quantity_on_hand,
 COALESCE(SUM(m.quantity_delta),0)<=i.reorder_level AS reorder_required
FROM ug_hospitality.inventory_items i JOIN ug_hospitality.properties p USING(property_id)
LEFT JOIN ug_hospitality.stock_movements m USING(item_id)
GROUP BY p.property_ref,i.item_ref,i.item_name,i.unit_code,i.reorder_level;

CREATE OR REPLACE VIEW ug_hospitality.v_order_totals AS
SELECT o.order_ref,o.order_status,p.property_ref,COUNT(l.order_line_id) AS line_count,
 COALESCE(SUM(l.quantity*l.unit_price),0)::NUMERIC(16,2) AS order_total
FROM ug_hospitality.orders o JOIN ug_hospitality.properties p USING(property_id)
LEFT JOIN ug_hospitality.order_lines l USING(order_id)
GROUP BY o.order_id,o.order_ref,o.order_status,p.property_ref;
