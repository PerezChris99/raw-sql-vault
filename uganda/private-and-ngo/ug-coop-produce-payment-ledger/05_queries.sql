-- Purpose: reporting examples for cooperative deliveries and settlements.
-- Engine: PostgreSQL 15+. Prerequisites: schema, seed and views.
-- Use bound parameters in applications; synthetic references below are illustrative.

-- 01. Delivery valuation and current settlement balance.
SELECT delivery_ref,member_ref,produce_code,grade_code,accepted_weight_kg,rate_per_kg,
       gross_value,approved_deductions,net_value,allocated_amount,remaining_balance
FROM ug_coop_pay.v_delivery_settlement ORDER BY received_at,delivery_ref;

-- 02. Member statement summary.
SELECT member_code,net_produce_value,amount_allocated,remaining_balance
FROM ug_coop_pay.v_member_settlement_summary ORDER BY member_code;

-- 03. Deliveries without a current matching approved rate.
SELECT d.delivery_ref,d.produce_type_id,d.grade_code,d.received_at
FROM ug_coop_pay.deliveries d
LEFT JOIN ug_coop_pay.v_delivery_valuation v USING(delivery_id)
WHERE v.rate_per_kg IS NULL ORDER BY d.received_at;

-- 04. Unapproved deductions requiring review.
SELECT d.delivery_ref,x.deduction_code,x.amount,x.reason,x.source_reference,x.recorded_by
FROM ug_coop_pay.deductions x JOIN ug_coop_pay.deliveries d USING(delivery_id)
WHERE x.approved_by IS NULL ORDER BY x.recorded_at;

-- 05. Payments with remaining unallocated value.
SELECT p.payment_ref,p.member_ref,p.amount,
       p.amount-COALESCE(SUM(a.amount),0) AS unallocated_amount,p.paid_at
FROM ug_coop_pay.payments p
LEFT JOIN ug_coop_pay.payment_allocations a USING(payment_id)
GROUP BY p.payment_id,p.payment_ref,p.member_ref,p.amount,p.paid_at
HAVING p.amount>COALESCE(SUM(a.amount),0)
ORDER BY p.paid_at,p.payment_ref;

-- 06. Deliveries where allocated amount exceeds current net valuation (should return zero).
SELECT delivery_ref,allocated_amount,net_value
FROM ug_coop_pay.v_delivery_settlement WHERE allocated_amount>net_value;

-- 07. Duplicate source ticket identifiers (unique constraint should prevent these).
SELECT source_ticket_ref,COUNT(*) FROM ug_coop_pay.deliveries
GROUP BY source_ticket_ref HAVING COUNT(*)>1;

-- 08. Volume and accepted-weight rate by produce and month.
SELECT produce_code,date_trunc('month',received_at)::date AS month,
       COUNT(*) AS deliveries,SUM(gross_weight_kg) AS gross_kg,SUM(accepted_weight_kg) AS accepted_kg
FROM ug_coop_pay.v_delivery_valuation GROUP BY produce_code,date_trunc('month',received_at)::date
ORDER BY month,produce_code;

-- 09. Approved deductions by code for audit review.
SELECT deduction_code,COUNT(*) AS entries,SUM(amount) AS amount
FROM ug_coop_pay.deductions WHERE approved_by IS NOT NULL
GROUP BY deduction_code ORDER BY amount DESC;

-- 10. Delivery history by reference.
SELECT e.recorded_at,e.event_type,e.reason,e.source_reference,e.recorded_by
FROM ug_coop_pay.delivery_events e JOIN ug_coop_pay.deliveries d USING(delivery_id)
WHERE d.delivery_ref='UGD-DEMO-0001' ORDER BY e.recorded_at,e.event_id;
