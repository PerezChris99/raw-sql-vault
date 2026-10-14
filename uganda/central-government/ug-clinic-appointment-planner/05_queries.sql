-- Purpose: scheduling and operational reporting queries.
-- Engine: PostgreSQL 15+. Prerequisites: schema, seeds and views.
-- Synthetic references only; use bound parameters in applications.

-- 01. Search upcoming available slots.
SELECT * FROM ug_clinic_sched.v_available_slots ORDER BY starts_at,clinic_ref,service_code;

-- 02. Daily clinic load in Uganda local time.
SELECT * FROM ug_clinic_sched.v_daily_clinic_load ORDER BY service_date,clinic_ref;

-- 03. Active appointment queue.
SELECT * FROM ug_clinic_sched.v_appointment_queue ORDER BY starts_at,clinic_ref;

-- 04. Cancelled appointments for operational review.
SELECT appointment_ref,patient_ref,cancelled_at,cancellation_reason
FROM ug_clinic_sched.appointments WHERE status='cancelled' ORDER BY cancelled_at DESC;

-- 05. Published slots without a corresponding appointment.
SELECT sl.slot_ref,c.clinic_ref,s.service_code,sl.starts_at
FROM ug_clinic_sched.slots sl
JOIN ug_clinic_sched.clinics c USING(clinic_id)
JOIN ug_clinic_sched.services s USING(service_id)
LEFT JOIN ug_clinic_sched.appointments a ON a.slot_id=sl.slot_id AND a.status IN ('booked','checked_in')
WHERE sl.status='open' AND sl.starts_at>now() AND a.appointment_id IS NULL
ORDER BY sl.starts_at;

-- 06. Slot overbooking check (partial unique index should prevent active duplicates).
SELECT slot_id,COUNT(*) FROM ug_clinic_sched.appointments
WHERE status IN ('booked','checked_in') GROUP BY slot_id HAVING COUNT(*)>1;

-- 07. Appointment event timeline.
SELECT e.occurred_at,e.event_type,e.from_status,e.to_status,e.actor_ref,e.reason
FROM ug_clinic_sched.appointment_events e
JOIN ug_clinic_sched.appointments a USING(appointment_id)
WHERE a.appointment_ref='UGAPT-DEMO-0001' ORDER BY e.occurred_at,e.event_id;

-- 08. No-show counts by clinic and service date.
SELECT c.clinic_ref,(sl.starts_at AT TIME ZONE 'Africa/Kampala')::date AS service_date,
       COUNT(*) FILTER (WHERE a.status='no_show') AS no_shows,
       COUNT(*) FILTER (WHERE a.status='completed') AS completed
FROM ug_clinic_sched.appointments a
JOIN ug_clinic_sched.slots sl USING(slot_id)
JOIN ug_clinic_sched.clinics c USING(clinic_id)
GROUP BY c.clinic_ref,(sl.starts_at AT TIME ZONE 'Africa/Kampala')::date
ORDER BY service_date,c.clinic_ref;

-- 09. Services with no future published slots.
SELECT c.clinic_ref,s.service_code
FROM ug_clinic_sched.clinics c CROSS JOIN ug_clinic_sched.services s
LEFT JOIN ug_clinic_sched.slots sl ON sl.clinic_id=c.clinic_id AND sl.service_id=s.service_id
 AND sl.status='open' AND sl.starts_at>now()
WHERE c.is_active AND s.is_active
GROUP BY c.clinic_ref,s.service_code HAVING COUNT(sl.slot_id)=0;

-- 10. Slots scheduled in the next seven days.
SELECT clinic_ref,service_code,COUNT(*) AS slots
FROM ug_clinic_sched.v_available_slots
WHERE starts_at<now()+INTERVAL '7 days'
GROUP BY clinic_ref,service_code ORDER BY clinic_ref,service_code;
