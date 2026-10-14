CREATE OR REPLACE VIEW social_demo.v_enrolment_summary AS
SELECT p.programme_code,p.service_type,e.status,COUNT(*) AS enrolment_count
FROM social_demo.enrolments e JOIN social_demo.programmes p USING(programme_id)
GROUP BY p.programme_code,p.service_type,e.status;
CREATE OR REPLACE VIEW social_demo.v_open_milestones AS
SELECT m.milestone_ref,e.enrolment_ref,p.programme_code,m.milestone_type,m.due_date,m.status,m.owner_ref,m.summary
FROM social_demo.service_milestones m JOIN social_demo.enrolments e USING(enrolment_id)
JOIN social_demo.programmes p USING(programme_id)
WHERE m.status NOT IN('completed','cancelled');
CREATE OR REPLACE VIEW social_demo.v_overdue_milestones AS SELECT * FROM social_demo.v_open_milestones WHERE due_date<CURRENT_DATE;