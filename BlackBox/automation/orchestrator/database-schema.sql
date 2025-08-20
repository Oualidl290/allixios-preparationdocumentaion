-- ========================================================
-- ORCHESTRATOR DATABASE SCHEMA
-- ========================================================
-- Core database schema for the Master Orchestrator Pattern
-- Supports workflow execution tracking, resource management, and monitoring

-- ========================================================
-- 1. CORE ORCHESTRATION TABLES
-- ========================================================

-- Main workflow execution tracking table
CREATE TABLE IF NOT EXISTS workflow_orchestration (
    execution_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    workflow_type TEXT NOT NULL CHECK (workflow_type IN ('content_pipeline', 'seo_monitor', 'revenue_optimizer', 'intelligence_engine')),
    status TEXT NOT NULL CHECK (status IN ('queued', 'analyzing', 'dispatching', 'running', 'completed', 'failed', 'retrying', 'timeout', 'cancelled')),
    priority INTEGER NOT NULL DEFAULT 50 CHECK (priority >= 0 AND priority <= 100),
    
    -- Timing fields
    scheduled_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    timeout_at TIMESTAMPTZ,
    
    -- Execution context and data
    context JSONB NOT NULL DEFAULT '{}',
    input_data JSONB,
    result_data JSONB,
    error_data JSONB,
    
    -- Relationship tracking
    parent_execution_id UUID REFERENCES workflow_orchestration(execution_id),
    batch_id UUID,
    worker_id TEXT,
    
    -- Retry and recovery
    retry_count INTEGER DEFAULT 0,
    max_retries INTEGER DEFAULT 3,
    next_retry_at TIMESTAMPTZ,
    
    -- Performance metrics
    duration_ms INTEGER,
    cost_usd DECIMAL(10,4),
    items_processed INTEGER,
    api_calls_made INTEGER,
    
    -- Audit fields
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Resource usage tracking for cost and limit management
CREATE TABLE IF NOT EXISTS workflow_resource_usage (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    execution_id UUID NOT NULL REFERENCES workflow_orchestration(execution_id) ON DELETE CASCADE,
    resource_type TEXT NOT NULL CHECK (resource_type IN ('api_call', 'database_query', 'memory_usage', 'storage_usage')),
    provider TEXT, -- 'gemini', 'openai', 'supabase', 'system'
    usage_amount INTEGER NOT NULL,
    cost_usd DECIMAL(10,4),
    rate_limit_remaining INTEGER,
    metadata JSONB DEFAULT '{}',
    timestamp TIMESTAMPTZ DEFAULT NOW()
);

-- System health and performance metrics
CREATE TABLE IF NOT EXISTS orchestrator_metrics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    metric_type TEXT NOT NULL CHECK (metric_type IN ('throughput', 'latency', 'success_rate', 'cost_efficiency', 'queue_depth', 'api_usage', 'error_rate', 'system_health')),
    metric_value DECIMAL(12,4) NOT NULL,
    metric_unit TEXT, -- 'per_minute', 'milliseconds', 'percentage', 'usd', 'count'
    workflow_type TEXT,
    metadata JSONB DEFAULT '{}',
    timestamp TIMESTAMPTZ DEFAULT NOW()
);

