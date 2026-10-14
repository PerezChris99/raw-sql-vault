-- Purpose: deterministic synthetic permit types and applications.
-- Engine: PostgreSQL 15+. Prerequisite: 01_schema.sql. Safe to rerun.
INSERT INTO ug_permit.permit_types(type_code,type_name,issuing_office_code,validity_days,fee_amount,currency_code)
VALUES
 ('DEMO-TRADING','Synthetic trading permit','DEMO-OFFICE-01',365,50000.00,'UGX'),
 ('DEMO-SIGNAGE','Synthetic signage permit','DEMO-OFFICE-01',365,25000.00,'UGX'),
 ('DEMO-RENEWAL','Synthetic annual renewal','DEMO-OFFICE-02',365,30000.00,'UGX')
ON CONFLICT(type_code) DO NOTHING;

INSERT INTO ug_permit.applications(application_ref,permit_type_id,applicant_ref,locality_code,status,submitted_at,created_by)
SELECT v.application_ref,t.permit_type_id,v.applicant_ref,v.locality_code,v.status,
       CASE WHEN v.status<>'draft' THEN TIMESTAMPTZ '2026-01-15 09:00:00+03' END,
       'synthetic-seed'
FROM (VALUES
 ('UGP-DEMO-0001','SYNTHETIC-APPLICANT-001','DEMO-LOCALITY-01','submitted'),
 ('UGP-DEMO-0002','SYNTHETIC-APPLICANT-002','DEMO-LOCALITY-02','under_review'),
 ('UGP-DEMO-0003','SYNTHETIC-APPLICANT-003','DEMO-LOCALITY-01','draft')
) AS v(application_ref,applicant_ref,locality_code,status)
JOIN ug_permit.permit_types t ON t.type_code='DEMO-TRADING'
ON CONFLICT(application_ref) DO NOTHING;

INSERT INTO ug_permit.application_events(application_id,event_type,from_status,to_status,actor_ref,reason)
SELECT a.application_id,'created',NULL,a.status,'synthetic-seed','Synthetic application fixture'
FROM ug_permit.applications a
WHERE a.application_ref LIKE 'UGP-DEMO-%'
  AND NOT EXISTS (SELECT 1 FROM ug_permit.application_events e WHERE e.application_id=a.application_id AND e.event_type='created');
