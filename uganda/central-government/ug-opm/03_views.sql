-- Purpose: consistent programme action reporting.
-- Engine: PostgreSQL 15+; requires 01_schema.sql and 02_seed.sql.
-- Rerun safety: CREATE OR REPLACE VIEW.

CREATE OR REPLACE VIEW opm_demo.v_overdue_actions AS
SELECT
    a.action_id,
    a.reference_code,
    a.title,
    d.department_code AS owner_department,
    a.due_date,
    a.status,
    CURRENT_DATE - a.due_date AS days_overdue
FROM opm_demo.programme_actions AS a
JOIN opm_demo.departments AS d ON d.department_id = a.owner_department_id
WHERE a.is_deleted = FALSE
  AND a.due_date < CURRENT_DATE
  AND a.status NOT IN ('done', 'cancelled');

CREATE OR REPLACE VIEW opm_demo.v_action_status_summary AS
SELECT
    d.department_code,
    d.department_name,
    a.status,
    COUNT(a.action_id)::BIGINT AS action_count
FROM opm_demo.departments AS d
LEFT JOIN opm_demo.programme_actions AS a
    ON a.owner_department_id = d.department_id
   AND a.is_deleted = FALSE
GROUP BY d.department_code, d.department_name, a.status;

COMMENT ON VIEW opm_demo.v_overdue_actions IS
    'Open actions past their target due date; overdue is a monitoring signal, not a compliance finding.';