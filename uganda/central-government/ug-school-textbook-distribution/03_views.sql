-- Purpose: stock on hand, allocation delivery reconciliation and shortages.
-- Engine: PostgreSQL 15+. Prerequisite: 01_schema.sql. Rerunnable.
CREATE OR REPLACE VIEW ug_textbooks.v_stock_on_hand AS
SELECT w.warehouse_ref,w.warehouse_name,t.textbook_code,t.title,
       COALESCE(SUM(m.quantity_delta),0)::BIGINT AS quantity_on_hand
FROM ug_textbooks.warehouses w CROSS JOIN ug_textbooks.textbooks t
LEFT JOIN ug_textbooks.stock_movements m ON m.warehouse_id=w.warehouse_id AND m.textbook_id=t.textbook_id
GROUP BY w.warehouse_id,w.warehouse_ref,w.warehouse_name,t.textbook_id,t.textbook_code,t.title;

CREATE OR REPLACE VIEW ug_textbooks.v_allocation_reconciliation AS
SELECT a.allocation_ref,a.destination_school_ref,a.academic_year,t.textbook_code,a.allocated_quantity,
       COALESCE(SUM(r.quantity_received),0)::BIGINT AS received_quantity,
       a.allocated_quantity-COALESCE(SUM(r.quantity_received),0) AS outstanding_quantity,
       COUNT(DISTINCT d.dispatch_id) AS dispatch_count
FROM ug_textbooks.allocations a JOIN ug_textbooks.textbooks t USING(textbook_id)
LEFT JOIN ug_textbooks.dispatches d USING(allocation_id)
LEFT JOIN ug_textbooks.receipts r USING(dispatch_id)
GROUP BY a.allocation_id,a.allocation_ref,a.destination_school_ref,a.academic_year,t.textbook_code,a.allocated_quantity;

CREATE OR REPLACE VIEW ug_textbooks.v_receipt_exceptions AS
SELECT d.dispatch_ref,a.allocation_ref,a.destination_school_ref,t.textbook_code,d.quantity,
       COALESCE(SUM(r.quantity_received),0)::BIGINT AS received_quantity,
       d.quantity-COALESCE(SUM(r.quantity_received),0) AS unresolved_quantity
FROM ug_textbooks.dispatches d JOIN ug_textbooks.allocations a USING(allocation_id)
JOIN ug_textbooks.textbooks t USING(textbook_id)
LEFT JOIN ug_textbooks.receipts r USING(dispatch_id)
GROUP BY d.dispatch_id,d.dispatch_ref,a.allocation_ref,a.destination_school_ref,t.textbook_code,d.quantity
HAVING COALESCE(SUM(r.quantity_received),0)<>d.quantity;
