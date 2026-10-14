CREATE OR REPLACE VIEW water_demo.v_latest_observation AS
SELECT DISTINCT ON(p.point_id) p.point_code,p.point_name,p.locality_code,p.source_type,
 o.observation_ref,o.sampled_at,o.outcome,o.method_ref,o.standard_ref,o.result_note,o.reviewer_ref
FROM water_demo.water_points p LEFT JOIN water_demo.water_observations o USING(point_id)
WHERE p.is_active=TRUE ORDER BY p.point_id,o.sampled_at DESC NULLS LAST,o.observation_id DESC;
CREATE OR REPLACE VIEW water_demo.v_open_maintenance AS
SELECT j.job_ref,p.point_code,p.point_name,p.locality_code,j.summary,j.status,j.priority,j.estimate_ugx,j.due_date
FROM water_demo.maintenance_jobs j JOIN water_demo.water_points p USING(point_id)
WHERE j.is_deleted=FALSE AND j.status NOT IN('completed','cancelled');
CREATE OR REPLACE VIEW water_demo.v_overdue_maintenance AS
SELECT * FROM water_demo.v_open_maintenance WHERE due_date<CURRENT_DATE;
COMMENT ON VIEW water_demo.v_latest_observation IS 'Latest entered observation metadata; not a universal water-safety determination.';