-- Orchestrator state management
CREATE TABLE IF NOT EXISTS orchestrator_state (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    state_type TEXT NOT NULL CHECK (state_type IN ('IDLE', 'ANALYZING', 'DISPATCHING', 'MONITORING', 'ERROR_RECOVERY', 'COOLDOWN')),
    context JSONB NOT NULL DEFAULT '{}',
    active_executions JSONB DEFAULT '[]',
    resource_status JSONB DEFAULT '{}',
    last_heartbeat TIMESTAMPTZ DEFAULT NOW(),
    worker_id TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ========================================================
-- 2. PERFORMANCE INDEXES
-- ========================================================

-- Orchestration table indexes
CREATE INDEX IF NOT EXISTS idx_workflow_orchestration_status ON workflow_orchestration(status);
CREATE INDEX IF NOT EXISTS idx_workflow_orchestration_type ON workflow_orchestration(workflow_type);
CREATE INDEX IF NOT EXISTS idx_workflow_orchestration_priority ON workflow_orchestration(priority DESC, created_at ASC);
CREATE INDEX IF NOT EXISTS idx_workflow_orchestration_scheduled ON workflow_orchestration(scheduled_at);
CREATE INDEX IF NOT EXISTS idx_workflow_orchestration_parent ON workflow_orchestration(parent_execution_id);
CREATE INDEX IF NOT EXISTS idx_workflow_orchestration_worker ON workflow_orchestration(worker_id);
CREATE INDEX IF NOT EXISTS idx_workflow_orchestration_retry ON workflow_orchestration(next_retry_at) WHERE next_retry_at IS NOT NULL;

-- Resource usage indexes
CREATE INDEX IF NOT EXISTS idx_resource_usage_execution ON workflow_resource_usage(execution_id);
CREATE INDEX IF NOT EXISTS idx_resource_usage_provider ON workflow_resource_usage(provider, timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_resource_usage_type ON workflow_resource_usage(resource_type, timestamp DESC);

-- Metrics indexes
CREATE INDEX IF NOT EXISTS idx_orchestrator_metrics_type ON orchestrator_metrics(metric_type, timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_orchestrator_metrics_workflow ON orchestrator_metrics(workflow_type, timestamp DESC);

-- State management indexes
CREATE INDEX IF NOT EXISTS idx_orchestrator_state_type ON orchestrator_state(state_type);
CREATE INDEX IF NOT EXISTS idx_orchestrator_state_worker ON orchestrator_state(worker_id);
CREATE INDEX IF NOT EXISTS idx_orchestrator_state_heartbeat ON orchestrator_state(last_heartbeat DESC);

-- ========================================================
-- 3. CORE ORCHESTRATION FUNCTIONS
-- ========================================================

-- Get next scheduled tasks with intelligent prioritization
CREATE OR REPLACE FUNCTION orchestrate_next_execution(
    p_worker_id TEXT DEFAULT NULL,
    p_max_tasks INTEGER DEFAULT 5,
    p_resource_limits JSONB DEFAULT '{}'::JSONB
)
RETURNS TABLE (
    execution_id UUID,
    workflow_type TEXT,
    priority INTEGER,
    priority_score INTEGER,
    input_data JSONB,
    should_execute BOOLEAN,
    reason TEXT,
    estimated_cost DECIMAL,
    estimated_duration INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_worker_id TEXT;
    v_current_time TIMESTAMPTZ := NOW();
    v_queue_depth INTEGER;
    v_system_load DECIMAL;
BEGIN
    -- Generate worker ID if not provided
    v_worker_id := COALESCE(p_worker_id, 'orchestrator-' || gen_random_uuid()::TEXT);
    
    -- Get current queue depth for load balancing
    SELECT COUNT(*) INTO v_queue_depth
    FROM workflow_orchestration
    WHERE status IN ('queued', 'retrying');
    
    -- Calculate system load factor
    v_system_load := LEAST(v_queue_depth / 100.0, 1.0);
    
    RETURN QUERY
    WITH priority_calculation AS (
        SELECT 
            wo.execution_id,
            wo.workflow_type,
            wo.priority,
            wo.input_data,
            wo.context,
            wo.retry_count,
            wo.created_at,
            -- Priority scoring algorithm: (Priority × 10) + (Age in minutes) + starvation prevention
            (wo.priority * 10 + 
             EXTRACT(EPOCH FROM (v_current_time - wo.created_at)) / 60 +
             CASE WHEN EXTRACT(EPOCH FROM (v_current_time - wo.created_at)) / 60 > 30 THEN 50 ELSE 0 END -
             wo.retry_count * 5
            )::INTEGER as priority_score,
            -- Estimate cost based on workflow type and context
            CASE wo.workflow_type
                WHEN 'content_pipeline' THEN 0.15
                WHEN 'seo_monitor' THEN 0.05
                WHEN 'revenue_optimizer' THEN 0.02
                WHEN 'intelligence_engine' THEN 0.08
                ELSE 0.10
            END as estimated_cost,
            -- Estimate duration based on workflow type
            CASE wo.workflow_type
                WHEN 'content_pipeline' THEN 180
                WHEN 'seo_monitor' THEN 120
                WHEN 'revenue_optimizer' THEN 60
                WHEN 'intelligence_engine' THEN 240
                ELSE 120
            END as estimated_duration
        FROM workflow_orchestration wo
        WHERE wo.status IN ('queued', 'retrying')
          AND (wo.next_retry_at IS NULL OR wo.next_retry_at <= v_current_time)
          AND wo.retry_count < wo.max_retries
    ),
    resource_check AS (
        SELECT 
            pc.*,
            -- Resource availability check
            CASE 
                WHEN pc.workflow_type = 'content_pipeline' AND 
                     (p_resource_limits->>'gemini_remaining')::INTEGER < 10 THEN FALSE
                WHEN pc.estimated_cost > (p_resource_limits->>'budget_remaining')::DECIMAL THEN FALSE
                WHEN v_system_load > 0.8 AND pc.priority < 80 THEN FALSE
                ELSE TRUE
            END as should_execute,
            CASE 
                WHEN pc.workflow_type = 'content_pipeline' AND 
                     (p_resource_limits->>'gemini_remaining')::INTEGER < 10 THEN 'API rate limit'
                WHEN pc.estimated_cost > (p_resource_limits->>'budget_remaining')::DECIMAL THEN 'Budget limit'
                WHEN v_system_load > 0.8 AND pc.priority < 80 THEN 'System overload'
                ELSE 'Ready for execution'
            END as reason
        FROM priority_calculation pc
    )
    SELECT 
        rc.execution_id,
        rc.workflow_type,
        rc.priority,
        rc.priority_score,
        rc.input_data,
        rc.should_execute,
        rc.reason,
        rc.estimated_cost,
        rc.estimated_duration
    FROM resource_check rc
    ORDER BY rc.priority_score DESC, rc.created_at ASC
    LIMIT p_max_tasks;
END;
$$;

-- Enqueue new workflow task
CREATE OR REPLACE FUNCTION enqueue_workflow_task(
    p_workflow_type TEXT,
    p_priority INTEGER DEFAULT 50,
    p_input_data JSONB DEFAULT '{}'::JSONB,
    p_scheduled_at TIMESTAMPTZ DEFAULT NOW(),
    p_context JSONB DEFAULT '{}'::JSONB
) 
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_execution_id UUID;
BEGIN
    INSERT INTO workflow_orchestration (
        workflow_type,
        status,
        priority,
        scheduled_at,
        input_data,
        context
    ) VALUES (
        p_workflow_type,
        'queued',
        p_priority,
        p_scheduled_at,
        p_input_data,
        p_context
    ) RETURNING execution_id INTO v_execution_id;
    
    -- Record metrics
    INSERT INTO orchestrator_metrics (metric_type, metric_value, workflow_type, metadata)
    VALUES ('queue_depth', 1, p_workflow_type, jsonb_build_object('action', 'enqueued'));
    
    RETURN v_execution_id;
END;
$$;

-- Update execution status with comprehensive tracking
CREATE OR REPLACE FUNCTION update_execution_status(
    p_execution_id UUID,
    p_status TEXT,
    p_result_data JSONB DEFAULT NULL,
    p_error_data JSONB DEFAULT NULL,
    p_metrics JSONB DEFAULT '{}'::JSONB
) 
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_old_status TEXT;
    v_workflow_type TEXT;
    v_started_at TIMESTAMPTZ;
    v_duration_ms INTEGER;
BEGIN
    -- Get current status and start time
    SELECT status, workflow_type, started_at 
    INTO v_old_status, v_workflow_type, v_started_at
    FROM workflow_orchestration 
    WHERE execution_id = p_execution_id;
    
    IF NOT FOUND THEN
        RETURN FALSE;
    END IF;
    
    -- Calculate duration if completing
    IF p_status IN ('completed', 'failed', 'timeout') AND v_started_at IS NOT NULL THEN
        v_duration_ms := EXTRACT(EPOCH FROM (NOW() - v_started_at)) * 1000;
    END IF;
    
    -- Update the execution record
    UPDATE workflow_orchestration SET
        status = p_status,
        result_data = COALESCE(p_result_data, result_data),
        error_data = COALESCE(p_error_data, error_data),
        completed_at = CASE WHEN p_status IN ('completed', 'failed', 'timeout') THEN NOW() ELSE completed_at END,
        started_at = CASE WHEN p_status = 'running' AND started_at IS NULL THEN NOW() ELSE started_at END,
        duration_ms = COALESCE(v_duration_ms, duration_ms),
        cost_usd = COALESCE((p_metrics->>'cost_usd')::DECIMAL, cost_usd),
        items_processed = COALESCE((p_metrics->>'items_processed')::INTEGER, items_processed),
        api_calls_made = COALESCE((p_metrics->>'api_calls_made')::INTEGER, api_calls_made),
        updated_at = NOW()
    WHERE execution_id = p_execution_id;
    
    -- Record state transition metrics
    INSERT INTO orchestrator_metrics (metric_type, metric_value, workflow_type, metadata)
    VALUES ('state_transition', 1, v_workflow_type, 
            jsonb_build_object('from', v_old_status, 'to', p_status, 'execution_id', p_execution_id));
    
    -- Record completion metrics
    IF p_status = 'completed' THEN
        INSERT INTO orchestrator_metrics (metric_type, metric_value, workflow_type, metadata)
        VALUES 
            ('success_rate', 1, v_workflow_type, jsonb_build_object('execution_id', p_execution_id)),
            ('latency', v_duration_ms, v_workflow_type, jsonb_build_object('execution_id', p_execution_id));
    ELSIF p_status = 'failed' THEN
        INSERT INTO orchestrator_metrics (metric_type, metric_value, workflow_type, metadata)
        VALUES ('error_rate', 1, v_workflow_type, jsonb_build_object('execution_id', p_execution_id, 'error', p_error_data));
    END IF;
    
    RETURN TRUE;
END;
$$;

-- ========================================================
-- 4. RESOURCE MANAGEMENT FUNCTIONS
-- ========================================================

-- Check API limits and resource availability
CREATE OR REPLACE FUNCTION check_resource_availability()
RETURNS TABLE (
    resource_type TEXT,
    provider TEXT,
    available BOOLEAN,
    current_usage INTEGER,
    limit_value INTEGER,
    remaining INTEGER,
    reset_time TIMESTAMPTZ,
    cost_today DECIMAL
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    WITH api_usage_today AS (
        SELECT 
            wru.provider,
            COUNT(*) as calls_today,
            SUM(wru.cost_usd) as cost_today,
            MAX(wru.rate_limit_remaining) as last_remaining
        FROM workflow_resource_usage wru
        WHERE wru.resource_type = 'api_call'
          AND wru.timestamp >= CURRENT_DATE
        GROUP BY wru.provider
    ),
    resource_limits AS (
        SELECT * FROM (VALUES
            ('api_call', 'gemini', 60, 300.00),
            ('api_call', 'openai', 50, 200.00),
            ('database_query', 'supabase', 1000, 0.00)
        ) AS t(resource_type, provider, per_minute_limit, daily_cost_limit)
    )
    SELECT 
        rl.resource_type,
        rl.provider,
        CASE 
            WHEN COALESCE(aut.calls_today, 0) < rl.per_minute_limit * 0.8 
             AND COALESCE(aut.cost_today, 0) < rl.daily_cost_limit * 0.9 
            THEN TRUE 
            ELSE FALSE 
        END as available,
        COALESCE(aut.calls_today, 0)::INTEGER as current_usage,
        rl.per_minute_limit as limit_value,
        GREATEST(0, rl.per_minute_limit - COALESCE(aut.calls_today, 0))::INTEGER as remaining,
        (CURRENT_DATE + INTERVAL '1 day')::TIMESTAMPTZ as reset_time,
        COALESCE(aut.cost_today, 0) as cost_today
    FROM resource_limits rl
    LEFT JOIN api_usage_today aut ON rl.provider = aut.provider;
END;
$$;

-- Record resource usage for tracking and limits
CREATE OR REPLACE FUNCTION record_resource_usage(
    p_execution_id UUID,
    p_resource_type TEXT,
    p_provider TEXT,
    p_usage_amount INTEGER,
    p_cost_usd DECIMAL DEFAULT 0,
    p_rate_limit_remaining INTEGER DEFAULT NULL,
    p_metadata JSONB DEFAULT '{}'::JSONB
) 
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    INSERT INTO workflow_resource_usage (
        execution_id,
        resource_type,
        provider,
        usage_amount,
        cost_usd,
        rate_limit_remaining,
        metadata
    ) VALUES (
        p_execution_id,
        p_resource_type,
        p_provider,
        p_usage_amount,
        p_cost_usd,
        p_rate_limit_remaining,
        p_metadata
    );
    
    -- Update metrics
    INSERT INTO orchestrator_metrics (metric_type, metric_value, workflow_type, metadata)
    VALUES ('api_usage', p_usage_amount, NULL, 
            jsonb_build_object('provider', p_provider, 'cost', p_cost_usd));
END;
$$;

-- ========================================================
-- 5. PRIORITY QUEUE MANAGEMENT
-- ========================================================

-- Get next priority task with fairness algorithm
CREATE OR REPLACE FUNCTION get_next_priority_task(
    p_limit INTEGER DEFAULT 1,
    p_exclude_types TEXT[] DEFAULT '{}'::TEXT[]
)
RETURNS TABLE (
    execution_id UUID,
    workflow_type TEXT,
    priority_score INTEGER,
    age_minutes INTEGER,
    input_data JSONB,
    context JSONB
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        wo.execution_id,
        wo.workflow_type,
        (wo.priority * 10 + 
         EXTRACT(EPOCH FROM (NOW() - wo.created_at)) / 60 +
         CASE WHEN EXTRACT(EPOCH FROM (NOW() - wo.created_at)) / 60 > 30 THEN 50 ELSE 0 END -
         wo.retry_count * 5
        )::INTEGER as priority_score,
        EXTRACT(EPOCH FROM (NOW() - wo.created_at)) / 60 as age_minutes,
        wo.input_data,
        wo.context
    FROM workflow_orchestration wo
    WHERE wo.status IN ('queued', 'retrying')
      AND (wo.next_retry_at IS NULL OR wo.next_retry_at <= NOW())
      AND wo.retry_count < wo.max_retries
      AND NOT (wo.workflow_type = ANY(p_exclude_types))
    ORDER BY priority_score DESC, wo.created_at ASC
    LIMIT p_limit;
END;
$$;

-- Prevent starvation by boosting old tasks
CREATE OR REPLACE FUNCTION prevent_starvation(
    p_age_threshold_minutes INTEGER DEFAULT 30,
    p_boost_amount INTEGER DEFAULT 20
) 
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_boosted_count INTEGER;
BEGIN
    UPDATE workflow_orchestration SET
        priority = LEAST(priority + p_boost_amount, 100),
        updated_at = NOW()
    WHERE status IN ('queued', 'retrying')
      AND EXTRACT(EPOCH FROM (NOW() - created_at)) / 60 > p_age_threshold_minutes
      AND priority < 80; -- Don't boost already high priority tasks
    
    GET DIAGNOSTICS v_boosted_count = ROW_COUNT;
    
    -- Record starvation prevention metric
    IF v_boosted_count > 0 THEN
        INSERT INTO orchestrator_metrics (metric_type, metric_value, metadata)
        VALUES ('starvation_prevention', v_boosted_count, 
                jsonb_build_object('threshold_minutes', p_age_threshold_minutes, 'boost_amount', p_boost_amount));
    END IF;
    
    RETURN v_boosted_count;
END;
$$;

-- ========================================================
-- 6. STATE MANAGEMENT FUNCTIONS
-- ========================================================

-- Get current orchestrator state
CREATE OR REPLACE FUNCTION get_orchestrator_state(
    p_worker_id TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_state JSONB;
    v_queue_depth INTEGER;
    v_active_executions INTEGER;
BEGIN
    -- Get queue statistics
    SELECT COUNT(*) INTO v_queue_depth
    FROM workflow_orchestration
    WHERE status IN ('queued', 'retrying');
    
    SELECT COUNT(*) INTO v_active_executions
    FROM workflow_orchestration
    WHERE status IN ('running', 'dispatching');
    
    -- Get latest state or create default
    SELECT jsonb_build_object(
        'state_type', COALESCE(os.state_type, 'IDLE'),
        'context', COALESCE(os.context, '{}'::JSONB),
        'queue_depth', v_queue_depth,
        'active_executions', v_active_executions,
        'last_heartbeat', COALESCE(os.last_heartbeat, NOW()),
        'worker_id', COALESCE(os.worker_id, p_worker_id)
    ) INTO v_state
    FROM orchestrator_state os
    WHERE os.worker_id = COALESCE(p_worker_id, os.worker_id)
    ORDER BY os.updated_at DESC
    LIMIT 1;
    
    RETURN COALESCE(v_state, jsonb_build_object(
        'state_type', 'IDLE',
        'context', '{}',
        'queue_depth', v_queue_depth,
        'active_executions', v_active_executions,
        'last_heartbeat', NOW(),
        'worker_id', p_worker_id
    ));
END;
$$;

-- Update orchestrator state
CREATE OR REPLACE FUNCTION update_orchestrator_state(
    p_state_type TEXT,
    p_context JSONB DEFAULT '{}'::JSONB,
    p_worker_id TEXT DEFAULT NULL
) 
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_worker_id TEXT;
BEGIN
    v_worker_id := COALESCE(p_worker_id, 'orchestrator-' || gen_random_uuid()::TEXT);
    
    INSERT INTO orchestrator_state (
        state_type,
        context,
        worker_id,
        last_heartbeat
    ) VALUES (
        p_state_type,
        p_context,
        v_worker_id,
        NOW()
    );
    
    -- Clean up old state records (keep last 10 per worker)
    DELETE FROM orchestrator_state
    WHERE id NOT IN (
        SELECT id FROM orchestrator_state
        WHERE worker_id = v_worker_id
        ORDER BY updated_at DESC
        LIMIT 10
    ) AND worker_id = v_worker_id;
    
    RETURN TRUE;
END;
$$;

-- ========================================================
-- 7. MONITORING AND HEALTH CHECK FUNCTIONS
-- ========================================================

-- Get comprehensive system health status
CREATE OR REPLACE FUNCTION get_system_health()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_health JSONB;
    v_queue_depth INTEGER;
    v_error_rate DECIMAL;
    v_avg_latency DECIMAL;
    v_cost_today DECIMAL;
BEGIN
    -- Get queue depth
    SELECT COUNT(*) INTO v_queue_depth
    FROM workflow_orchestration
    WHERE status IN ('queued', 'retrying');
    
    -- Calculate error rate (last hour)
    SELECT 
        CASE 
            WHEN COUNT(*) = 0 THEN 0
            ELSE (COUNT(*) FILTER (WHERE status = 'failed')::DECIMAL / COUNT(*)) * 100
        END INTO v_error_rate
    FROM workflow_orchestration
    WHERE created_at >= NOW() - INTERVAL '1 hour';
    
    -- Calculate average latency (last hour, completed tasks)
    SELECT AVG(duration_ms) INTO v_avg_latency
    FROM workflow_orchestration
    WHERE status = 'completed'
      AND completed_at >= NOW() - INTERVAL '1 hour';
    
    -- Calculate cost today
    SELECT COALESCE(SUM(cost_usd), 0) INTO v_cost_today
    FROM workflow_orchestration
    WHERE DATE(created_at) = CURRENT_DATE;
    
    v_health := jsonb_build_object(
        'status', CASE 
            WHEN v_error_rate > 10 THEN 'critical'
            WHEN v_queue_depth > 1000 THEN 'warning'
            WHEN v_cost_today > 450 THEN 'warning'
            ELSE 'healthy'
        END,
        'queue_depth', v_queue_depth,
        'error_rate_percent', ROUND(v_error_rate, 2),
        'avg_latency_ms', ROUND(v_avg_latency, 0),
        'cost_today_usd', v_cost_today,
        'timestamp', NOW(),
        'checks', jsonb_build_object(
            'queue_healthy', v_queue_depth < 1000,
            'error_rate_ok', v_error_rate < 10,
            'latency_ok', v_avg_latency < 300000,
            'budget_ok', v_cost_today < 450
        )
    );
    
    -- Record health check metric
    INSERT INTO orchestrator_metrics (metric_type, metric_value, metadata)
    VALUES ('system_health', 
            CASE 
                WHEN v_health->>'status' = 'healthy' THEN 1
                WHEN v_health->>'status' = 'warning' THEN 0.5
                ELSE 0
            END, 
            v_health);
    
    RETURN v_health;
END;
$$;

-- Record workflow execution metrics
CREATE OR REPLACE FUNCTION record_workflow_metrics(
    p_workflow_type TEXT,
    p_metrics JSONB
) 
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Insert individual metrics
    IF p_metrics ? 'throughput' THEN
        INSERT INTO orchestrator_metrics (metric_type, metric_value, workflow_type, metric_unit)
        VALUES ('throughput', (p_metrics->>'throughput')::DECIMAL, p_workflow_type, 'per_minute');
    END IF;
    
    IF p_metrics ? 'latency_ms' THEN
        INSERT INTO orchestrator_metrics (metric_type, metric_value, workflow_type, metric_unit)
        VALUES ('latency', (p_metrics->>'latency_ms')::DECIMAL, p_workflow_type, 'milliseconds');
    END IF;
    
    IF p_metrics ? 'cost_usd' THEN
        INSERT INTO orchestrator_metrics (metric_type, metric_value, workflow_type, metric_unit)
        VALUES ('cost_efficiency', (p_metrics->>'cost_usd')::DECIMAL, p_workflow_type, 'usd');
    END IF;
    
    IF p_metrics ? 'success_rate' THEN
        INSERT INTO orchestrator_metrics (metric_type, metric_value, workflow_type, metric_unit)
        VALUES ('success_rate', (p_metrics->>'success_rate')::DECIMAL, p_workflow_type, 'percentage');
    END IF;
END;
$$;

-- ========================================================
-- 8. CLEANUP AND MAINTENANCE
-- ========================================================

-- Clean up old execution records (keep 30 days)
CREATE OR REPLACE FUNCTION cleanup_old_executions()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_deleted_count INTEGER;
BEGIN
    DELETE FROM workflow_orchestration
    WHERE created_at < NOW() - INTERVAL '30 days'
      AND status IN ('completed', 'failed', 'cancelled');
    
    GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
    
    -- Clean up orphaned resource usage records
    DELETE FROM workflow_resource_usage
    WHERE timestamp < NOW() - INTERVAL '30 days';
    
    -- Clean up old metrics (keep 90 days)
    DELETE FROM orchestrator_metrics
    WHERE timestamp < NOW() - INTERVAL '90 days';
    
    RETURN v_deleted_count;
END;
$$;

\echo 'Orchestrator database schema deployed successfully!'