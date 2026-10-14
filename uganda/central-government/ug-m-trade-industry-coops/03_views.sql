CREATE OR REPLACE VIEW trade_demo.v_application_summary AS
SELECT p.programme_code,p.service_type,a.application_ref,a.status,ar.business_type,ar.sector_code,ar.locality_code,a.submitted_at
FROM trade_demo.applications a JOIN trade_demo.programmes p USING(programme_id) JOIN trade_demo.applicant_refs ar USING(applicant_id);
CREATE OR REPLACE VIEW trade_demo.v_open_milestones AS
SELECT m.milestone_ref,a.application_ref,p.programme_code,m.milestone_type,m.owner_ref,m.due_date,m.status,m.summary
FROM trade_demo.milestones m JOIN trade_demo.applications a USING(application_id) JOIN trade_demo.programmes p USING(programme_id)
WHERE m.status NOT IN('completed','cancelled');
CREATE OR REPLACE VIEW trade_demo.v_overdue_milestones AS SELECT * FROM trade_demo.v_open_milestones WHERE due_date<CURRENT_DATE;