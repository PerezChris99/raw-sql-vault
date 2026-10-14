-- Purpose: close a finding only after independent passing verification and evidence.
-- Engine: PostgreSQL 15+. Prerequisite: 01_schema.sql. Rerunnable.
CREATE OR REPLACE FUNCTION ug_cyber.fn_record_verification(
 p_finding_ref TEXT,p_verifier_ref TEXT,p_result TEXT,p_evidence_ref TEXT,p_notes_redacted TEXT
) RETURNS BIGINT LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ug_cyber AS $$
DECLARE f ug_cyber.findings%ROWTYPE; v_id BIGINT;
BEGIN
 IF p_result NOT IN ('pass','fail','inconclusive') OR length(btrim(COALESCE(p_verifier_ref,'')))=0
 OR length(btrim(COALESCE(p_evidence_ref,'')))=0 OR length(btrim(COALESCE(p_notes_redacted,'')))=0 THEN
  RAISE EXCEPTION 'Verifier, result, evidence and redacted notes are required' USING ERRCODE='invalid_parameter_value';
 END IF;
 SELECT * INTO f FROM ug_cyber.findings WHERE finding_ref=p_finding_ref FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Finding not found' USING ERRCODE='no_data_found'; END IF;
 IF f.status IN ('verified','closed') THEN RAISE EXCEPTION 'Verified/closed finding requires a formal reopen event' USING ERRCODE='check_violation'; END IF;
 IF p_verifier_ref=f.owner_ref THEN RAISE EXCEPTION 'Remediation owner cannot independently verify own fix' USING ERRCODE='check_violation'; END IF;
 INSERT INTO ug_cyber.verification_results(finding_id,verifier_ref,result,evidence_ref,notes_redacted)
 VALUES(f.finding_id,p_verifier_ref,p_result,p_evidence_ref,p_notes_redacted) RETURNING verification_id INTO v_id;
 IF p_result='pass' THEN UPDATE ug_cyber.findings SET status='verified' WHERE finding_id=f.finding_id;
 ELSIF p_result='fail' THEN UPDATE ug_cyber.findings SET status='in_progress' WHERE finding_id=f.finding_id; END IF;
 INSERT INTO ug_cyber.remediation_events(finding_id,event_type,actor_ref,reason_redacted,evidence_ref)
 VALUES(f.finding_id,CASE p_result WHEN 'pass' THEN 'verification_passed' WHEN 'fail' THEN 'verification_failed' ELSE 'assigned' END,
 p_verifier_ref,'Independent remediation verification: '||p_result,p_evidence_ref);
 RETURN v_id;
END; $$;
