-- Purpose: practical, read-only query catalogue.
-- Engine: PostgreSQL 15+; run after schema, seeds and views.
-- Queries use synthetic data. Mutations belong in the controlled function file.

-- 01. All non-terminal actions by due date.
SELECT reference_code, title, status, due_date
FROM opm_demo.programme_actions
WHERE is_deleted = FALSE AND status NOT IN ('done', 'cancelled')
ORDER BY due_date NULLS LAST, action_id;

-- 02. Overdue list.
SELECT * FROM opm_demo.v_overdue_actions
ORDER BY days_overdue DESC, action_id;

-- 03. Workload by responsible department.
SELECT department_code, department_name, COUNT(a.action_id) AS open_actions
FROM opm_demo.departments d
LEFT JOIN opm_demo.programme_actions a
  ON a.owner_department_id = d.department_id
 AND a.is_deleted = FALSE AND a.status NOT IN ('done', 'cancelled')
GROUP BY d.department_code, d.department_name
ORDER BY open_actions DESC, department_code;

-- 04. Status breakdown.
SELECT status, COUNT(*) AS action_count
FROM opm_demo.programme_actions
WHERE is_deleted = FALSE
GROUP BY status ORDER BY status;

-- 05. Due this calendar month.
SELECT reference_code, title, due_date
FROM opm_demo.programme_actions
WHERE is_deleted = FALSE
  AND due_date >= date_trunc('month', CURRENT_DATE)::date
  AND due_date < (date_trunc('month', CURRENT_DATE) + INTERVAL '1 month')::date
ORDER BY due_date, reference_code;

-- 06. Actions missing a due date.
SELECT reference_code, title, status
FROM opm_demo.programme_actions
WHERE is_deleted = FALSE AND status NOT IN ('done', 'cancelled') AND due_date IS NULL;

-- 07. Full action history.
SELECT a.reference_code, e.previous_status, e.new_status, e.event_note, e.actor_ref, e.happened_at
FROM opm_demo.action_events e
JOIN opm_demo.programme_actions a ON a.action_id = e.action_id
ORDER BY a.reference_code, e.happened_at, e.event_id;

-- 08. Most recent transition for each action.
SELECT DISTINCT ON (action_id) action_id, previous_status, new_status, happened_at
FROM opm_demo.action_events
ORDER BY action_id, happened_at DESC, event_id DESC;

-- 09. Actions that have never transitioned.
SELECT a.action_id, a.reference_code, a.title
FROM opm_demo.programme_actions a
WHERE a.is_deleted = FALSE
  AND NOT EXISTS (SELECT 1 FROM opm_demo.action_events e WHERE e.action_id = a.action_id);

-- 10. Rank open actions within each owner department by urgency.
SELECT department_code, reference_code, title, due_date,
       ROW_NUMBER() OVER (
           PARTITION BY owner_department_id
           ORDER BY due_date NULLS LAST, action_id
       ) AS urgency_rank
FROM opm_demo.programme_actions a
JOIN opm_demo.departments d ON d.department_id = a.owner_department_id
WHERE a.is_deleted = FALSE AND a.status NOT IN ('done', 'cancelled');

-- 11. Sponsor-to-owner handoff pairs.
SELECT s.department_code AS sponsor, o.department_code AS owner,
       COUNT(*) AS action_count
FROM opm_demo.programme_actions a
JOIN opm_demo.departments s ON s.department_id = a.sponsor_department_id
JOIN opm_demo.departments o ON o.department_id = a.owner_department_id
WHERE a.is_deleted = FALSE
GROUP BY s.department_code, o.department_code
ORDER BY action_count DESC, sponsor, owner;

-- 12. Blocked actions needing escalation.
SELECT reference_code, title, due_date, outcome_note
FROM opm_demo.programme_actions
WHERE is_deleted = FALSE AND status = 'blocked'
ORDER BY due_date NULLS LAST;

-- 13. Average elapsed time between status events by final status.
WITH events AS (
    SELECT action_id, new_status, happened_at,
           LAG(happened_at) OVER (PARTITION BY action_id ORDER BY happened_at, event_id) AS prior_at
    FROM opm_demo.action_events
)
SELECT new_status, AVG(happened_at - prior_at) AS average_time_since_prior_event
FROM events WHERE prior_at IS NOT NULL
GROUP BY new_status ORDER BY new_status;

-- 14. Department/status matrix.
SELECT department_code,
       COUNT(*) FILTER (WHERE status = 'planned') AS planned,
       COUNT(*) FILTER (WHERE status = 'in_progress') AS in_progress,
       COUNT(*) FILTER (WHERE status = 'blocked') AS blocked,
       COUNT(*) FILTER (WHERE status = 'done') AS done
FROM opm_demo.programme_actions a
JOIN opm_demo.departments d ON d.department_id = a.owner_department_id
WHERE a.is_deleted = FALSE
GROUP BY department_code ORDER BY department_code;

-- 15. Action-event volume by UTC month.
SELECT date_trunc('month', happened_at AT TIME ZONE 'UTC') AS utc_month,
       COUNT(*) AS event_count
FROM opm_demo.action_events
GROUP BY 1 ORDER BY 1;

-- 16. Actions by age bucket.
SELECT CASE
           WHEN CURRENT_DATE - created_at::date < 7 THEN 'under_7_days'
           WHEN CURRENT_DATE - created_at::date < 30 THEN '7_to_29_days'
           ELSE '30_days_or_more'
       END AS age_bucket,
       COUNT(*) AS action_count
FROM opm_demo.programme_actions
WHERE is_deleted = FALSE
GROUP BY 1 ORDER BY 1;

-- 17. Referential check: actions whose sponsor differs from owner.
SELECT reference_code, title
FROM opm_demo.programme_actions
WHERE sponsor_department_id <> owner_department_id AND is_deleted = FALSE;

-- 18. Count actions with no recorded outcome note.
SELECT COUNT(*) AS missing_outcome_note
FROM opm_demo.programme_actions
WHERE is_deleted = FALSE AND status = 'done' AND NULLIF(btrim(outcome_note), '') IS NULL;

-- 19. Actions due in the next 14 calendar days.
SELECT reference_code, title, due_date
FROM opm_demo.programme_actions
WHERE is_deleted = FALSE
  AND status NOT IN ('done', 'cancelled')
  AND due_date >= CURRENT_DATE AND due_date < CURRENT_DATE + 14
ORDER BY due_date, reference_code;

-- 20. All actions sponsored by the programme coordination office.
SELECT a.reference_code, a.title, owner.department_name AS delivery_owner, a.status
FROM opm_demo.programme_actions a
JOIN opm_demo.departments sponsor ON sponsor.department_id = a.sponsor_department_id
JOIN opm_demo.departments owner ON owner.department_id = a.owner_department_id
WHERE sponsor.department_code = 'DEMO-OPM' AND a.is_deleted = FALSE
ORDER BY a.due_date NULLS LAST, a.reference_code;