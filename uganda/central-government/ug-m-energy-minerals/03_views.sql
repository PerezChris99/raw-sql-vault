CREATE OR REPLACE VIEW energy_demo.v_licence_register AS
SELECT l.licence_ref,h.holder_ref,l.sector,l.issued_on,l.expires_on,l.status,l.region_code,l.public_summary,
 CASE WHEN l.expires_on IS NULL THEN NULL ELSE l.expires_on-CURRENT_DATE END AS days_until_expiry
FROM energy_demo.licences l JOIN energy_demo.licence_holders h USING(holder_id);
CREATE OR REPLACE VIEW energy_demo.v_expiry_watch AS
SELECT * FROM energy_demo.v_licence_register
WHERE status='active' AND expires_on<CURRENT_DATE+INTERVAL '90 days';
CREATE OR REPLACE VIEW energy_demo.v_open_corrective_actions AS
SELECT a.action_ref,i.inspection_ref,l.licence_ref,a.summary,a.status,a.due_date,a.owner_ref
FROM energy_demo.corrective_actions a JOIN energy_demo.inspections i USING(inspection_id)
JOIN energy_demo.licences l USING(licence_id) WHERE a.status NOT IN('closed','cancelled');
CREATE OR REPLACE VIEW energy_demo.v_overdue_actions AS
SELECT * FROM energy_demo.v_open_corrective_actions WHERE due_date<CURRENT_DATE;
