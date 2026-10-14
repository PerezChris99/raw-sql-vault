-- Purpose: distribution oversight and stock reconciliation queries.
-- Engine: PostgreSQL 15+. Prerequisites: schema, seed and views.
-- 01. Stock on hand by store and textbook.
SELECT * FROM ug_textbooks.v_stock_on_hand ORDER BY warehouse_ref,textbook_code;
-- 02. Allocation delivery progress by school reference.
SELECT * FROM ug_textbooks.v_allocation_reconciliation ORDER BY academic_year,destination_school_ref,textbook_code;
-- 03. Dispatches with a quantity mismatch.
SELECT * FROM ug_textbooks.v_receipt_exceptions ORDER BY dispatch_ref;
-- 04. Negative balances (should return zero).
SELECT * FROM ug_textbooks.v_stock_on_hand WHERE quantity_on_hand<0;
-- 05. Approved allocations without a dispatch.
SELECT a.allocation_ref,a.destination_school_ref,a.allocated_quantity
FROM ug_textbooks.allocations a LEFT JOIN ug_textbooks.dispatches d USING(allocation_id)
WHERE a.status='approved' GROUP BY a.allocation_id,a.allocation_ref,a.destination_school_ref,a.allocated_quantity
HAVING COUNT(d.dispatch_id)=0;
-- 06. Stock adjustments requiring review.
SELECT movement_ref,warehouse_id,textbook_id,quantity_delta,source_ref,reason,recorded_by,occurred_at
FROM ug_textbooks.stock_movements WHERE movement_type IN ('write_off','correction') ORDER BY occurred_at DESC;
-- 07. Allocation quantities not yet reconciled.
SELECT * FROM ug_textbooks.v_allocation_reconciliation WHERE outstanding_quantity<>0 ORDER BY allocation_ref;
