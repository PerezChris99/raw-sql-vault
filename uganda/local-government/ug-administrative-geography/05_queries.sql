-- Purpose: query examples for reference maintenance and service reporting joins.
-- Engine: PostgreSQL 15+. Prerequisite: 01_schema.sql and 02_seed.sql. Read-only.
-- 01. Current administrative units by level.
SELECT unit_level,COUNT(*) AS unit_count
FROM ug_admin_ref.admin_units WHERE valid_to IS NULL
GROUP BY unit_level ORDER BY unit_level;

-- 02. Current hierarchy, root to leaf.
SELECT depth,unit_level,unit_name,code_path
FROM ug_admin_ref.v_unit_tree ORDER BY code_path;

-- 03. Current children for a parent code.
SELECT c.unit_code,c.unit_name,c.unit_level
FROM ug_admin_ref.admin_units p
JOIN ug_admin_ref.admin_units c ON c.parent_admin_unit_id=p.admin_unit_id
WHERE p.unit_code=$$DEMO-DIST-A$$ AND c.valid_to IS NULL
ORDER BY c.unit_level,c.unit_name;

-- 04. Unverified current records requiring steward review.
SELECT unit_code,unit_name,unit_level,source_reference
FROM ug_admin_ref.admin_units WHERE valid_to IS NULL AND NOT is_verified
ORDER BY unit_level,unit_name;

-- 05. Find missing source references or empty actor-free metadata.
SELECT admin_unit_id,unit_code
FROM ug_admin_ref.admin_units
WHERE source_reference IS NULL OR length(btrim(source_reference))=0;

-- 06. Count active children by parent.
SELECT p.unit_code,p.unit_name,COUNT(c.admin_unit_id) AS active_children
FROM ug_admin_ref.admin_units p
LEFT JOIN ug_admin_ref.admin_units c ON c.parent_admin_unit_id=p.admin_unit_id AND c.valid_to IS NULL
WHERE p.valid_to IS NULL GROUP BY p.admin_unit_id,p.unit_code,p.unit_name
ORDER BY active_children DESC,p.unit_code;

-- 07. List change history for an internal unit code.
SELECT h.recorded_at,h.change_kind,h.change_reason,h.source_reference,h.recorded_by,h.old_values,h.new_values
FROM ug_admin_ref.admin_unit_changes h
JOIN ug_admin_ref.admin_units u USING(admin_unit_id)
WHERE u.unit_code=$$DEMO-VILLAGE-A$$ ORDER BY h.recorded_at DESC,h.change_id DESC;

-- 08. Ancestors for a selected unit; replace code with an authorised parameter in applications.
SELECT a.* FROM ug_admin_ref.admin_units u
CROSS JOIN LATERAL ug_admin_ref.fn_get_ancestors(u.admin_unit_id) a
WHERE u.unit_code=$$DEMO-VILLAGE-A$$;

-- 09. Current units with an invalid or retired parent (should return zero).
SELECT c.unit_code,c.unit_name,p.unit_code AS parent_code
FROM ug_admin_ref.admin_units c
LEFT JOIN ug_admin_ref.admin_units p ON p.admin_unit_id=c.parent_admin_unit_id
WHERE c.valid_to IS NULL AND c.parent_admin_unit_id IS NOT NULL
  AND (p.admin_unit_id IS NULL OR p.valid_to IS NOT NULL);

-- 10. Effective dates suitable for a review queue.
SELECT unit_code,unit_name,valid_from,valid_to
FROM ug_admin_ref.admin_units
WHERE valid_to IS NOT NULL ORDER BY valid_to DESC,unit_code;
