-- Purpose: hospitality occupancy calendar and stock/order oversight.
-- Engine: PostgreSQL 15+. Prerequisites: schema, seed and views.
-- 01. Current/upcoming reservations.
SELECT * FROM ug_hospitality.v_reservation_calendar ORDER BY property_ref,resource_ref,starts_at;
-- 02. Items at or below reorder level.
SELECT * FROM ug_hospitality.v_stock_on_hand WHERE reorder_required ORDER BY property_ref,item_ref;
-- 03. Order totals.
SELECT * FROM ug_hospitality.v_order_totals ORDER BY property_ref,order_ref;
-- 04. Overlapping active reservations (should return zero).
SELECT a.reservation_ref,b.reservation_ref,a.resource_id
FROM ug_hospitality.reservations a JOIN ug_hospitality.reservations b
 ON a.resource_id=b.resource_id AND a.reservation_id<b.reservation_id
 AND a.starts_at<b.ends_at AND a.ends_at>b.starts_at
WHERE a.status IN ('requested','confirmed','checked_in') AND b.status IN ('requested','confirmed','checked_in');
-- 05. Negative stock balances (should return zero).
SELECT * FROM ug_hospitality.v_stock_on_hand WHERE quantity_on_hand<0;
