-- Purpose: synthetic operator, route, stops and schedule fixtures. Safe to rerun.
-- Engine: PostgreSQL 15+. Prerequisite: 01_schema.sql.
INSERT INTO ug_transport.operators(operator_ref,operator_name,operator_type)
VALUES('UGTOP-DEMO-01','Synthetic transport operator','licensed_private')
ON CONFLICT(operator_ref) DO NOTHING;
INSERT INTO ug_transport.routes(route_ref,operator_id,origin_locality_ref,destination_locality_ref,route_name,planned_minutes)
SELECT 'UGTR-DEMO-01',operator_id,'SYN-LOCALITY-01','SYN-LOCALITY-02','Synthetic route Alpha',90
FROM ug_transport.operators WHERE operator_ref='UGTOP-DEMO-01'
ON CONFLICT(route_ref) DO NOTHING;
INSERT INTO ug_transport.stops(stop_ref,locality_ref,stop_name) VALUES
('UGTS-DEMO-01','SYN-LOCALITY-01','Synthetic origin stop'),
('UGTS-DEMO-02','SYN-LOCALITY-02','Synthetic destination stop')
ON CONFLICT(stop_ref) DO NOTHING;
INSERT INTO ug_transport.route_stops(route_id,stop_id,sequence_no,scheduled_offset_minutes)
SELECT r.route_id,s.stop_id,v.seq,v.offset_min FROM ug_transport.routes r
JOIN (VALUES('UGTS-DEMO-01',1,0),('UGTS-DEMO-02',2,90)) v(stop_ref,seq,offset_min) ON TRUE
JOIN ug_transport.stops s ON s.stop_ref=v.stop_ref
WHERE r.route_ref='UGTR-DEMO-01' ON CONFLICT DO NOTHING;
INSERT INTO ug_transport.departure_schedules(schedule_ref,route_id,stop_id,scheduled_at,service_date,vehicle_class)
SELECT 'UGTSCH-DEMO-01',r.route_id,s.stop_id,TIMESTAMPTZ '2026-10-16 07:00:00+03',DATE '2026-10-16','SYN-MINIBUS'
FROM ug_transport.routes r JOIN ug_transport.stops s ON s.stop_ref='UGTS-DEMO-01'
WHERE r.route_ref='UGTR-DEMO-01' ON CONFLICT(schedule_ref) DO NOTHING;
