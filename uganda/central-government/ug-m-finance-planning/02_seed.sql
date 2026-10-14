INSERT INTO finance_demo.budget_lines(budget_line_code,vote_code,programme_code,fiscal_year_start,approved_ceiling_ugx) VALUES
('DEMO-BUD-001','DEMO-VOTE-A','DEMO-PROG-HEALTH',2026,1000000000),
('DEMO-BUD-002','DEMO-VOTE-B','DEMO-PROG-EDU',2026,650000000),
('DEMO-BUD-003','DEMO-VOTE-C','DEMO-PROG-WORKS',2026,400000000)
ON CONFLICT(budget_line_code) DO NOTHING;
SELECT finance_demo.fn_record_release('DEMO-REL-001','DEMO-BUD-001',DATE '2026-08-15',250000000,'DEMO-AUTH-001','SEED-REL-001');
SELECT finance_demo.fn_record_release('DEMO-REL-002','DEMO-BUD-001',DATE '2026-10-05',100000000,'DEMO-AUTH-002','SEED-REL-002');
SELECT finance_demo.fn_record_release('DEMO-REL-003','DEMO-BUD-002',DATE '2026-09-12',180000000,'DEMO-AUTH-003','SEED-REL-003');
SELECT finance_demo.fn_record_expenditure('DEMO-EXP-001','DEMO-BUD-001',DATE '2026-09-01',70000000,'goods','DEMO-VOUCHER-001','SEED-EXP-001');
SELECT finance_demo.fn_record_expenditure('DEMO-EXP-002','DEMO-BUD-001',DATE '2026-10-08',35000000,'services','DEMO-VOUCHER-002','SEED-EXP-002');
SELECT finance_demo.fn_record_expenditure('DEMO-EXP-003','DEMO-BUD-002',DATE '2026-10-11',55000000,'goods','DEMO-VOUCHER-003','SEED-EXP-003');