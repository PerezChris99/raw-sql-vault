-- Purpose: inspect open-ticket and event-history query plans.
-- Engine: PostgreSQL 15+. Run after representative synthetic data is loaded.
ANALYZE ug_support.tickets;
ANALYZE ug_support.ticket_events;
EXPLAIN (COSTS, VERBOSE)
SELECT ticket_ref,priority,opened_at FROM ug_support.tickets WHERE status NOT IN ('resolved','closed') ORDER BY opened_at;
EXPLAIN (COSTS, VERBOSE)
SELECT ticket_id,occurred_at FROM ug_support.ticket_events WHERE ticket_id=1 ORDER BY occurred_at DESC,event_id DESC;
