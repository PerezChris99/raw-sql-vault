CREATE OR REPLACE FUNCTION pos_demo.fn_record_return(p_ref TEXT,p_sale_line BIGINT,p_qty INTEGER,p_reason TEXT,p_approver TEXT)
RETURNS BIGINT LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pos_demo AS $$
DECLARE v_sold INTEGER;v_returned INTEGER;v_product BIGINT;v_id BIGINT;
BEGIN
 IF NULLIF(btrim(p_ref),'') IS NULL OR p_qty IS NULL OR p_qty<=0 OR NULLIF(btrim(p_approver),'') IS NULL THEN RAISE EXCEPTION 'return reference, positive quantity and approver required' USING ERRCODE='22023'; END IF;
 IF p_reason IS NULL OR p_reason NOT IN('damaged','wrong_item','customer_return','other') THEN RAISE EXCEPTION 'invalid return reason' USING ERRCODE='22023'; END IF;
 PERFORM 1 FROM pos_demo.sale_lines WHERE sale_line_id=p_sale_line FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'sale line not found' USING ERRCODE='P0002'; END IF;
 SELECT quantity,product_id INTO v_sold,v_product FROM pos_demo.sale_lines WHERE sale_line_id=p_sale_line;
 SELECT COALESCE(SUM(quantity),0) INTO v_returned FROM pos_demo.returns WHERE sale_line_id=p_sale_line;
 IF v_returned+p_qty>v_sold THEN RAISE EXCEPTION 'return exceeds sold quantity' USING ERRCODE='23514'; END IF;
 INSERT INTO pos_demo.returns(return_ref,sale_line_id,quantity,reason,approved_by_ref) VALUES(btrim(p_ref),p_sale_line,p_qty,p_reason,btrim(p_approver)) RETURNING return_id INTO v_id;
 INSERT INTO pos_demo.stock_events(product_id,quantity_delta,reason,source_ref) VALUES(v_product,p_qty,'return',btrim(p_ref));
 RETURN v_id;
END; $$;
REVOKE ALL ON FUNCTION pos_demo.fn_record_return(TEXT,BIGINT,INTEGER,TEXT,TEXT) FROM PUBLIC;