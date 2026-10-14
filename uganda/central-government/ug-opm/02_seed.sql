-- Purpose: load deterministic fictional offices and programme actions.
-- Engine: PostgreSQL 15+; requires 01_schema.sql.
-- Rerun safety: inserts use stable unique business keys.

INSERT INTO opm_demo.departments(department_code, department_name) VALUES
    ('DEMO-OPM', 'Synthetic Programme Coordination Office'),
    ('DEMO-HEALTH', 'Synthetic Health Programme Office'),
    ('DEMO-EDU', 'Synthetic Education Programme Office'),
    ('DEMO-WORKS', 'Synthetic Works Programme Office')
ON CONFLICT (department_code) DO NOTHING;

INSERT INTO opm_demo.programme_actions
    (reference_code, title, description, sponsor_department_id, owner_department_id, due_date, status, created_by_ref)
SELECT v.reference_code, v.title, v.description, sponsor.department_id, owner.department_id,
       v.due_date, v.status, 'seed-script'
FROM (VALUES
    ('DEMO-ACT-001', 'Publish quarterly service dashboard', 'Compile validated aggregate indicators.', 'DEMO-OPM', 'DEMO-HEALTH', DATE '2027-02-15', 'in_progress'),
    ('DEMO-ACT-002', 'Review school asset inventory', 'Reconcile fictional school asset samples.', 'DEMO-OPM', 'DEMO-EDU', DATE '2027-03-01', 'planned'),
    ('DEMO-ACT-003', 'Validate road maintenance schedule', 'Check fictional work-order dependencies.', 'DEMO-OPM', 'DEMO-WORKS', DATE '2027-01-15', 'blocked'),
    ('DEMO-ACT-004', 'Close prior-quarter action items', 'Resolve action items with accepted evidence.', 'DEMO-OPM', 'DEMO-OPM', DATE '2026-01-31', 'done')
) AS v(reference_code, title, description, sponsor_code, owner_code, due_date, status)
JOIN opm_demo.departments AS sponsor ON sponsor.department_code = v.sponsor_code
JOIN opm_demo.departments AS owner ON owner.department_code = v.owner_code
ON CONFLICT (reference_code) DO NOTHING;