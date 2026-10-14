-- Purpose: approve leave requests and freeze an evidenced payroll input period before export.
-- Engine: PostgreSQL 15+. Prerequisite: 01_schema.sql. Rerunnable.
CREATE OR REPLACE FUNCTION ug_hr_payroll.fn_review_leave(
 p_leave_ref TEXT,p_decision TEXT,p_reviewer_ref TEXT,p_evidence_ref TEXT
) RETURNS BIGINT LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ug_hr_payroll AS $$
DECLARE l ug_hr_payroll.leave_requests%ROWTYPE; v_id BIGINT;
BEGIN
 IF p_decision NOT IN ('approved','rejected') OR length(btrim(COALESCE(p_reviewer_ref,'')))=0
 OR length(btrim(COALESCE(p_evidence_ref,'')))=0 THEN RAISE EXCEPTION 'Decision, reviewer and evidence are required' USING ERRCODE='invalid_parameter_value'; END IF;
 SELECT * INTO l FROM ug_hr_payroll.leave_requests WHERE leave_ref=p_leave_ref FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Leave request not found' USING ERRCODE='no_data_found'; END IF;
 IF l.status<>'submitted' THEN RAISE EXCEPTION 'Leave request is not reviewable' USING ERRCODE='check_violation'; END IF;
 UPDATE ug_hr_payroll.leave_requests SET status=p_decision,reviewed_by_ref=p_reviewer_ref,reviewed_at=clock_timestamp(),review_evidence_ref=p_evidence_ref
 WHERE leave_request_id=l.leave_request_id;
 INSERT INTO ug_hr_payroll.audit_events(entity_type,entity_ref,event_type,actor_ref,reason,evidence_ref)
 VALUES('leave',p_leave_ref,p_decision,p_reviewer_ref,'Leave request reviewed',p_evidence_ref) RETURNING event_id INTO v_id;
 RETURN v_id;
END; $$;

CREATE OR REPLACE FUNCTION ug_hr_payroll.fn_approve_period(
 p_period_ref TEXT,p_reviewer_ref TEXT,p_evidence_ref TEXT
) RETURNS BIGINT LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ug_hr_payroll AS $$
DECLARE p ug_hr_payroll.payroll_periods%ROWTYPE; v_count BIGINT; v_id BIGINT;
BEGIN
 IF length(btrim(COALESCE(p_reviewer_ref,'')))=0 OR length(btrim(COALESCE(p_evidence_ref,'')))=0 THEN
  RAISE EXCEPTION 'Reviewer and approval evidence are required' USING ERRCODE='invalid_parameter_value'; END IF;
 SELECT * INTO p FROM ug_hr_payroll.payroll_periods WHERE period_ref=p_period_ref FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Payroll period not found' USING ERRCODE='no_data_found'; END IF;
 IF p.status NOT IN ('open','review') THEN RAISE EXCEPTION 'Period cannot be approved in current status' USING ERRCODE='check_violation'; END IF;
 SELECT COUNT(*) INTO v_count FROM ug_hr_payroll.leave_requests l
 JOIN ug_hr_payroll.staff_refs s USING(staff_id)
 WHERE l.status='submitted' AND l.starts_on<=p.period_end AND l.ends_on>=p.period_start;
 IF v_count>0 THEN RAISE EXCEPTION 'Pending leave requests overlap this period; resolve them before payroll input approval' USING ERRCODE='check_violation'; END IF;
 UPDATE ug_hr_payroll.payroll_periods SET status='approved',approved_by_ref=p_reviewer_ref,approved_at=clock_timestamp(),approval_evidence_ref=p_evidence_ref
 WHERE period_id=p.period_id;
 INSERT INTO ug_hr_payroll.audit_events(entity_type,entity_ref,event_type,actor_ref,reason,evidence_ref)
 VALUES('payroll_period',p_period_ref,'approved',p_reviewer_ref,'Payroll input period approved for controlled export',p_evidence_ref)
 RETURNING event_id INTO v_id;
 RETURN v_id;
END; $$;
