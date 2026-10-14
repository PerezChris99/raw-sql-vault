-- Stable fictional roads and work-order examples. Safe to re-run.
INSERT INTO works_demo.road_assets(road_code,road_name,locality_code,road_class,length_metres) VALUES
('DEMO-RD-001','Synthetic North Link','DEMO-AREA-A','district',4200),
('DEMO-RD-002','Synthetic Market Access','DEMO-AREA-B','urban',1250),
('DEMO-RD-003','Synthetic River Approach','DEMO-AREA-A','community',800)
ON CONFLICT(road_code) DO NOTHING;
INSERT INTO works_demo.road_inspections(road_id,observed_at,condition_rating,safety_priority,inspector_ref,observation_note)
SELECT r.road_id,v.observed_at,v.rating,v.priority,'synthetic-inspector',v.note
FROM (VALUES
('DEMO-RD-001',TIMESTAMPTZ '2026-09-15 09:00:00+00','poor',3,'Illustrative surface wear'),
('DEMO-RD-002',TIMESTAMPTZ '2026-10-02 11:00:00+00','critical',5,'Illustrative drainage hazard'),
('DEMO-RD-003',TIMESTAMPTZ '2026-08-20 08:00:00+00','fair',2,'Illustrative routine observation')
) v(code,observed_at,rating,priority,note) JOIN works_demo.road_assets r ON r.road_code=v.code
WHERE NOT EXISTS(SELECT 1 FROM works_demo.road_inspections x WHERE x.road_id=r.road_id AND x.observed_at=v.observed_at);
INSERT INTO works_demo.work_orders(work_order_ref,road_id,inspection_id,summary,status,priority,estimated_cost_ugx,due_date)
SELECT v.ref,r.road_id,i.inspection_id,v.summary,v.status,v.priority,v.cost,v.due_date
FROM (VALUES
('DEMO-WO-001','DEMO-RD-001','Illustrative patch repairs','planned',3,12000000::numeric,DATE '2027-01-31','2026-09-15 09:00:00+00'::timestamptz),
('DEMO-WO-002','DEMO-RD-002','Illustrative urgent drainage intervention','in_progress',5,28000000::numeric,DATE '2026-11-30','2026-10-02 11:00:00+00'::timestamptz),
('DEMO-WO-003','DEMO-RD-003','Illustrative shoulder maintenance','blocked',2,6000000::numeric,DATE '2026-09-15','2026-08-20 08:00:00+00'::timestamptz)
) v(ref,code,summary,status,priority,cost,due_date,inspected_at)
JOIN works_demo.road_assets r ON r.road_code=v.code
JOIN works_demo.road_inspections i ON i.road_id=r.road_id AND i.observed_at=v.inspected_at
ON CONFLICT(work_order_ref) DO NOTHING;