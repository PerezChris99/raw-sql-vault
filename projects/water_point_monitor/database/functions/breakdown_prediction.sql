-- ============================================================================
-- Water Point Usage Monitor - Breakdown Prediction Functions
-- PostgreSQL 14+ with TimescaleDB 2.x
-- Functions for predicting and managing breakdown risks
-- ============================================================================

-- ============================================================================
-- Calculate Risk Score for Single Borehole
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_calculate_risk_score(
    p_borehole_id UUID
)
RETURNS TABLE (
    borehole_id UUID,
    borehole_name TEXT,
    risk_score NUMERIC,
    risk_level TEXT,
    usage_indicator NUMERIC,
    flow_indicator NUMERIC,
    cycling_indicator NUMERIC,
    pressure_indicator NUMERIC,
    runtime_indicator NUMERIC,
    indicators_json JSONB
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_usage_drop NUMERIC := 0;
    v_flow_deg NUMERIC := 0;
    v_cycling NUMERIC := 0;
    v_pressure NUMERIC := 0;
    v_runtime NUMERIC := 0;
    v_daily RECORD;
    v_borehole RECORD;
BEGIN
    -- Get borehole details
    SELECT * INTO v_borehole FROM boreholes WHERE boreholes.borehole_id = p_borehole_id;
    
    -- Get latest daily stats with rolling average
    SELECT 
        d.total_usage_liters,
        d.avg_flow_rate,
        d.runtime_hours,
        d.total_pump_cycles,
        d.avg_pressure,
        AVG(d.total_usage_liters) OVER (ORDER BY d.bucket ROWS BETWEEN 6 PRECEDING AND 1 PRECEDING) as rolling_7day_avg
    INTO v_daily
    FROM usage_daily_agg d
    WHERE d.borehole_id = p_borehole_id
      AND d.bucket >= NOW() - INTERVAL '14 days'
    ORDER BY d.bucket DESC
    LIMIT 1;
    
    IF v_daily IS NULL THEN
        RETURN QUERY SELECT 
            p_borehole_id,
            v_borehole.name,
            0::NUMERIC,
            'unknown'::TEXT,
            0::NUMERIC, 0::NUMERIC, 0::NUMERIC, 0::NUMERIC, 0::NUMERIC,
            '{}'::JSONB;
        RETURN;
    END IF;
    
    -- Calculate indicators
    
    -- 1. Usage drop (40% weight)
    v_usage_drop := CASE 
        WHEN v_daily.total_usage_liters < v_daily.rolling_7day_avg * 0.7 THEN 1.0
        WHEN v_daily.total_usage_liters < v_daily.rolling_7day_avg * 0.85 THEN 0.5
        ELSE 0.0
    END;
    
    -- 2. Flow degradation (30% weight)
    v_flow_deg := CASE 
        WHEN v_daily.avg_flow_rate < v_borehole.yield_lpm * 0.6 THEN 1.0
        WHEN v_daily.avg_flow_rate < v_borehole.yield_lpm * 0.8 THEN 0.5
        ELSE 0.0
    END;
    
    -- 3. Pump cycling (15% weight)
    v_cycling := CASE 
        WHEN v_daily.total_pump_cycles / NULLIF(v_daily.runtime_hours, 0) > 10 THEN 1.0
        WHEN v_daily.total_pump_cycles / NULLIF(v_daily.runtime_hours, 0) > 5 THEN 0.5
        ELSE 0.0
    END;
    
    -- 4. Pressure anomaly (10% weight)
    v_pressure := CASE 
        WHEN v_daily.avg_pressure < 1.5 OR v_daily.avg_pressure > 5 THEN 1.0
        WHEN v_daily.avg_pressure < 2 OR v_daily.avg_pressure > 4 THEN 0.3
        ELSE 0.0
    END;
    
    -- 5. Runtime increase (5% weight)
    v_runtime := CASE 
        WHEN v_daily.runtime_hours > 20 THEN 1.0
        WHEN v_daily.runtime_hours > 16 THEN 0.5
        ELSE 0.0
    END;
    
    RETURN QUERY SELECT 
        p_borehole_id,
        v_borehole.name,
        ROUND((v_usage_drop * 40 + v_flow_deg * 30 + v_cycling * 15 + v_pressure * 10 + v_runtime * 5)::NUMERIC, 1),
        CASE 
            WHEN (v_usage_drop * 40 + v_flow_deg * 30 + v_cycling * 15 + v_pressure * 10 + v_runtime * 5) >= 80 THEN 'emergency'
            WHEN (v_usage_drop * 40 + v_flow_deg * 30 + v_cycling * 15 + v_pressure * 10 + v_runtime * 5) >= 60 THEN 'critical'
            WHEN (v_usage_drop * 40 + v_flow_deg * 30 + v_cycling * 15 + v_pressure * 10 + v_runtime * 5) >= 40 THEN 'warning'
            WHEN (v_usage_drop * 40 + v_flow_deg * 30 + v_cycling * 15 + v_pressure * 10 + v_runtime * 5) >= 20 THEN 'info'
            ELSE 'normal'
        END::TEXT,
        v_usage_drop,
        v_flow_deg,
        v_cycling,
        v_pressure,
        v_runtime,
        jsonb_build_object(
            'usage_drop_pct', ROUND(100.0 * (v_daily.rolling_7day_avg - v_daily.total_usage_liters) / NULLIF(v_daily.rolling_7day_avg, 0), 1),
            'current_usage', ROUND(v_daily.total_usage_liters, 1),
            'avg_7day_usage', ROUND(v_daily.rolling_7day_avg, 1),
            'current_flow', ROUND(v_daily.avg_flow_rate, 2),
            'design_flow', v_borehole.yield_lpm,
            'flow_pct', ROUND(100.0 * v_daily.avg_flow_rate / NULLIF(v_borehole.yield_lpm, 0), 1),
            'pump_cycles_per_hour', ROUND(v_daily.total_pump_cycles / NULLIF(v_daily.runtime_hours, 0), 1),
            'avg_pressure', ROUND(v_daily.avg_pressure, 2),
            'runtime_hours', ROUND(v_daily.runtime_hours, 1)
        );
END;
$$;

COMMENT ON FUNCTION fn_calculate_risk_score IS 'Calculate breakdown risk score for a single borehole';

-- ============================================================================
-- Get Priority Breakdown Risk Queue
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_get_breakdown_risk_queue(
    p_min_risk NUMERIC DEFAULT 20,
    p_limit INTEGER DEFAULT 50
)
RETURNS TABLE (
    priority_rank BIGINT,
    borehole_id UUID,
    borehole_name TEXT,
    code TEXT,
    region TEXT,
    risk_score NUMERIC,
    risk_level TEXT,
    health_score NUMERIC,
    population_served INTEGER,
    last_maintenance DATE,
    days_since_maintenance INTEGER,
    indicators JSONB
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ROW_NUMBER() OVER (ORDER BY rs.risk_score DESC) as priority_rank,
        rs.borehole_id,
        rs.borehole_name,
        b.code,
        r.name as region,
        rs.risk_score,
        rs.risk_level,
        b.health_score,
        b.population_served,
        b.last_maintenance_date,
        EXTRACT(DAY FROM CURRENT_TIMESTAMP - b.last_maintenance_date::TIMESTAMPTZ)::INTEGER as days_since_maintenance,
        rs.indicators_json as indicators
    FROM boreholes b
    CROSS JOIN LATERAL fn_calculate_risk_score(b.borehole_id) rs
    LEFT JOIN regions r ON b.region_id = r.region_id
    WHERE b.status != 'decommissioned'
      AND rs.risk_score >= p_min_risk
    ORDER BY rs.risk_score DESC
    LIMIT p_limit;
END;
$$;

COMMENT ON FUNCTION fn_get_breakdown_risk_queue IS 'Get prioritized list of boreholes by breakdown risk';

-- ============================================================================
-- Generate Breakdown Alert
-- ============================================================================

CREATE OR REPLACE PROCEDURE sp_generate_breakdown_alerts(
    p_risk_threshold NUMERIC DEFAULT 40.0
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_borehole RECORD;
    v_risk RECORD;
    v_alert_type_id UUID;
    v_alerts_created INTEGER := 0;
BEGIN
    -- Get appropriate alert type
    SELECT alert_type_id INTO v_alert_type_id 
    FROM alert_types WHERE code = 'BREAKDOWN';
    
    FOR v_borehole IN 
        SELECT borehole_id FROM boreholes WHERE status NOT IN ('decommissioned', 'offline')
    LOOP
        SELECT * INTO v_risk FROM fn_calculate_risk_score(v_borehole.borehole_id);
        
        -- Check if risk exceeds threshold and no unresolved alert exists
        IF v_risk.risk_score >= p_risk_threshold THEN
            -- Check for existing unresolved alert
            IF NOT EXISTS (
                SELECT 1 FROM breakdown_alerts 
                WHERE borehole_id = v_borehole.borehole_id 
                  AND resolved = FALSE 
                  AND detected_at >= NOW() - INTERVAL '24 hours'
            ) THEN
                INSERT INTO breakdown_alerts (
                    borehole_id,
                    alert_type_id,
                    detected_at,
                    detection_method,
                    risk_score,
                    severity,
                    indicators
                )
                VALUES (
                    v_borehole.borehole_id,
                    v_alert_type_id,
                    CURRENT_TIMESTAMP,
                    'automated',
                    v_risk.risk_score,
                    v_risk.risk_level,
                    v_risk.indicators_json
                );
                
                v_alerts_created := v_alerts_created + 1;
            END IF;
        END IF;
    END LOOP;
    
    RAISE NOTICE 'Generated % new breakdown alerts', v_alerts_created;
END;
$$;

COMMENT ON PROCEDURE sp_generate_breakdown_alerts IS 'Automatically generate alerts for at-risk boreholes';

-- ============================================================================
-- Update Health Scores
-- ============================================================================

CREATE OR REPLACE PROCEDURE sp_update_health_scores()
LANGUAGE plpgsql
AS $$
DECLARE
    v_borehole RECORD;
    v_risk RECORD;
    v_new_score NUMERIC;
    v_updates INTEGER := 0;
BEGIN
    FOR v_borehole IN 
        SELECT borehole_id, health_score FROM boreholes WHERE status != 'decommissioned'
    LOOP
        SELECT * INTO v_risk FROM fn_calculate_risk_score(v_borehole.borehole_id);
        
        -- Health score is inverse of risk score
        v_new_score := GREATEST(0, 100 - v_risk.risk_score);
        
        -- Update if changed significantly
        IF ABS(v_new_score - COALESCE(v_borehole.health_score, 0)) > 2 THEN
            UPDATE boreholes 
            SET health_score = v_new_score,
                last_health_check = CURRENT_TIMESTAMP
            WHERE borehole_id = v_borehole.borehole_id;
            
            -- Record in history
            INSERT INTO health_score_history (
                recorded_at, borehole_id, health_score, 
                score_change, trend
            )
            VALUES (
                CURRENT_TIMESTAMP,
                v_borehole.borehole_id,
                v_new_score,
                v_new_score - COALESCE(v_borehole.health_score, 100),
                CASE 
                    WHEN v_new_score > COALESCE(v_borehole.health_score, 100) THEN 'improving'
                    WHEN v_new_score < COALESCE(v_borehole.health_score, 100) THEN 'declining'
                    ELSE 'stable'
                END
            );
            
            v_updates := v_updates + 1;
        END IF;
    END LOOP;
    
    RAISE NOTICE 'Updated health scores for % boreholes', v_updates;
END;
$$;

COMMENT ON PROCEDURE sp_update_health_scores IS 'Update health scores for all boreholes';

-- ============================================================================
-- Predict Time to Failure
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_predict_time_to_failure(
    p_borehole_id UUID
)
RETURNS TABLE (
    borehole_id UUID,
    current_health NUMERIC,
    degradation_rate NUMERIC,
    predicted_days_to_critical INTEGER,
    predicted_days_to_failure INTEGER,
    confidence TEXT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_current_health NUMERIC;
    v_slope NUMERIC;
    v_data_points INTEGER;
BEGIN
    -- Get current health
    SELECT health_score INTO v_current_health 
    FROM boreholes WHERE boreholes.borehole_id = p_borehole_id;
    
    -- Calculate degradation rate from history
    WITH numbered_data AS (
        SELECT 
            health_score,
            ROW_NUMBER() OVER (ORDER BY recorded_at) as day_num
        FROM health_score_history
        WHERE health_score_history.borehole_id = p_borehole_id
          AND recorded_at >= NOW() - INTERVAL '30 days'
    )
    SELECT 
        (COUNT(*) * SUM(day_num * health_score) - SUM(day_num) * SUM(health_score)) /
        NULLIF((COUNT(*) * SUM(day_num * day_num) - SUM(day_num) * SUM(day_num)), 0),
        COUNT(*)
    INTO v_slope, v_data_points
    FROM numbered_data;
    
    -- Default if insufficient data
    IF v_slope IS NULL OR v_data_points < 7 THEN
        v_slope := 0;
    END IF;
    
    RETURN QUERY SELECT 
        p_borehole_id,
        v_current_health,
        ROUND(v_slope, 3) as degradation_rate,
        CASE 
            WHEN v_slope >= 0 THEN NULL  -- Not declining
            ELSE ((v_current_health - 40) / ABS(v_slope))::INTEGER  -- Days to reach 40 (critical)
        END as predicted_days_to_critical,
        CASE 
            WHEN v_slope >= 0 THEN NULL
            ELSE ((v_current_health - 20) / ABS(v_slope))::INTEGER  -- Days to reach 20 (failure)
        END as predicted_days_to_failure,
        CASE 
            WHEN v_data_points < 7 THEN 'low'
            WHEN v_data_points < 14 THEN 'medium'
            ELSE 'high'
        END as confidence;
END;
$$;

COMMENT ON FUNCTION fn_predict_time_to_failure IS 'Predict days until critical/failure based on trend';

-- ============================================================================
-- Get Maintenance Recommendations
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_get_maintenance_recommendations(
    p_limit INTEGER DEFAULT 20
)
RETURNS TABLE (
    priority INTEGER,
    borehole_id UUID,
    borehole_name TEXT,
    code TEXT,
    risk_score NUMERIC,
    risk_level TEXT,
    days_until_failure INTEGER,
    recommended_action TEXT,
    estimated_urgency TEXT
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    WITH risk_data AS (
        SELECT 
            b.borehole_id,
            b.name,
            b.code,
            rs.risk_score,
            rs.risk_level,
            rs.indicators_json
        FROM boreholes b
        CROSS JOIN LATERAL fn_calculate_risk_score(b.borehole_id) rs
        WHERE b.status NOT IN ('decommissioned', 'offline')
    ),
    predictions AS (
        SELECT 
            rd.*,
            p.predicted_days_to_failure
        FROM risk_data rd
        CROSS JOIN LATERAL fn_predict_time_to_failure(rd.borehole_id) p
    )
    SELECT 
        ROW_NUMBER() OVER (ORDER BY 
            CASE 
                WHEN p.risk_level = 'emergency' THEN 1
                WHEN p.risk_level = 'critical' THEN 2
                WHEN p.risk_level = 'warning' THEN 3
                ELSE 4
            END,
            p.predicted_days_to_failure NULLS LAST
        )::INTEGER as priority,
        p.borehole_id,
        p.name as borehole_name,
        p.code,
        p.risk_score,
        p.risk_level,
        p.predicted_days_to_failure,
        CASE 
            WHEN p.risk_level = 'emergency' THEN 'Immediate dispatch - potential complete failure'
            WHEN p.risk_level = 'critical' THEN 'Schedule urgent maintenance within 24-48 hours'
            WHEN (p.indicators_json->>'flow_pct')::NUMERIC < 60 THEN 'Pump inspection - low flow rate'
            WHEN (p.indicators_json->>'pump_cycles_per_hour')::NUMERIC > 10 THEN 'Pump controller check - excessive cycling'
            WHEN (p.indicators_json->>'usage_drop_pct')::NUMERIC > 30 THEN 'System inspection - usage anomaly'
            WHEN p.risk_level = 'warning' THEN 'Schedule preventive maintenance'
            ELSE 'Monitor - no immediate action required'
        END as recommended_action,
        CASE 
            WHEN p.predicted_days_to_failure IS NOT NULL AND p.predicted_days_to_failure <= 7 THEN 'immediate'
            WHEN p.predicted_days_to_failure IS NOT NULL AND p.predicted_days_to_failure <= 14 THEN 'urgent'
            WHEN p.predicted_days_to_failure IS NOT NULL AND p.predicted_days_to_failure <= 30 THEN 'scheduled'
            ELSE 'routine'
        END as estimated_urgency
    FROM predictions p
    WHERE p.risk_score >= 20
    ORDER BY priority
    LIMIT p_limit;
END;
$$;

COMMENT ON FUNCTION fn_get_maintenance_recommendations IS 'Get prioritized maintenance recommendations';
