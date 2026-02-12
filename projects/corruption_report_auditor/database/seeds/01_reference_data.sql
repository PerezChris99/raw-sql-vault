-- ============================================================================
-- Corruption Report Auditor - Reference Data
-- Description: Lookup tables and reference data
-- ============================================================================

-- ============================================================================
-- Statuses (Workflow states)
-- ============================================================================

INSERT INTO statuses (status_id, name, description, display_order, is_terminal, sla_days, color_code) VALUES
    (uuid_generate_v4(), 'open', 'Newly filed report awaiting review', 1, FALSE, 3, '#17a2b8'),
    (uuid_generate_v4(), 'under_review', 'Report being reviewed by officer', 2, FALSE, 7, '#007bff'),
    (uuid_generate_v4(), 'investigation', 'Active investigation in progress', 3, FALSE, 30, '#fd7e14'),
    (uuid_generate_v4(), 'pending_evidence', 'Waiting for additional evidence', 4, FALSE, 14, '#ffc107'),
    (uuid_generate_v4(), 'pending_witness', 'Waiting for witness statements', 5, FALSE, 14, '#ffc107'),
    (uuid_generate_v4(), 'escalated', 'Escalated to higher authority', 6, FALSE, 7, '#dc3545'),
    (uuid_generate_v4(), 'legal_review', 'Under legal department review', 7, FALSE, 21, '#6f42c1'),
    (uuid_generate_v4(), 'resolved', 'Investigation completed with findings', 8, TRUE, NULL, '#28a745'),
    (uuid_generate_v4(), 'dismissed', 'Report dismissed (insufficient evidence)', 9, TRUE, NULL, '#6c757d'),
    (uuid_generate_v4(), 'withdrawn', 'Complainant withdrew the report', 10, TRUE, NULL, '#6c757d');

-- ============================================================================
-- Categories (Types of corruption)
-- ============================================================================

INSERT INTO categories (category_id, name, description, severity_level, default_priority, sla_days, requires_evidence) VALUES
    (uuid_generate_v4(), 'Bribery', 'Offering, giving, receiving, or soliciting something of value to influence official action', 5, 1, 30, TRUE),
    (uuid_generate_v4(), 'Embezzlement', 'Misappropriation of funds or assets entrusted to one''s care', 5, 1, 45, TRUE),
    (uuid_generate_v4(), 'Fraud', 'Intentional deception to secure unfair or unlawful gain', 4, 2, 30, TRUE),
    (uuid_generate_v4(), 'Extortion', 'Obtaining money or property through coercion or threats', 5, 1, 21, TRUE),
    (uuid_generate_v4(), 'Nepotism', 'Favoritism shown to relatives in appointments or contracts', 3, 3, 45, FALSE),
    (uuid_generate_v4(), 'Conflict of Interest', 'Personal interests interfering with professional duties', 3, 3, 30, FALSE),
    (uuid_generate_v4(), 'Procurement Irregularities', 'Violations in public procurement processes', 4, 2, 60, TRUE),
    (uuid_generate_v4(), 'Ghost Employees', 'Salaries paid to non-existent employees', 4, 2, 45, TRUE),
    (uuid_generate_v4(), 'Contract Fraud', 'Fraudulent practices in contract awards or execution', 4, 2, 60, TRUE),
    (uuid_generate_v4(), 'Kickbacks', 'Payments made in return for facilitating transactions', 4, 2, 30, TRUE),
    (uuid_generate_v4(), 'Abuse of Authority', 'Misuse of official position for personal gain', 3, 3, 30, FALSE),
    (uuid_generate_v4(), 'Misuse of Resources', 'Improper use of government resources', 2, 4, 21, FALSE),
    (uuid_generate_v4(), 'Document Forgery', 'Falsification of official documents', 4, 2, 30, TRUE),
    (uuid_generate_v4(), 'Other', 'Other forms of corruption not categorized above', 2, 4, 30, FALSE);

