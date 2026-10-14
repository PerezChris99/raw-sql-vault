-- PostgreSQL 15+; roll back test data after assertions.
BEGIN;
DO $test$
DECLARE v_line BIGINT;v_count BIGINT;v_id BIGINT;
BEGIN
 SELECT sale_line_id INTO v_line FROM pos_demo.sale_lines l JOIN pos_demo.sales s USING(sale_id) JOIN pos_demo.products p USING(product_id) WHERE s.receipt_ref='DEMO-RECEIPT-001' AND p.sku='DEMO-POS-001' FOR UPDATE;
 DELETE FROM pos_demo.stock_events WHERE source_ref='TEST-POS-RETURN';
 DELETE FROM pos_demo.returns WHERE return_ref='TEST-POS-RETURN';
 v_id:=pos_demo.fn_record_return('TEST-POS-RETURN',v_line,1,'customer_return','test-approver');
 SELECT COUNT(*) INTO v_count FROM pos_demo.returns WHERE sale_line_id=v_line;
 IF v_count<>1 THEN RAISE EXCEPTION 'ASSERT return record missing'; END IF;
 BEGIN PERFORM pos_demo.fn_record_return('TEST-POS-RETURN-OVER',v_line,99,'customer_return','test-approver'); RAISE EXCEPTION 'ASSERT excess return accepted'; EXCEPTION WHEN check_violation THEN NULL; END;
END; $test$;
ROLLBACK;