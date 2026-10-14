-- Purpose: synthetic route, service point and shift fixtures. Safe to rerun.
-- Engine: PostgreSQL 15+. Prerequisite: 01_schema.sql.
INSERT INTO ug_waste.service_areas(area_ref,locality_ref,area_name)
VALUES('UGWA-DEMO-01','SYN-LOCALITY-01','Synthetic service area Alpha')
ON CONFLICT(area_ref) DO NOTHING;
INSERT INTO ug_waste.routes(route_ref,area_id,route_name,route_type,planned_minutes)
SELECT 'UGWR-DEMO-01',area_id,'Synthetic mixed collection route','mixed',240
FROM ug_waste.service_areas WHERE area_ref='UGWA-DEMO-01'
ON CONFLICT(route_ref) DO NOTHING;
INSERT INTO ug_waste.route_stops(route_id,stop_ref,sequence_no,locality_ref,service_point_token)
SELECT route_id,v.stop_ref,v.seq,'SYN-LOCALITY-01',v.token FROM ug_waste.routes
CROSS JOIN (VALUES('UGWS-DEMO-01',1,'SYN-SERVICE-POINT-01'),('UGWS-DEMO-02',2,'SYN-SERVICE-POINT-02')) v(stop_ref,seq,token)
WHERE route_ref='UGWR-DEMO-01' ON CONFLICT(stop_ref) DO NOTHING;
INSERT INTO ug_waste.shifts(shift_ref,route_id,vehicle_ref,crew_ref,planned_start,planned_end)
SELECT 'UGW-SH-DEMO-01',route_id,'SYN-VEHICLE-01','SYN-CREW-01',
 TIMESTAMPTZ '2026-10-16 06:00:00+03',TIMESTAMPTZ '2026-10-16 10:00:00+03'
FROM ug_waste.routes WHERE route_ref='UGWR-DEMO-01'
ON CONFLICT(shift_ref) DO NOTHING;