-- ============================================================================
-- Complainant Types
-- ============================================================================

INSERT INTO complainant_types (complainant_type_id, name, description) VALUES
    (uuid_generate_v4(), 'Citizen', 'General public member'),
    (uuid_generate_v4(), 'Government Employee', 'Current government employee'),
    (uuid_generate_v4(), 'Contractor', 'Government contractor or vendor'),
    (uuid_generate_v4(), 'NGO', 'Non-governmental organization'),
    (uuid_generate_v4(), 'Media', 'Journalist or media organization'),
    (uuid_generate_v4(), 'Anonymous', 'Anonymous whistleblower'),
    (uuid_generate_v4(), 'Internal Audit', 'Internal audit department'),
    (uuid_generate_v4(), 'External Audit', 'External audit body'),
    (uuid_generate_v4(), 'Law Enforcement', 'Police or other law enforcement'),
    (uuid_generate_v4(), 'Other Agency', 'Another government agency');

-- ============================================================================
-- Action Types
-- ============================================================================

INSERT INTO action_types (action_type_id, name, description, requires_note, affects_sla) VALUES
    (uuid_generate_v4(), 'Initial Review', 'First review of the complaint', FALSE, FALSE),
    (uuid_generate_v4(), 'Evidence Request', 'Request for additional evidence', TRUE, TRUE),
    (uuid_generate_v4(), 'Witness Interview', 'Interview conducted with witness', TRUE, FALSE),
    (uuid_generate_v4(), 'Site Visit', 'Physical inspection of location', TRUE, FALSE),
    (uuid_generate_v4(), 'Document Review', 'Review of relevant documents', FALSE, FALSE),
    (uuid_generate_v4(), 'Database Check', 'Cross-reference with other databases', FALSE, FALSE),
    (uuid_generate_v4(), 'Expert Consultation', 'Consultation with subject matter expert', TRUE, TRUE),
    (uuid_generate_v4(), 'Legal Consultation', 'Consultation with legal team', TRUE, TRUE),
    (uuid_generate_v4(), 'Report Draft', 'Draft of investigation report', TRUE, FALSE),
    (uuid_generate_v4(), 'Case Transfer', 'Transfer to another department', TRUE, TRUE),
    (uuid_generate_v4(), 'Follow-up Call', 'Follow-up communication', FALSE, FALSE),
    (uuid_generate_v4(), 'Status Update', 'General status update', TRUE, FALSE),
    (uuid_generate_v4(), 'Final Report', 'Final investigation report submitted', TRUE, FALSE),
    (uuid_generate_v4(), 'Case Closure', 'Administrative closure of case', TRUE, FALSE);

-- ============================================================================
-- Departments (Hierarchical)
-- ============================================================================

-- Top-level departments
INSERT INTO departments (department_id, name, code, description, is_active) VALUES
    ('11111111-1111-1111-1111-111111111111'::UUID, 'Anti-Corruption Commission', 'ACC', 'Central anti-corruption authority', TRUE),
    ('22222222-2222-2222-2222-222222222222'::UUID, 'Ministry of Finance', 'MOF', 'Financial oversight and budget', TRUE),
    ('33333333-3333-3333-3333-333333333333'::UUID, 'Ministry of Infrastructure', 'MOI', 'Public works and infrastructure', TRUE),
    ('44444444-4444-4444-4444-444444444444'::UUID, 'Ministry of Health', 'MOH', 'Health services and facilities', TRUE),
    ('55555555-5555-5555-5555-555555555555'::UUID, 'Ministry of Education', 'MOE', 'Education services and institutions', TRUE),
    ('66666666-6666-6666-6666-666666666666'::UUID, 'Ministry of Justice', 'MOJ', 'Legal affairs and prosecution', TRUE),
    ('77777777-7777-7777-7777-777777777777'::UUID, 'Ministry of Interior', 'MIO', 'Internal security and administration', TRUE),
    ('88888888-8888-8888-8888-888888888888'::UUID, 'Revenue Authority', 'RA', 'Tax collection and customs', TRUE);

