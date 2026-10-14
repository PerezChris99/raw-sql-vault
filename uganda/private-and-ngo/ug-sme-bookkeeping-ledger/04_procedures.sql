-- Purpose: post only balanced, multi-line journals into an open accounting period.
-- Engine: PostgreSQL 15+. Prerequisite: 01_schema.sql. Rerunnable.
CREATE OR REPLACE FUNCTION ug_sme_ledger.fn_post_journal(
 p_journal_ref TEXT,p_actor_ref TEXT,p_evidence_ref TEXT
) RETURNS BIGINT LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ug_sme_ledger AS $$
DECLARE j ug_sme_ledger.journal_entries%ROWTYPE; p ug_sme_ledger.periods%ROWTYPE;
 v_lines BIGINT; v_debit NUMERIC(16,2); v_credit NUMERIC(16,2); v_id BIGINT;
BEGIN
 IF length(btrim(COALESCE(p_actor_ref,'')))=0 OR length(btrim(COALESCE(p_evidence_ref,'')))=0 THEN
  RAISE EXCEPTION 'Posting actor and evidence are required' USING ERRCODE='invalid_parameter_value';
 END IF;
 SELECT * INTO j FROM ug_sme_ledger.journal_entries WHERE journal_ref=p_journal_ref FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Journal not found' USING ERRCODE='no_data_found'; END IF;
 IF j.status<>'draft' THEN RAISE EXCEPTION 'Only draft journals may be posted' USING ERRCODE='check_violation'; END IF;
 SELECT * INTO p FROM ug_sme_ledger.periods WHERE period_id=j.period_id FOR UPDATE;
 IF p.status<>'open' OR j.transaction_date NOT BETWEEN p.starts_on AND p.ends_on THEN
  RAISE EXCEPTION 'Journal date is outside an open accounting period' USING ERRCODE='check_violation';
 END IF;
 SELECT COUNT(*),COALESCE(SUM(debit),0),COALESCE(SUM(credit),0)
 INTO v_lines,v_debit,v_credit FROM ug_sme_ledger.journal_lines WHERE journal_id=j.journal_id;
 IF v_lines<2 OR v_debit<=0 OR v_debit<>v_credit THEN
  RAISE EXCEPTION 'Journal must contain at least two lines and equal positive debit/credit totals' USING ERRCODE='check_violation';
 END IF;
 UPDATE ug_sme_ledger.journal_entries SET status='posted',posted_by_ref=p_actor_ref,posted_at=clock_timestamp(),posting_evidence_ref=p_evidence_ref
 WHERE journal_id=j.journal_id;
 INSERT INTO ug_sme_ledger.audit_events(journal_id,event_type,actor_ref,reason,evidence_ref)
 VALUES(j.journal_id,'posted',p_actor_ref,'Journal posted after balance validation',p_evidence_ref) RETURNING event_id INTO v_id;
 RETURN v_id;
END; $$;

CREATE OR REPLACE FUNCTION ug_sme_ledger.fn_close_period(
 p_period_ref TEXT,p_actor_ref TEXT,p_evidence_ref TEXT
) RETURNS BIGINT LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ug_sme_ledger AS $$
DECLARE p ug_sme_ledger.periods%ROWTYPE; v_count BIGINT; v_id BIGINT;
BEGIN
 IF length(btrim(COALESCE(p_actor_ref,'')))=0 OR length(btrim(COALESCE(p_evidence_ref,'')))=0 THEN
  RAISE EXCEPTION 'Period closer and evidence are required' USING ERRCODE='invalid_parameter_value';
 END IF;
 SELECT * INTO p FROM ug_sme_ledger.periods WHERE period_ref=p_period_ref FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Period not found' USING ERRCODE='no_data_found'; END IF;
 IF p.status='closed' THEN RAISE EXCEPTION 'Period already closed' USING ERRCODE='check_violation'; END IF;
 SELECT COUNT(*) INTO v_count FROM ug_sme_ledger.journal_entries WHERE period_id=p.period_id AND status='draft';
 IF v_count>0 THEN RAISE EXCEPTION 'Cannot close period while draft journals remain' USING ERRCODE='check_violation'; END IF;
 UPDATE ug_sme_ledger.periods SET status='closed',closed_by_ref=p_actor_ref,closed_at=clock_timestamp(),closure_evidence_ref=p_evidence_ref
 WHERE period_id=p.period_id;
 SELECT journal_id INTO v_id FROM ug_sme_ledger.journal_entries WHERE period_id=p.period_id ORDER BY journal_id LIMIT 1;
 IF v_id IS NOT NULL THEN
  INSERT INTO ug_sme_ledger.audit_events(journal_id,event_type,actor_ref,reason,evidence_ref)
  VALUES(v_id,'period_closed',p_actor_ref,'Accounting period closed',p_evidence_ref);
 END IF;
 RETURN p.period_id;
END; $$;
