-- 20 read-only PostgreSQL reports. Values are synthetic; interpret only using validated protocols.
-- 01 latest observation per point.
SELECT * FROM water_demo.v_latest_observation ORDER BY locality_code,point_code;
-- 02 unacceptable observations needing review.
SELECT * FROM water_demo.v_latest_observation WHERE outcome='unacceptable';
-- 03 pending/inconclusive observations.
SELECT * FROM water_demo.v_latest_observation WHERE outcome IN('pending','inconclusive');
-- 04 open maintenance queue.
SELECT * FROM water_demo.v_open_maintenance ORDER BY priority DESC,due_date NULLS LAST;
-- 05 overdue maintenance.
SELECT * FROM water_demo.v_overdue_maintenance ORDER BY due_date;
-- 06 latest outcome counts by locality.
SELECT locality_code,outcome,COUNT(*) FROM water_demo.v_latest_observation GROUP BY locality_code,outcome;
-- 07 observation history per point.
SELECT p.point_code,o.observation_ref,o.sampled_at,o.outcome,o.standard_ref,o.reviewer_ref FROM water_demo.water_observations o JOIN water_demo.water_points p USING(point_id) ORDER BY p.point_code,o.sampled_at;
-- 08 maintenance event history.
SELECT j.job_ref,e.previous_status,e.new_status,e.actor_ref,e.happened_at FROM water_demo.maintenance_events e JOIN water_demo.maintenance_jobs j USING(job_id) ORDER BY j.job_ref,e.happened_at;
-- 09 latest job event.
SELECT DISTINCT ON(job_id) job_id,new_status,happened_at FROM water_demo.maintenance_events ORDER BY job_id,happened_at DESC,event_id DESC;
-- 10 active points never sampled.
SELECT p.point_code FROM water_demo.water_points p WHERE is_active AND NOT EXISTS(SELECT 1 FROM water_demo.water_observations o WHERE o.point_id=p.point_id);
-- 11 unreviewed final outcomes (should be empty by constraint).
SELECT observation_ref FROM water_demo.water_observations WHERE outcome<>'pending' AND reviewer_ref IS NULL;
-- 12 sample volume by method and standard.
SELECT method_ref,standard_ref,COUNT(*) FROM water_demo.water_observations GROUP BY method_ref,standard_ref;
-- 13 median synthetic turbidity by source type.
SELECT p.source_type,PERCENTILE_CONT(0.5) WITHIN GROUP(ORDER BY o.turbidity_ntu) AS median_turbidity FROM water_demo.water_observations o JOIN water_demo.water_points p USING(point_id) WHERE o.turbidity_ntu IS NOT NULL GROUP BY p.source_type;
-- 14 median synthetic pH by source type.
SELECT p.source_type,PERCENTILE_CONT(0.5) WITHIN GROUP(ORDER BY o.ph_value) AS median_ph FROM water_demo.water_observations o JOIN water_demo.water_points p USING(point_id) WHERE o.ph_value IS NOT NULL GROUP BY p.source_type;
-- 15 maintenance estimate by locality.
SELECT locality_code,SUM(estimate_ugx) AS estimate_ugx FROM water_demo.v_open_maintenance GROUP BY locality_code;
-- 16 priority-one/five work.
SELECT job_ref,priority,status FROM water_demo.maintenance_jobs WHERE priority IN(1,5) AND is_deleted=FALSE;
-- 17 jobs lacking target dates.
SELECT job_ref FROM water_demo.maintenance_jobs WHERE due_date IS NULL AND status NOT IN('completed','cancelled') AND is_deleted=FALSE;
-- 18 observation intake by UTC month.
SELECT date_trunc('month',received_at AT TIME ZONE 'UTC') AS month_utc,COUNT(*) FROM water_demo.water_observations GROUP BY 1 ORDER BY 1;
-- 19 jobs due within 30 days.
SELECT job_ref,due_date FROM water_demo.v_open_maintenance WHERE due_date>=CURRENT_DATE AND due_date<CURRENT_DATE+30 ORDER BY due_date;
-- 20 points by source type and locality.
SELECT locality_code,source_type,COUNT(*) FROM water_demo.water_points GROUP BY locality_code,source_type ORDER BY 1,2;