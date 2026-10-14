-- Purpose: synthetic asset class, authorised asset and remediation finding. Safe to rerun.
-- Engine: PostgreSQL 15+. Prerequisite: 01_schema.sql.
INSERT INTO ug_cyber.asset_classes(class_code,class_name,default_criticality)
VALUES('SYN-SERVER','Synthetic server class','high')
ON CONFLICT(class_code) DO NOTHING;
INSERT INTO ug_cyber.assets(asset_ref,class_id,owner_unit_ref,asset_label_redacted,environment,criticality,data_classification,authorised_inventory_ref)
SELECT 'UGASSET-DEMO-01',class_id,'SYN-UNIT-01','Synthetic reporting server','staging','high','internal','SYN-ASSET-AUTH-001'
FROM ug_cyber.asset_classes WHERE class_code='SYN-SERVER'
ON CONFLICT(asset_ref) DO NOTHING;
INSERT INTO ug_cyber.findings(finding_ref,asset_id,source_ref,category,severity,summary_redacted,remediation_due,owner_ref)
SELECT 'UGFIND-DEMO-001',asset_id,'SYN-AUTHORISED-SCAN-001','patching','medium','Synthetic patch-level review finding',CURRENT_DATE+14,'SYN-SECURITY-OWNER'
FROM ug_cyber.assets WHERE asset_ref='UGASSET-DEMO-01'
ON CONFLICT(finding_ref) DO NOTHING;
