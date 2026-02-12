-- ============================================================================
-- 🏥 HEALTHCARE OUTBREAK DETECTOR - ALERT SYSTEM
-- ============================================================================
-- File: 08_alerts.sql
-- Purpose: Alert generation, notification workflows, escalation
-- Database: PostgreSQL 14+
-- ============================================================================

SET search_path TO surveillance, public;

-- ============================================================================
-- SECTION 1: ALERT GENERATION
-- ============================================================================

-- 1.1 Main alert generation procedure
CREATE OR REPLACE PROCEDURE surveillance.generate_alerts()
LANGUAGE plpgsql
AS $$
DECLARE
    v_disease RECORD;
    v_district RECORD;
    v_current_cases INTEGER;
    v_baseline NUMERIC;
    v_zscore NUMERIC;
    v_alert_id UUID;
BEGIN
    -- Check each disease-district combination
    FOR v_disease IN 
        SELECT disease_id, disease_code, disease_name, outbreak_threshold, baseline_cases_per_week
        FROM surveillance.diseases
        WHERE is_active = TRUE
    LOOP
        FOR v_district IN
            SELECT district_id, district_code, district_name
            FROM surveillance.districts
            WHERE is_active = TRUE
        LOOP
            -- Count recent cases
            SELECT COUNT(*) INTO v_current_cases
            FROM surveillance.cases
            WHERE disease_id = v_disease.disease_id
            AND district_id = v_district.district_id
            AND report_date > CURRENT_DATE - INTERVAL '7 days';
            
            -- Only process if there are cases
            IF v_current_cases > 0 THEN
                -- Calculate baseline (historical average)
                SELECT COALESCE(AVG(new_cases), 0) INTO v_baseline
                FROM surveillance.daily_case_counts
                WHERE disease_id = v_disease.disease_id
                AND district_id = v_district.district_id
                AND count_date BETWEEN CURRENT_DATE - INTERVAL '56 days' AND CURRENT_DATE - INTERVAL '7 days';
                
                -- Calculate z-score
                v_zscore := CASE WHEN v_baseline > 0 THEN 
                    (v_current_cases - v_baseline * 7) / GREATEST(SQRT(v_baseline * 7), 1)
                    ELSE v_current_cases END;
                
                -- Check for threshold breach
                IF v_current_cases >= COALESCE(v_disease.outbreak_threshold, 10) 
                   OR v_zscore > 2 THEN
                    
                    -- Check if similar alert already exists
                    IF NOT EXISTS (
                        SELECT 1 FROM surveillance.alerts
                        WHERE disease_id = v_disease.disease_id
                        AND district_id = v_district.district_id
                        AND alert_status = 'active'
                        AND detection_date > CURRENT_DATE - INTERVAL '7 days'
                    ) THEN
                        -- Create new alert
                        INSERT INTO surveillance.alerts (
                            alert_code,
                            alert_level,
                            alert_status,
                            alert_type,
                            disease_id,
                            district_id,
                            title,
                            description,
                            detection_date,
                            current_value,
                            threshold_value,
                            baseline_value
                        ) VALUES (
                            'ALERT-' || v_disease.disease_code || '-' || v_district.district_code || 
                            '-' || TO_CHAR(CURRENT_TIMESTAMP, 'YYYYMMDDHH24MI'),
                            CASE 
                                WHEN v_zscore > 4 OR v_current_cases > v_disease.outbreak_threshold * 2 THEN 'outbreak'
                                WHEN v_zscore > 3 OR v_current_cases > v_disease.outbreak_threshold THEN 'alert'
                                ELSE 'watch'
                            END,
                            'active',
                            'threshold_breach',
                            v_disease.disease_id,
                            v_district.district_id,
                            v_disease.disease_name || ' threshold alert in ' || v_district.district_name,
                            FORMAT('Detected %s cases in last 7 days (threshold: %s, z-score: %s)',
                                   v_current_cases, v_disease.outbreak_threshold, ROUND(v_zscore, 2)),
                            CURRENT_DATE,
                            v_current_cases,
                            v_disease.outbreak_threshold,
                            ROUND(v_baseline * 7, 0)
                        )
                        RETURNING alert_id INTO v_alert_id;
                        
                        RAISE NOTICE 'Alert created: % in % (cases: %, z-score: %)',
                            v_disease.disease_name, v_district.district_name, v_current_cases, ROUND(v_zscore, 2);
                    END IF;
                END IF;
            END IF;
        END LOOP;
    END LOOP;
    
    RAISE NOTICE 'Alert generation completed at %', CURRENT_TIMESTAMP;
