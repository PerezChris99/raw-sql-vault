-- Purpose: distinguish unknown scores from genuinely low scores.
-- Engine: PostgreSQL 15+; depends on sql/fixes/00_demo_schema.sql.
-- Rerun safety: CREATE OR REPLACE VIEW.
-- Thresholds are teaching examples, not a validated credit/benefit/eligibility model.

CREATE OR REPLACE VIEW vault_demo.v_customer_score_banded AS
SELECT
    c.customer_id,
    c.display_name,
    c.score,
    CASE
        WHEN c.score IS NULL THEN 'unknown'
        WHEN c.score >= 80 THEN 'excellent'
        WHEN c.score >= 50 THEN 'good'
        WHEN c.score >= 20 THEN 'at_risk'
        ELSE 'low_score'
    END AS score_band
FROM vault_demo.customers AS c
WHERE c.is_deleted = FALSE;

COMMENT ON VIEW vault_demo.v_customer_score_banded IS
    'NULL scores remain unknown; downstream decisions must not treat unknown as zero or low.';