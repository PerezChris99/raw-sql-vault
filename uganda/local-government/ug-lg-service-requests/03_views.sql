-- Purpose: consistent queue and locality roll-up views.
-- Engine: PostgreSQL 15+; requires schema and seed scripts.
-- Rerun safety: CREATE OR REPLACE VIEW.

CREATE OR REPLACE VIEW service_demo.v_open_requests AS
SELECT r.request_id, r.request_ref, r.request_type, r.description,
       l.locality_code, l.locality_name, r.priority, r.status, r.due_at,
       r.created_at,
       EXTRACT(EPOCH FROM (now() - r.created_at)) / 3600.0 AS age_hours
FROM service_demo.service_requests r
JOIN service_demo.localities l ON l.locality_id = r.locality_id
WHERE r.is_deleted = FALSE AND r.status NOT IN ('resolved', 'cancelled');

CREATE OR REPLACE VIEW service_demo.v_overdue_requests AS
SELECT *
FROM service_demo.v_open_requests
WHERE due_at IS NOT NULL AND due_at < now();

CREATE OR REPLACE VIEW service_demo.v_locality_service_summary AS
SELECT l.locality_code, l.locality_name,
       COUNT(r.request_id) FILTER (WHERE r.is_deleted = FALSE) AS total_requests,
       COUNT(r.request_id) FILTER (
           WHERE r.is_deleted = FALSE AND r.status NOT IN ('resolved', 'cancelled')
       ) AS open_requests,
       COUNT(r.request_id) FILTER (
           WHERE r.is_deleted = FALSE AND r.status = 'resolved'
       ) AS resolved_requests
FROM service_demo.localities l
LEFT JOIN service_demo.service_requests r ON r.locality_id = l.locality_id
GROUP BY l.locality_code, l.locality_name;

COMMENT ON VIEW service_demo.v_overdue_requests IS
    'Requests with a missed due_at timestamp that remain open; requires operational interpretation.';