END;
$$;

-- 1.2 Generate immediate notification alerts (triggered by report_case)
CREATE OR REPLACE FUNCTION surveillance.check_immediate_notification()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_disease RECORD;
BEGIN
    SELECT * INTO v_disease 
    FROM surveillance.diseases 
    WHERE disease_id = NEW.disease_id;
    
    IF v_disease.is_immediately_notifiable THEN
        -- Create immediate notification alert
        INSERT INTO surveillance.alerts (
            alert_code,
            alert_level,
            alert_status,
            alert_type,
            disease_id,
            district_id,
            title,
            description,
            detection_date,
            current_value
        ) VALUES (
            'IMMED-' || v_disease.disease_code || '-' || TO_CHAR(CURRENT_TIMESTAMP, 'YYYYMMDDHH24MISS'),
            CASE 
                WHEN v_disease.disease_code IN ('EBO', 'MAR', 'PLG', 'ANT') THEN 'emergency'
                ELSE 'alert'
            END,
            'active',
            'immediate_notification',
            NEW.disease_id,
            NEW.district_id,
            'Immediately Notifiable: ' || v_disease.disease_name,
            'New case reported requiring immediate notification',
            CURRENT_DATE,
            1
        );
    END IF;
    
    RETURN NEW;
END;
$$;

-- Trigger for immediate notification
DROP TRIGGER IF EXISTS trg_check_immediate_notification ON surveillance.cases;
CREATE TRIGGER trg_check_immediate_notification
    AFTER INSERT ON surveillance.cases
    FOR EACH ROW
    EXECUTE FUNCTION surveillance.check_immediate_notification();

-- ============================================================================
-- SECTION 2: NOTIFICATION MANAGEMENT
-- ============================================================================

