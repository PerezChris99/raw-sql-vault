-- Purpose: synthetic case categories and case/referral fixtures.
-- Engine: PostgreSQL 15+. Prerequisite: 01_schema.sql. Safe to rerun.
INSERT INTO ug_public_case.case_categories(category_code,category_name,default_sla_hours,confidentiality) VALUES
 ('DEMO-SERVICE','Synthetic service complaint',120,'restricted'),
 ('DEMO-CONDUCT','Synthetic conduct concern',240,'highly_restricted'),
 ('DEMO-REFERRAL','Synthetic inter-office referral',72,'restricted')
ON CONFLICT(category_code) DO NOTHING;

INSERT INTO ug_public_case.cases(case_ref,idempotency_key,category_id,received_at,channel,complainant_ref,locality_ref,severity,status,due_at,confidentiality,created_by)
SELECT v.case_ref,v.idem,c.category_id,TIMESTAMPTZ '2026-02-01 09:00:00+03',v.channel,v.complainant,v.locality,
       v.severity,v.status,TIMESTAMPTZ '2026-02-06 09:00:00+03',c.confidentiality,'synthetic-seed'
FROM (VALUES
 ('UGCASE-DEMO-0001','case-idem-demo-0001','DEMO-SERVICE','web_form','SYN-COMPLAINANT-001','DEMO-LOCALITY-01','normal','triaged'),
 ('UGCASE-DEMO-0002','case-idem-demo-0002','DEMO-CONDUCT','in_person','SYN-COMPLAINANT-002','DEMO-LOCALITY-02','high','received')
) AS v(case_ref,idem,category_code,channel,complainant,locality,severity,status)
JOIN ug_public_case.case_categories c ON c.category_code=v.category_code
ON CONFLICT(case_ref) DO NOTHING;

INSERT INTO ug_public_case.case_events(case_id,event_type,from_status,to_status,actor_ref,reason)
SELECT c.case_id,'received',NULL,c.status,'synthetic-seed','Synthetic case fixture'
FROM ug_public_case.cases c
WHERE c.case_ref LIKE 'UGCASE-DEMO-%'
AND NOT EXISTS (SELECT 1 FROM ug_public_case.case_events e WHERE e.case_id=c.case_id AND e.event_type='received');
