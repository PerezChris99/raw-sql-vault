-- Purpose: synthetic clinics, service definitions and future appointment slots.
-- Engine: PostgreSQL 15+. Prerequisite: 01_schema.sql. Safe to rerun.
INSERT INTO ug_clinic_sched.clinics(clinic_ref,clinic_name,locality_ref) VALUES
 ('UGCL-DEMO-001','Synthetic Clinic Alpha','DEMO-LOCALITY-01'),
 ('UGCL-DEMO-002','Synthetic Clinic Beta','DEMO-LOCALITY-02')
ON CONFLICT(clinic_ref) DO NOTHING;

INSERT INTO ug_clinic_sched.services(service_code,service_name,default_duration_minutes) VALUES
 ('DEMO-CONSULT','Synthetic general consultation',20),
 ('DEMO-FOLLOWUP','Synthetic follow-up appointment',15)
ON CONFLICT(service_code) DO NOTHING;

INSERT INTO ug_clinic_sched.slots(slot_ref,clinic_id,service_id,clinician_ref,starts_at,ends_at,status)
SELECT v.slot_ref,c.clinic_id,s.service_id,v.clinician_ref,
       ((date_trunc('day', now() AT TIME ZONE 'Africa/Kampala') + INTERVAL '1 day 9 hours' + v.slot_offset) AT TIME ZONE 'Africa/Kampala'),
       ((date_trunc('day', now() AT TIME ZONE 'Africa/Kampala') + INTERVAL '1 day' + v.slot_offset + make_interval(mins=>s.default_duration_minutes)) AT TIME ZONE 'Africa/Kampala'),'open'
FROM (VALUES
 ('UGSLOT-DEMO-001','UGCL-DEMO-001','DEMO-CONSULT','SYN-CLINICIAN-01',INTERVAL '0 minutes'),
 ('UGSLOT-DEMO-002','UGCL-DEMO-001','DEMO-CONSULT','SYN-CLINICIAN-01',INTERVAL '30 minutes'),
 ('UGSLOT-DEMO-003','UGCL-DEMO-002','DEMO-FOLLOWUP','SYN-CLINICIAN-02',INTERVAL '0 minutes')
) AS v(slot_ref,clinic_ref,service_code,clinician_ref,slot_offset)
JOIN ug_clinic_sched.clinics c ON c.clinic_ref=v.clinic_ref
JOIN ug_clinic_sched.services s ON s.service_code=v.service_code
ON CONFLICT(slot_ref) DO UPDATE SET starts_at=EXCLUDED.starts_at,ends_at=EXCLUDED.ends_at
WHERE NOT EXISTS (SELECT 1 FROM ug_clinic_sched.appointments a WHERE a.slot_id=ug_clinic_sched.slots.slot_id);
