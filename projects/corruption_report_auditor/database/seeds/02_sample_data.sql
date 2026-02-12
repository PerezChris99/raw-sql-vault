-- ============================================================================
-- Corruption Report Auditor - Sample Data
-- Description: Sample reports for testing temporal analytics
-- Note: Uses relative dates for realistic temporal analysis
-- ============================================================================

-- Get status IDs dynamically
DO $$
DECLARE
    v_open UUID;
    v_under_review UUID;
    v_investigation UUID;
    v_pending_evidence UUID;
    v_escalated UUID;
    v_resolved UUID;
    v_dismissed UUID;
    
    v_bribery UUID;
    v_embezzlement UUID;
    v_fraud UUID;
    v_procurement UUID;
    v_ghost_employees UUID;
    v_nepotism UUID;
    v_kickbacks UUID;
    v_abuse UUID;
    
    v_citizen UUID;
    v_govt_employee UUID;
    v_anonymous UUID;
    v_ngo UUID;
    
    v_acc UUID := '11111111-1111-1111-1111-111111111111';
    v_mof UUID := '22222222-2222-2222-2222-222222222222';
    v_moi UUID := '33333333-3333-3333-3333-333333333333';
    v_moh UUID := '44444444-4444-4444-4444-444444444444';
    v_moe UUID := '55555555-5555-5555-5555-555555555555';
    v_ra UUID := '88888888-8888-8888-8888-888888888888';
    
    v_officer1 UUID := 'aaaa1111-1111-1111-1111-111111111111';
    v_officer2 UUID := 'aaaa2222-2222-2222-2222-222222222222';
    v_officer3 UUID := 'aaaa3333-3333-3333-3333-333333333333';
    v_officer4 UUID := 'aaaa4444-4444-4444-4444-444444444444';
    v_officer5 UUID := 'aaaa5555-5555-5555-5555-555555555555';
    
