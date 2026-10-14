-- Purpose: allocate a recorded payment safely to a delivery.
-- Engine: PostgreSQL 15+. Prerequisite: 01_schema.sql and 03_views.sql. Rerunnable.
CREATE OR REPLACE FUNCTION ug_coop_pay.fn_allocate_payment(
    p_payment_ref TEXT,p_delivery_ref TEXT,p_amount NUMERIC,p_actor TEXT,p_allocation_reference TEXT
) RETURNS BIGINT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path=pg_catalog,ug_coop_pay
AS $$
DECLARE v_payment ug_coop_pay.payments%ROWTYPE; v_delivery ug_coop_pay.deliveries%ROWTYPE;
        v_delivery_member TEXT; v_paid_allocated NUMERIC(14,2); v_delivery_allocated NUMERIC(14,2);
        v_net_value NUMERIC(14,2); v_id BIGINT;
BEGIN
 IF p_amount IS NULL OR p_amount<=0 OR length(btrim(COALESCE(p_actor,'')))=0
    OR length(btrim(COALESCE(p_allocation_reference,'')))=0 THEN
   RAISE EXCEPTION 'Positive amount, actor and allocation reference are required' USING ERRCODE='invalid_parameter_value';
 END IF;
 SELECT * INTO v_payment FROM ug_coop_pay.payments WHERE payment_ref=p_payment_ref FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Payment % not found',p_payment_ref USING ERRCODE='no_data_found'; END IF;
 SELECT * INTO v_delivery FROM ug_coop_pay.deliveries WHERE delivery_ref=p_delivery_ref FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Delivery % not found',p_delivery_ref USING ERRCODE='no_data_found'; END IF;
 IF v_payment.member_ref<>v_delivery.member_ref THEN
   RAISE EXCEPTION 'Payment and delivery belong to different members' USING ERRCODE='check_violation';
 END IF;
 SELECT COALESCE(SUM(amount),0) INTO v_paid_allocated FROM ug_coop_pay.payment_allocations WHERE payment_id=v_payment.payment_id;
 IF v_paid_allocated+p_amount>v_payment.amount THEN
   RAISE EXCEPTION 'Allocation exceeds unallocated payment balance' USING ERRCODE='check_violation';
 END IF;
 SELECT COALESCE(ROUND(v_delivery.accepted_weight_kg*r.rate_per_kg,2),0)
        - COALESCE((SELECT SUM(d.amount) FROM ug_coop_pay.deductions d WHERE d.delivery_id=v_delivery.delivery_id AND d.approved_by IS NOT NULL),0)
 INTO v_net_value
 FROM (SELECT 1) q
 LEFT JOIN LATERAL (
   SELECT rate_per_kg FROM ug_coop_pay.price_rates
   WHERE produce_type_id=v_delivery.produce_type_id AND grade_code=v_delivery.grade_code
     AND v_delivery.received_at::date>=valid_from AND (valid_to IS NULL OR v_delivery.received_at::date<=valid_to)
   ORDER BY valid_from DESC,price_rate_id DESC LIMIT 1
 ) r ON TRUE;
 v_net_value:=GREATEST(COALESCE(v_net_value,0),0);
 SELECT COALESCE(SUM(amount),0) INTO v_delivery_allocated
 FROM ug_coop_pay.payment_allocations WHERE delivery_id=v_delivery.delivery_id;
 IF v_delivery_allocated+p_amount>v_net_value THEN
   RAISE EXCEPTION 'Allocation exceeds delivery net value' USING ERRCODE='check_violation';
 END IF;
 INSERT INTO ug_coop_pay.payment_allocations(payment_id,delivery_id,amount,allocated_by,allocation_reference)
 VALUES(v_payment.payment_id,v_delivery.delivery_id,p_amount,p_actor,p_allocation_reference)
 RETURNING allocation_id INTO v_id;
 RETURN v_id;
END;
$$;
