-- Purpose: record returns without allowing returned quantity to exceed original sale quantity.
-- Engine: PostgreSQL 15+. Prerequisite: 01_schema.sql. Rerunnable.
CREATE OR REPLACE FUNCTION ug_sales_analytics.fn_record_return(
 p_return_ref TEXT,p_idempotency_key TEXT,p_sale_ref TEXT,p_line_no INTEGER,p_quantity NUMERIC,
 p_refund_amount NUMERIC,p_reason TEXT,p_source_ref TEXT,p_actor_ref TEXT
) RETURNS BIGINT LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ug_sales_analytics AS $$
DECLARE l ug_sales_analytics.sale_lines%ROWTYPE; s ug_sales_analytics.sales%ROWTYPE; v_returned NUMERIC(14,3); v_id BIGINT;
BEGIN
 IF p_quantity IS NULL OR p_quantity<=0 OR p_refund_amount IS NULL OR p_refund_amount<0
 OR length(btrim(COALESCE(p_reason,'')))=0 OR length(btrim(COALESCE(p_source_ref,'')))=0
 OR length(btrim(COALESCE(p_actor_ref,'')))=0 THEN
  RAISE EXCEPTION 'Positive return quantity, non-negative refund, reason, source and actor are required' USING ERRCODE='invalid_parameter_value';
 END IF;
 SELECT * INTO s FROM ug_sales_analytics.sales WHERE sale_ref=p_sale_ref FOR UPDATE;
 IF NOT FOUND OR s.status<>'completed' THEN RAISE EXCEPTION 'Completed sale not found' USING ERRCODE='no_data_found'; END IF;
 SELECT * INTO l FROM ug_sales_analytics.sale_lines WHERE sale_id=s.sale_id AND line_no=p_line_no FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Sale line not found' USING ERRCODE='no_data_found'; END IF;
 SELECT COALESCE(SUM(quantity),0) INTO v_returned FROM ug_sales_analytics.returns WHERE sale_line_id=l.sale_line_id;
 IF v_returned+p_quantity>l.quantity THEN RAISE EXCEPTION 'Return exceeds original quantity' USING ERRCODE='check_violation'; END IF;
 IF p_refund_amount>p_quantity*l.unit_price THEN RAISE EXCEPTION 'Refund exceeds original line value' USING ERRCODE='check_violation'; END IF;
 INSERT INTO ug_sales_analytics.returns(return_ref,idempotency_key,sale_line_id,quantity,refund_amount,reason,source_ref,recorded_by_ref)
 VALUES(p_return_ref,p_idempotency_key,l.sale_line_id,p_quantity,p_refund_amount,p_reason,p_source_ref,p_actor_ref)
 RETURNING return_id INTO v_id;
 RETURN v_id;
END; $$;