BEGIN
    -- Get status IDs
    SELECT status_id INTO v_open FROM statuses WHERE name = 'open';
    SELECT status_id INTO v_under_review FROM statuses WHERE name = 'under_review';
    SELECT status_id INTO v_investigation FROM statuses WHERE name = 'investigation';
    SELECT status_id INTO v_pending_evidence FROM statuses WHERE name = 'pending_evidence';
    SELECT status_id INTO v_escalated FROM statuses WHERE name = 'escalated';
    SELECT status_id INTO v_resolved FROM statuses WHERE name = 'resolved';
    SELECT status_id INTO v_dismissed FROM statuses WHERE name = 'dismissed';
    
    -- Get category IDs
    SELECT category_id INTO v_bribery FROM categories WHERE name = 'Bribery';
    SELECT category_id INTO v_embezzlement FROM categories WHERE name = 'Embezzlement';
    SELECT category_id INTO v_fraud FROM categories WHERE name = 'Fraud';
    SELECT category_id INTO v_procurement FROM categories WHERE name = 'Procurement Irregularities';
    SELECT category_id INTO v_ghost_employees FROM categories WHERE name = 'Ghost Employees';
    SELECT category_id INTO v_nepotism FROM categories WHERE name = 'Nepotism';
    SELECT category_id INTO v_kickbacks FROM categories WHERE name = 'Kickbacks';
    SELECT category_id INTO v_abuse FROM categories WHERE name = 'Abuse of Authority';
    
    -- Get complainant type IDs
    SELECT complainant_type_id INTO v_citizen FROM complainant_types WHERE name = 'Citizen';
    SELECT complainant_type_id INTO v_govt_employee FROM complainant_types WHERE name = 'Government Employee';
    SELECT complainant_type_id INTO v_anonymous FROM complainant_types WHERE name = 'Anonymous';
    SELECT complainant_type_id INTO v_ngo FROM complainant_types WHERE name = 'NGO';
    
    -- ============================================================================
    -- Insert Sample Reports (Mix of statuses, dates, and categories)
    -- ============================================================================
    
    -- Recent open cases (last 30 days)
    INSERT INTO reports (department_id, category_id, status_id, complainant_type_id, assigned_to, reported_date, incident_date, title, description, priority, estimated_amount, is_anonymous, location) VALUES
    (v_mof, v_embezzlement, v_open, v_govt_employee, v_officer5, CURRENT_TIMESTAMP - INTERVAL '2 days', CURRENT_DATE - INTERVAL '30 days', 'Missing funds in development budget', 'Approximately 5 million shillings cannot be accounted for in the FY2025 development budget allocation for road maintenance.', 1, 5000000, FALSE, 'Finance Headquarters'),
    (v_moi, v_procurement, v_under_review, v_citizen, v_officer3, CURRENT_TIMESTAMP - INTERVAL '5 days', CURRENT_DATE - INTERVAL '60 days', 'Irregular road construction tender', 'The tender for the Northern Highway reconstruction was awarded without proper evaluation of bids.', 2, 150000000, FALSE, 'Northern Region'),
    (v_moh, v_kickbacks, v_open, v_anonymous, v_officer4, CURRENT_TIMESTAMP - INTERVAL '7 days', CURRENT_DATE - INTERVAL '45 days', 'Medical equipment procurement kickbacks', 'Hospital administrator allegedly receiving 15% commissions on medical equipment purchases.', 1, 25000000, TRUE, 'Central Hospital'),
    (v_acc, v_bribery, v_investigation, v_citizen, v_officer1, CURRENT_TIMESTAMP - INTERVAL '10 days', CURRENT_DATE - INTERVAL '20 days', 'Traffic officer bribery ring', 'Network of traffic officers systematically collecting bribes at checkpoints.', 2, 500000, FALSE, 'Highway Checkpoint A'),
    (v_moe, v_ghost_employees, v_under_review, v_govt_employee, v_officer2, CURRENT_TIMESTAMP - INTERVAL '12 days', CURRENT_DATE - INTERVAL '180 days', 'Ghost teachers on payroll', 'Investigation reveals 47 non-existent teachers receiving monthly salaries.', 2, 28200000, FALSE, 'District Education Office');
    
    -- Cases 31-90 days old
    INSERT INTO reports (department_id, category_id, status_id, complainant_type_id, assigned_to, reported_date, incident_date, title, description, priority, estimated_amount, is_anonymous, location) VALUES
    (v_ra, v_fraud, v_investigation, v_ngo, v_officer5, CURRENT_TIMESTAMP - INTERVAL '45 days', CURRENT_DATE - INTERVAL '120 days', 'Tax evasion scheme by construction company', 'Major construction firm allegedly evading taxes through falsified invoices.', 2, 75000000, FALSE, 'Revenue Authority HQ'),
    (v_mof, v_fraud, v_pending_evidence, v_citizen, v_officer3, CURRENT_TIMESTAMP - INTERVAL '55 days', CURRENT_DATE - INTERVAL '90 days', 'Pension fund irregularities', 'Suspicious withdrawals from civil service pension fund.', 1, 120000000, FALSE, 'Pension Department'),
    (v_moi, v_embezzlement, v_escalated, v_anonymous, v_officer1, CURRENT_TIMESTAMP - INTERVAL '60 days', CURRENT_DATE - INTERVAL '200 days', 'Building materials theft at construction site', 'Large quantities of construction materials diverted from government project.', 2, 18000000, TRUE, 'Capital Building Project'),
    (v_acc, v_nepotism, v_investigation, v_govt_employee, v_officer2, CURRENT_TIMESTAMP - INTERVAL '75 days', CURRENT_DATE - INTERVAL '365 days', 'Hiring irregularities in ministry', 'Multiple relatives of senior officials hired without proper qualifications.', 3, NULL, FALSE, 'Ministry of Agriculture'),
    (v_moh, v_abuse, v_under_review, v_citizen, v_officer4, CURRENT_TIMESTAMP - INTERVAL '80 days', CURRENT_DATE - INTERVAL '100 days', 'Hospital director misusing ambulances', 'Director using official ambulances for personal transportation.', 4, 50000, FALSE, 'Regional Hospital');
    
    -- Cases 91-180 days old
    INSERT INTO reports (department_id, category_id, status_id, complainant_type_id, assigned_to, reported_date, incident_date, title, description, priority, estimated_amount, is_anonymous, location) VALUES
    (v_mof, v_procurement, v_investigation, v_ngo, v_officer5, CURRENT_TIMESTAMP - INTERVAL '100 days', CURRENT_DATE - INTERVAL '300 days', 'IT system procurement scandal', 'Overpriced IT systems purchased from connected vendors.', 1, 250000000, FALSE, 'IT Department'),
    (v_ra, v_bribery, v_escalated, v_anonymous, v_officer1, CURRENT_TIMESTAMP - INTERVAL '120 days', CURRENT_DATE - INTERVAL '150 days', 'Customs officers accepting bribes', 'Systematic bribery at main cargo terminal.', 1, 35000000, TRUE, 'Main Port'),
    (v_moi, v_fraud, v_pending_evidence, v_citizen, v_officer3, CURRENT_TIMESTAMP - INTERVAL '140 days', CURRENT_DATE - INTERVAL '250 days', 'Falsified road completion certificates', 'Roads certified as complete but only partially constructed.', 2, 85000000, FALSE, 'Eastern Region'),
    (v_moe, v_embezzlement, v_investigation, v_govt_employee, v_officer2, CURRENT_TIMESTAMP - INTERVAL '160 days', CURRENT_DATE - INTERVAL '400 days', 'School feeding program funds misappropriated', 'Funds meant for school meals diverted to personal accounts.', 2, 45000000, FALSE, 'School Feeding Program'),
    (v_acc, v_kickbacks, v_under_review, v_citizen, v_officer4, CURRENT_TIMESTAMP - INTERVAL '175 days', CURRENT_DATE - INTERVAL '220 days', 'Land allocation kickbacks', 'Officials allegedly receiving payments for favorable land allocations.', 2, 60000000, FALSE, 'Lands Department');
    
    -- Cases over 180 days old (aging)
    INSERT INTO reports (department_id, category_id, status_id, complainant_type_id, assigned_to, reported_date, incident_date, title, description, priority, estimated_amount, is_anonymous, location) VALUES
    (v_mof, v_embezzlement, v_investigation, v_anonymous, v_officer5, CURRENT_TIMESTAMP - INTERVAL '200 days', CURRENT_DATE - INTERVAL '500 days', 'Treasury funds diversion', 'Large-scale diversion of treasury funds through fake projects.', 1, 500000000, TRUE, 'Treasury'),
    (v_moi, v_procurement, v_escalated, v_ngo, v_officer1, CURRENT_TIMESTAMP - INTERVAL '220 days', CURRENT_DATE - INTERVAL '400 days', 'Bridge construction tender manipulation', 'Tender requirements tailored to favor specific contractor.', 1, 350000000, FALSE, 'Western Region'),
    (v_ra, v_fraud, v_pending_evidence, v_citizen, v_officer3, CURRENT_TIMESTAMP - INTERVAL '250 days', CURRENT_DATE - INTERVAL '365 days', 'VAT refund fraud scheme', 'Organized scheme to claim fraudulent VAT refunds.', 1, 180000000, FALSE, 'Revenue Authority HQ'),
    (v_moh, v_ghost_employees, v_investigation, v_govt_employee, v_officer2, CURRENT_TIMESTAMP - INTERVAL '280 days', CURRENT_DATE - INTERVAL '600 days', 'Ghost health workers scandal', 'Hundreds of non-existent health workers on payroll.', 1, 720000000, FALSE, 'Ministry of Health HQ'),
    (v_acc, v_bribery, v_escalated, v_anonymous, v_officer4, CURRENT_TIMESTAMP - INTERVAL '300 days', CURRENT_DATE - INTERVAL '350 days', 'Judicial bribery network', 'Alleged network of court officials accepting bribes to influence cases.', 1, 0, TRUE, 'Courts');
    
    -- Resolved cases (for resolution rate analysis)
    INSERT INTO reports (department_id, category_id, status_id, complainant_type_id, assigned_to, reported_date, incident_date, title, description, priority, estimated_amount, actual_amount, is_anonymous, location, resolution_date, resolution_type, resolution_notes) VALUES
    (v_acc, v_bribery, v_resolved, v_citizen, v_officer1, CURRENT_TIMESTAMP - INTERVAL '90 days', CURRENT_DATE - INTERVAL '120 days', 'Licensing office bribery', 'Officer caught accepting bribes for expedited licenses.', 2, 150000, 175000, FALSE, 'Licensing Office', CURRENT_TIMESTAMP - INTERVAL '30 days', 'Prosecution', 'Officer prosecuted and convicted. Funds recovered.'),
    (v_mof, v_fraud, v_resolved, v_govt_employee, v_officer5, CURRENT_TIMESTAMP - INTERVAL '120 days', CURRENT_DATE - INTERVAL '180 days', 'Travel expense fraud', 'Official submitting fraudulent travel claims.', 3, 500000, 485000, FALSE, 'Finance Department', CURRENT_TIMESTAMP - INTERVAL '45 days', 'Administrative Action', 'Official dismissed and funds recovered.'),
    (v_moi, v_abuse, v_dismissed, v_anonymous, v_officer3, CURRENT_TIMESTAMP - INTERVAL '60 days', CURRENT_DATE - INTERVAL '90 days', 'Vehicle misuse allegation', 'Allegation of government vehicle misuse.', 4, 25000, NULL, TRUE, 'Transport Pool', CURRENT_TIMESTAMP - INTERVAL '10 days', 'Dismissed', 'Insufficient evidence to support claims.'),
    (v_moe, v_nepotism, v_resolved, v_citizen, v_officer2, CURRENT_TIMESTAMP - INTERVAL '150 days', CURRENT_DATE - INTERVAL '200 days', 'School principal hiring relatives', 'Principal hired multiple unqualified family members.', 3, NULL, NULL, FALSE, 'District School', CURRENT_TIMESTAMP - INTERVAL '60 days', 'Administrative Action', 'Principal transferred. Relatives'' contracts terminated.'),
    (v_ra, v_embezzlement, v_resolved, v_ngo, v_officer4, CURRENT_TIMESTAMP - INTERVAL '180 days', CURRENT_DATE - INTERVAL '250 days', 'Customs revenue skimming', 'Customs officers skimming cash payments.', 2, 8500000, 7200000, FALSE, 'Border Post', CURRENT_TIMESTAMP - INTERVAL '90 days', 'Prosecution', 'Three officers prosecuted. Partial funds recovered.');
    
    -- Additional resolved cases from previous year
    INSERT INTO reports (department_id, category_id, status_id, complainant_type_id, assigned_to, reported_date, incident_date, title, description, priority, estimated_amount, actual_amount, is_anonymous, location, resolution_date, resolution_type, resolution_notes) VALUES
    (v_mof, v_procurement, v_resolved, v_citizen, v_officer5, CURRENT_TIMESTAMP - INTERVAL '400 days', CURRENT_DATE - INTERVAL '450 days', 'Office supplies overpricing', 'Vendor consistently overcharging for office supplies.', 3, 2500000, 2100000, FALSE, 'Procurement Unit', CURRENT_TIMESTAMP - INTERVAL '350 days', 'Administrative Action', 'Vendor blacklisted. Excess charges refunded.'),
    (v_acc, v_kickbacks, v_resolved, v_anonymous, v_officer1, CURRENT_TIMESTAMP - INTERVAL '380 days', CURRENT_DATE - INTERVAL '420 days', 'Construction permit kickbacks', 'Building inspectors demanding kickbacks.', 2, 15000000, 12000000, TRUE, 'Building Authority', CURRENT_TIMESTAMP - INTERVAL '300 days', 'Prosecution', 'Five inspectors prosecuted.'),
    (v_moh, v_fraud, v_resolved, v_govt_employee, v_officer4, CURRENT_TIMESTAMP - INTERVAL '365 days', CURRENT_DATE - INTERVAL '400 days', 'Pharmaceutical procurement fraud', 'Fake pharmaceuticals purchased at premium prices.', 1, 95000000, 78000000, FALSE, 'Central Medical Stores', CURRENT_TIMESTAMP - INTERVAL '250 days', 'Prosecution', 'Supplier prosecuted. Officials dismissed.');
    
