-- Purpose: synthetic aid programme, recipient token and authorisation fixtures. Safe to rerun.
-- Engine: PostgreSQL 15+. Prerequisite: 01_schema.sql.
INSERT INTO ug_aid.programmes(programme_ref,sponsor_ref,programme_name,assistance_type,period_start,period_end,status)
VALUES('UGAID-P-DEMO-01','SYN-SPONSOR-01','Synthetic household essentials support','food',DATE '2026-10-01',DATE '2026-12-31','active')
ON CONFLICT(programme_ref) DO NOTHING;
INSERT INTO ug_aid.recipients(recipient_token,locality_ref,registration_source_ref,consent_or_authority_ref)
VALUES('SYN-AID-RECIPIENT-001','SYN-LOCALITY-01','SYN-REGISTRATION-SOURCE-001','SYN-AUTHORITY-001')
ON CONFLICT(recipient_token) DO NOTHING;
INSERT INTO ug_aid.authorisations(authorisation_ref,programme_id,recipient_id,assistance_period,quantity,unit_code,decision,decision_by_ref,decision_reason_redacted,evidence_ref)
SELECT 'UGAID-A-DEMO-001',p.programme_id,r.recipient_id,DATE '2026-10-01',1,'package','approved','SYN-CASE-REVIEWER','Synthetic human-reviewed authorisation','SYN-AUTHORISATION-EVIDENCE-001'
FROM ug_aid.programmes p CROSS JOIN ug_aid.recipients r
WHERE p.programme_ref='UGAID-P-DEMO-01' AND r.recipient_token='SYN-AID-RECIPIENT-001'
ON CONFLICT(authorisation_ref) DO NOTHING;
