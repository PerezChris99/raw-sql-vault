-- Purpose: deterministic synthetic produce, member, rate, delivery and payment fixtures.
-- Engine: PostgreSQL 15+. Prerequisite: 01_schema.sql. Safe to rerun.
INSERT INTO ug_coop_pay.members(member_ref,member_code)
VALUES ('SYN-MEMBER-001','DEMO-MEM-001'),('SYN-MEMBER-002','DEMO-MEM-002')
ON CONFLICT(member_ref) DO NOTHING;

INSERT INTO ug_coop_pay.produce_types(produce_code,produce_name)
VALUES ('DEMO-COFFEE','Synthetic coffee'),('DEMO-MAIZE','Synthetic maize')
ON CONFLICT(produce_code) DO NOTHING;

INSERT INTO ug_coop_pay.price_rates(produce_type_id,grade_code,valid_from,valid_to,rate_per_kg,currency_code,source_reference,approved_by)
SELECT p.produce_type_id,'A',DATE '2026-01-01',NULL,
       CASE p.produce_code WHEN 'DEMO-COFFEE' THEN 8500.0000 ELSE 1200.0000 END,
       'UGX','SYNTHETIC-RATE-CARD-01','synthetic-approver'
FROM ug_coop_pay.produce_types p
WHERE p.produce_code IN ('DEMO-COFFEE','DEMO-MAIZE')
AND NOT EXISTS (SELECT 1 FROM ug_coop_pay.price_rates r WHERE r.produce_type_id=p.produce_type_id AND r.grade_code='A' AND r.valid_from=DATE '2026-01-01');

INSERT INTO ug_coop_pay.deliveries(delivery_ref,source_ticket_ref,member_ref,produce_type_id,grade_code,received_at,
    gross_weight_kg,accepted_weight_kg,status,scale_reference,recorded_by)
SELECT v.delivery_ref,v.ticket,v.member_ref,p.produce_type_id,'A',TIMESTAMPTZ '2026-02-01 08:00:00+03',
       v.gross,v.accepted,v.status,'SYNTHETIC-SCALE-01','synthetic-seed'
FROM (VALUES
 ('UGD-DEMO-0001','TICKET-DEMO-001','SYN-MEMBER-001','DEMO-COFFEE',50.000::numeric,50.000::numeric,'accepted'),
 ('UGD-DEMO-0002','TICKET-DEMO-002','SYN-MEMBER-001','DEMO-MAIZE',100.000::numeric,90.000::numeric,'partially_accepted'),
 ('UGD-DEMO-0003','TICKET-DEMO-003','SYN-MEMBER-002','DEMO-COFFEE',20.000::numeric,0.000::numeric,'rejected')
) AS v(delivery_ref,ticket,member_ref,produce_code,gross,accepted,status)
JOIN ug_coop_pay.produce_types p ON p.produce_code=v.produce_code
ON CONFLICT(delivery_ref) DO NOTHING;

INSERT INTO ug_coop_pay.delivery_events(delivery_id,event_type,reason,source_reference,recorded_by)
SELECT d.delivery_id,'received','Synthetic delivery fixture',d.source_ticket_ref,'synthetic-seed'
FROM ug_coop_pay.deliveries d
WHERE d.delivery_ref LIKE 'UGD-DEMO-%'
AND NOT EXISTS (SELECT 1 FROM ug_coop_pay.delivery_events e WHERE e.delivery_id=d.delivery_id AND e.event_type='received');
