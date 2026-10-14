-- Fictional fixtures; safe to re-run using stable codes and references.
INSERT INTO water_demo.water_points(point_code,point_name,locality_code,source_type,operator_ref,commissioned_on) VALUES
('DEMO-WP-001','Synthetic Hill Borehole','DEMO-LOCALITY-A','borehole','demo-operator-a',DATE '2021-06-01'),
('DEMO-WP-002','Synthetic Market Standpipe','DEMO-LOCALITY-B','standpipe','demo-operator-b',DATE '2022-02-15'),
('DEMO-WP-003','Synthetic Valley Spring','DEMO-LOCALITY-A','protected_spring','demo-operator-a',DATE '2020-09-10')
ON CONFLICT(point_code) DO NOTHING;
INSERT INTO water_demo.water_observations(observation_ref,point_id,sampled_at,method_ref,standard_ref,ph_value,turbidity_ntu,ecoli_cfu_per_100ml,outcome,result_note,reviewer_ref)
SELECT v.ref,p.point_id,v.sampled,v.method,v.standard,v.ph,v.turb,v.ecoli,v.outcome,v.note,CASE WHEN v.outcome='pending' THEN NULL ELSE 'synthetic-reviewer' END
FROM (VALUES
('DEMO-SAMPLE-001','DEMO-WP-001',TIMESTAMPTZ '2026-09-14 09:00:00+00','DEMO-METHOD-A','DEMO-STANDARD-A',7.1::numeric,1.2::numeric,0::numeric,'acceptable','Fictional result for SQL exercises'),
('DEMO-SAMPLE-002','DEMO-WP-002',TIMESTAMPTZ '2026-10-03 11:30:00+00','DEMO-METHOD-A','DEMO-STANDARD-A',6.2::numeric,8.4::numeric,5::numeric,'unacceptable','Fictional result awaiting remedial action'),
('DEMO-SAMPLE-003','DEMO-WP-003',TIMESTAMPTZ '2026-10-10 08:00:00+00','DEMO-METHOD-B','DEMO-STANDARD-B',NULL::numeric,NULL::numeric,NULL::numeric,'pending','Fictional result awaiting laboratory review')
) v(ref,code,sampled,method,standard,ph,turb,ecoli,outcome,note)
JOIN water_demo.water_points p ON p.point_code=v.code
ON CONFLICT(observation_ref) DO NOTHING;
INSERT INTO water_demo.maintenance_jobs(job_ref,point_id,observation_id,summary,status,priority,estimate_ugx,due_date)
SELECT v.ref,p.point_id,o.observation_id,v.summary,v.status,v.priority,v.cost,v.due
FROM (VALUES
('DEMO-WMJ-001','DEMO-WP-002','DEMO-SAMPLE-002','Synthetic source inspection and remediation','planned',5,8500000::numeric,DATE '2026-11-15'),
('DEMO-WMJ-002','DEMO-WP-001','DEMO-SAMPLE-001','Synthetic pump preventive maintenance','in_progress',2,2400000::numeric,DATE '2026-12-15')
) v(ref,code,sample_ref,summary,status,priority,cost,due)
JOIN water_demo.water_points p ON p.point_code=v.code
JOIN water_demo.water_observations o ON o.observation_ref=v.sample_ref
ON CONFLICT(job_ref) DO NOTHING;