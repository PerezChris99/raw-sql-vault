-- ============================================================================
-- Water Point Usage Monitor - Sample Logs
-- PostgreSQL 14+ with TimescaleDB 2.x
-- Generate realistic usage data for testing time-series analysis
-- ============================================================================

-- ============================================================================
-- Generate Usage Logs (30 days of data)
-- ============================================================================

DO $$
DECLARE
    v_borehole RECORD;
    v_day INTEGER;
    v_hour INTEGER;
    v_timestamp TIMESTAMPTZ;
    v_base_usage NUMERIC;
    v_usage NUMERIC;
    v_flow_rate NUMERIC;
    v_pressure NUMERIC;
    v_runtime INTEGER;
    v_cycles INTEGER;
    v_day_factor NUMERIC;
    v_hour_factor NUMERIC;
    v_degradation_factor NUMERIC;
    v_anomaly_day INTEGER;
BEGIN
    -- Loop through each borehole
    FOR v_borehole IN SELECT * FROM boreholes WHERE status != 'decommissioned' LOOP
        
        -- Set base values based on borehole capacity
        v_base_usage := v_borehole.yield_lpm * 60 * 0.6;  -- 60% of hourly capacity
        v_anomaly_day := CASE 
            WHEN v_borehole.health_score < 50 THEN 5   -- Degraded: anomaly starts day 5
            WHEN v_borehole.health_score < 70 THEN 12  -- At risk: anomaly starts day 12
            ELSE 999  -- Healthy: no anomaly in 30 days
        END;
        
        -- Generate 30 days of data
        FOR v_day IN 0..29 LOOP
            
            -- Day of week factor (weekends slightly lower)
            v_day_factor := CASE 
                WHEN EXTRACT(DOW FROM (NOW() - (v_day || ' days')::INTERVAL)) IN (0, 6) 
                THEN 0.85 
                ELSE 1.0 
            END;
            
            -- Progressive degradation for troubled boreholes
            v_degradation_factor := CASE 
                WHEN v_day >= v_anomaly_day AND v_borehole.health_score < 70 THEN 
                    1.0 - (0.02 * (v_day - v_anomaly_day))  -- 2% degradation per day
                ELSE 1.0
            END;
            v_degradation_factor := GREATEST(v_degradation_factor, 0.3);  -- Floor at 30%
            
            -- Generate readings every 5 minutes (288 per day reduced for sample)
            -- Using hourly for demo to keep data size reasonable
            FOR v_hour IN 0..23 LOOP
                
                -- Hour factor (peak usage 6am-9am and 4pm-7pm)
                v_hour_factor := CASE 
                    WHEN v_hour BETWEEN 6 AND 9 THEN 1.4
                    WHEN v_hour BETWEEN 16 AND 19 THEN 1.3
                    WHEN v_hour BETWEEN 10 AND 15 THEN 0.8
                    WHEN v_hour BETWEEN 22 AND 5 THEN 0.3
                    ELSE 1.0
                END;
                
                v_timestamp := NOW() - (v_day || ' days')::INTERVAL 
                             + (v_hour || ' hours')::INTERVAL
                             + (RANDOM() * 30 || ' minutes')::INTERVAL;
                
                -- Calculate values with randomness
                v_usage := v_base_usage * v_day_factor * v_hour_factor * v_degradation_factor 
                         * (0.9 + RANDOM() * 0.2);  -- ±10% random variation
                
                v_flow_rate := v_borehole.yield_lpm * v_degradation_factor 
                             * (0.85 + RANDOM() * 0.15);
                
                -- Pressure drops when degraded
                v_pressure := CASE 
                    WHEN v_degradation_factor < 0.7 THEN 1.5 + RANDOM() * 0.5
                    WHEN v_degradation_factor < 0.9 THEN 2.0 + RANDOM() * 1.0
                    ELSE 2.5 + RANDOM() * 1.0
                END;
                
                -- Runtime increases when degraded (pump works harder)
                v_runtime := (3600 * v_hour_factor * (2.0 - v_degradation_factor) * (0.8 + RANDOM() * 0.4))::INTEGER;
                v_runtime := LEAST(v_runtime, 3600);  -- Cap at 1 hour
                
                -- Pump cycles increase when degraded
                v_cycles := CASE 
                    WHEN v_degradation_factor < 0.6 THEN (8 + RANDOM() * 8)::INTEGER   -- High cycling
                    WHEN v_degradation_factor < 0.8 THEN (4 + RANDOM() * 4)::INTEGER   -- Medium cycling
                    ELSE (1 + RANDOM() * 3)::INTEGER  -- Normal cycling
                END;
                
                INSERT INTO usage_logs (
                    logged_at, borehole_id, usage_liters, flow_rate_lpm,
                    pump_runtime_sec, pump_cycles, pump_status, pressure_bar,
                    voltage, temperature_c, source, reading_quality
                )
                VALUES (
                    v_timestamp,
                    v_borehole.borehole_id,
                    ROUND(v_usage, 2),
                    ROUND(v_flow_rate, 2),
                    v_runtime,
                    v_cycles,
                    CASE WHEN v_hour_factor > 0.5 THEN 'running' ELSE 'stopped' END,
                    ROUND(v_pressure::NUMERIC, 3),
                    CASE 
                        WHEN v_borehole.pump_type_id IS NOT NULL THEN 220 + RANDOM() * 10
                        ELSE NULL
                    END,
                    20 + RANDOM() * 8,  -- Water temp 20-28°C
                    'sensor',
                    CASE 
                        WHEN RANDOM() > 0.98 THEN 'suspect'  -- 2% suspect readings
                        ELSE 'normal'
                    END
                )
                ON CONFLICT (logged_at, borehole_id) DO NOTHING;
                
            END LOOP;  -- hours
        END LOOP;  -- days
        
        RAISE NOTICE 'Generated logs for borehole: %', v_borehole.code;
    END LOOP;  -- boreholes
