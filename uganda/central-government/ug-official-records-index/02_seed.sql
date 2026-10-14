-- Purpose: synthetic office, retention category and record metadata fixtures.
-- Engine: PostgreSQL 15+. Prerequisite: 01_schema.sql. Safe to rerun.
INSERT INTO ug_records.offices(office_ref,office_name,locality_ref) VALUES
('UGOFF-DEMO-01','Synthetic originating office','SYN-LOCALITY-01'),
('UGOFF-DEMO-02','Synthetic records custody office','SYN-LOCALITY-02')
ON CONFLICT(office_ref) DO NOTHING;
INSERT INTO ug_records.record_categories(category_code,category_name,retention_months,disposal_authority_ref,classification_default,requires_disposition_approval)
VALUES('SYN-MINUTES','Synthetic meeting minutes',120,'SYN-RETENTION-AUTHORITY','internal',TRUE)
ON CONFLICT(category_code) DO NOTHING;
INSERT INTO ug_records.records(record_ref,category_id,originating_office_id,current_custodian_office_id,external_reference,title_redacted,document_object_ref,sha256_hex,classification,received_on,retention_until,created_by_ref)
SELECT 'UGREC-DEMO-001',c.category_id,o.office_id,o.office_id,'SYN-REF-001','Synthetic committee minutes metadata',
 'SECURE-OBJECT-REF-001',repeat('a',64),'internal',DATE '2026-01-10',DATE '2036-01-10','SYN-RECORDS-CLERK'
FROM ug_records.record_categories c CROSS JOIN ug_records.offices o
WHERE c.category_code='SYN-MINUTES' AND o.office_ref='UGOFF-DEMO-01'
ON CONFLICT(record_ref) DO NOTHING;
