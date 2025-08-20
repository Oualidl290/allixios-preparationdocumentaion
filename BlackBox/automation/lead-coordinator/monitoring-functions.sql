-- ========================================================
-- ULTIMATE LEAD COORDINATOR - MONITORING & ANALYTICS
-- ========================================================
-- Advanced monitoring, state management, and analytics functions
-- ========================================================

-- Update coordinator state with comprehensive tracking
CREATE OR REPLACE FUNCTION update_coordinator_state(
    p_state TEXT,
    p_execution_plan JSONB,
    p_worker_id TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $update_state$
DECLARE
    v_previous_state TEXT;
    v_state_duration INTEGER;
BEGIN
    -- Get previous state for transition tracking
    SELECT state, EXTRACT(EPOCH FROM (NOW() - entered_at)) * 1000
    INTO v_previous_state, v_state_duration
    FROM workflow_states 
    WHERE execution_id = (p_execution_plan->>'plan_id')
    ORDER BY entered_at DESC 
    LIMIT 1;
    
    -- Insert new state record
    INSERT INTO workflow_states (
        execution_id,
        state,
        previous_state,
        transition_reason,
        entered_at,
        duration_ms,
        state_data
    ) VALUES (
        p_execution_plan->>'plan_id',
        p_state,
        v_previous_state,
        CASE p_state
            WHEN 'ANALYZING' THEN 'System health check completed'
            WHEN 'DISPATCHING' THEN 'Workflows scheduled for execution'
            WHEN 'MONITORING' THEN 'Executions in progress'
            WHEN 'IDLE' THEN 'No workflows to execute'
            WHEN 'ERROR_RECOVERY' THEN 'Error detected, initiating recovery'
            ELSE 'State transition'
        END,
        NOW(),
        v_state_duration,
        jsonb_build_object(
            'worker_id', p_worker_id,
            'workflows_count', jsonb_array_length(p_execution_plan->'workflows_to_execute'),
            'total_estimated_cost', p_execution_plan->'resource_allocation'->>'total_estimated_cost',
            'execution_strategy', p_execution_plan->>'execution_strategy'
        )
    );
    
    RETURN TRUE;
    
EXCEPTION
    WHEN OTHERS THEN
        -- Log state update failure
        INSERT INTO workflow_states (
            execution_id,
            state,
            transition_reason,
            state_data
        ) VALUES (
            'state-update-failed',
            'ERROR',
            'Failed to update coordinator state: ' || SQLERRM,
            jsonb_build_object(
                'error_code', SQLSTATE,
                'worker_id', p_worker_id,
                'target_state', p_state
            )
        );
        
        RETURN FALSE;
END;
$update_state$;

-- Record comprehensive orchestration metrics
CREATE OR REPLACE FUNCTION record_orchestration_metrics(
    p_execution_plan JSONB,
    p_system_health JSONB,
    p_timestamp TIMESTAMPTZ
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $record_metrics$
DECLARE
    v_workflow JSONB;
    v_hour INTEGER := EXTRACT(hour FROM p_timestamp);
    v_date DATE := p_timestamp::DATE;
BEGIN
    -- Record system-level metrics
    INSERT INTO system_health (metric_name, metric_value, metric_unit, is_healthy, last_updated)
    VALUES 
        ('coordinator_executions_per_hour', 
         jsonb_array_length(p_execution_plan->'workflows_to_execute'), 
         'count', 
         jsonb_array_length(p_execution_plan->'workflows_to_execute') <= 10,
         p_timestamp),
        ('coordinator_total_cost_estimate',
         (p_execution_plan->'resource_allocation'->>'total_estimated_cost')::DECIMAL,
         'usd',
         (p_execution_plan->'resource_allocation'->>'total_estimated_cost')::DECIMAL <= 50,
         p_timestamp),
        ('coordinator_resource_efficiency',
         (p_execution_plan->'resource_allocation'->>'resource_efficiency_score')::DECIMAL,
         'percentage',
         (p_execution_plan->'resource_allocation'->>'resource_efficiency_score')::DECIMAL >= 80,
         p_timestamp)
    ON CONFLICT (metric_name) DO UPDATE SET
        metric_value = EXCLUDED.metric_value,
        is_healthy = EXCLUDED.is_healthy,
        last_updated = EXCLUDED.last_updated;
    
    -- Record workflow-specific metrics in execution history
    FOR v_workflow IN SELECT jsonb_array_elements(p_execution_plan->'workflows_to_execute')
    LOOP
        INSERT INTO execution_history (
            workflow_type,
            execution_date,
            hour_of_day,
            total_executions,
            avg_duration_ms,
            total_cost,
            avg_batch_size,
            avg_success_rate
        ) VALUES (
            v_workflow->>'workflow_type',
            v_date,
            v_hour,
            1,
            (v_workflow->>'estimated_duration_ms')::INTEGER,
            (v_workflow->>'estimated_cost')::DECIMAL,
            (v_workflow->>'batch_size')::INTEGER,
            (v_workflow->>'predicted_success_rate')::DECIMAL
        )
        ON CONFLICT (workflow_type, execution_date, hour_of_day) DO UPDATE SET
            total_executions = execution_history.total_executions + 1,
            avg_duration_ms = (execution_history.avg_duration_ms + (v_workflow->>'estimated_duration_ms')::INTEGER) / 2,
            total_cost = execution_history.total_cost + (v_workflow->>'estimated_cost')::DECIMAL,
            avg_batch_size = (execution_history.avg_batch_size + (v_workflow->>'batch_size')::INTEGER) / 2,
            avg_success_rate = (execution_history.avg_success_rate + (v_workflow->>'predicted_success_rate')::DECIMAL) / 2;
    END LOOP;
    
    -- Record resource usage metrics
    INSERT INTO resource_usage (
        resource_type,
        used_amount,
        total_capacity,
        execution_id,
        metadata
    ) VALUES (
        'orchestration_cycle',
        1,
        12, -- 12 cycles per hour (every 5 minutes)
        p_execution_plan->>'plan_id',
        jsonb_build_object(
            'workflows_dispatched', jsonb_array_length(p_execution_plan->'workflows_to_execute'),
            'system_health_status', p_system_health->>'overall_status',
            'resource_efficiency', p_execution_plan->'resource_allocation'->>'resource_efficiency_score',
            'timestamp', p_timestamp
        )
    );
END;
$record_metrics$;

-- Log orchestration errors with comprehensive context
CREATE OR REPLACE FUNCTION log_orchestration_error(
    p_error_code TEXT,
    p_error_message TEXT,
    p_execution_context JSONB,
    p_worker_id TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $log_error$
BEGIN
    -- Insert error into workflow orchestration table
    INSERT INTO workflow_orchestration (
        execution_id,
        workflow_type,
        status,
        error_details,
        worker_id,
        input_context
    ) VALUES (
        'error-' || extract(epoch from NOW())::bigint || '-' || substring(gen_random_uuid()::text, 1, 8),
        'coordinator_error',
        'failed',
        jsonb_build_object(
            'error_code', p_error_code,
            'error_message', p_error_message,
            'timestamp', NOW(),
            'recovery_action', 'automatic_retry_scheduled'
        ),
        p_worker_id,
        p_execution_context
    );
    
    -- Update system health to reflect error
    INSERT INTO system_health (metric_name, metric_value, is_healthy, last_updated)
    VALUES (
        'coordinator_error_count',
        1,
        FALSE,
        NOW()
    )
    ON CONFLICT (metric_name) DO UPDATE SET
        metric_value = system_health.metric_value + 1,
        is_healthy = system_health.metric_value < 5, -- Healthy if less than 5 errors
        last_updated = NOW();
    
    -- Log to resource usage for monitoring
    INSERT INTO resource_usage (
        resource_type,
        used_amount,
        total_capacity,
        execution_id,
        metadata
    ) VALUES (
        'error_tracking',
        1,
        10, -- Max 10 errors before critical status
        'error-log',
        jsonb_build_object(
            'error_code', p_error_code,
            'error_message', p_error_message,
            'worker_id', p_worker_id,
            'context', p_execution_context
        )
    );
END;
$log_error$;

-- Get coordinator performance dashboard
CREATE OR REPLACE FUNCTION get_coordinator_dashboard(
    p_hours_back INTEGER DEFAULT 24
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $dashboard$
DECLARE
    v_dashboard JSONB;
    v_execution_stats JSONB;
    v_resource_stats JSONB;
    v_performance_stats JSONB;
    v_health_stats JSONB;
BEGIN
    -- Execution statistics
    WITH execution_summary AS (
        SELECT 
            COUNT(*) as total_executions,
            COUNT(*) FILTER (WHERE status = 'completed') as successful_executions,
            COUNT(*) FILTER (WHERE status = 'failed') as failed_executions,
            COUNT(*) FILTER (WHERE status IN ('running', 'dispatching')) as active_executions,
            AVG(EXTRACT(EPOCH FROM (completed_at - started_at)) * 1000) as avg_duration_ms,
            SUM(actual_cost) as total_cost,
            AVG(batch_size) as avg_batch_size
        FROM workflow_orchestration
        WHERE created_at > NOW() - (p_hours_back || ' hours')::INTERVAL
        AND worker_id LIKE 'lead-coordinator%'
    )
    SELECT INTO v_execution_stats
        jsonb_build_object(
            'total_executions', total_executions,
            'successful_executions', successful_executions,
            'failed_executions', failed_executions,
            'active_executions', active_executions,
            'success_rate_percent', CASE 
                WHEN total_executions > 0 THEN 
                    ROUND((successful_executions::DECIMAL / total_executions) * 100, 2)
                ELSE 0
            END,
            'avg_duration_ms', ROUND(COALESCE(avg_duration_ms, 0)),
            'total_cost_usd', COALESCE(total_cost, 0),
            'avg_batch_size', ROUND(COALESCE(avg_batch_size, 0), 1)
        )
    FROM execution_summary;
    
    -- Resource utilization statistics
    WITH resource_summary AS (
        SELECT 
            resource_type,
            AVG(utilization_percent) as avg_utilization,
            MAX(utilization_percent) as peak_utilization,
            COUNT(*) as measurement_count
        FROM resource_usage
        WHERE timestamp > NOW() - (p_hours_back || ' hours')::INTERVAL
        GROUP BY resource_type
    )
    SELECT INTO v_resource_stats
        jsonb_object_agg(
            resource_type,
            jsonb_build_object(
                'avg_utilization_percent', ROUND(avg_utilization, 2),
                'peak_utilization_percent', ROUND(peak_utilization, 2),
                'measurement_count', measurement_count,
                'status', CASE 
                    WHEN avg_utilization > 90 THEN 'critical'
                    WHEN avg_utilization > 70 THEN 'warning'
                    ELSE 'healthy'
                END
            )
        )
    FROM resource_summary;
    
    -- Performance trends
    WITH hourly_performance AS (
        SELECT 
            DATE_TRUNC('hour', created_at) as hour,
            COUNT(*) as executions_per_hour,
            AVG(EXTRACT(EPOCH FROM (completed_at - started_at)) * 1000) as avg_duration_ms,
            SUM(actual_cost) as cost_per_hour
        FROM workflow_orchestration
        WHERE created_at > NOW() - (p_hours_back || ' hours')::INTERVAL
        AND worker_id LIKE 'lead-coordinator%'
        AND status = 'completed'
        GROUP BY DATE_TRUNC('hour', created_at)
        ORDER BY hour DESC
        LIMIT 24
    )
    SELECT INTO v_performance_stats
        jsonb_build_object(
            'hourly_trends', jsonb_agg(
                jsonb_build_object(
                    'hour', hour,
                    'executions', executions_per_hour,
                    'avg_duration_ms', ROUND(avg_duration_ms),
                    'cost_usd', cost_per_hour
                ) ORDER BY hour DESC
            ),
            'peak_hour_executions', MAX(executions_per_hour),
            'avg_hourly_cost', ROUND(AVG(cost_per_hour), 4)
        )
    FROM hourly_performance;
    
    -- Current system health
    WITH health_summary AS (
        SELECT 
            COUNT(*) as total_metrics,
            COUNT(*) FILTER (WHERE is_healthy) as healthy_metrics,
            jsonb_object_agg(metric_name, 
                jsonb_build_object(
                    'value', metric_value,
                    'is_healthy', is_healthy,
                    'last_updated', last_updated
                )
            ) as metrics_detail
        FROM system_health
        WHERE last_updated > NOW() - INTERVAL '1 hour'
    )
    SELECT INTO v_health_stats
        jsonb_build_object(
            'overall_health_percent', CASE 
                WHEN total_metrics > 0 THEN 
                    ROUND((healthy_metrics::DECIMAL / total_metrics) * 100, 2)
                ELSE 100
            END,
            'total_metrics', total_metrics,
            'healthy_metrics', healthy_metrics,
            'metrics_detail', metrics_detail,
            'status', CASE 
                WHEN total_metrics = 0 THEN 'unknown'
                WHEN healthy_metrics::DECIMAL / total_metrics >= 0.9 THEN 'healthy'
                WHEN healthy_metrics::DECIMAL / total_metrics >= 0.7 THEN 'warning'
                ELSE 'critical'
            END
        )
    FROM health_summary;
    
    -- Compile dashboard
    v_dashboard := jsonb_build_object(
        'coordinator_dashboard', jsonb_build_object(
            'generated_at', NOW(),
            'time_range_hours', p_hours_back,
            'execution_stats', v_execution_stats,
            'resource_stats', v_resource_stats,
            'performance_stats', v_performance_stats,
            'health_stats', v_health_stats,
            'recommendations', generate_coordinator_recommendations(v_execution_stats, v_resource_stats, v_health_stats)
        )
    );
    
    RETURN v_dashboard;
END;
$dashboard$;

-- Generate intelligent recommendations based on performance data
CREATE OR REPLACE FUNCTION generate_coordinator_recommendations(
    p_execution_stats JSONB,
    p_resource_stats JSONB,
    p_health_stats JSONB
)
RETURNS JSONB[]
LANGUAGE plpgsql
SECURITY DEFINER
AS $recommendations$
DECLARE
    v_recommendations JSONB[] := ARRAY[]::JSONB[];
    v_success_rate DECIMAL;
    v_avg_duration DECIMAL;
    v_health_percent DECIMAL;
BEGIN
    v_success_rate := (p_execution_stats->>'success_rate_percent')::DECIMAL;
    v_avg_duration := (p_execution_stats->>'avg_duration_ms')::DECIMAL;
    v_health_percent := (p_health_stats->>'overall_health_percent')::DECIMAL;
    
    -- Success rate recommendations
    IF v_success_rate < 95 THEN
        v_recommendations := array_append(v_recommendations,
            jsonb_build_object(
                'type', 'reliability',
                'priority', CASE WHEN v_success_rate < 90 THEN 'critical' ELSE 'high' END,
                'title', 'Improve Success Rate',
                'description', 'Success rate is ' || v_success_rate || '%. Investigate failed executions.',
                'action', 'Review error logs and optimize workflow configurations',
                'metric_value', v_success_rate,
                'target_value', 95
            )
        );
    END IF;
    
    -- Performance recommendations
    IF v_avg_duration > 300000 THEN -- 5 minutes
        v_recommendations := array_append(v_recommendations,
            jsonb_build_object(
                'type', 'performance',
                'priority', 'medium',
                'title', 'Optimize Execution Time',
                'description', 'Average execution time is ' || ROUND(v_avg_duration/1000) || ' seconds.',
                'action', 'Consider reducing batch sizes or optimizing database queries',
                'metric_value', v_avg_duration,
                'target_value', 180000
            )
        );
    END IF;
    
    -- Health recommendations
    IF v_health_percent < 80 THEN
        v_recommendations := array_append(v_recommendations,
            jsonb_build_object(
                'type', 'health',
                'priority', 'critical',
                'title', 'System Health Critical',
                'description', 'Only ' || v_health_percent || '% of health metrics are healthy.',
                'action', 'Immediate investigation required for failing health checks',
                'metric_value', v_health_percent,
                'target_value', 95
            )
        );
    END IF;
    
    -- Resource utilization recommendations
    IF p_resource_stats ? 'gemini_api' AND 
       (p_resource_stats->'gemini_api'->>'avg_utilization_percent')::DECIMAL > 80 THEN
        v_recommendations := array_append(v_recommendations,
            jsonb_build_object(
                'type', 'resource_optimization',
                'priority', 'medium',
                'title', 'High API Utilization',
                'description', 'Gemini API utilization is high. Consider rate limiting.',
                'action', 'Implement intelligent batching or reduce API call frequency',
                'metric_value', (p_resource_stats->'gemini_api'->>'avg_utilization_percent')::DECIMAL,
                'target_value', 70
            )
        );
    END IF;
    
    -- If no issues, provide optimization suggestions
    IF array_length(v_recommendations, 1) IS NULL OR array_length(v_recommendations, 1) = 0 THEN
        v_recommendations := array_append(v_recommendations,
            jsonb_build_object(
                'type', 'optimization',
                'priority', 'low',
                'title', 'System Running Optimally',
                'description', 'All metrics are within healthy ranges. Consider advanced optimizations.',
                'action', 'Explore ML-based prediction improvements or cost optimization strategies',
                'metric_value', 100,
                'target_value', 100
            )
        );
    END IF;
    
    RETURN v_recommendations;
END;
$recommendations$;

-- Initialize API rate limits with default values
INSERT INTO api_rate_limits (provider, requests_per_minute, daily_cost_limit) VALUES
    ('gemini', 60, 300.00),
    ('openai', 50, 200.00),
    ('supabase', 1000, 0.00)
ON CONFLICT (provider) DO NOTHING;

\echo 'Ultimate Lead Coordinator monitoring functions deployed successfully!'