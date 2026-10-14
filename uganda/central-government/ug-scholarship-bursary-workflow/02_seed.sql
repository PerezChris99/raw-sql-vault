-- Purpose: synthetic scholarship programme and application fixtures.
-- Engine: PostgreSQL 15+. Prerequisite: 01_schema.sql. Safe to rerun.
INSERT INTO ug_bursary.programmes(programme_code,programme_name,academic_year,sponsor_ref,opens_on,closes_on,award_amount,currency_code,programme_status)
VALUES ('DEMO-BURSARY-01','Synthetic Education Support Award','2026/2027','SYNTHETIC-SPONSOR',DATE '2026-01-01',DATE '2026-12-31',750000,'UGX','open')
ON CONFLICT(programme_code) DO NOTHING;

INSERT INTO ug_bursary.applications(application_ref,programme_id,student_ref,school_ref,status,submitted_at,
    decision_at,decision_evidence_ref,decision_reason,created_by)
SELECT v.application_ref,p.programme_id,v.student_ref,v.school_ref,v.status,
       CASE WHEN v.status<>'draft' THEN TIMESTAMPTZ '2026-02-01 09:00:00+03' END,
       CASE WHEN v.status='rejected' THEN TIMESTAMPTZ '2026-02-10 12:00:00+03' END,
       CASE WHEN v.status='rejected' THEN 'SYNTHETIC-DECISION-REF-01' END,
       CASE WHEN v.status='rejected' THEN 'Synthetic decision fixture' END,
       'synthetic-seed'
FROM (VALUES
 ('UGB-DEMO-0001','SYN-STUDENT-001','SYN-SCHOOL-001','under_review'),
 ('UGB-DEMO-0002','SYN-STUDENT-002','SYN-SCHOOL-001','rejected'),
 ('UGB-DEMO-0003','SYN-STUDENT-003','SYN-SCHOOL-002','draft')
) AS v(application_ref,student_ref,school_ref,status)
JOIN ug_bursary.programmes p ON p.programme_code='DEMO-BURSARY-01'
ON CONFLICT(application_ref) DO NOTHING;

INSERT INTO ug_bursary.application_events(application_id,event_type,from_status,to_status,actor_ref,reason,evidence_reference)
SELECT a.application_id,'created',NULL,a.status,'synthetic-seed','Synthetic application fixture',NULL
FROM ug_bursary.applications a
WHERE a.application_ref LIKE 'UGB-DEMO-%'
AND NOT EXISTS (SELECT 1 FROM ug_bursary.application_events e WHERE e.application_id=a.application_id AND e.event_type='created');
