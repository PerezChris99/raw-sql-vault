-- Purpose: hierarchy and current-unit reporting views.
-- Engine: PostgreSQL 15+. Prerequisite: 01_schema.sql. Rerunnable: yes.
CREATE OR REPLACE VIEW ug_admin_ref.v_current_units AS
SELECT u.admin_unit_id,u.unit_code,u.unit_name,u.unit_level,u.parent_admin_unit_id,
       p.unit_code AS parent_unit_code,p.unit_name AS parent_unit_name,
       u.valid_from,u.source_reference,u.is_verified
FROM ug_admin_ref.admin_units u
LEFT JOIN ug_admin_ref.admin_units p ON p.admin_unit_id=u.parent_admin_unit_id
WHERE u.valid_to IS NULL;

CREATE OR REPLACE VIEW ug_admin_ref.v_unit_tree AS
WITH RECURSIVE tree AS (
    SELECT u.admin_unit_id,u.unit_code,u.unit_name,u.unit_level,u.parent_admin_unit_id,
           0 AS depth,ARRAY[u.admin_unit_id] AS path, u.unit_code::TEXT AS code_path
    FROM ug_admin_ref.admin_units u
    WHERE u.parent_admin_unit_id IS NULL AND u.valid_to IS NULL
    UNION ALL
    SELECT c.admin_unit_id,c.unit_code,c.unit_name,c.unit_level,c.parent_admin_unit_id,
           t.depth+1,t.path||c.admin_unit_id,t.code_path||' / '||c.unit_code
    FROM ug_admin_ref.admin_units c
    JOIN tree t ON c.parent_admin_unit_id=t.admin_unit_id
    WHERE c.valid_to IS NULL AND NOT c.admin_unit_id=ANY(t.path)
)
SELECT admin_unit_id,unit_code,unit_name,unit_level,parent_admin_unit_id,depth,code_path
FROM tree;
