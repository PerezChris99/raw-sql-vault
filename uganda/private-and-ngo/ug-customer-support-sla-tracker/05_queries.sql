-- Purpose: support backlog, SLA and category analysis.
-- Engine: PostgreSQL 15+. Prerequisites: schema, seed and views.
-- 01. Active ticket queue and SLA flags.
SELECT * FROM ug_support.v_open_ticket_queue ORDER BY priority DESC,opened_at;
-- 02. Monthly response and resolution SLA totals.
SELECT * FROM ug_support.v_monthly_sla_summary ORDER BY month_start,queue_ref;
-- 03. Ticket event history.
SELECT t.ticket_ref,e.occurred_at,e.event_type,e.from_status,e.to_status,e.actor_ref,e.note_redacted,e.evidence_ref
FROM ug_support.ticket_events e JOIN ug_support.tickets t USING(ticket_id)
ORDER BY t.ticket_ref,e.occurred_at,e.event_id;
-- 04. Categories with most open cases.
SELECT queue_ref,category,COUNT(*) AS open_count
FROM ug_support.tickets t JOIN ug_support.queues q USING(queue_id)
WHERE t.status NOT IN ('resolved','closed') GROUP BY queue_ref,category ORDER BY open_count DESC;
-- 05. Pauses that were never ended and need supervisor review.
SELECT ticket_id,pause_reason,started_at,approved_by_ref,evidence_ref
FROM ug_support.sla_pauses WHERE ended_at IS NULL ORDER BY started_at;
