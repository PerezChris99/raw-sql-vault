CREATE OR REPLACE VIEW education_demo.v_allocation_status AS
SELECT a.allocation_ref,s.school_code,s.school_name,s.locality_code,c.asset_code,c.asset_name,c.category,
 a.planned_quantity,a.dispatched_quantity,a.received_quantity,
 a.planned_quantity-a.dispatched_quantity AS not_dispatched_quantity,
 a.dispatched_quantity-a.received_quantity AS not_received_quantity,
 a.status,a.planned_dispatch_date,a.dispatch_reference,a.receipt_reference
FROM education_demo.allocations a JOIN education_demo.schools s USING(school_id)
JOIN education_demo.asset_catalog c USING(asset_id) WHERE a.is_deleted=FALSE;
CREATE OR REPLACE VIEW education_demo.v_allocation_exceptions AS
SELECT * FROM education_demo.v_allocation_status
WHERE status='disputed' OR (planned_dispatch_date<CURRENT_DATE AND status NOT IN('received','cancelled'));
COMMENT ON VIEW education_demo.v_allocation_exceptions IS 'Operational follow-up queue; variance alone is not evidence of misconduct.';