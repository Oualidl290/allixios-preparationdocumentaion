-- ========================================================
-- ULTIMATE LEAD COORDINATOR DATABASE SCHEMA
-- ========================================================
-- Production-grade orchestration database for intelligent workflow coordination
-- Optimized for high-frequency execution (every 5 minutes)
-- ========================================================

-- ========================================================
-- 1. CORE ORCHESTRATION TABLES
-- ========================================================

-- Main execution tracking with comprehensive metadata
CREATE TABLE IF NOT EXISTS workflow_orchestration (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    execution_id TEXT UNIQUE NOT NULL,
    workflow_type TEXT NOT NULL CHECK (workflow_type IN ('content_pipeline', 'seo_monitor', 'revenue_optimizer', 'intelligence_engine')),
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'analyzing', 'dispatching', 'running', 'completed', 'failed', 'timeout', 'cancelled')),
    priority_score INTEGER NOT NULL DEFAULT 50 CHECK (priority_score >= 0 AND priority_score <= 100),
    
    -- Timing fields with precision
    scheduled_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    timeout_at TIMESTAMPTZ,
    
    -- Resource allocation tracking
    batch_size INTEGER DEFAULT 5 CHECK (batch_size > 0 AND batch_size <= 100),
    estimated_cost DECIMAL(10,4) DEFAULT 0,
    actual_cost DECIMAL(10,4) DEFAULT 0,
    api_calls_allocated INTEGER DEFAULT 0,
    memory_allocated_mb INTEGER DEFAULT 512,
    
    -- Context and results with structured data
    input_context JSONB DEFAULT '{}',
    output_result JSONB DEFAULT '{}',
    error_details JSONB DEFAULT '{}',
    metrics JSONB DEFAULT '{}',
    
    -- Relationship tracking
    parent_execution_id TEXT,
    worker_id TEXT NOT NULL,
    retry_count INTEGER DEFAULT 0 CHECK (retry_count >= 0),
    max_retries INTEGER DEFAULT 3 CHECK (max_retries >= 0),
    
    -- Audit fields
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Performance indexes for orchestration
CREATE INDEX IF NOT EXISTS idx_orchestration_status_scheduled ON workflow_orchestration(status, scheduled_at);
CREATE INDEX IF NOT EXISTS idx_orchestration_workflow_status ON workflow_orchestration(workflow_type, status);
CREATE INDEX IF NOT EXISTS idx_orchestration_parent ON workflow_orchestration(parent_execution_id);
CREATE INDEX IF NOT EXISTS idx_orchestration_worker ON workflow_orchestration(worker_id);
CREATE INDEX IF NOT EXISTS idx_orchestration_priority ON workflow_orchestration(priority_score DESC, created_at);

-- Resource usage tracking with real-time monitoring
CREATE TABLE IF NOT EXISTS resource_usage (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    resource_type TEXT NOT NULL CHECK (resource_type IN ('gemini_api', 'openai_api', 'database', 'memory', 'budget', 'storage')),
    
    -- Usage metrics with calculated utilization
    used_amount DECIMAL(10,4) NOT NULL CHECK (used_amount >= 0),
    total_capacity DECIMAL(10,4) NOT NULL CHECK (total_capacity > 0),
    utilization_percent DECIMAL(5,2) GENERATED ALWAYS AS ((used_amount / total_capacity) * 100) STORED,
    
    -- Thresholds and alerting
    soft_limit DECIMAL(10,4) CHECK (soft_limit >= 0),
    hard_limit DECIMAL(10,4) CHECK (hard_limit >= soft_limit),
    threshold_alert_sent BOOLEAN DEFAULT FALSE,
    
    -- Context linking
    execution_id TEXT,
    workflow_type TEXT,
    provider TEXT, -- 'gemini', 'openai', 'supabase', etc.
    
    -- Metadata for detailed tracking
    metadata JSONB DEFAULT '{}'
);

