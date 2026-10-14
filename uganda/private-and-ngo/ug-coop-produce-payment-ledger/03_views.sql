-- Purpose: delivery valuation, member balances and payment allocation reports.
-- Engine: PostgreSQL 15+. Prerequisite: 01_schema.sql and 02_seed.sql. Rerunnable.
CREATE OR REPLACE VIEW ug_coop_pay.v_delivery_valuation AS
SELECT d.delivery_id,d.delivery_ref,d.member_ref,p.produce_code,p.produce_name,d.grade_code,d.received_at,
       d.gross_weight_kg,d.accepted_weight_kg,d.status,r.rate_per_kg,r.currency_code,
       ROUND(d.accepted_weight_kg*r.rate_per_kg,2) AS gross_value,
       COALESCE(x.approved_deductions,0)::NUMERIC(14,2) AS approved_deductions,
       GREATEST(ROUND(d.accepted_weight_kg*r.rate_per_kg,2)-COALESCE(x.approved_deductions,0),0)::NUMERIC(14,2) AS net_value
FROM ug_coop_pay.deliveries d
JOIN ug_coop_pay.produce_types p USING(produce_type_id)
LEFT JOIN LATERAL (
 SELECT rr.rate_per_kg,rr.currency_code
 FROM ug_coop_pay.price_rates rr
 WHERE rr.produce_type_id=d.produce_type_id AND rr.grade_code=d.grade_code
   AND d.received_at::date>=rr.valid_from AND (rr.valid_to IS NULL OR d.received_at::date<=rr.valid_to)
 ORDER BY rr.valid_from DESC,rr.price_rate_id DESC LIMIT 1
) r ON TRUE
LEFT JOIN LATERAL (
 SELECT SUM(dd.amount) AS approved_deductions
 FROM ug_coop_pay.deductions dd
 WHERE dd.delivery_id=d.delivery_id AND dd.approved_by IS NOT NULL
) x ON TRUE;

CREATE OR REPLACE VIEW ug_coop_pay.v_delivery_settlement AS
SELECT v.delivery_id,v.delivery_ref,v.member_ref,v.produce_code,v.grade_code,v.received_at,
       v.accepted_weight_kg,v.rate_per_kg,v.currency_code,v.gross_value,v.approved_deductions,v.net_value,
       COALESCE(a.allocated_amount,0)::NUMERIC(14,2) AS allocated_amount,
       (v.net_value-COALESCE(a.allocated_amount,0))::NUMERIC(14,2) AS remaining_balance
FROM ug_coop_pay.v_delivery_valuation v
LEFT JOIN LATERAL (
 SELECT SUM(pa.amount) AS allocated_amount FROM ug_coop_pay.payment_allocations pa
 WHERE pa.delivery_id=v.delivery_id
) a ON TRUE;

CREATE OR REPLACE VIEW ug_coop_pay.v_member_settlement_summary AS
SELECT m.member_ref,m.member_code,
       COALESCE(SUM(s.net_value),0)::NUMERIC(14,2) AS net_produce_value,
       COALESCE(SUM(s.allocated_amount),0)::NUMERIC(14,2) AS amount_allocated,
       COALESCE(SUM(s.remaining_balance),0)::NUMERIC(14,2) AS remaining_balance
FROM ug_coop_pay.members m
LEFT JOIN ug_coop_pay.v_delivery_settlement s USING(member_ref)
GROUP BY m.member_ref,m.member_code;