END $$;

-- ============================================================================
-- Add some specific anomaly patterns for testing
-- ============================================================================

-- Simulate sudden breakdown pattern for offline borehole
DO $$
DECLARE
    v_offline_bh_id UUID;
    v_day INTEGER;
    v_hour INTEGER;
    v_timestamp TIMESTAMPTZ;
BEGIN
    SELECT borehole_id INTO v_offline_bh_id 
    FROM boreholes WHERE status = 'offline' LIMIT 1;
    
    IF v_offline_bh_id IS NOT NULL THEN
        -- Add dramatic decline pattern
        FOR v_day IN 0..4 LOOP
            FOR v_hour IN 6..18 LOOP
                v_timestamp := NOW() - ((25 + v_day) || ' days')::INTERVAL 
                             + (v_hour || ' hours')::INTERVAL;
                
                INSERT INTO usage_logs (
                    logged_at, borehole_id, usage_liters, flow_rate_lpm,
                    pump_runtime_sec, pump_cycles, pump_status, pressure_bar,
                    source, reading_quality
                )
                VALUES (
                    v_timestamp,
                    v_offline_bh_id,
                    (500 * (1 - v_day * 0.25))::NUMERIC,  -- Rapid decline
                    (30 * (1 - v_day * 0.2))::NUMERIC,
                    3600,  -- Continuous running
                    (15 + v_day * 5)::INTEGER,  -- Increasing cycles
                    'error',
                    1.0 - (v_day * 0.15),  -- Dropping pressure
                    'sensor',
                    'suspect'
                )
                ON CONFLICT (logged_at, borehole_id) DO NOTHING;
            END LOOP;
        END LOOP;
        
        RAISE NOTICE 'Added breakdown pattern for offline borehole';
    END IF;
END $$;

-- ============================================================================
-- Refresh Continuous Aggregates with Sample Data
-- ============================================================================

-- Refresh aggregates to include sample data
CALL refresh_continuous_aggregate('usage_hourly_agg', NOW() - INTERVAL '35 days', NOW());
CALL refresh_continuous_aggregate('usage_daily_agg', NOW() - INTERVAL '35 days', NOW());
CALL refresh_continuous_aggregate('usage_weekly_agg', NOW() - INTERVAL '35 days', NOW());

-- ============================================================================
-- Generate Health Score History
-- ============================================================================

INSERT INTO health_score_history (recorded_at, borehole_id, health_score, usage_score, flow_score, pressure_score, pump_score, score_change, trend)
SELECT 
    time_bucket('1 day', bucket) as recorded_at,
    borehole_id,
    -- Simplified health score calculation
    ROUND((
        LEAST(total_usage_liters / NULLIF(b.yield_lpm * 60 * 12, 0) * 100, 100) * 0.3 +
        LEAST(avg_flow_rate / NULLIF(b.yield_lpm, 0) * 100, 100) * 0.3 +
        CASE WHEN avg_pressure BETWEEN 2 AND 4 THEN 100 ELSE 60 END * 0.2 +
        CASE WHEN total_pump_cycles / NULLIF(runtime_hours, 0) < 5 THEN 100 ELSE 50 END * 0.2
    )::NUMERIC, 2) as health_score,
    ROUND(LEAST(total_usage_liters / NULLIF(b.yield_lpm * 60 * 12, 0) * 100, 100)::NUMERIC, 2),
    ROUND(LEAST(avg_flow_rate / NULLIF(b.yield_lpm, 0) * 100, 100)::NUMERIC, 2),
    CASE WHEN avg_pressure BETWEEN 2 AND 4 THEN 100.00 ELSE 60.00 END,
    CASE WHEN total_pump_cycles / NULLIF(runtime_hours, 0) < 5 THEN 100.00 ELSE 50.00 END,
    NULL,
    'stable'
