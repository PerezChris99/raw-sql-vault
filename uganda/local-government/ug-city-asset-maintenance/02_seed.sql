INSERT INTO city_ops_demo.assets(asset_ref,asset_type,area_code,display_label,condition_state) VALUES
('DEMO-CITY-ASSET-001','drainage','DEMO-AREA-CENTRAL','Synthetic Central Drain','poor'),
('DEMO-CITY-ASSET-002','streetlight','DEMO-AREA-EAST','Synthetic East Streetlight','critical'),
('DEMO-CITY-ASSET-003','market_facility','DEMO-AREA-WEST','Synthetic West Market Facility','fair')
ON CONFLICT(asset_ref) DO NOTHING;
INSERT INTO city_ops_demo.inspections(inspection_ref,asset_id,inspected_at,condition_state,priority,inspector_ref,summary)
SELECT v.ref,a.asset_id,v.at_time,v.state,v.priority,'DEMO-INSPECTOR',v.summary FROM (VALUES
('DEMO-CITY-INSP-001','DEMO-CITY-ASSET-001',TIMESTAMPTZ '2026-09-01 08:00+00','poor',4,'Synthetic drainage maintenance observation'),
('DEMO-CITY-INSP-002','DEMO-CITY-ASSET-002',TIMESTAMPTZ '2026-10-01 10:00+00','critical',5,'Synthetic lighting repair candidate'),
('DEMO-CITY-INSP-003','DEMO-CITY-ASSET-003',TIMESTAMPTZ '2026-08-15 09:00+00','fair',2,'Synthetic routine facility review')
) v(ref,asset,at_time,state,priority,summary) JOIN city_ops_demo.assets a ON a.asset_ref=v.asset ON CONFLICT(inspection_ref) DO NOTHING;
INSERT INTO city_ops_demo.work_orders(work_ref,asset_id,inspection_id,work_type,summary,priority,estimated_cost_ugx,due_date,status)
SELECT v.ref,a.asset_id,i.inspection_id,v.typ,v.summary,v.priority,v.cost,v.due,v.status FROM (VALUES
('DEMO-CITY-WO-001','DEMO-CITY-ASSET-001','DEMO-CITY-INSP-001','cleaning','Synthetic drain clearing',4,1500000::numeric,DATE '2026-11-30','planned'),
('DEMO-CITY-WO-002','DEMO-CITY-ASSET-002','DEMO-CITY-INSP-002','repair','Synthetic light repair',5,850000::numeric,DATE '2026-11-10','in_progress')
) v(ref,asset,insp,typ,summary,priority,cost,due,status) JOIN city_ops_demo.assets a ON a.asset_ref=v.asset JOIN city_ops_demo.inspections i ON i.inspection_ref=v.insp ON CONFLICT(work_ref) DO NOTHING;