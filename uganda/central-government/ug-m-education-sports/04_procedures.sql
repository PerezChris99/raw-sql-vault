CREATE OR REPLACE FUNCTION education_demo.fn_transition_allocation(p_id BIGINT,p_to TEXT,p_note TEXT,p_actor TEXT,p_quantity INTEGER DEFAULT NULL,p_document_ref TEXT DEFAULT NULL)
RETURNS BIGINT LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,education_demo AS $$
DECLARE v_from TEXT;v_planned INTEGER;v_dispatched INTEGER;
BEGIN
 IF p_to IS NULL OR p_to NOT IN('planned','dispatched','received','disputed','cancelled') THEN RAISE EXCEPTION 'invalid allocation status' USING ERRCODE='23514'; END IF;
 IF NULLIF(btrim(p_note),'') IS NULL OR NULLIF(btrim(p_actor),'') IS NULL THEN RAISE EXCEPTION 'note and actor required' USING ERRCODE='22023'; END IF;
 SELECT status,planned_quantity,dispatched_quantity INTO v_from,v_planned,v_dispatched FROM education_demo.allocations WHERE allocation_id=p_id AND is_deleted=FALSE FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'allocation not found' USING ERRCODE='P0002'; END IF;
 IF v_from=p_to THEN RETURN p_id; END IF;
 IF NOT((v_from='planned' AND p_to IN('dispatched','cancelled')) OR
 (v_from='dispatched' AND p_to IN('received','disputed')) OR
 (v_from='disputed' AND p_to IN('received','cancelled'))) THEN
 RAISE EXCEPTION 'transition not allowed: % -> %',v_from,p_to USING ERRCODE='23514'; END IF;
 IF p_to='dispatched' AND (p_quantity IS NULL OR p_quantity<=0 OR p_quantity>v_planned) THEN RAISE EXCEPTION 'dispatch quantity must be within planned quantity' USING ERRCODE='22023'; END IF;
 IF p_to='received' AND (p_quantity IS NULL OR p_quantity<=0 OR p_quantity>v_dispatched) THEN RAISE EXCEPTION 'received quantity must be positive and no greater than dispatched' USING ERRCODE='22023'; END IF;
 UPDATE education_demo.allocations SET status=p_to,
  dispatched_quantity=CASE WHEN p_to='dispatched' THEN p_quantity ELSE dispatched_quantity END,
  received_quantity=CASE WHEN p_to='received' THEN p_quantity ELSE received_quantity END,
  dispatch_reference=CASE WHEN p_to='dispatched' THEN p_document_ref ELSE dispatch_reference END,
  receipt_reference=CASE WHEN p_to='received' THEN p_document_ref ELSE receipt_reference END
 WHERE allocation_id=p_id;
 INSERT INTO education_demo.allocation_events(allocation_id,previous_status,new_status,event_note,actor_ref)
 VALUES(p_id,v_from,p_to,btrim(p_note),btrim(p_actor));
 RETURN p_id;
END; $$;
REVOKE ALL ON FUNCTION education_demo.fn_transition_allocation(BIGINT,TEXT,TEXT,TEXT,INTEGER,TEXT) FROM PUBLIC;