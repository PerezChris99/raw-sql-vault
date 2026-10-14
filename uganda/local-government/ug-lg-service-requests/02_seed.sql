-- Purpose: deterministic synthetic locality/request seed.
-- Engine: PostgreSQL 15+; requires 01_schema.sql.
-- Rerun safety: stable unique codes/references and ON CONFLICT DO NOTHING.

INSERT INTO service_demo.localities(locality_code, locality_name, locality_type)
VALUES
    ('DEMO-DISTRICT-001', 'Synthetic District A', 'district'),
    ('DEMO-CITY-001', 'Synthetic City B', 'city')
ON CONFLICT (locality_code) DO NOTHING;

INSERT INTO service_demo.localities(locality_code, locality_name, locality_type, parent_locality_id)
SELECT 'DEMO-PARISH-001', 'Synthetic Parish North', 'parish', locality_id
FROM service_demo.localities WHERE locality_code = 'DEMO-DISTRICT-001'
ON CONFLICT (locality_code) DO NOTHING;

INSERT INTO service_demo.localities(locality_code, locality_name, locality_type, parent_locality_id)
SELECT 'DEMO-DIVISION-001', 'Synthetic City Division East', 'division', locality_id
FROM service_demo.localities WHERE locality_code = 'DEMO-CITY-001'
ON CONFLICT (locality_code) DO NOTHING;

INSERT INTO service_demo.service_requests
    (request_ref, request_type, description, locality_id, priority, status, reporter_ref, due_at, resolved_at)
SELECT v.request_ref, v.request_type, v.description, l.locality_id, v.priority, v.status,
       v.reporter_ref, v.due_at, v.resolved_at
FROM (VALUES
    ('DEMO-SR-001', 'drainage', 'Synthetic drainage blockage near a public road.', 'DEMO-PARISH-001', 2, 'new', NULL::text, now() - INTERVAL '2 days', NULL::timestamptz),
    ('DEMO-SR-002', 'road_defect', 'Synthetic road surface defect for inspection.', 'DEMO-DISTRICT-001', 1, 'triaged', 'opaque-reporter-a', now() - INTERVAL '1 day', NULL::timestamptz),
    ('DEMO-SR-003', 'waste', 'Synthetic missed public collection point.', 'DEMO-DIVISION-001', 3, 'in_progress', NULL::text, now() + INTERVAL '2 days', NULL::timestamptz),
    ('DEMO-SR-004', 'streetlight', 'Synthetic streetlight fault; no residence details.', 'DEMO-CITY-001', 4, 'resolved', NULL::text, now() - INTERVAL '20 days', now() - INTERVAL '4 days')
) AS v(request_ref, request_type, description, locality_code, priority, status, reporter_ref, due_at, resolved_at)
JOIN service_demo.localities l ON l.locality_code = v.locality_code
ON CONFLICT (request_ref) DO NOTHING;