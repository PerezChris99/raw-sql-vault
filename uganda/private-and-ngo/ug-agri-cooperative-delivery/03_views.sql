CREATE OR REPLACE VIEW coop_demo.v_delivery_summary AS
SELECT d.delivery_ref,c.cooperative_code,c.locality_code,m.member_ref,p.produce_code,p.produce_label,
 d.delivery_date,d.gross_kg,d.accepted_kg,d.rejected_kg,d.price_per_kg_ugx,d.payable_ugx,d.status,d.grade_ref
FROM coop_demo.deliveries d JOIN coop_demo.members m USING(member_id)
JOIN coop_demo.cooperatives c USING(cooperative_id) JOIN coop_demo.produce_catalog p USING(produce_id);
CREATE OR REPLACE VIEW coop_demo.v_delivery_payables AS
SELECT d.delivery_ref,c.cooperative_code,m.member_ref,p.produce_code,d.status,d.payable_ugx,
 COALESCE(pay.paid_ugx,0)::NUMERIC(20,2) AS paid_ugx,
 d.payable_ugx-COALESCE(pay.paid_ugx,0) AS outstanding_ugx,
 CASE WHEN d.status<>'approved' THEN 'not_approved' WHEN COALESCE(pay.paid_ugx,0)=0 THEN 'unpaid'
 WHEN COALESCE(pay.paid_ugx,0)<d.payable_ugx THEN 'part_paid' ELSE 'settled' END AS settlement_status
FROM coop_demo.deliveries d JOIN coop_demo.members m USING(member_id)
JOIN coop_demo.cooperatives c USING(cooperative_id) JOIN coop_demo.produce_catalog p USING(produce_id)
LEFT JOIN(SELECT delivery_id,SUM(amount_ugx) paid_ugx FROM coop_demo.payments GROUP BY delivery_id) pay USING(delivery_id);
COMMENT ON VIEW coop_demo.v_delivery_payables IS 'Derived payables view; reconciliation to payment-provider statements remains mandatory.';