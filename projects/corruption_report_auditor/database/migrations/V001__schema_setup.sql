-- ============================================================================
-- Corruption Report Auditor - Schema Setup
-- Version: V001
-- Description: Core tables for corruption report tracking and temporal analytics
-- ============================================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- ============================================================================
-- Reference/Lookup Tables
-- ============================================================================

-- Departments (hierarchical - supports parent/child)
CREATE TABLE departments (
    department_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    parent_id UUID REFERENCES departments(department_id),
    name VARCHAR(200) NOT NULL,
    code VARCHAR(20) NOT NULL UNIQUE,
    description TEXT,
    head_officer VARCHAR(200),
    contact_email VARCHAR(255),
    contact_phone VARCHAR(20),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE departments IS 'Government departments that receive/handle corruption reports';

-- Report Categories
CREATE TABLE categories (
    category_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    severity_level INTEGER NOT NULL CHECK (severity_level BETWEEN 1 AND 5),
    default_priority INTEGER DEFAULT 3 CHECK (default_priority BETWEEN 1 AND 5),
    sla_days INTEGER NOT NULL DEFAULT 30,
    requires_evidence BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE categories IS 'Types of corruption (bribery, embezzlement, fraud, etc.)';
COMMENT ON COLUMN categories.severity_level IS '1=Low, 5=Critical';

-- Report Statuses
CREATE TABLE statuses (
    status_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(50) NOT NULL UNIQUE,
    description TEXT,
    display_order INTEGER NOT NULL,
    is_terminal BOOLEAN DEFAULT FALSE,
    sla_days INTEGER,
    color_code VARCHAR(7),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE statuses IS 'Workflow statuses for reports';
COMMENT ON COLUMN statuses.is_terminal IS 'TRUE if this is a final state (resolved, dismissed, etc.)';

-- Complainant Types
CREATE TABLE complainant_types (
    complainant_type_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    is_active BOOLEAN DEFAULT TRUE
);

-- Officers/Investigators
CREATE TABLE officers (
    officer_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    department_id UUID REFERENCES departments(department_id),
    employee_number VARCHAR(20) NOT NULL UNIQUE,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    rank VARCHAR(100),
    email VARCHAR(255) UNIQUE,
    phone VARCHAR(20),
    max_caseload INTEGER DEFAULT 20,
    is_active BOOLEAN DEFAULT TRUE,
    hired_date DATE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE officers IS 'Investigators and case handlers';

-- Action Types
CREATE TABLE action_types (
    action_type_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    requires_note BOOLEAN DEFAULT FALSE,
    affects_sla BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE
);

-- ============================================================================
-- Core Tables
-- ============================================================================

-- Main Reports Table
CREATE TABLE reports (
    report_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    report_number VARCHAR(20) NOT NULL UNIQUE,
    
    -- Foreign Keys
    department_id UUID NOT NULL REFERENCES departments(department_id),
    category_id UUID NOT NULL REFERENCES categories(category_id),
    status_id UUID NOT NULL REFERENCES statuses(status_id),
    complainant_type_id UUID REFERENCES complainant_types(complainant_type_id),
    assigned_to UUID REFERENCES officers(officer_id),
    
    -- Temporal Fields (KEY for this project)
    reported_date TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    incident_date DATE,
    incident_end_date DATE,
    last_activity_date TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    target_resolution_date DATE,
    resolution_date TIMESTAMPTZ,
    
    -- Report Details
    title VARCHAR(500) NOT NULL,
    description TEXT NOT NULL,
    location TEXT,
    
    -- Complainant Info
    is_anonymous BOOLEAN DEFAULT FALSE,
    complainant_name VARCHAR(200),
    complainant_contact TEXT,
    
    -- Case Attributes
    priority INTEGER NOT NULL DEFAULT 3 CHECK (priority BETWEEN 1 AND 5),
    estimated_amount NUMERIC(15,2),
    actual_amount NUMERIC(15,2),
    
    -- Resolution
    resolution_type VARCHAR(100),
    resolution_notes TEXT,
    
    -- Audit Fields
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    created_by VARCHAR(100),
    updated_by VARCHAR(100),
    
    -- Constraints
    CONSTRAINT chk_incident_dates CHECK (incident_end_date IS NULL OR incident_end_date >= incident_date),
    CONSTRAINT chk_resolution_date CHECK (resolution_date IS NULL OR resolution_date >= reported_date)
);

COMMENT ON TABLE reports IS 'Main corruption reports/complaints table';
COMMENT ON COLUMN reports.reported_date IS 'When the report was filed (key temporal field)';
COMMENT ON COLUMN reports.incident_date IS 'When the alleged corruption occurred';
COMMENT ON COLUMN reports.priority IS '1=Critical, 5=Low';

-- Status History (Temporal tracking of status changes)
CREATE TABLE status_history (
    history_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    report_id UUID NOT NULL REFERENCES reports(report_id) ON DELETE CASCADE,
    old_status_id UUID REFERENCES statuses(status_id),
    new_status_id UUID NOT NULL REFERENCES statuses(status_id),
    changed_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    changed_by VARCHAR(100),
    reason TEXT,
    time_in_previous_status INTERVAL
);

COMMENT ON TABLE status_history IS 'Tracks all status transitions for temporal analysis';

-- Case Actions
CREATE TABLE case_actions (
    action_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    report_id UUID NOT NULL REFERENCES reports(report_id) ON DELETE CASCADE,
    action_type_id UUID NOT NULL REFERENCES action_types(action_type_id),
    performed_by UUID REFERENCES officers(officer_id),
    action_date TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    notes TEXT,
    time_spent_minutes INTEGER,
    is_billable BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE case_actions IS 'Log of all actions taken on a case';

-- Escalations
CREATE TABLE escalations (
    escalation_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    report_id UUID NOT NULL REFERENCES reports(report_id) ON DELETE CASCADE,
    escalated_from UUID REFERENCES departments(department_id),
    escalated_to UUID NOT NULL REFERENCES departments(department_id),
    escalated_by UUID REFERENCES officers(officer_id),
    escalated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    reason TEXT NOT NULL,
    priority_before INTEGER,
    priority_after INTEGER,
    resolved_at TIMESTAMPTZ,
    outcome TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE escalations IS 'Tracks when cases are escalated to higher authorities';

-- Evidence/Attachments
CREATE TABLE evidence (
    evidence_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    report_id UUID NOT NULL REFERENCES reports(report_id) ON DELETE CASCADE,
    file_name VARCHAR(255) NOT NULL,
    file_type VARCHAR(100),
    file_size_bytes BIGINT,
    file_path TEXT NOT NULL,
    description TEXT,
    uploaded_by VARCHAR(100),
    uploaded_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    is_verified BOOLEAN DEFAULT FALSE,
    verified_by UUID REFERENCES officers(officer_id),
    verified_at TIMESTAMPTZ
);

-- Involved Parties
CREATE TABLE involved_parties (
    party_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    report_id UUID NOT NULL REFERENCES reports(report_id) ON DELETE CASCADE,
    party_type VARCHAR(50) NOT NULL, -- 'accused', 'witness', 'victim', 'other'
    name VARCHAR(200),
    position VARCHAR(200),
    organization VARCHAR(200),
    contact_info TEXT,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- Analytics Support Tables
-- ============================================================================

-- Daily Statistics (pre-aggregated for performance)
CREATE TABLE daily_statistics (
    stat_date DATE PRIMARY KEY,
    new_reports INTEGER DEFAULT 0,
    resolved_reports INTEGER DEFAULT 0,
    escalated_reports INTEGER DEFAULT 0,
    total_open_reports INTEGER DEFAULT 0,
    avg_age_open_reports_days NUMERIC(10,2),
    total_amount_reported NUMERIC(15,2) DEFAULT 0,
    total_amount_confirmed NUMERIC(15,2) DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE daily_statistics IS 'Pre-computed daily stats for dashboard performance';

-- Department Monthly Stats
CREATE TABLE department_monthly_stats (
    stat_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    department_id UUID NOT NULL REFERENCES departments(department_id),
    stat_month DATE NOT NULL, -- First of month
    new_reports INTEGER DEFAULT 0,
    resolved_reports INTEGER DEFAULT 0,
    avg_resolution_days NUMERIC(10,2),
    sla_compliance_pct NUMERIC(5,2),
    escalation_count INTEGER DEFAULT 0,
    total_amount_reported NUMERIC(15,2) DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(department_id, stat_month)
);

-- ============================================================================
-- Audit Log
-- ============================================================================

CREATE TABLE audit_log (
    log_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    table_name VARCHAR(100) NOT NULL,
    record_id UUID,
    operation VARCHAR(10) NOT NULL, -- INSERT, UPDATE, DELETE
    old_values JSONB,
    new_values JSONB,
    changed_fields TEXT[],
    performed_by VARCHAR(100),
    performed_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ip_address INET,
    user_agent TEXT
);

COMMENT ON TABLE audit_log IS 'Comprehensive audit trail for compliance';

-- ============================================================================
-- Sequences for Report Numbers
-- ============================================================================

CREATE SEQUENCE report_number_seq START WITH 1000;

-- Function to generate report numbers
CREATE OR REPLACE FUNCTION fn_generate_report_number()
RETURNS VARCHAR(20) AS $$
BEGIN
    RETURN 'CR-' || TO_CHAR(CURRENT_DATE, 'YYYY') || '-' || 
           LPAD(nextval('report_number_seq')::TEXT, 6, '0');
END;
$$ LANGUAGE plpgsql;
