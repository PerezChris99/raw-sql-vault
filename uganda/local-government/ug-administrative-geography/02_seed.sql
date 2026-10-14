-- Purpose: deterministic synthetic fixtures; no real administrative codes or claims.
-- Engine: PostgreSQL 15+. Prerequisite: 01_schema.sql. Rerunnable: yes.
INSERT INTO ug_admin_ref.admin_units(unit_code,unit_name,unit_level,parent_admin_unit_id,valid_from,source_reference,is_verified)
VALUES
 ('DEMO-DIST-A','Synthetic District Alpha','district',NULL,DATE '2020-01-01','SYNTHETIC-FIXTURE',FALSE),
 ('DEMO-CITY-A','Synthetic City Alpha','city',NULL,DATE '2020-01-01','SYNTHETIC-FIXTURE',FALSE)
ON CONFLICT(unit_code) DO NOTHING;

INSERT INTO ug_admin_ref.admin_units(unit_code,unit_name,unit_level,parent_admin_unit_id,valid_from,source_reference,is_verified)
SELECT v.code,v.name,v.level,p.admin_unit_id,DATE '2020-01-01','SYNTHETIC-FIXTURE',FALSE
FROM (VALUES
 ('DEMO-COUNTY-A','Synthetic County Alpha','county','DEMO-DIST-A'),
 ('DEMO-SUBCOUNTY-A','Synthetic Sub-county Alpha','sub_county','DEMO-COUNTY-A'),
 ('DEMO-MUNI-A','Synthetic Municipality Alpha','municipality','DEMO-DIST-A'),
 ('DEMO-DIVISION-A','Synthetic Division Alpha','division','DEMO-CITY-A'),
 ('DEMO-PARISH-A','Synthetic Parish Alpha','parish','DEMO-SUBCOUNTY-A'),
 ('DEMO-WARD-A','Synthetic Ward Alpha','ward','DEMO-DIVISION-A'),
 ('DEMO-VILLAGE-A','Synthetic Village Alpha','village','DEMO-PARISH-A'),
 ('DEMO-CELL-A','Synthetic Cell Alpha','cell','DEMO-WARD-A')
) AS v(code,name,level,parent_code)
JOIN ug_admin_ref.admin_units p ON p.unit_code=v.parent_code
ON CONFLICT(unit_code) DO NOTHING;