-- 2.1 Create notification for alert
CREATE OR REPLACE FUNCTION surveillance.create_alert_notification(
    p_alert_id UUID,
    p_recipient_type VARCHAR(50),
    p_recipient_id VARCHAR(100),
    p_channel VARCHAR(20) DEFAULT 'system',
    p_message TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
AS $$
DECLARE
    v_notification_id UUID;
    v_alert RECORD;
BEGIN
    SELECT a.*, d.disease_name, dist.district_name
    INTO v_alert
    FROM surveillance.alerts a
    LEFT JOIN surveillance.diseases d ON a.disease_id = d.disease_id
    LEFT JOIN surveillance.districts dist ON a.district_id = dist.district_id
    WHERE a.alert_id = p_alert_id;
    
    INSERT INTO surveillance.alert_notifications (
        alert_id,
        recipient_type,
        recipient_id,
        notification_channel,
        message,
        status
    ) VALUES (
        p_alert_id,
        p_recipient_type,
        p_recipient_id,
        p_channel,
        COALESCE(p_message, v_alert.title || ': ' || v_alert.description),
        'pending'
    )
    RETURNING notification_id INTO v_notification_id;
    
    RETURN v_notification_id;
END;
$$;

-- 2.2 Send notification (updates status, would integrate with external service)
CREATE OR REPLACE FUNCTION surveillance.send_notification(p_notification_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
DECLARE
    v_notification RECORD;
BEGIN
    SELECT * INTO v_notification 
    FROM surveillance.alert_notifications 
    WHERE notification_id = p_notification_id;
    
    IF v_notification.notification_id IS NULL THEN
        RETURN FALSE;
    END IF;
    
    -- In production, this would call external notification services
    -- For now, we just update the status
    UPDATE surveillance.alert_notifications SET
        sent_at = CURRENT_TIMESTAMP,
        status = 'sent',
        updated_at = CURRENT_TIMESTAMP
    WHERE notification_id = p_notification_id;
    
    RETURN TRUE;
END;
$$;

-- 2.3 Bulk notify for alert
CREATE OR REPLACE PROCEDURE surveillance.notify_alert(
    p_alert_id UUID,
    p_channels VARCHAR[] DEFAULT ARRAY['system', 'email']
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_alert RECORD;
    v_channel VARCHAR;
    v_recipient RECORD;
BEGIN
    SELECT a.*, d.disease_name, dist.district_id, dist.district_name
    INTO v_alert
    FROM surveillance.alerts a
    LEFT JOIN surveillance.diseases d ON a.disease_id = d.disease_id
    LEFT JOIN surveillance.districts dist ON a.district_id = dist.district_id
    WHERE a.alert_id = p_alert_id;
    
    -- Notify based on alert level
    FOREACH v_channel IN ARRAY p_channels
    LOOP
        -- District Health Team
        PERFORM surveillance.create_alert_notification(
            p_alert_id, 'district_health_team', v_alert.district_id::VARCHAR, v_channel
        );
        
        -- For higher level alerts, notify regional and national
        IF v_alert.alert_level IN ('alert', 'outbreak', 'emergency') THEN
            PERFORM surveillance.create_alert_notification(
                p_alert_id, 'regional_surveillance', 
                (SELECT region_id::VARCHAR FROM surveillance.districts WHERE district_id = v_alert.district_id),
                v_channel
            );
        END IF;
        
        IF v_alert.alert_level IN ('outbreak', 'emergency') THEN
            PERFORM surveillance.create_alert_notification(
                p_alert_id, 'national_surveillance', 'MOH-SURVEILLANCE', v_channel
            );
        END IF;
        
        IF v_alert.alert_level = 'emergency' THEN
            PERFORM surveillance.create_alert_notification(
                p_alert_id, 'emergency_operations', 'EOC', v_channel
            );
        END IF;
    END LOOP;
    
    -- Update alert to indicate notifications sent
    UPDATE surveillance.alerts SET
        notification_sent = TRUE,
        notification_sent_at = CURRENT_TIMESTAMP
    WHERE alert_id = p_alert_id;
    
    RAISE NOTICE 'Notifications created for alert %', v_alert.alert_code;
END;
$$;

-- ============================================================================
-- SECTION 3: ALERT ESCALATION
-- ============================================================================

-- 3.1 Escalate alert
CREATE OR REPLACE FUNCTION surveillance.escalate_alert(
    p_alert_id UUID,
    p_new_level surveillance.alert_level,
    p_reason TEXT DEFAULT NULL,
    p_escalated_by VARCHAR(100) DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
DECLARE
    v_old_level surveillance.alert_level;
BEGIN
    SELECT alert_level INTO v_old_level FROM surveillance.alerts WHERE alert_id = p_alert_id;
    
    IF v_old_level IS NULL THEN
        RETURN FALSE;
    END IF;
    
    UPDATE surveillance.alerts SET
        alert_level = p_new_level,
        escalated = TRUE,
        escalation_date = CURRENT_TIMESTAMP,
        escalation_reason = p_reason,
        escalated_by = p_escalated_by,
        updated_at = CURRENT_TIMESTAMP
    WHERE alert_id = p_alert_id;
    
    -- Re-notify for escalation
    CALL surveillance.notify_alert(p_alert_id);
    
    RETURN TRUE;
END;
$$;

-- 3.2 Auto-escalate stale alerts
CREATE OR REPLACE PROCEDURE surveillance.auto_escalate_alerts()
LANGUAGE plpgsql
AS $$
DECLARE
    v_alert RECORD;
BEGIN
    -- Escalate unacknowledged alerts after 24 hours
    FOR v_alert IN
        SELECT alert_id, alert_code, alert_level
        FROM surveillance.alerts
        WHERE alert_status = 'active'
        AND acknowledged_at IS NULL
        AND created_at < CURRENT_TIMESTAMP - INTERVAL '24 hours'
        AND escalated = FALSE
    LOOP
        PERFORM surveillance.escalate_alert(
            v_alert.alert_id,
            CASE v_alert.alert_level
                WHEN 'watch' THEN 'alert'::surveillance.alert_level
                WHEN 'alert' THEN 'outbreak'::surveillance.alert_level
                WHEN 'outbreak' THEN 'emergency'::surveillance.alert_level
                ELSE 'emergency'::surveillance.alert_level
            END,
            'Auto-escalated: unacknowledged for 24+ hours',
            'SYSTEM'
        );
        
        RAISE NOTICE 'Auto-escalated alert %', v_alert.alert_code;
    END LOOP;
END;
$$;

-- ============================================================================
-- SECTION 4: ALERT ACTIONS
-- ============================================================================

-- 4.1 Acknowledge alert
CREATE OR REPLACE FUNCTION surveillance.acknowledge_alert(
    p_alert_id UUID,
    p_acknowledged_by VARCHAR(100)
)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE surveillance.alerts SET
        acknowledged_at = CURRENT_TIMESTAMP,
        acknowledged_by = p_acknowledged_by,
        updated_at = CURRENT_TIMESTAMP
    WHERE alert_id = p_alert_id
    AND acknowledged_at IS NULL;
    
    RETURN FOUND;
END;
$$;

-- 4.2 Resolve alert
CREATE OR REPLACE FUNCTION surveillance.resolve_alert(
    p_alert_id UUID,
    p_resolution_notes TEXT DEFAULT NULL,
    p_resolved_by VARCHAR(100) DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE surveillance.alerts SET
        alert_status = 'resolved',
        resolved_at = CURRENT_TIMESTAMP,
        resolved_by = p_resolved_by,
        resolution_notes = p_resolution_notes,
        updated_at = CURRENT_TIMESTAMP
    WHERE alert_id = p_alert_id
    AND alert_status = 'active';
    
    RETURN FOUND;
END;
$$;

-- 4.3 Dismiss alert (false alarm)
CREATE OR REPLACE FUNCTION surveillance.dismiss_alert(
    p_alert_id UUID,
    p_reason TEXT,
    p_dismissed_by VARCHAR(100)
)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE surveillance.alerts SET
        alert_status = 'dismissed',
        resolution_notes = 'DISMISSED: ' || p_reason,
        resolved_at = CURRENT_TIMESTAMP,
        resolved_by = p_dismissed_by,
        updated_at = CURRENT_TIMESTAMP
    WHERE alert_id = p_alert_id
    AND alert_status = 'active';
    
    RETURN FOUND;
END;
$$;

-- ============================================================================
-- SECTION 5: ALERT REPORTING
-- ============================================================================

-- 5.1 Get alert history
CREATE OR REPLACE FUNCTION surveillance.get_alert_history(
    p_days INTEGER DEFAULT 30,
    p_disease_code VARCHAR DEFAULT NULL,
    p_district_code VARCHAR DEFAULT NULL
)
RETURNS TABLE (
    alert_id UUID,
    alert_code VARCHAR,
    alert_level surveillance.alert_level,
    alert_status surveillance.alert_status,
    disease_name VARCHAR,
    district_name VARCHAR,
    detection_date DATE,
    resolved_at TIMESTAMP,
    days_to_resolution INTEGER,
    was_escalated BOOLEAN
)
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        a.alert_id,
        a.alert_code,
        a.alert_level,
        a.alert_status,
        d.disease_name,
        dist.district_name,
        a.detection_date,
        a.resolved_at,
        CASE WHEN a.resolved_at IS NOT NULL 
             THEN (a.resolved_at::DATE - a.detection_date)::INTEGER
             ELSE NULL END,
        a.escalated
    FROM surveillance.alerts a
    LEFT JOIN surveillance.diseases d ON a.disease_id = d.disease_id
    LEFT JOIN surveillance.districts dist ON a.district_id = dist.district_id
    WHERE a.created_at > CURRENT_DATE - p_days
    AND (p_disease_code IS NULL OR d.disease_code = p_disease_code)
    AND (p_district_code IS NULL OR dist.district_code = p_district_code)
    ORDER BY a.created_at DESC;
END;
$$;

-- 5.2 Alert statistics
CREATE OR REPLACE FUNCTION surveillance.get_alert_statistics(p_days INTEGER DEFAULT 30)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
    RETURN (
        SELECT jsonb_build_object(
            'period_days', p_days,
            'total_alerts', COUNT(*),
            'by_level', jsonb_build_object(
                'emergency', COUNT(*) FILTER (WHERE alert_level = 'emergency'),
                'outbreak', COUNT(*) FILTER (WHERE alert_level = 'outbreak'),
                'alert', COUNT(*) FILTER (WHERE alert_level = 'alert'),
                'watch', COUNT(*) FILTER (WHERE alert_level = 'watch')
            ),
            'by_status', jsonb_build_object(
                'active', COUNT(*) FILTER (WHERE alert_status = 'active'),
                'resolved', COUNT(*) FILTER (WHERE alert_status = 'resolved'),
                'dismissed', COUNT(*) FILTER (WHERE alert_status = 'dismissed')
            ),
            'escalated_count', COUNT(*) FILTER (WHERE escalated),
            'avg_time_to_acknowledge_hrs', ROUND(AVG(
                EXTRACT(EPOCH FROM (acknowledged_at - created_at))/3600
            ) FILTER (WHERE acknowledged_at IS NOT NULL), 1),
            'avg_time_to_resolve_days', ROUND(AVG(
                EXTRACT(EPOCH FROM (resolved_at - created_at))/86400
            ) FILTER (WHERE resolved_at IS NOT NULL), 1),
            'top_diseases', (
                SELECT COALESCE(jsonb_agg(jsonb_build_object(
                    'disease_name', d.disease_name,
                    'alert_count', sub.cnt
                ) ORDER BY sub.cnt DESC), '[]'::jsonb)
                FROM (
                    SELECT disease_id, COUNT(*) AS cnt
                    FROM surveillance.alerts
                    WHERE created_at > CURRENT_DATE - p_days
                    GROUP BY disease_id
                    ORDER BY cnt DESC
                    LIMIT 5
                ) sub
                JOIN surveillance.diseases d ON sub.disease_id = d.disease_id
            )
        )
        FROM surveillance.alerts
        WHERE created_at > CURRENT_DATE - p_days
    );
END;
$$;

-- ============================================================================
-- SECTION 6: SCHEDULED ALERT JOBS
-- ============================================================================

-- 6.1 Hourly alert check procedure
CREATE OR REPLACE PROCEDURE surveillance.run_hourly_alert_check()
LANGUAGE plpgsql
AS $$
BEGIN
    -- Generate new alerts
    CALL surveillance.generate_alerts();
    
    -- Auto-escalate stale alerts
    CALL surveillance.auto_escalate_alerts();
    
    RAISE NOTICE 'Hourly alert check completed at %', CURRENT_TIMESTAMP;
END;
$$;

-- 6.2 Daily alert summary
CREATE OR REPLACE FUNCTION surveillance.generate_daily_alert_summary()
RETURNS JSONB
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN jsonb_build_object(
        'summary_date', CURRENT_DATE - 1,
        'generated_at', CURRENT_TIMESTAMP,
        'alerts_generated', (
            SELECT COUNT(*) FROM surveillance.alerts 
            WHERE DATE(created_at) = CURRENT_DATE - 1
        ),
        'alerts_resolved', (
            SELECT COUNT(*) FROM surveillance.alerts 
            WHERE DATE(resolved_at) = CURRENT_DATE - 1
        ),
        'currently_active', (
            SELECT COUNT(*) FROM surveillance.alerts 
            WHERE alert_status = 'active'
        ),
        'critical_active', (
            SELECT COUNT(*) FROM surveillance.alerts 
            WHERE alert_status = 'active' 
            AND alert_level IN ('emergency', 'outbreak')
        ),
        'active_alerts', (
            SELECT COALESCE(jsonb_agg(jsonb_build_object(
                'alert_code', a.alert_code,
                'level', a.alert_level,
                'disease', d.disease_name,
                'district', dist.district_name,
                'days_active', CURRENT_DATE - a.detection_date
            ) ORDER BY 
                CASE a.alert_level WHEN 'emergency' THEN 1 WHEN 'outbreak' THEN 2 ELSE 3 END
            ), '[]'::jsonb)
            FROM surveillance.alerts a
            LEFT JOIN surveillance.diseases d ON a.disease_id = d.disease_id
            LEFT JOIN surveillance.districts dist ON a.district_id = dist.district_id
            WHERE a.alert_status = 'active'
        )
    );
END;
$$;

-- ============================================================================
-- VERIFICATION
-- ============================================================================

DO $$
DECLARE
    v_alert_func_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_alert_func_count
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'surveillance'
    AND (p.proname LIKE '%alert%' OR p.proname LIKE '%notif%');
    
    RAISE NOTICE '==========================================';
    RAISE NOTICE 'ALERT SYSTEM CREATED SUCCESSFULLY';
    RAISE NOTICE '==========================================';
    RAISE NOTICE 'Alert-related functions: %', v_alert_func_count;
    RAISE NOTICE '';
    RAISE NOTICE 'Alert Generation:';
    RAISE NOTICE '  - generate_alerts()          (procedure)';
    RAISE NOTICE '  - check_immediate_notification() (trigger)';
    RAISE NOTICE '';
    RAISE NOTICE 'Notification:';
    RAISE NOTICE '  - create_alert_notification()';
    RAISE NOTICE '  - send_notification()';
    RAISE NOTICE '  - notify_alert()             (procedure)';
    RAISE NOTICE '';
    RAISE NOTICE 'Escalation:';
    RAISE NOTICE '  - escalate_alert()';
    RAISE NOTICE '  - auto_escalate_alerts()     (procedure)';
    RAISE NOTICE '';
    RAISE NOTICE 'Alert Actions:';
    RAISE NOTICE '  - acknowledge_alert()';
    RAISE NOTICE '  - resolve_alert()';
    RAISE NOTICE '  - dismiss_alert()';
    RAISE NOTICE '';
    RAISE NOTICE 'Reporting:';
    RAISE NOTICE '  - get_alert_history()';
    RAISE NOTICE '  - get_alert_statistics()';
    RAISE NOTICE '  - generate_daily_alert_summary()';
    RAISE NOTICE '';
    RAISE NOTICE 'Scheduled Jobs:';
    RAISE NOTICE '  - run_hourly_alert_check()   (procedure)';
    RAISE NOTICE '==========================================';
END $$;
