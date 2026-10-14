-- 20 read-only reports over synthetic data; member identifiers are pseudonymous.
-- 01 delivery and weight summary.
SELECT * FROM coop_demo.v_delivery_summary ORDER BY cooperative_code,delivery_date;
-- 02 approved outstanding payables.
SELECT * FROM coop_demo.v_delivery_payables WHERE outstanding_ugx>0 ORDER BY cooperative_code,delivery_ref;
-- 03 paid/unpaid/partial counts.
SELECT settlement_status,COUNT(*) FROM coop_demo.v_delivery_payables GROUP BY settlement_status;
-- 04 accepted and rejected weights by produce.
SELECT produce_code,SUM(accepted_kg) accepted_kg,SUM(rejected_kg) rejected_kg FROM coop_demo.v_delivery_summary GROUP BY produce_code;
-- 05 delivery counts by state.
SELECT status,COUNT(*) FROM coop_demo.deliveries GROUP BY status;
-- 06 gross weight by cooperative.
SELECT cooperative_code,SUM(gross_kg) gross_kg FROM coop_demo.v_delivery_summary GROUP BY cooperative_code;
-- 07 rejection proportion by produce.
SELECT produce_code,SUM(rejected_kg)/NULLIF(SUM(gross_kg),0) AS rejected_ratio FROM coop_demo.v_delivery_summary GROUP BY produce_code;
-- 08 delivery status event history.
SELECT d.delivery_ref,e.previous_status,e.new_status,e.actor_ref,e.happened_at,e.grade_ref FROM coop_demo.delivery_events e JOIN coop_demo.deliveries d USING(delivery_id) ORDER BY d.delivery_ref,e.happened_at,e.event_id;
-- 08b registered payment events.
SELECT d.delivery_ref,p.payment_ref,p.paid_at,p.amount_ugx,p.channel FROM coop_demo.payments p JOIN coop_demo.deliveries d USING(delivery_id) ORDER BY d.delivery_ref,p.paid_at;
-- 09 deliveries waiting for approval.
SELECT delivery_ref,cooperative_code,accepted_kg,status FROM coop_demo.v_delivery_summary WHERE status='quality_checked';
-- 10 deliveries with a nonzero rejected weight.
SELECT delivery_ref,rejected_kg,grade_ref FROM coop_demo.v_delivery_summary WHERE rejected_kg>0;
-- 11 monthly delivery volume.
SELECT date_trunc('month',delivery_date)::date delivery_month,COUNT(*) FROM coop_demo.deliveries GROUP BY 1 ORDER BY 1;
-- 12 weighted average price per kg by produce.
SELECT produce_code,SUM(accepted_kg*price_per_kg_ugx)/NULLIF(SUM(accepted_kg),0) weighted_price_ugx FROM coop_demo.v_delivery_summary GROUP BY produce_code;
-- 13 members with no deliveries.
SELECT member_ref FROM coop_demo.members m WHERE NOT EXISTS(SELECT 1 FROM coop_demo.deliveries d WHERE d.member_id=m.member_id);
-- 14 cumulative payment per delivery.
SELECT delivery_ref,paid_ugx,payable_ugx FROM coop_demo.v_delivery_payables ORDER BY paid_ugx DESC;
-- 15 outstanding payables by cooperative.
SELECT cooperative_code,SUM(outstanding_ugx) outstanding_ugx FROM coop_demo.v_delivery_payables GROUP BY cooperative_code;
-- 16 deliveries whose gross weight does not reconcile to accepted + rejected (should be empty).
SELECT delivery_ref FROM coop_demo.deliveries WHERE gross_kg<>accepted_kg+rejected_kg;
-- 17 payment idempotency collisions (should be empty).
SELECT idempotency_key,COUNT(*) FROM coop_demo.payments GROUP BY idempotency_key HAVING COUNT(*)>1;
-- 18 deliveries by locality/produce.
SELECT locality_code,produce_code,COUNT(*) FROM coop_demo.v_delivery_summary GROUP BY locality_code,produce_code;
-- 19 payables ranked by amount.
SELECT delivery_ref,payable_ugx,DENSE_RANK() OVER(ORDER BY payable_ugx DESC) payable_rank FROM coop_demo.v_delivery_payables;
-- 20 delivery with no grade reference (should be empty).
SELECT delivery_ref FROM coop_demo.deliveries WHERE grade_ref IS NULL;