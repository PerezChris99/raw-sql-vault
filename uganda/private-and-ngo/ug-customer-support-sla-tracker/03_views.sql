-- Purpose: first-response and resolution SLA queues with pause durations reported separately.
-- Engine: PostgreSQL 15+. Prerequisite: 01_schema.sql. Rerunnable.
CREATE OR REPLACE VIEW ug_support.v_ticket_sla AS
SELECT t.ticket_ref,q.queue_ref,t.category,t.priority,t.status,t.opened_at,t.first_response_at,t.resolved_at,
 q.first_response_minutes,q.resolution_minutes,
 floor(EXTRACT(EPOCH FROM (COALESCE(t.first_response_at,now())-t.opened_at))/60)::BIGINT AS elapsed_first_response_minutes,
 floor(EXTRACT(EPOCH FROM (COALESCE(t.resolved_at,now())-t.opened_at))/60)::BIGINT AS elapsed_resolution_minutes,
 CASE WHEN t.first_response_at IS NULL AND now()>t.opened_at+make_interval(mins=>q.first_response_minutes) THEN TRUE ELSE FALSE END AS first_response_overdue,
 CASE WHEN t.resolved_at IS NULL AND now()>t.opened_at+make_interval(mins=>q.resolution_minutes) THEN TRUE ELSE FALSE END AS resolution_overdue
FROM ug_support.tickets t JOIN ug_support.queues q USING(queue_id);

CREATE OR REPLACE VIEW ug_support.v_open_ticket_queue AS
SELECT ticket_ref,queue_ref,category,priority,status,opened_at,assigned_to_ref,first_response_overdue,resolution_overdue
FROM ug_support.v_ticket_sla WHERE status NOT IN ('resolved','closed');

CREATE OR REPLACE VIEW ug_support.v_monthly_sla_summary AS
SELECT queue_ref,date_trunc('month',opened_at)::date AS month_start,COUNT(*) AS tickets,
 COUNT(*) FILTER(WHERE first_response_at IS NOT NULL AND first_response_at<=opened_at+make_interval(mins=>first_response_minutes)) AS first_response_within_sla,
 COUNT(*) FILTER(WHERE resolved_at IS NOT NULL AND resolved_at<=opened_at+make_interval(mins=>resolution_minutes)) AS resolved_within_sla,
 COUNT(*) FILTER(WHERE resolved_at IS NULL) AS unresolved
FROM ug_support.v_ticket_sla GROUP BY queue_ref,date_trunc('month',opened_at)::date;