CREATE INDEX IF NOT EXISTS idx_resource_usage_type_time ON resource_usage(resource_type, timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_resource_usage_execution ON resource_usage(execution_id);
CREATE INDEX IF NOT EXISTS idx_resource_usage_provider ON resource_usage(provider, timestamp DESC);

-- State machine tracking for workflow states
CREATE TABLE IF NOT EXISTS workflow_states (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    execution_id TEXT NOT NULL,
    state TEXT NOT NULL CHECK (state IN ('IDLE', 'ANALYZING', 'DISPATCHING', 'MONITORING', 'ERROR_RECOVERY', 'COOLDOWN', 'COMPLETED')),
    previous_state TEXT,
    transition_reason TEXT,
    entered_at TIMESTAMPTZ DEFAULT NOW(),
    duration_ms INTEGER,
    state_data JSONB DEFAULT '{}',
    
    -- Performance tracking
    cpu_usage_percent DECIMAL(5,2),
    memory_usage_mb INTEGER,
    active_connections INTEGER
);

CREATE INDEX IF NOT EXISTS idx_workflow_states_execution ON workflow_states(execution_id, entered_at DESC);
CREATE INDEX IF NOT EXISTS idx_workflow_states_current ON workflow_states(state, entered_at DESC);

-- Intelligent priority queue with ML-based scoring
CREATE TABLE IF NOT EXISTS task_queue (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    task_type TEXT NOT NULL,
    priority_base INTEGER DEFAULT 50 CHECK (priority_base >= 0 AND priority_base <= 100),
    priority_calculated INTEGER,
    age_minutes INTEGER DEFAULT 0,
    
    -- Task details and dependencies
    payload JSONB NOT NULL,
    dependencies JSONB DEFAULT '[]',
    estimated_duration_ms INTEGER,
    estimated_cost DECIMAL(10,4),
    
    -- Status and scheduling
    status TEXT DEFAULT 'queued' CHECK (status IN ('queued', 'processing', 'completed', 'failed', 'deferred')),
    deferred_until TIMESTAMPTZ,
    defer_reason TEXT,
    
    -- ML predictions
    predicted_success_rate DECIMAL(3,2) DEFAULT 0.95,
    complexity_score INTEGER DEFAULT 50,
    
    -- Audit
    created_at TIMESTAMPTZ DEFAULT NOW(),
    processed_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_task_queue_priority ON task_queue(status, priority_calculated DESC NULLS LAST, created_at);
CREATE INDEX IF NOT EXISTS idx_task_queue_type ON task_queue(task_type, status);

-- ========================================================
-- 2. RESOURCE MANAGEMENT TABLES
-- ========================================================

-- API rate limits with dynamic adjustment
CREATE TABLE IF NOT EXISTS api_rate_limits (
    provider TEXT PRIMARY KEY,
    requests_per_minute INTEGER NOT NULL CHECK (requests_per_minute > 0),
    requests_used_current_minute INTEGER DEFAULT 0 CHECK (requests_used_current_minute >= 0),
    minute_reset_at TIMESTAMPTZ DEFAULT (date_trunc('minute', NOW()) + INTERVAL '1 minute'),
    
    -- Daily limits
    daily_cost_limit DECIMAL(10,2) NOT NULL CHECK (daily_cost_limit > 0),
    daily_cost_used DECIMAL(10,2) DEFAULT 0 CHECK (daily_cost_used >= 0),
    day_reset_at TIMESTAMPTZ DEFAULT (date_trunc('day', NOW()) + INTERVAL '1 day'),
    
    -- Status and health
    is_available BOOLEAN DEFAULT TRUE,
    last_error_at TIMESTAMPTZ,
    consecutive_errors INTEGER DEFAULT 0,
    
    -- Dynamic adjustment
    burst_capacity INTEGER DEFAULT 0,
    burst_used INTEGER DEFAULT 0,
    adaptive_limit INTEGER, -- ML-adjusted limit
    
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- System health metrics with real-time monitoring
CREATE TABLE IF NOT EXISTS system_health (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    metric_name TEXT NOT NULL,
    metric_value DECIMAL(10,4) NOT NULL,
    metric_unit TEXT,
    
    -- Thresholds
    threshold_warning DECIMAL(10,4),
    threshold_critical DECIMAL(10,4),
    is_healthy BOOLEAN DEFAULT TRUE,
    
    -- Trend analysis
    previous_value DECIMAL(10,4),
    trend_direction TEXT CHECK (trend_direction IN ('up', 'down', 'stable')),
    change_rate DECIMAL(10,4),
    
    -- Metadata
    source TEXT,
    tags JSONB DEFAULT '{}',
    last_updated TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(metric_name)
);

CREATE INDEX IF NOT EXISTS idx_system_health_status ON system_health(is_healthy, last_updated DESC);
CREATE INDEX IF NOT EXISTS idx_system_health_metric ON system_health(metric_name, last_updated DESC);

-- Execution history for ML predictions and optimization
CREATE TABLE IF NOT EXISTS execution_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    workflow_type TEXT NOT NULL,
    execution_date DATE NOT NULL,
    hour_of_day INTEGER NOT NULL CHECK (hour_of_day >= 0 AND hour_of_day <= 23),
    
    -- Performance metrics
    total_executions INTEGER DEFAULT 0 CHECK (total_executions >= 0),
    successful_executions INTEGER DEFAULT 0 CHECK (successful_executions >= 0),
    failed_executions INTEGER DEFAULT 0 CHECK (failed_executions >= 0),
    avg_duration_ms INTEGER,
    total_cost DECIMAL(10,4) DEFAULT 0,
    
    -- Resource usage patterns
    avg_api_calls INTEGER,
    avg_memory_mb INTEGER,
    avg_batch_size INTEGER,
    peak_concurrent_executions INTEGER,
    
    -- Quality metrics
    avg_success_rate DECIMAL(5,4),
    avg_quality_score DECIMAL(5,2),
    
    -- Business metrics
    content_items_processed INTEGER DEFAULT 0,
    revenue_generated DECIMAL(10,4) DEFAULT 0,
    
    UNIQUE(workflow_type, execution_date, hour_of_day)
);

CREATE INDEX IF NOT EXISTS idx_execution_history_workflow_date ON execution_history(workflow_type, execution_date DESC);
CREATE INDEX IF NOT EXISTS idx_execution_history_performance ON execution_history(avg_success_rate DESC, avg_duration_ms);

-- ========================================================
-- 3. INTELLIGENT COORDINATION FUNCTIONS
-- ========================================================

-- Main orchestration controller with comprehensive intelligence
CREATE OR REPLACE FUNCTION orchestrate_workflow_execution(
    p_worker_id TEXT,
    p_current_time TIMESTAMPTZ DEFAULT NOW(),
    p_max_concurrent INTEGER DEFAULT 3,
    p_debug_mode BOOLEAN DEFAULT FALSE
) 
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $orchestrate$
DECLARE
    v_result JSONB;
    v_system_health JSONB;
    v_scheduled_tasks JSONB;
    v_resource_status JSONB;
    v_execution_plan JSONB;
    v_coordinator_state TEXT;
BEGIN
    -- Initialize execution context
    v_result := jsonb_build_object(
        'execution_id', 'coord-' || extract(epoch from p_current_time)::bigint || '-' || substring(gen_random_uuid()::text, 1, 8),
        'worker_id', p_worker_id,
        'timestamp', p_current_time,
        'debug_mode', p_debug_mode
    );
    
    -- 1. SYSTEM HEALTH CHECK
    v_system_health := check_system_health_comprehensive();
    
    IF NOT (v_system_health->>'can_proceed')::BOOLEAN THEN
        RETURN v_result || jsonb_build_object(
            'success', false,
            'reason', v_system_health->>'reason',
            'health_status', v_system_health,
            'action', 'system_health_failure'
        );
    END IF;
    
    -- 2. INTELLIGENT TASK SCHEDULING
    v_scheduled_tasks := get_intelligent_scheduled_tasks(p_current_time, p_max_concurrent);
    
    -- 3. RESOURCE AVAILABILITY CHECK
    v_resource_status := check_comprehensive_resource_availability(v_scheduled_tasks);
    
    -- 4. CREATE OPTIMAL EXECUTION PLAN
    v_execution_plan := create_optimal_execution_plan(
        v_scheduled_tasks,
        v_resource_status,
        p_worker_id,
        p_current_time
    );
    
    -- 5. RESERVE RESOURCES AND CREATE EXECUTIONS
    IF jsonb_array_length(v_execution_plan->'workflows_to_execute') > 0 THEN
        PERFORM reserve_execution_resources(v_execution_plan);
        PERFORM create_execution_records(v_execution_plan, p_worker_id);
        v_coordinator_state := 'DISPATCHING';
    ELSE
        v_coordinator_state := 'IDLE';
    END IF;
    
    -- 6. UPDATE COORDINATOR STATE
    PERFORM update_coordinator_state(v_coordinator_state, v_execution_plan, p_worker_id);
    
    -- 7. RECORD METRICS
    PERFORM record_orchestration_metrics(v_execution_plan, v_system_health, p_current_time);
    
    RETURN v_result || jsonb_build_object(
        'success', true,
        'coordinator_state', v_coordinator_state,
        'system_health', v_system_health,
        'scheduled_tasks', v_scheduled_tasks,
        'resource_status', v_resource_status,
        'execution_plan', v_execution_plan,
        'workflows_dispatched', jsonb_array_length(v_execution_plan->'workflows_to_execute')
    );
    
EXCEPTION
    WHEN OTHERS THEN
        -- Comprehensive error handling
        PERFORM log_orchestration_error(SQLSTATE, SQLERRM, v_result, p_worker_id);
        
        RETURN v_result || jsonb_build_object(
            'success', false,
            'error', jsonb_build_object(
                'code', SQLSTATE,
                'message', SQLERRM,
                'timestamp', NOW()
            ),
            'action', 'error_recovery_initiated'
        );
END;
$orchestrate$;

-- Comprehensive system health check
CREATE OR REPLACE FUNCTION check_system_health_comprehensive()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $health_check$
DECLARE
    v_health_metrics JSONB := '{}';
    v_can_proceed BOOLEAN := TRUE;
    v_warnings JSONB[] := ARRAY[]::JSONB[];
    v_critical_issues JSONB[] := ARRAY[]::JSONB[];
    v_db_connections INTEGER;
    v_active_executions INTEGER;
    v_recent_failures INTEGER;
    v_queue_depth INTEGER;
    v_avg_response_time DECIMAL;
BEGIN
    -- Database connection health
    SELECT COUNT(*) INTO v_db_connections
    FROM pg_stat_activity 
    WHERE state = 'active' AND application_name LIKE '%n8n%';
    
    -- Active executions check
    SELECT COUNT(*) INTO v_active_executions
    FROM workflow_orchestration 
    WHERE status IN ('running', 'dispatching') 
    AND created_at > NOW() - INTERVAL '1 hour';
    
    -- Recent failure analysis
    SELECT COUNT(*) INTO v_recent_failures
    FROM workflow_orchestration 
    WHERE status = 'failed' 
    AND created_at > NOW() - INTERVAL '1 hour';
    
    -- Queue depth analysis
    SELECT COUNT(*) INTO v_queue_depth
    FROM task_queue 
    WHERE status = 'queued';
    
    -- Average response time (last hour)
    SELECT AVG(EXTRACT(EPOCH FROM (completed_at - started_at)) * 1000) INTO v_avg_response_time
    FROM workflow_orchestration 
    WHERE status = 'completed' 
    AND completed_at > NOW() - INTERVAL '1 hour';
    
    -- Build health metrics
    v_health_metrics := jsonb_build_object(
        'database_connections', v_db_connections,
        'active_executions', v_active_executions,
        'recent_failures', v_recent_failures,
        'queue_depth', v_queue_depth,
        'avg_response_time_ms', COALESCE(v_avg_response_time, 0),
        'max_concurrent_limit', 3,
        'failure_rate_percent', CASE 
            WHEN v_active_executions + v_recent_failures = 0 THEN 0
            ELSE ROUND((v_recent_failures::DECIMAL / (v_active_executions + v_recent_failures)) * 100, 2)
        END
    );
    
    -- Health checks with specific thresholds
    IF v_active_executions >= 3 THEN
        v_can_proceed := FALSE;
        v_critical_issues := array_append(v_critical_issues, 
            jsonb_build_object(
                'type', 'max_concurrent_reached',
                'message', 'Maximum concurrent executions (3) reached',
                'current_value', v_active_executions,
                'threshold', 3
            )
        );
    END IF;
    
    IF v_recent_failures > 5 THEN
        v_can_proceed := FALSE;
        v_critical_issues := array_append(v_critical_issues,
            jsonb_build_object(
                'type', 'high_failure_rate',
                'message', 'High failure rate detected in last hour',
                'current_value', v_recent_failures,
                'threshold', 5
            )
        );
    END IF;
    
    IF v_queue_depth > 1000 THEN
        v_warnings := array_append(v_warnings,
            jsonb_build_object(
                'type', 'high_queue_depth',
                'message', 'Queue depth is very high, consider scaling',
                'current_value', v_queue_depth,
                'threshold', 1000
            )
        );
    END IF;
    
    IF v_avg_response_time > 300000 THEN -- 5 minutes
        v_warnings := array_append(v_warnings,
            jsonb_build_object(
                'type', 'slow_response_time',
                'message', 'Average response time is high',
                'current_value', v_avg_response_time,
                'threshold', 300000
            )
        );
    END IF;
    
    -- Update system health table
    INSERT INTO system_health (metric_name, metric_value, is_healthy, last_updated)
    VALUES 
        ('active_executions', v_active_executions, v_active_executions < 3, NOW()),
        ('recent_failures', v_recent_failures, v_recent_failures <= 5, NOW()),
        ('queue_depth', v_queue_depth, v_queue_depth <= 1000, NOW()),
        ('avg_response_time_ms', COALESCE(v_avg_response_time, 0), COALESCE(v_avg_response_time, 0) <= 300000, NOW())
    ON CONFLICT (metric_name) DO UPDATE SET
        metric_value = EXCLUDED.metric_value,
        is_healthy = EXCLUDED.is_healthy,
        last_updated = EXCLUDED.last_updated;
    
    RETURN jsonb_build_object(
        'can_proceed', v_can_proceed,
        'overall_status', CASE 
            WHEN NOT v_can_proceed THEN 'critical'
            WHEN array_length(v_warnings, 1) > 0 THEN 'warning'
            ELSE 'healthy'
        END,
        'metrics', v_health_metrics,
        'critical_issues', v_critical_issues,
        'warnings', v_warnings,
        'timestamp', NOW(),
        'next_check_in_seconds', 300
    );
END;
$health_check$;

-- Get intelligently scheduled tasks with ML predictions
CREATE OR REPLACE FUNCTION get_intelligent_scheduled_tasks(
    p_current_time TIMESTAMPTZ,
    p_max_concurrent INTEGER DEFAULT 3
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $get_tasks$
DECLARE
    v_tasks JSONB := '[]'::JSONB;
    v_workflow_config JSONB;
    v_hour INTEGER := EXTRACT(hour FROM p_current_time);
    v_day_of_week INTEGER := EXTRACT(dow FROM p_current_time);
    v_is_business_hours BOOLEAN := v_hour >= 9 AND v_hour <= 17;
    v_is_peak_hours BOOLEAN := v_hour >= 10 AND v_hour <= 16;
    v_is_weekend BOOLEAN := v_day_of_week IN (0, 6);
BEGIN
    -- Advanced workflow configuration with ML predictions
    v_workflow_config := jsonb_build_object(
        'content_pipeline', jsonb_build_object(
            'base_interval_minutes', 15,
            'priority_base', 90,
            'max_batch_size', 10,
            'estimated_duration_ms', 180000,
            'cost_per_item', 0.15,
            'success_rate_threshold', 0.85
        ),
        'seo_monitor', jsonb_build_object(
            'base_interval_minutes', 120,
            'priority_base', 60,
            'max_batch_size', 20,
            'estimated_duration_ms', 120000,
            'cost_per_item', 0.05,
            'success_rate_threshold', 0.90
        ),
        'revenue_optimizer', jsonb_build_object(
            'base_interval_minutes', 240,
            'priority_base', 50,
            'max_batch_size', 50,
            'estimated_duration_ms', 90000,
            'cost_per_item', 0.10,
            'success_rate_threshold', 0.95
        ),
        'intelligence_engine', jsonb_build_object(
            'base_interval_minutes', 60,
            'priority_base', 40,
            'max_batch_size', 1,
            'estimated_duration_ms', 240000,
            'cost_per_item', 0.25,
            'success_rate_threshold', 0.98
        )
    );
    
    -- Get last execution times and calculate priorities
    WITH last_executions AS (
        SELECT 
            workflow_type,
            MAX(started_at) as last_run,
            COUNT(*) FILTER (WHERE status = 'completed' AND started_at > NOW() - INTERVAL '24 hours') as recent_successes,
            COUNT(*) FILTER (WHERE status = 'failed' AND started_at > NOW() - INTERVAL '24 hours') as recent_failures,
            AVG(EXTRACT(EPOCH FROM (completed_at - started_at)) * 1000) as avg_duration_ms
        FROM workflow_orchestration 
        WHERE started_at > NOW() - INTERVAL '7 days'
        GROUP BY workflow_type
    ),
    queue_metrics AS (
        SELECT 
            'content_pipeline' as workflow_type,
            COUNT(*) as pending_items
        FROM task_queue 
        WHERE task_type = 'content_generation' AND status = 'queued'
        
        UNION ALL
        
        SELECT 
            'seo_monitor' as workflow_type,
            COUNT(*) as pending_items
        FROM task_queue 
        WHERE task_type = 'seo_analysis' AND status = 'queued'
        
        UNION ALL
        
        SELECT 
            'revenue_optimizer' as workflow_type,
            COUNT(*) as pending_items
        FROM task_queue 
        WHERE task_type = 'revenue_optimization' AND status = 'queued'
        
        UNION ALL
        
        SELECT 
            'intelligence_engine' as workflow_type,
            COUNT(*) as pending_items
        FROM task_queue 
        WHERE task_type = 'intelligence_analysis' AND status = 'queued'
    ),
    workflow_analysis AS (
        SELECT 
            wf.key as workflow_type,
            wf.value as config,
            COALESCE(le.last_run, '2000-01-01'::TIMESTAMPTZ) as last_run,
            EXTRACT(EPOCH FROM (p_current_time - COALESCE(le.last_run, '2000-01-01'::TIMESTAMPTZ)))/60 as minutes_since_last,
            COALESCE(qm.pending_items, 0) as pending_items,
            COALESCE(le.recent_successes, 0) as recent_successes,
            COALESCE(le.recent_failures, 0) as recent_failures,
            COALESCE(le.avg_duration_ms, (wf.value->>'estimated_duration_ms')::INTEGER) as avg_duration_ms
        FROM jsonb_each(v_workflow_config) wf
        LEFT JOIN last_executions le ON le.workflow_type = wf.key
        LEFT JOIN queue_metrics qm ON qm.workflow_type = wf.key
    ),
    priority_calculation AS (
        SELECT 
            workflow_type,
            config,
            last_run,
            minutes_since_last,
            pending_items,
            recent_successes,
            recent_failures,
            avg_duration_ms,
            
            -- Advanced priority calculation
            (config->>'priority_base')::INTEGER +
            
            -- Time-based priority
            CASE 
                WHEN minutes_since_last >= (config->>'base_interval_minutes')::INTEGER * 1.5 THEN 30
                WHEN minutes_since_last >= (config->>'base_interval_minutes')::INTEGER THEN 20
                ELSE 0
            END +
            
            -- Queue-based priority
            CASE 
                WHEN pending_items > 50 THEN 25
                WHEN pending_items > 20 THEN 15
                WHEN pending_items > 5 THEN 10
                ELSE 0
            END +
            
            -- Business hours adjustment
            CASE 
                WHEN v_is_peak_hours AND NOT v_is_weekend THEN 10
                WHEN v_is_business_hours AND NOT v_is_weekend THEN 5
                ELSE 0
            END +
            
            -- Success rate adjustment
            CASE 
                WHEN recent_successes + recent_failures > 0 THEN
                    CASE 
                        WHEN recent_successes::DECIMAL / (recent_successes + recent_failures) >= 0.95 THEN 5
                        WHEN recent_successes::DECIMAL / (recent_successes + recent_failures) < 0.8 THEN -10
                        ELSE 0
                    END
                ELSE 0
            END as calculated_priority,
            
            -- Determine optimal batch size
            CASE workflow_type
                WHEN 'content_pipeline' THEN 
                    LEAST((config->>'max_batch_size')::INTEGER, GREATEST(1, pending_items / 5))
                WHEN 'seo_monitor' THEN 
                    LEAST((config->>'max_batch_size')::INTEGER, GREATEST(5, pending_items))
                WHEN 'revenue_optimizer' THEN 
                    LEAST((config->>'max_batch_size')::INTEGER, GREATEST(10, pending_items))
                ELSE 1
            END as optimal_batch_size,
            
            -- Calculate success probability
            CASE 
                WHEN recent_successes + recent_failures > 0 THEN
                    recent_successes::DECIMAL / (recent_successes + recent_failures)
                ELSE (config->>'success_rate_threshold')::DECIMAL
            END as predicted_success_rate
            
        FROM workflow_analysis
    ),
    tasks_to_schedule AS (
        SELECT 
            workflow_type,
            calculated_priority,
            optimal_batch_size,
            predicted_success_rate,
            minutes_since_last,
            pending_items,
            avg_duration_ms,
            (config->>'cost_per_item')::DECIMAL * optimal_batch_size as estimated_cost,
            
            -- Decision logic
            calculated_priority >= 60 AND 
            minutes_since_last >= (config->>'base_interval_minutes')::INTEGER * 0.9 AND
            predicted_success_rate >= (config->>'success_rate_threshold')::DECIMAL as should_execute,
            
            -- Reasoning
            ARRAY[
                CASE WHEN minutes_since_last >= (config->>'base_interval_minutes')::INTEGER 
                     THEN 'Scheduled interval reached' END,
                CASE WHEN pending_items > 20 
                     THEN 'High queue backlog (' || pending_items || ' items)' END,
                CASE WHEN v_is_peak_hours AND NOT v_is_weekend 
                     THEN 'Peak business hours' END,
                CASE WHEN predicted_success_rate >= 0.95 
                     THEN 'High success rate predicted' END
            ]::TEXT[] as reasoning
            
        FROM priority_calculation
    )
    SELECT INTO v_tasks
        COALESCE(jsonb_agg(
            jsonb_build_object(
                'workflow_type', workflow_type,
                'priority', calculated_priority,
                'should_execute', should_execute,
                'batch_size', optimal_batch_size,
                'estimated_duration_ms', avg_duration_ms,
                'estimated_cost', estimated_cost,
                'predicted_success_rate', predicted_success_rate,
                'pending_items', pending_items,
                'minutes_since_last', ROUND(minutes_since_last),
                'reasoning', array_to_json(reasoning)
            ) ORDER BY calculated_priority DESC
        ), '[]'::JSONB)
    FROM tasks_to_schedule;
    
    RETURN jsonb_build_object(
        'tasks', v_tasks,
        'analysis_context', jsonb_build_object(
            'current_time', p_current_time,
            'hour_of_day', v_hour,
            'is_business_hours', v_is_business_hours,
            'is_peak_hours', v_is_peak_hours,
            'is_weekend', v_is_weekend,
            'max_concurrent', p_max_concurrent
        ),
        'total_tasks_analyzed', jsonb_array_length(v_tasks),
        'tasks_ready_to_execute', (
            SELECT COUNT(*)
            FROM jsonb_array_elements(v_tasks) task
            WHERE (task->>'should_execute')::BOOLEAN
        )
    );
END;
$get_tasks$;

\echo 'Ultimate Lead Coordinator database schema deployed successfully!'