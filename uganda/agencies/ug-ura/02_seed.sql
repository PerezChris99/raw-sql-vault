INSERT INTO ura_demo.tax_accounts(taxpayer_ref,account_type,registered_area_code) VALUES
('DEMO-TAXPAYER-A','business_demo','DEMO-AREA-A'),
('DEMO-TAXPAYER-B','individual_demo','DEMO-AREA-B'),
('DEMO-TAXPAYER-C','institution_demo','DEMO-AREA-A')
ON CONFLICT(taxpayer_ref) DO NOTHING;
INSERT INTO ura_demo.filings(filing_ref,account_id,tax_type,period_start,period_end,revision_no,filed_at,declared_payable,assessed_payable,currency,status,source_document_ref)
SELECT v.ref,a.account_id,v.tax_type,v.ps,v.pe,v.revision,v.filed,v.declared,v.assessed,'UGX',v.status,v.source
FROM (VALUES
('DEMO-FILING-001','DEMO-TAXPAYER-A','vat_demo',DATE '2026-07-01',DATE '2026-07-31',1,TIMESTAMPTZ '2026-08-10 08:00:00+00',2500000::numeric,2600000::numeric,'assessed','DEMO-SOURCE-001'),
('DEMO-FILING-002','DEMO-TAXPAYER-B','income_demo',DATE '2026-07-01',DATE '2026-12-31',1,TIMESTAMPTZ '2026-10-01 09:00:00+00',420000::numeric,420000::numeric,'filed','DEMO-SOURCE-002'),
('DEMO-FILING-003','DEMO-TAXPAYER-C','withholding_demo',DATE '2026-08-01',DATE '2026-08-31',1,TIMESTAMPTZ '2026-09-12 10:00:00+00',780000::numeric,700000::numeric,'disputed','DEMO-SOURCE-003')
) v(ref,taxpayer_ref,tax_type,ps,pe,revision,filed,declared,assessed,status,source)
JOIN ura_demo.tax_accounts a ON a.taxpayer_ref=v.taxpayer_ref
ON CONFLICT(filing_ref) DO NOTHING;
INSERT INTO ura_demo.filing_events(filing_id,previous_status,new_status,note,actor_ref)
SELECT f.filing_id,NULL,f.status,'Synthetic initial state','seed-script'
FROM ura_demo.filings f
WHERE NOT EXISTS(SELECT 1 FROM ura_demo.filing_events e WHERE e.filing_id=f.filing_id);
