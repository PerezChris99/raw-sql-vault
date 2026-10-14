-- Purpose: synthetic support queue and ticket. Safe to rerun.
-- Engine: PostgreSQL 15+. Prerequisite: 01_schema.sql.
INSERT INTO ug_support.queues(queue_ref,queue_name,first_response_minutes,resolution_minutes,business_calendar_ref)
VALUES('UGSUPQ-DEMO-01','Synthetic SME service desk',240,2880,'SYN-CALENDAR-UG-01')
ON CONFLICT(queue_ref) DO NOTHING;
INSERT INTO ug_support.tickets(ticket_ref,idempotency_key,queue_id,customer_ref,category,priority,subject_redacted,description_redacted,source_ref)
SELECT 'UGTKT-DEMO-001','support-ticket-demo-001',queue_id,'SYN-CUSTOMER-01','delivery','normal',
 'Synthetic delivery status request','Synthetic issue description without contact or payment data','SYN-CHANNEL-01'
FROM ug_support.queues WHERE queue_ref='UGSUPQ-DEMO-01'
ON CONFLICT(ticket_ref) DO NOTHING;
INSERT INTO ug_support.ticket_events(ticket_id,event_type,to_status,actor_ref,note_redacted)
SELECT ticket_id,'opened','open','SYN-SUPPORT-AGENT','Synthetic ticket opened'
FROM ug_support.tickets WHERE ticket_ref='UGTKT-DEMO-001'
AND NOT EXISTS(SELECT 1 FROM ug_support.ticket_events e WHERE e.ticket_id=ug_support.tickets.ticket_id AND e.event_type='opened');
