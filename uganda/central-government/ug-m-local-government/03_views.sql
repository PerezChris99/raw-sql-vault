-- Consistent budget execution and overdue programme reports.
CREATE OR REPLACE VIEW lgmin_demo.v_budget_execution AS
SELECT p.programme_ref,p.title,a.authority_code,p.fiscal_year,p.status,
 p.approved_ugx,p.released_ugx,p.spent_ugx,p.released_ugx-p.spent_ugx AS released_unspent_ugx,
 ROUND(100*p.spent_ugx/NULLIF(p.released_ugx,0),2) AS release_utilisation_pct
FROM lgmin_demo.programmes p JOIN lgmin_demo.authorities a USING(authority_id)
WHERE p.is_deleted=FALSE;
CREATE OR REPLACE VIEW lgmin_demo.v_overdue_programmes AS
SELECT b.* FROM lgmin_demo.v_budget_execution b
JOIN lgmin_demo.programmes p USING(programme_ref)
WHERE p.target_date<CURRENT_DATE AND p.status NOT IN('completed','cancelled');
COMMENT ON VIEW lgmin_demo.v_overdue_programmes IS 'A due-date monitoring signal, not a formal compliance finding.';