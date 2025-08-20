-- ========================================================
-- ULTIMATE LEAD COORDINATOR - RESOURCE MANAGEMENT
-- ========================================================
-- Advanced resource management with intelligent allocation and monitoring
-- ========================================================

-- Check comprehensive resource availability with predictive analysis
CREATE OR REPLACE FUNCTION check_comprehensive_resource_availability(
    p_scheduled_tasks JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $resource_check$
DECLARE
    v_resource_status JSONB := '{}';
    v_api_limits JSONB := '{}';
    v_budget_status JSONB := '{}';
    v_system_resources JSONB := '{}';
    v_constraints JSONB := '{}';
    v_recommendations JSONB[] := ARRAY[]::JSONB[];
BEGIN
    -- 1. API RATE LIMITS CHECK
    WITH api_status AS (
        SELECT 
            provider,
            requests_per_minute,
            requests_used_current_minute,
            daily_cost_limit,
            daily_cost_used,
            is_available,
            consecutive_errors,
            -- Calculate remaining capacity
            GREATEST(0, requests_per_minute - requests_used_current_minute) as requests_remaining,
            GREATEST(0, daily_cost_limit - daily_cost_used) as budget_remaining,
            -- Calculate utilization percentages
            ROUND((requests_used_current_minute::DECIMAL / requests_per_minute) * 100, 2) as rate_utilization,
            ROUND((daily_cost_used / daily_cost_limit) * 100, 2) as budget_utilization
        FROM api_rate_limits
    )
    SELECT INTO v_api_limits
        jsonb_object_agg(
            provider,
            jsonb_build_object(
                'available', is_available AND consecutive_errors < 5,
                'requests_remaining', requests_remaining,
                'budget_remaining', budget_remaining,
                'rate_utilization_percent', rate_utilization,
                'budget_utilization_percent', budget_utilization,
                'status', CASE 
                    WHEN NOT is_available OR consecutive_errors >= 5 THEN 'unavailable'
                    WHEN rate_utilization > 90 OR budget_utilization > 90 THEN 'critical'
                    WHEN rate_utilization > 70 OR budget_utilization > 70 THEN 'warning'
                    ELSE 'healthy'
                END,
                'next_reset', CASE 
                    WHEN rate_utilization > budget_utilization THEN minute_reset_at
                    ELSE day_reset_at
                END
            )
        )
    FROM api_status;
    
    -- 2. SYSTEM RESOURCE CHECK
    WITH system_metrics AS (
        SELECT 
            COUNT(*) FILTER (WHERE state = 'active') as active_connections,
            COUNT(*) FILTER (WHERE state = 'idle') as idle_connections,
            20 as max_connections -- Supabase connection limit
        FROM pg_stat_activity
        WHERE application_name LIKE '%n8n%'
    ),
    memory_usage AS (
        SELECT 
            SUM(memory_allocated_mb) as allocated_memory_mb,
            2048 as total_memory_mb -- 2GB limit
        FROM workflow_orchestration 
        WHERE status IN ('running', 'dispatching')
    )
    SELECT INTO v_system_resources
        jsonb_build_object(
            'database_connections', jsonb_build_object(
                'active', sm.active_connections,
                'idle', sm.idle_connections,
                'max', sm.max_connections,
                'utilization_percent', ROUND((sm.active_connections::DECIMAL / sm.max_connections) * 100, 2),
                'available', sm.max_connections - sm.active_connections,
                'status', CASE 
                    WHEN sm.active_connections >= sm.max_connections * 0.9 THEN 'critical'
                    WHEN sm.active_connections >= sm.max_connections * 0.7 THEN 'warning'
                    ELSE 'healthy'
                END
            ),
            'memory', jsonb_build_object(
                'allocated_mb', COALESCE(mu.allocated_memory_mb, 0),
                'total_mb', mu.total_memory_mb,
                'utilization_percent', ROUND((COALESCE(mu.allocated_memory_mb, 0)::DECIMAL / mu.total_memory_mb) * 100, 2),
                'available_mb', mu.total_memory_mb - COALESCE(mu.allocated_memory_mb, 0),
                'status', CASE 
                    WHEN COALESCE(mu.allocated_memory_mb, 0) >= mu.total_memory_mb * 0.9 THEN 'critical'
                    WHEN COALESCE(mu.allocated_memory_mb, 0) >= mu.total_memory_mb * 0.7 THEN 'warning'
                    ELSE 'healthy'
                END
            )
        )
    FROM system_metrics sm
    CROSS JOIN memory_usage mu;
    
    -- 3. WORKFLOW-SPECIFIC CONSTRAINTS
    WITH workflow_constraints AS (
        SELECT 
            task->>'workflow_type' as workflow_type,
            task->>'estimated_cost' as estimated_cost,
            task->>'batch_size' as batch_size,
            CASE task->>'workflow_type'
                WHEN 'content_pipeline' THEN 
                    CASE 
                        WHEN (v_api_limits->'gemini'->>'status')::TEXT != 'healthy' THEN 'API rate limit constraint'
                        WHEN (task->>'estimated_cost')::DECIMAL > (v_api_limits->'gemini'->>'budget_remaining')::DECIMAL THEN 'Budget constraint'
                        ELSE NULL
                    END
                WHEN 'seo_monitor' THEN 
                    CASE 
                        WHEN (v_system_resources->'database_connections'->>'status')::TEXT = 'critical' THEN 'Database connection constraint'
                        ELSE NULL
                    END
                WHEN 'revenue_optimizer' THEN 
                    CASE 
                        WHEN (v_system_resources->'memory'->>'status')::TEXT = 'critical' THEN 'Memory constraint'
                        ELSE NULL
                    END
                ELSE NULL
            END as constraint_reason
        FROM jsonb_array_elements(p_scheduled_tasks->'tasks') task
        WHERE (task->>'should_execute')::BOOLEAN
    )
    SELECT INTO v_constraints
        COALESCE(
            jsonb_object_agg(
                workflow_type,
                jsonb_build_object(
                    'has_constraint', constraint_reason IS NOT NULL,
                    'constraint_reason', constraint_reason,
                    'estimated_cost', estimated_cost,
                    'batch_size', batch_size
                )
            ) FILTER (WHERE constraint_reason IS NOT NULL),
            '{}'::JSONB
        )
    FROM workflow_constraints;
    
    -- 4. GENERATE RECOMMENDATIONS
    -- API optimization recommendations
    IF (v_api_limits->'gemini'->>'rate_utilization_percent')::DECIMAL > 80 THEN
        v_recommendations := array_append(v_recommendations,
            jsonb_build_object(
                'type', 'api_optimization',
                'priority', 'high',
                'message', 'Gemini API usage is high, consider reducing batch sizes',
                'action', 'reduce_content_pipeline_batch_size'
            )
        );
    END IF;
    
    -- Budget recommendations
    IF (v_api_limits->'gemini'->>'budget_utilization_percent')::DECIMAL > 85 THEN
        v_recommendations := array_append(v_recommendations,
            jsonb_build_object(
                'type', 'budget_optimization',
                'priority', 'critical',
                'message', 'Daily budget nearly exhausted, throttle expensive operations',
                'action', 'enable_budget_throttling'
            )
        );
    END IF;
    
    -- System resource recommendations
    IF (v_system_resources->'database_connections'->>'utilization_percent')::DECIMAL > 70 THEN
        v_recommendations := array_append(v_recommendations,
            jsonb_build_object(
                'type', 'system_optimization',
                'priority', 'medium',
                'message', 'Database connection usage is high, optimize query patterns',
                'action', 'optimize_database_usage'
            )
        );
    END IF;
    
    -- 5. UPDATE RESOURCE USAGE TRACKING
    INSERT INTO resource_usage (resource_type, used_amount, total_capacity, execution_id, metadata)
    VALUES 
        ('gemini_api', 
         (v_api_limits->'gemini'->>'requests_used_current_minute')::DECIMAL,
         (v_api_limits->'gemini'->>'requests_per_minute')::DECIMAL,
         'coordinator-check',
         jsonb_build_object('check_type', 'availability_check')
        ),
        ('database', 
         (v_system_resources->'database_connections'->>'active')::DECIMAL,
         (v_system_resources->'database_connections'->>'max')::DECIMAL,
         'coordinator-check',
         jsonb_build_object('check_type', 'availability_check')
        ),
        ('memory', 
         (v_system_resources->'memory'->>'allocated_mb')::DECIMAL,
         (v_system_resources->'memory'->>'total_mb')::DECIMAL,
         'coordinator-check',
         jsonb_build_object('check_type', 'availability_check')
        );
    
    RETURN jsonb_build_object(
        'overall_status', CASE 
            WHEN jsonb_object_keys(v_constraints) IS NOT NULL AND array_length(jsonb_object_keys(v_constraints), 1) > 0 THEN 'constrained'
            WHEN array_length(v_recommendations, 1) > 0 THEN 'warning'
            ELSE 'healthy'
        END,
        'api_limits', v_api_limits,
        'system_resources', v_system_resources,
        'constraints', v_constraints,
        'recommendations', v_recommendations,
        'can_proceed', jsonb_object_keys(v_constraints) IS NULL OR array_length(jsonb_object_keys(v_constraints), 1) = 0,
        'timestamp', NOW()
    );
END;
$resource_check$;

-- Create optimal execution plan with intelligent resource allocation
CREATE OR REPLACE FUNCTION create_optimal_execution_plan(
    p_scheduled_tasks JSONB,
    p_resource_status JSONB,
    p_worker_id TEXT,
    p_current_time TIMESTAMPTZ
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $execution_plan$
DECLARE
    v_execution_plan JSONB;
    v_workflows_to_execute JSONB[] := ARRAY[]::JSONB[];
    v_total_estimated_cost DECIMAL := 0;
    v_total_estimated_duration INTEGER := 0;
    v_resource_allocation JSONB := '{}';
    v_execution_sequence JSONB[] := ARRAY[]::JSONB[];
BEGIN
    -- Filter executable workflows based on resource constraints
    WITH executable_workflows AS (
        SELECT 
            task->>'workflow_type' as workflow_type,
            (task->>'priority')::INTEGER as priority,
            (task->>'batch_size')::INTEGER as batch_size,
            (task->>'estimated_duration_ms')::INTEGER as estimated_duration_ms,
            (task->>'estimated_cost')::DECIMAL as estimated_cost,
            (task->>'predicted_success_rate')::DECIMAL as predicted_success_rate,
            task->'reasoning' as reasoning,
            -- Check if workflow can execute given current constraints
            NOT COALESCE((p_resource_status->'constraints'->(task->>'workflow_type')->>'has_constraint')::BOOLEAN, FALSE) as can_execute
        FROM jsonb_array_elements(p_scheduled_tasks->'tasks') task
        WHERE (task->>'should_execute')::BOOLEAN
    ),
    prioritized_workflows AS (
        SELECT 
            *,
            -- Calculate execution order based on priority and resource efficiency
            ROW_NUMBER() OVER (
                ORDER BY 
                    priority DESC,
                    estimated_cost / GREATEST(predicted_success_rate, 0.1) ASC,
                    estimated_duration_ms ASC
            ) as execution_order
        FROM executable_workflows
        WHERE can_execute
    ),
    resource_optimized_workflows AS (
        SELECT 
            pw.*,
            -- Optimize batch sizes based on available resources
            CASE workflow_type
                WHEN 'content_pipeline' THEN
                    LEAST(
                        batch_size,
                        FLOOR((p_resource_status->'api_limits'->'gemini'->>'budget_remaining')::DECIMAL / 0.15)::INTEGER,
                        (p_resource_status->'api_limits'->'gemini'->>'requests_remaining')::INTEGER
                    )
                WHEN 'seo_monitor' THEN
                    LEAST(
                        batch_size,
                        (p_resource_status->'system_resources'->'database_connections'->>'available')::INTEGER * 2
                    )
                ELSE batch_size
            END as optimized_batch_size,
            
            -- Calculate resource requirements
            CASE workflow_type
                WHEN 'content_pipeline' THEN 512 -- MB memory per execution
                WHEN 'seo_monitor' THEN 256
                WHEN 'revenue_optimizer' THEN 128
                WHEN 'intelligence_engine' THEN 1024
                ELSE 256
            END as memory_requirement_mb,
            
            -- Estimate API calls needed
            CASE workflow_type
                WHEN 'content_pipeline' THEN batch_size * 3 -- 3 API calls per content item
                WHEN 'seo_monitor' THEN batch_size * 1
                WHEN 'revenue_optimizer' THEN batch_size * 2
                WHEN 'intelligence_engine' THEN 5
                ELSE 1
            END as api_calls_needed
            
        FROM prioritized_workflows pw
    ),
    final_execution_plan AS (
        SELECT 
            row.*,
            -- Recalculate costs with optimized batch sizes
            CASE workflow_type
                WHEN 'content_pipeline' THEN optimized_batch_size * 0.15
                WHEN 'seo_monitor' THEN 0.05
                WHEN 'revenue_optimizer' THEN optimized_batch_size * 0.02
                WHEN 'intelligence_engine' THEN 0.25
                ELSE estimated_cost
            END as final_estimated_cost,
            
            -- Generate execution ID
            'exec-' || workflow_type || '-' || extract(epoch from p_current_time)::bigint || '-' || 
            substring(gen_random_uuid()::text, 1, 8) as execution_id,
            
            -- Calculate timeout
            p_current_time + (estimated_duration_ms || ' milliseconds')::INTERVAL as timeout_at
            
        FROM resource_optimized_workflows row
        WHERE optimized_batch_size > 0 -- Only include workflows with valid batch sizes
    )
    SELECT 
        COALESCE(array_agg(
            jsonb_build_object(
                'execution_id', execution_id,
                'workflow_type', workflow_type,
                'priority', priority,
                'batch_size', optimized_batch_size,
                'estimated_duration_ms', estimated_duration_ms,
                'estimated_cost', final_estimated_cost,
                'predicted_success_rate', predicted_success_rate,
                'memory_requirement_mb', memory_requirement_mb,
                'api_calls_needed', api_calls_needed,
                'timeout_at', timeout_at,
                'execution_order', execution_order,
                'reasoning', reasoning
            ) ORDER BY execution_order
        ), ARRAY[]::JSONB[]),
        COALESCE(SUM(final_estimated_cost), 0),
        COALESCE(SUM(estimated_duration_ms), 0)
    INTO v_workflows_to_execute, v_total_estimated_cost, v_total_estimated_duration
    FROM final_execution_plan;
    
    -- Create resource allocation plan
    v_resource_allocation := jsonb_build_object(
        'total_memory_allocated_mb', (
            SELECT COALESCE(SUM((workflow->>'memory_requirement_mb')::INTEGER), 0)
            FROM unnest(v_workflows_to_execute) workflow
        ),
        'total_api_calls_allocated', (
            SELECT COALESCE(SUM((workflow->>'api_calls_needed')::INTEGER), 0)
            FROM unnest(v_workflows_to_execute) workflow
        ),
        'total_estimated_cost', v_total_estimated_cost,
        'total_estimated_duration_ms', v_total_estimated_duration,
        'resource_efficiency_score', CASE 
            WHEN v_total_estimated_cost > 0 THEN 
                ROUND((array_length(v_workflows_to_execute, 1)::DECIMAL / v_total_estimated_cost) * 100, 2)
            ELSE 100
        END
    );
    
    -- Generate execution sequence with dependencies
    SELECT array_agg(
        jsonb_build_object(
            'sequence_number', ordinality,
            'execution_id', workflow->>'execution_id',
            'workflow_type', workflow->>'workflow_type',
            'start_after', CASE 
                WHEN ordinality = 1 THEN p_current_time
                ELSE p_current_time + ((ordinality - 1) * 30 || ' seconds')::INTERVAL
            END,
            'dependencies', CASE 
                WHEN workflow->>'workflow_type' = 'intelligence_engine' THEN 
                    jsonb_build_array('content_pipeline', 'seo_monitor', 'revenue_optimizer')
                ELSE jsonb_build_array()
            END
        ) ORDER BY ordinality
    ) INTO v_execution_sequence
    FROM unnest(v_workflows_to_execute) WITH ORDINALITY workflow;
    
    v_execution_plan := jsonb_build_object(
        'plan_id', 'plan-' || extract(epoch from p_current_time)::bigint || '-' || substring(gen_random_uuid()::text, 1, 8),
        'created_at', p_current_time,
        'worker_id', p_worker_id,
        'workflows_to_execute', v_workflows_to_execute,
        'execution_sequence', COALESCE(v_execution_sequence, ARRAY[]::JSONB[]),
        'resource_allocation', v_resource_allocation,
        'total_workflows', array_length(v_workflows_to_execute, 1),
        'execution_strategy', CASE 
            WHEN array_length(v_workflows_to_execute, 1) > 2 THEN 'sequential_with_overlap'
            WHEN array_length(v_workflows_to_execute, 1) > 1 THEN 'sequential'
            ELSE 'single'
        END,
        'estimated_completion_time', p_current_time + (v_total_estimated_duration || ' milliseconds')::INTERVAL,
        'risk_assessment', jsonb_build_object(
            'overall_risk', CASE 
                WHEN v_total_estimated_cost > (p_resource_status->'api_limits'->'gemini'->>'budget_remaining')::DECIMAL * 0.8 THEN 'high'
                WHEN array_length(v_workflows_to_execute, 1) > 2 THEN 'medium'
                ELSE 'low'
            END,
            'cost_risk', v_total_estimated_cost > (p_resource_status->'api_limits'->'gemini'->>'budget_remaining')::DECIMAL * 0.5,
            'resource_risk', (v_resource_allocation->>'total_memory_allocated_mb')::INTEGER > 1500,
            'timing_risk', v_total_estimated_duration > 600000 -- 10 minutes
        )
    );
    
    RETURN v_execution_plan;
END;
$execution_plan$;

-- Reserve resources for planned executions
CREATE OR REPLACE FUNCTION reserve_execution_resources(
    p_execution_plan JSONB
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $reserve_resources$
DECLARE
    v_workflow JSONB;
    v_total_cost DECIMAL;
    v_total_memory INTEGER;
    v_total_api_calls INTEGER;
BEGIN
    -- Extract totals from execution plan
    v_total_cost := (p_execution_plan->'resource_allocation'->>'total_estimated_cost')::DECIMAL;
    v_total_memory := (p_execution_plan->'resource_allocation'->>'total_memory_allocated_mb')::INTEGER;
    v_total_api_calls := (p_execution_plan->'resource_allocation'->>'total_api_calls_allocated')::INTEGER;
    
    -- Update API rate limits
    UPDATE api_rate_limits 
    SET 
        requests_used_current_minute = requests_used_current_minute + v_total_api_calls,
        daily_cost_used = daily_cost_used + v_total_cost,
        updated_at = NOW()
    WHERE provider = 'gemini';
    
    -- Record resource reservations for each workflow
    FOR v_workflow IN SELECT jsonb_array_elements(p_execution_plan->'workflows_to_execute')
    LOOP
        INSERT INTO resource_usage (
            resource_type,
            used_amount,
            total_capacity,
            execution_id,
            workflow_type,
            provider,
            metadata
        ) VALUES 
            ('gemini_api',
             (v_workflow->>'api_calls_needed')::DECIMAL,
             60, -- requests per minute
             v_workflow->>'execution_id',
             v_workflow->>'workflow_type',
             'gemini',
             jsonb_build_object(
                 'reservation_type', 'planned_execution',
                 'batch_size', v_workflow->>'batch_size',
                 'estimated_cost', v_workflow->>'estimated_cost'
             )
            ),
            ('memory',
             (v_workflow->>'memory_requirement_mb')::DECIMAL,
             2048, -- total memory MB
             v_workflow->>'execution_id',
             v_workflow->>'workflow_type',
             'system',
             jsonb_build_object(
                 'reservation_type', 'planned_execution',
                 'estimated_duration_ms', v_workflow->>'estimated_duration_ms'
             )
            ),
            ('budget',
             (v_workflow->>'estimated_cost')::DECIMAL,
             500, -- daily budget
             v_workflow->>'execution_id',
             v_workflow->>'workflow_type',
             'gemini',
             jsonb_build_object(
                 'reservation_type', 'planned_execution',
                 'plan_id', p_execution_plan->>'plan_id'
             )
            );
    END LOOP;
    
    RETURN TRUE;
    
EXCEPTION
    WHEN OTHERS THEN
        -- Log reservation failure
        INSERT INTO resource_usage (
            resource_type,
            used_amount,
            total_capacity,
            execution_id,
            metadata
        ) VALUES (
            'reservation_error',
            0,
            1,
            'reservation-failed',
            jsonb_build_object(
                'error_code', SQLSTATE,
                'error_message', SQLERRM,
                'plan_id', p_execution_plan->>'plan_id'
            )
        );
        
        RETURN FALSE;
END;
$reserve_resources$;

-- Create execution records for planned workflows
CREATE OR REPLACE FUNCTION create_execution_records(
    p_execution_plan JSONB,
    p_worker_id TEXT
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $create_records$
DECLARE
    v_workflow JSONB;
    v_records_created INTEGER := 0;
BEGIN
    -- Create execution record for each planned workflow
    FOR v_workflow IN SELECT jsonb_array_elements(p_execution_plan->'workflows_to_execute')
    LOOP
        INSERT INTO workflow_orchestration (
            execution_id,
            workflow_type,
            status,
            priority_score,
            scheduled_at,
            timeout_at,
            batch_size,
            estimated_cost,
            api_calls_allocated,
            memory_allocated_mb,
            input_context,
            worker_id,
            max_retries
        ) VALUES (
            v_workflow->>'execution_id',
            v_workflow->>'workflow_type',
            'pending',
            (v_workflow->>'priority')::INTEGER,
            NOW(),
            (v_workflow->>'timeout_at')::TIMESTAMPTZ,
            (v_workflow->>'batch_size')::INTEGER,
            (v_workflow->>'estimated_cost')::DECIMAL,
            (v_workflow->>'api_calls_needed')::INTEGER,
            (v_workflow->>'memory_requirement_mb')::INTEGER,
            jsonb_build_object(
                'plan_id', p_execution_plan->>'plan_id',
                'execution_order', v_workflow->>'execution_order',
                'reasoning', v_workflow->'reasoning',
                'predicted_success_rate', v_workflow->>'predicted_success_rate',
                'resource_allocation', p_execution_plan->'resource_allocation'
            ),
            p_worker_id,
            3
        );
        
        v_records_created := v_records_created + 1;
    END LOOP;
    
    RETURN v_records_created;
    
EXCEPTION
    WHEN OTHERS THEN
        -- Log creation failure
        INSERT INTO workflow_orchestration (
            execution_id,
            workflow_type,
            status,
            error_details,
            worker_id
        ) VALUES (
            'creation-failed-' || extract(epoch from NOW())::bigint,
            'coordinator_error',
            'failed',
            jsonb_build_object(
                'error_code', SQLSTATE,
                'error_message', SQLERRM,
                'plan_id', p_execution_plan->>'plan_id',
                'records_created_before_failure', v_records_created
            ),
            p_worker_id
        );
        
        RETURN v_records_created;
END;
$create_records$;

\echo 'Ultimate Lead Coordinator resource management functions deployed successfully!'