-- Sub-departments
INSERT INTO departments (department_id, parent_id, name, code, description, is_active) VALUES
    ('11111111-aaaa-1111-1111-111111111111'::UUID, '11111111-1111-1111-1111-111111111111', 'ACC - Investigation Unit', 'ACC-INV', 'Criminal investigations', TRUE),
    ('11111111-bbbb-1111-1111-111111111111'::UUID, '11111111-1111-1111-1111-111111111111', 'ACC - Prevention Unit', 'ACC-PRE', 'Corruption prevention programs', TRUE),
    ('22222222-aaaa-2222-2222-222222222222'::UUID, '22222222-2222-2222-2222-222222222222', 'Budget Department', 'MOF-BUD', 'National budget management', TRUE),
    ('22222222-bbbb-2222-2222-222222222222'::UUID, '22222222-2222-2222-2222-222222222222', 'Procurement Department', 'MOF-PRO', 'Central procurement', TRUE),
    ('33333333-aaaa-3333-3333-333333333333'::UUID, '33333333-3333-3333-3333-333333333333', 'Roads Department', 'MOI-RDS', 'Road construction and maintenance', TRUE),
    ('33333333-bbbb-3333-3333-333333333333'::UUID, '33333333-3333-3333-3333-333333333333', 'Buildings Department', 'MOI-BLD', 'Public building projects', TRUE);

-- ============================================================================
-- Officers/Investigators
-- ============================================================================

INSERT INTO officers (officer_id, department_id, employee_number, first_name, last_name, rank, email, max_caseload, is_active, hired_date) VALUES
    ('aaaa1111-1111-1111-1111-111111111111'::UUID, '11111111-1111-1111-1111-111111111111', 'ACC001', 'John', 'Mwangi', 'Senior Investigator', 'j.mwangi@acc.gov', 15, TRUE, '2020-01-15'),
    ('aaaa2222-2222-2222-2222-222222222222'::UUID, '11111111-1111-1111-1111-111111111111', 'ACC002', 'Sarah', 'Ochieng', 'Lead Investigator', 's.ochieng@acc.gov', 10, TRUE, '2019-06-01'),
    ('aaaa3333-3333-3333-3333-333333333333'::UUID, '11111111-1111-1111-1111-111111111111', 'ACC003', 'David', 'Kimani', 'Investigator', 'd.kimani@acc.gov', 20, TRUE, '2021-03-10'),
    ('aaaa4444-4444-4444-4444-444444444444'::UUID, '11111111-aaaa-1111-1111-111111111111', 'ACC004', 'Grace', 'Wanjiku', 'Investigator', 'g.wanjiku@acc.gov', 20, TRUE, '2022-01-05'),
    ('aaaa5555-5555-5555-5555-555555555555'::UUID, '22222222-2222-2222-2222-222222222222', 'MOF001', 'Peter', 'Omondi', 'Financial Analyst', 'p.omondi@mof.gov', 25, TRUE, '2018-09-20'),
    ('aaaa6666-6666-6666-6666-666666666666'::UUID, '22222222-bbbb-2222-2222-222222222222', 'MOF002', 'Lucy', 'Akinyi', 'Procurement Officer', 'l.akinyi@mof.gov', 20, TRUE, '2021-07-15'),
    ('aaaa7777-7777-7777-7777-777777777777'::UUID, '33333333-3333-3333-3333-333333333333', 'MOI001', 'James', 'Njoroge', 'Technical Auditor', 'j.njoroge@moi.gov', 15, TRUE, '2020-04-01'),
    ('aaaa8888-8888-8888-8888-888888888888'::UUID, '44444444-4444-4444-4444-444444444444', 'MOH001', 'Mary', 'Kamau', 'Health Inspector', 'm.kamau@moh.gov', 25, TRUE, '2019-11-10');
