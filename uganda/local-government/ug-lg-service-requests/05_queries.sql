-- Purpose: read-only operational and analytics queries.
-- Engine: PostgreSQL 15+; run after schema, seed, views and procedures.

-- 01. Open queue, highest urgency first.
SELECT * FROM service_demo.v_open_requests ORDER BY priority, due_at NULLS LAST, request_id;

-- 02. Overdue requests.
SELECT * FROM service_demo.v_overdue_requests ORDER BY due_at, priority;

-- 03. Summary by locality.
SELECT * FROM service_demo.v_locality_service_summary ORDER BY open_requests DESC, locality_code;

-- 04. Volume by type and status.
SELECT request_type, status, COUNT(*) AS request_count
FROM service_demo.service_requests WHERE is_deleted = FALSE
GROUP BY request_type, status ORDER BY request_type, status;

-- 05. Priority-one open queue.
SELECT request_ref, request_type, locality_code, due_at
FROM service_demo.v_open_requests WHERE priority = 1 ORDER BY due_at NULLS LAST;

-- 06. Open requests without due dates.
SELECT request_ref, request_type, created_at
FROM service_demo.v_open_requests WHERE due_at IS NULL;

-- 07. Request event history.
SELECT r.request_ref, e.previous_status, e.new_status, e.event_note, e.actor_ref, e.happened_at
FROM service_demo.request_events e JOIN service_demo.service_requests r USING (request_id)
ORDER BY r.request_ref, e.happened_at, e.event_id;

-- 08. Latest status event per request.
SELECT DISTINCT ON (request_id) request_id, new_status, actor_ref, happened_at
FROM service_demo.request_events ORDER BY request_id, happened_at DESC, event_id DESC;

-- 09. Requests without a recorded transition.
SELECT r.request_ref FROM service_demo.service_requests r
WHERE r.is_deleted = FALSE AND NOT EXISTS (
    SELECT 1 FROM service_demo.request_events e WHERE e.request_id = r.request_id
);

-- 10. Average age of open requests by type.
SELECT request_type, ROUND(AVG(age_hours)::numeric, 1) AS average_age_hours
FROM service_demo.v_open_requests GROUP BY request_type ORDER BY average_age_hours DESC;

-- 11. Median hours to resolution for records with status history not stored as raw PII.
SELECT request_type,
       PERCENTILE_CONT(0.5) WITHIN GROUP (
           ORDER BY EXTRACT(EPOCH FROM (resolved_at - created_at)) / 3600.0
       ) AS median_hours
FROM service_demo.service_requests
WHERE status = 'resolved' AND resolved_at IS NOT NULL
GROUP BY request_type ORDER BY request_type;

-- 12. Requests created in the last seven days (half-open timestamp range).
SELECT request_ref, request_type, created_at
FROM service_demo.service_requests
WHERE created_at >= now() - INTERVAL '7 days' AND created_at < now()
ORDER BY created_at DESC;

-- 13. Open requests ranked within locality.
SELECT locality_code, request_ref, priority,
       ROW_NUMBER() OVER (PARTITION BY locality_code ORDER BY priority, due_at NULLS LAST) AS local_rank
FROM service_demo.v_open_requests;

-- 14. Localities with no requests.
SELECT l.locality_code, l.locality_name
FROM service_demo.localities l
WHERE NOT EXISTS (SELECT 1 FROM service_demo.service_requests r WHERE r.locality_id = l.locality_id);

-- 15. Resolution proportion by request type.
SELECT request_type,
       COUNT(*) AS total_requests,
       COUNT(*) FILTER (WHERE status = 'resolved') AS resolved,
       ROUND(100.0 * COUNT(*) FILTER (WHERE status = 'resolved') / NULLIF(COUNT(*), 0), 2) AS resolved_pct
FROM service_demo.service_requests WHERE is_deleted = FALSE
GROUP BY request_type ORDER BY resolved_pct DESC NULLS LAST;

-- 16. Unresolved requests grouped into age ranges.
SELECT CASE WHEN age_hours < 24 THEN 'under_24h'
            WHEN age_hours < 168 THEN '1_to_7d'
            ELSE 'over_7d' END AS age_bucket,
       COUNT(*) AS request_count
FROM service_demo.v_open_requests GROUP BY 1 ORDER BY 1;

-- 17. Same locality and type volume.
SELECT locality_code, request_type, COUNT(*) AS issue_count
FROM service_demo.v_open_requests GROUP BY locality_code, request_type
ORDER BY issue_count DESC, locality_code;

-- 18. Repeated request types in a locality (aggregate signal, not duplicate proof).
SELECT locality_code, request_type, COUNT(*) AS open_count
FROM service_demo.v_open_requests
GROUP BY locality_code, request_type HAVING COUNT(*) > 1;

-- 19. Resolved requests missing a note are a data quality exception.
SELECT request_ref FROM service_demo.service_requests
WHERE status = 'resolved' AND NULLIF(btrim(description), '') IS NULL;

-- 20. Weekly intake trends.
SELECT date_trunc('week', created_at AT TIME ZONE 'UTC') AS utc_week, COUNT(*) AS opened
FROM service_demo.service_requests GROUP BY 1 ORDER BY 1;