FROM usage_daily_agg d
JOIN boreholes b ON d.borehole_id = b.borehole_id
WHERE d.bucket >= NOW() - INTERVAL '30 days'
ON CONFLICT (recorded_at, borehole_id) DO NOTHING;

-- ============================================================================
-- Create Sample Alerts
-- ============================================================================

DO $$
DECLARE
    v_degraded_bh_id UUID;
    v_usage_drop_type_id UUID;
    v_flow_type_id UUID;
    v_offline_bh_id UUID;
    v_breakdown_type_id UUID;
BEGIN
    SELECT borehole_id INTO v_degraded_bh_id 
    FROM boreholes WHERE health_score BETWEEN 40 AND 70 LIMIT 1;
    
    SELECT borehole_id INTO v_offline_bh_id 
    FROM boreholes WHERE status = 'offline' LIMIT 1;
    
    SELECT alert_type_id INTO v_usage_drop_type_id FROM alert_types WHERE code = 'USAGE_DROP';
    SELECT alert_type_id INTO v_flow_type_id FROM alert_types WHERE code = 'FLOW_DEGRADED';
    SELECT alert_type_id INTO v_breakdown_type_id FROM alert_types WHERE code = 'BREAKDOWN';
    
    -- Alert for degraded borehole
    IF v_degraded_bh_id IS NOT NULL THEN
        INSERT INTO breakdown_alerts (
            borehole_id, alert_type_id, detected_at, detection_method,
            risk_score, severity, indicators, acknowledged
        )
        VALUES (
            v_degraded_bh_id,
            v_usage_drop_type_id,
            NOW() - INTERVAL '2 days',
            'automated',
            55.0,
            'warning',
            '{"usage_drop_pct": 35.2, "flow_degradation": 0.72, "pump_cycles_per_hour": 6}'::JSONB,
            FALSE
        ),
        (
            v_degraded_bh_id,
            v_flow_type_id,
            NOW() - INTERVAL '1 day',
            'automated',
            48.0,
            'warning',
            '{"current_flow_lpm": 28.5, "design_flow_lpm": 45.0, "pct_of_design": 63.3}'::JSONB,
            TRUE
        );
    END IF;
    
    -- Critical alert for offline borehole
    IF v_offline_bh_id IS NOT NULL THEN
        INSERT INTO breakdown_alerts (
            borehole_id, alert_type_id, detected_at, detection_method,
            risk_score, severity, indicators, acknowledged, resolved, resolution_notes
        )
        VALUES (
            v_offline_bh_id,
            v_breakdown_type_id,
            NOW() - INTERVAL '5 days',
            'automated',
            92.0,
            'emergency',
            '{"usage_drop_pct": 85.0, "flow_degradation": 0.2, "pump_cycles_per_hour": 20, "pressure_anomaly": true}'::JSONB,
            TRUE,
            FALSE,
            NULL
        );
    END IF;
    
    RAISE NOTICE 'Sample alerts created';
END $$;

-- ============================================================================
-- Verify Sample Data
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE 'Sample data loaded:';
    RAISE NOTICE '  - Usage logs: %', (SELECT COUNT(*) FROM usage_logs);
    RAISE NOTICE '  - Health history records: %', (SELECT COUNT(*) FROM health_score_history);
    RAISE NOTICE '  - Breakdown alerts: %', (SELECT COUNT(*) FROM breakdown_alerts);
    RAISE NOTICE '  - Date range: % to %', 
        (SELECT MIN(logged_at)::DATE FROM usage_logs),
        (SELECT MAX(logged_at)::DATE FROM usage_logs);
END $$;

-- Quick preview of user's sample query
\echo ''
\echo 'Preview: User Sample Query Pattern'
\echo '=================================='
SELECT 
    borehole_id,
    date,
    avg_daily,
    prev as prev_day_avg,
    pct_change_vs_prev as change_pct
FROM vw_daily_usage_comparison
ORDER BY borehole_id, date DESC
LIMIT 10;
