-- ============================================================================
-- Corruption Report Auditor - Indexes
-- Version: V002
-- Description: Performance indexes optimized for temporal queries
-- ============================================================================

-- ============================================================================
-- Reports Table Indexes (Primary focus for temporal analytics)
-- ============================================================================

-- Primary temporal index - most queries filter by reported_date
CREATE INDEX idx_reports_reported_date ON reports(reported_date);
CREATE INDEX idx_reports_reported_date_desc ON reports(reported_date DESC);

-- BRIN index for large time-series data (very efficient for temporal data)
CREATE INDEX idx_reports_reported_date_brin ON reports 
    USING BRIN(reported_date) WITH (pages_per_range = 32);

-- Composite indexes for common temporal + status queries
CREATE INDEX idx_reports_status_reported_date ON reports(status_id, reported_date);
CREATE INDEX idx_reports_category_reported_date ON reports(category_id, reported_date);
CREATE INDEX idx_reports_department_reported_date ON reports(department_id, reported_date);

-- Resolution date for resolution rate analytics
CREATE INDEX idx_reports_resolution_date ON reports(resolution_date) 
    WHERE resolution_date IS NOT NULL;

-- Last activity for stale case detection
CREATE INDEX idx_reports_last_activity ON reports(last_activity_date);

-- Incident date for incident timeline analysis
CREATE INDEX idx_reports_incident_date ON reports(incident_date) 
    WHERE incident_date IS NOT NULL;

-- ============================================================================
-- Partial Indexes (Very efficient for common filters)
-- ============================================================================

-- Unresolved cases (most common query pattern)
CREATE INDEX idx_reports_unresolved ON reports(reported_date, department_id, category_id)
    WHERE status_id IN (
        SELECT status_id FROM statuses WHERE is_terminal = FALSE
    );

-- Critical priority cases
CREATE INDEX idx_reports_critical ON reports(reported_date)
    WHERE priority = 1;

-- High-value cases
CREATE INDEX idx_reports_high_value ON reports(reported_date, estimated_amount)
    WHERE estimated_amount > 100000;

-- Anonymous reports
CREATE INDEX idx_reports_anonymous ON reports(reported_date)
    WHERE is_anonymous = TRUE;

-- Cases needing attention (no activity in 7+ days)
CREATE INDEX idx_reports_stale ON reports(last_activity_date, assigned_to)
    WHERE status_id IN (
        SELECT status_id FROM statuses WHERE is_terminal = FALSE
    );

-- ============================================================================
-- Foreign Key Indexes
-- ============================================================================

CREATE INDEX idx_reports_department_id ON reports(department_id);
CREATE INDEX idx_reports_category_id ON reports(category_id);
CREATE INDEX idx_reports_status_id ON reports(status_id);
CREATE INDEX idx_reports_assigned_to ON reports(assigned_to);
CREATE INDEX idx_reports_complainant_type ON reports(complainant_type_id);

-- ============================================================================
-- Status History Indexes (Critical for temporal state analysis)
-- ============================================================================

CREATE INDEX idx_status_history_report_id ON status_history(report_id);
CREATE INDEX idx_status_history_changed_at ON status_history(changed_at);
CREATE INDEX idx_status_history_report_changed ON status_history(report_id, changed_at);
CREATE INDEX idx_status_history_new_status ON status_history(new_status_id, changed_at);

-- ============================================================================
-- Case Actions Indexes
-- ============================================================================

CREATE INDEX idx_case_actions_report_id ON case_actions(report_id);
CREATE INDEX idx_case_actions_action_date ON case_actions(action_date);
CREATE INDEX idx_case_actions_performed_by ON case_actions(performed_by);
CREATE INDEX idx_case_actions_report_date ON case_actions(report_id, action_date);

-- ============================================================================
-- Escalations Indexes
-- ============================================================================

CREATE INDEX idx_escalations_report_id ON escalations(report_id);
CREATE INDEX idx_escalations_escalated_at ON escalations(escalated_at);
CREATE INDEX idx_escalations_to_dept ON escalations(escalated_to, escalated_at);

-- Unresolved escalations
CREATE INDEX idx_escalations_pending ON escalations(escalated_at, escalated_to)
    WHERE resolved_at IS NULL;

-- ============================================================================
-- Evidence Indexes
-- ============================================================================

CREATE INDEX idx_evidence_report_id ON evidence(report_id);
CREATE INDEX idx_evidence_uploaded_at ON evidence(uploaded_at);

-- ============================================================================
-- Officers Indexes
-- ============================================================================

CREATE INDEX idx_officers_department_id ON officers(department_id);
CREATE INDEX idx_officers_active ON officers(department_id) WHERE is_active = TRUE;

-- ============================================================================
-- Daily Statistics Indexes
-- ============================================================================

CREATE INDEX idx_daily_stats_date ON daily_statistics(stat_date);
CREATE INDEX idx_daily_stats_date_brin ON daily_statistics USING BRIN(stat_date);

-- ============================================================================
-- Department Monthly Stats Indexes
-- ============================================================================

CREATE INDEX idx_dept_monthly_department ON department_monthly_stats(department_id, stat_month);
CREATE INDEX idx_dept_monthly_month ON department_monthly_stats(stat_month);

-- ============================================================================
-- Audit Log Indexes
-- ============================================================================

CREATE INDEX idx_audit_log_table_record ON audit_log(table_name, record_id);
CREATE INDEX idx_audit_log_performed_at ON audit_log(performed_at);
CREATE INDEX idx_audit_log_operation ON audit_log(operation, performed_at);

-- ============================================================================
-- Text Search Indexes (for searching report content)
-- ============================================================================

CREATE INDEX idx_reports_title_trgm ON reports USING GIN(title gin_trgm_ops);
CREATE INDEX idx_reports_description_trgm ON reports USING GIN(description gin_trgm_ops);

-- Full text search index
CREATE INDEX idx_reports_fts ON reports USING GIN(
    to_tsvector('english', COALESCE(title, '') || ' ' || COALESCE(description, ''))
);

-- ============================================================================
-- Covering Indexes (Include frequently selected columns)
-- ============================================================================

-- For aging reports query
CREATE INDEX idx_reports_aging_cover ON reports(status_id, reported_date)
    INCLUDE (report_number, department_id, category_id, priority)
    WHERE status_id IN (
        SELECT status_id FROM statuses WHERE is_terminal = FALSE
    );

-- For department summary queries
CREATE INDEX idx_reports_dept_summary ON reports(department_id, status_id)
    INCLUDE (reported_date, resolution_date, estimated_amount);
