-- Stable fictional references; re-runnable on PostgreSQL 15+.
INSERT INTO lgmin_demo.authorities(authority_code,authority_name,authority_level) VALUES
('DEMO-DISTRICT-A','Synthetic District Authority A','district'),
('DEMO-MUNICIPALITY-A','Synthetic Municipal Authority A','municipality')
ON CONFLICT(authority_code) DO NOTHING;
INSERT INTO lgmin_demo.programmes(programme_ref,title,authority_id,fiscal_year,approved_ugx,released_ugx,spent_ugx,target_date,status,summary)
SELECT v.ref,v.title,a.authority_id,v.fy,v.approved,v.released,v.spent,v.target,v.status,v.summary
FROM (VALUES
('DEMO-LG-PROG-001','Synthetic parish access programme','DEMO-DISTRICT-A',2027,100000000::numeric,20000000::numeric,5000000::numeric,DATE '2027-06-30','planned','Drainage/footpath demo'),
('DEMO-LG-PROG-002','Synthetic market sanitation plan','DEMO-MUNICIPALITY-A',2027,65000000::numeric,40000000::numeric,18000000::numeric,DATE '2027-03-31','active','Public market demo'),
('DEMO-LG-PROG-003','Synthetic water point repair plan','DEMO-DISTRICT-A',2026,30000000::numeric,15000000::numeric,4000000::numeric,DATE '2026-09-30','blocked','Awaiting illustrative procurement milestone')
) AS v(ref,title,authority_code,fy,approved,released,spent,target,status,summary)
JOIN lgmin_demo.authorities a ON a.authority_code=v.authority_code
ON CONFLICT(programme_ref) DO NOTHING;