-- Purpose: available slot search, daily clinic load and appointment queue.
-- Engine: PostgreSQL 15+. Prerequisite: 01_schema.sql. Rerunnable.
CREATE OR REPLACE VIEW ug_clinic_sched.v_available_slots AS
SELECT sl.slot_id,sl.slot_ref,c.clinic_ref,c.clinic_name,c.locality_ref,s.service_code,s.service_name,
       sl.clinician_ref,sl.starts_at,sl.ends_at
FROM ug_clinic_sched.slots sl
JOIN ug_clinic_sched.clinics c USING(clinic_id)
JOIN ug_clinic_sched.services s USING(service_id)
WHERE sl.status='open' AND c.is_active AND s.is_active AND sl.starts_at>now()
AND NOT EXISTS (
 SELECT 1 FROM ug_clinic_sched.appointments a
 WHERE a.slot_id=sl.slot_id AND a.status IN ('booked','checked_in')
);

CREATE OR REPLACE VIEW ug_clinic_sched.v_daily_clinic_load AS
SELECT c.clinic_ref,c.clinic_name,(sl.starts_at AT TIME ZONE 'Africa/Kampala')::date AS service_date,
       COUNT(DISTINCT sl.slot_id) AS published_slots,
       COUNT(DISTINCT a.appointment_id) FILTER (WHERE a.status IN ('booked','checked_in','completed','no_show')) AS appointments,
       COUNT(DISTINCT a.appointment_id) FILTER (WHERE a.status='cancelled') AS cancellations
FROM ug_clinic_sched.clinics c
JOIN ug_clinic_sched.slots sl USING(clinic_id)
LEFT JOIN ug_clinic_sched.appointments a USING(slot_id)
GROUP BY c.clinic_ref,c.clinic_name,(sl.starts_at AT TIME ZONE 'Africa/Kampala')::date;

CREATE OR REPLACE VIEW ug_clinic_sched.v_appointment_queue AS
SELECT a.appointment_ref,a.patient_ref,a.status,a.booked_at,sl.slot_ref,sl.starts_at,sl.ends_at,
       c.clinic_ref,c.clinic_name,s.service_code,s.service_name
FROM ug_clinic_sched.appointments a
JOIN ug_clinic_sched.slots sl USING(slot_id)
JOIN ug_clinic_sched.clinics c USING(clinic_id)
JOIN ug_clinic_sched.services s USING(service_id)
WHERE a.status IN ('booked','checked_in');
