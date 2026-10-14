-- Purpose: document index rationale and safe plan inspection.
-- Engine: PostgreSQL 15+. Prerequisite: 01_schema.sql. Rerunnable: yes.
-- Indexes below are created with the schema so they are available before query review.
-- Parent/level supports hierarchy browsing; partial lower(name) supports current name lookup;
-- validity supports effective-date reports; event history supports per-unit newest-first audit.
ANALYZE ug_admin_ref.admin_units;
ANALYZE ug_admin_ref.admin_unit_changes;
EXPLAIN (COSTS, VERBOSE)
SELECT admin_unit_id,unit_code,unit_name
FROM ug_admin_ref.admin_units
WHERE parent_admin_unit_id=1 AND valid_to IS NULL
ORDER BY unit_level,unit_name;
-- Use EXPLAIN (ANALYZE, BUFFERS) only in a disposable environment with representative synthetic data.
-- Do not infer production performance from the tiny seed fixture.