END $$;

-- ============================================================================
-- Insert some historical daily statistics for testing
-- ============================================================================

INSERT INTO daily_statistics (stat_date, new_reports, resolved_reports, total_open_reports, total_amount_reported)
SELECT 
    d::DATE,
    FLOOR(RANDOM() * 5 + 1)::INTEGER,
    FLOOR(RANDOM() * 3)::INTEGER,
    FLOOR(RANDOM() * 50 + 20)::INTEGER,
    FLOOR(RANDOM() * 50000000 + 1000000)::NUMERIC
FROM generate_series(CURRENT_DATE - INTERVAL '365 days', CURRENT_DATE - INTERVAL '1 day', INTERVAL '1 day') d;

-- ============================================================================
-- Insert case actions for activity tracking
-- ============================================================================

DO $$
DECLARE
    v_report RECORD;
    v_initial_review UUID;
    v_document_review UUID;
    v_status_update UUID;
BEGIN
    SELECT action_type_id INTO v_initial_review FROM action_types WHERE name = 'Initial Review';
    SELECT action_type_id INTO v_document_review FROM action_types WHERE name = 'Document Review';
    SELECT action_type_id INTO v_status_update FROM action_types WHERE name = 'Status Update';
    
    -- Add initial review action to all reports
    FOR v_report IN SELECT report_id, assigned_to, reported_date FROM reports LOOP
        INSERT INTO case_actions (report_id, action_type_id, performed_by, action_date, notes, time_spent_minutes)
        VALUES (
            v_report.report_id,
            v_initial_review,
            v_report.assigned_to,
            v_report.reported_date + INTERVAL '1 day',
            'Initial review completed',
            30
        );
    END LOOP;
    
    -- Add document review to older cases
    FOR v_report IN SELECT report_id, assigned_to, reported_date FROM reports WHERE reported_date < CURRENT_DATE - INTERVAL '30 days' LOOP
        INSERT INTO case_actions (report_id, action_type_id, performed_by, action_date, notes, time_spent_minutes)
        VALUES (
            v_report.report_id,
            v_document_review,
            v_report.assigned_to,
            v_report.reported_date + INTERVAL '7 days',
            'Reviewed all submitted documents',
            120
        );
    END LOOP;
END $$;

-- ============================================================================
-- Insert escalations for escalated cases
-- ============================================================================

INSERT INTO escalations (report_id, escalated_from, escalated_to, escalated_by, escalated_at, reason)
SELECT 
    r.report_id,
    r.department_id,
    '11111111-1111-1111-1111-111111111111'::UUID, -- Escalate to ACC
    r.assigned_to,
    r.reported_date + INTERVAL '30 days',
    'Case requires higher authority due to complexity and amount involved'
FROM reports r
JOIN statuses s ON r.status_id = s.status_id
WHERE s.name = 'escalated';
