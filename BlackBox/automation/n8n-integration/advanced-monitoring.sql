-- ============================================================
-- ADVANCED N8N WORKFLOW MONITORING AND OPTIMIZATION
-- Real-time monitoring, performance analytics, and intelligent optimization
-- ============================================================

-- ============================================================
-- 1. ADVANCED MONITORING TABLES
-- ============================================================

-- Real-time workflow metrics
CREATE TABLE IF NOT EXISTS public.workflow_realtime_metrics (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    workflow_instance_id uuid REFERENCES public.workflow_instances(id) ON DELETE CASCADE,
    metric_timestamp timestamptz DEFAULT NOW(),
    execution_count_1min integer DEFAULT 0,
    execution_count_5min integer DEFAULT 0,
    execution_count_1hour integer DEFAULT 0,
    success_rate_1min numeric DEFAULT 0,
    success_rate_5min numeric DEFAULT 0,
    success_rate_1hour numeric DEFAULT 0,
    avg_execution_time_1min integer DEFAULT 0,
    avg_execution_time_5min integer DEFAULT 0,
    avg_execution_time_1hour integer DEFAULT 0,
    error_count_1min integer DEFAULT 0,
    error_count_5min integer DEFAULT 0,
    error_count_1hour integer DEFAULT 0,
    cost_1min numeric DEFAULT 0,
    cost_5min numeric DEFAULT 0,
    cost_1hour numeric DEFAULT 0,
    queue_depth integer DEFAULT 0,
    active_executions integer DEFAULT 0,
    resource_utilization jsonb DEFAULT '{}',
    created_at timestamptz DEFAULT NOW(),
    CONSTRAINT workflow_realtime_metrics_pkey PRIMARY KEY (id)
);

-- Workflow performance alerts
CREATE TABLE IF NOT EXISTS public.workflow_performance_alerts (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    workflow_instance_id uuid REFERENCES public.workflow_instances(id) ON DELETE CASCADE,
    alert_type text NOT NULL CHECK (alert_type IN ('error_rate', 'performance', 'cost', 'resource', 'availability')),
    severity text NOT NULL CHECK (severity IN ('info', 'warning', 'critical')),
    title text NOT NULL,
    description text NOT NULL,
    metric_value numeric,
    threshold_value numeric,
    alert_data jsonb DEFAULT '{}',
    is_resolved boolean DEFAULT false,
    resolved_at timestamptz,
    resolved_by uuid REFERENCES public.users(id),
    resolution_notes text,
    created_at timestamptz DEFAULT NOW(),
    CONSTRAINT workflow_performance_alerts_pkey PRIMARY KEY (id)
);

-- Workflow optimization recommendations
CREATE TABLE IF NOT EXISTS public.workflow_optimization_recommendations (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    workflow_instance_id uuid REFERENCES public.workflow_instances(id) ON DELETE CASCADE,
    recommendation_type text NOT NULL CHECK (recommendation_type IN ('performance', 'cost', 'reliability', 'scalability', 'security')),
    priority text NOT NULL CHECK (priority IN ('low', 'medium', 'high', 'critical')),
    title text NOT NULL,
    description text NOT NULL,
    impact_description text,
    implementation_effort text CHECK (implementation_effort IN ('low', 'medium', 'high')),
    estimated_improvement jsonb DEFAULT '{}',
    implementation_steps jsonb DEFAULT '[]',
    is_implemented boolean DEFAULT false,
    implemented_at timestamptz,
    implemented_by uuid REFERENCES public.users(id),
    implementation_notes text,
    created_at timestamptz DEFAULT NOW(),
    CONSTRAINT workflow_optimization_recommendations_pkey PRIMARY KEY (id)
);

-- Workflow node performance tracking
CREATE TABLE IF NOT EXISTS public.workflow_node_performance (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    workflow_instance_id uuid REFERENCES public.workflow_instances(id) ON DELETE CASCADE,
    execution_id uuid REFERENCES public.workflow_executions_enhanced(id) ON DELETE CASCADE,
    node_name text NOT NULL,
    node_type text NOT NULL,
    execution_time_ms integer DEFAULT 0,
    memory_usage_mb integer DEFAULT 0,
    cpu_usage_percent numeric DEFAULT 0,
    error_count integer DEFAULT 0,
    success_count integer DEFAULT 0,
    input_data_size_kb integer DEFAULT 0,
    output_data_size_kb integer DEFAULT 0,
    api_calls_made integer DEFAULT 0,
    cost_usd numeric DEFAULT 0,
    performance_score integer DEFAULT 0, -- 0-100
    bottleneck_detected boolean DEFAULT false,
    optimization_suggestions jsonb DEFAULT '[]',
    created_at timestamptz DEFAULT NOW(),
    CONSTRAINT workflow_node_performance_pkey PRIMARY KEY (id)
);

-- Workflow execution patterns
CREATE TABLE IF NOT EXISTS public.workflow_execution_patterns (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    workflow_instance_id uuid REFERENCES public.workflow_instances(id) ON DELETE CASCADE,
    pattern_type text NOT NULL CHECK (pattern_type IN ('time_based', 'load_based', 'error_based', 'cost_based')),
    pattern_name text NOT NULL,
    pattern_description text,
    pattern_data jsonb NOT NULL,
    confidence_score numeric DEFAULT 0, -- 0-1
    occurrences integer DEFAULT 1,
    first_detected timestamptz DEFAULT NOW(),
    last_detected timestamptz DEFAULT NOW(),
    is_active boolean DEFAULT true,
    created_at timestamptz DEFAULT NOW(),
    CONSTRAINT workflow_execution_patterns_pkey PRIMARY KEY (id)
);

-- ============================================================
-- 2. REAL-TIME MONITORING FUNCTIONS
-- ============================================================

-- Function to update real-time metrics
CREATE OR REPLACE FUNCTION update_workflow_realtime_metrics(
    p_workflow_instance_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $
DECLARE
    v_metrics RECORD;
    v_current_time timestamptz := NOW();
BEGIN
    -- Calculate metrics for different time windows
    SELECT 
        -- 1 minute metrics
        COUNT(*) FILTER (WHERE started_at >= v_current_time - INTERVAL '1 minute') as exec_1min,
        COUNT(*) FILTER (WHERE started_at >= v_current_time - INTERVAL '1 minute' AND execution_status = 'success') as success_1min,
        AVG(execution_time_ms) FILTER (WHERE started_at >= v_current_time - INTERVAL '1 minute') as avg_time_1min,
        COUNT(*) FILTER (WHERE started_at >= v_current_time - INTERVAL '1 minute' AND execution_status = 'error') as error_1min,
        SUM(cost_usd) FILTER (WHERE started_at >= v_current_time - INTERVAL '1 minute') as cost_1min,
        
        -- 5 minute metrics
        COUNT(*) FILTER (WHERE started_at >= v_current_time - INTERVAL '5 minutes') as exec_5min,
        COUNT(*) FILTER (WHERE started_at >= v_current_time - INTERVAL '5 minutes' AND execution_status = 'success') as success_5min,
        AVG(execution_time_ms) FILTER (WHERE started_at >= v_current_time - INTERVAL '5 minutes') as avg_time_5min,
        COUNT(*) FILTER (WHERE started_at >= v_current_time - INTERVAL '5 minutes' AND execution_status = 'error') as error_5min,
        SUM(cost_usd) FILTER (WHERE started_at >= v_current_time - INTERVAL '5 minutes') as cost_5min,
        
        -- 1 hour metrics
        COUNT(*) FILTER (WHERE started_at >= v_current_time - INTERVAL '1 hour') as exec_1hour,
        COUNT(*) FILTER (WHERE started_at >= v_current_time - INTERVAL '1 hour' AND execution_status = 'success') as success_1hour,
        AVG(execution_time_ms) FILTER (WHERE started_at >= v_current_time - INTERVAL '1 hour') as avg_time_1hour,
        COUNT(*) FILTER (WHERE started_at >= v_current_time - INTERVAL '1 hour' AND execution_status = 'error') as error_1hour,
        SUM(cost_usd) FILTER (WHERE started_at >= v_current_time - INTERVAL '1 hour') as cost_1hour,
        
        -- Current active executions
        COUNT(*) FILTER (WHERE execution_status = 'running') as active_exec
    INTO v_metrics
    FROM public.workflow_executions_enhanced
    WHERE workflow_instance_id = p_workflow_instance_id;
    
    -- Insert or update real-time metrics
    INSERT INTO public.workflow_realtime_metrics (
        workflow_instance_id,
        metric_timestamp,
        execution_count_1min,
        execution_count_5min,
        execution_count_1hour,
        success_rate_1min,
        success_rate_5min,
        success_rate_1hour,
        avg_execution_time_1min,
        avg_execution_time_5min,
        avg_execution_time_1hour,
        error_count_1min,
        error_count_5min,
        error_count_1hour,
        cost_1min,
        cost_5min,
        cost_1hour,
        active_executions
    ) VALUES (
        p_workflow_instance_id,
        v_current_time,
        COALESCE(v_metrics.exec_1min, 0),
        COALESCE(v_metrics.exec_5min, 0),
        COALESCE(v_metrics.exec_1hour, 0),
        CASE WHEN v_metrics.exec_1min > 0 THEN v_metrics.success_1min * 100.0 / v_metrics.exec_1min ELSE 0 END,
        CASE WHEN v_metrics.exec_5min > 0 THEN v_metrics.success_5min * 100.0 / v_metrics.exec_5min ELSE 0 END,
        CASE WHEN v_metrics.exec_1hour > 0 THEN v_metrics.success_1hour * 100.0 / v_metrics.exec_1hour ELSE 0 END,
        COALESCE(v_metrics.avg_time_1min, 0)::integer,
        COALESCE(v_metrics.avg_time_5min, 0)::integer,
        COALESCE(v_metrics.avg_time_1hour, 0)::integer,
        COALESCE(v_metrics.error_1min, 0),
        COALESCE(v_metrics.error_5min, 0),
        COALESCE(v_metrics.error_1hour, 0),
        COALESCE(v_metrics.cost_1min, 0),
        COALESCE(v_metrics.cost_5min, 0),
        COALESCE(v_metrics.cost_1hour, 0),
        COALESCE(v_metrics.active_exec, 0)
    );
    
    RETURN jsonb_build_object(
        'success', true,
        'workflow_instance_id', p_workflow_instance_id,
        'metrics_updated_at', v_current_time,
        'metrics', row_to_json(v_metrics)
    );

EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', SQLERRM
        );
END;
$;

-- Function to detect performance issues and generate alerts
CREATE OR REPLACE FUNCTION detect_workflow_performance_issues(
    p_workflow_instance_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $
DECLARE
    v_workflow RECORD;
    v_alerts_generated integer := 0;
    v_alert_id uuid;
BEGIN
    -- Process all workflows if none specified
    FOR v_workflow IN 
        SELECT wi.id, wi.name, wrm.*
        FROM public.workflow_instances wi
        LEFT JOIN public.workflow_realtime_metrics wrm ON wi.id = wrm.workflow_instance_id
        WHERE (p_workflow_instance_id IS NULL OR wi.id = p_workflow_instance_id)
            AND wi.status = 'active'
            AND wrm.metric_timestamp >= NOW() - INTERVAL '5 minutes'
        ORDER BY wrm.metric_timestamp DESC
    LOOP
        -- Check error rate alerts
        IF v_workflow.success_rate_5min < 90 AND v_workflow.execution_count_5min >= 5 THEN
            INSERT INTO public.workflow_performance_alerts (
                workflow_instance_id,
                alert_type,
                severity,
                title,
                description,
                metric_value,
                threshold_value,
                alert_data
            ) VALUES (
                v_workflow.id,
                'error_rate',
                CASE WHEN v_workflow.success_rate_5min < 70 THEN 'critical' 
                     WHEN v_workflow.success_rate_5min < 85 THEN 'warning' 
                     ELSE 'info' END,
                'High Error Rate Detected',
                'Workflow ' || v_workflow.name || ' has a success rate of ' || v_workflow.success_rate_5min::text || '% in the last 5 minutes',
                v_workflow.success_rate_5min,
                90,
                jsonb_build_object(
                    'execution_count', v_workflow.execution_count_5min,
                    'error_count', v_workflow.error_count_5min,
                    'time_window', '5 minutes'
                )
            ) RETURNING id INTO v_alert_id;
            
            v_alerts_generated := v_alerts_generated + 1;
        END IF;
        
        -- Check performance alerts
        IF v_workflow.avg_execution_time_5min > 300000 AND v_workflow.execution_count_5min >= 3 THEN -- 5 minutes
            INSERT INTO public.workflow_performance_alerts (
                workflow_instance_id,
                alert_type,
                severity,
                title,
                description,
                metric_value,
                threshold_value,
                alert_data
            ) VALUES (
                v_workflow.id,
                'performance',
                CASE WHEN v_workflow.avg_execution_time_5min > 600000 THEN 'critical' 
                     WHEN v_workflow.avg_execution_time_5min > 450000 THEN 'warning' 
                     ELSE 'info' END,
                'Slow Execution Performance',
                'Workflow ' || v_workflow.name || ' average execution time is ' || (v_workflow.avg_execution_time_5min/1000)::text || ' seconds',
                v_workflow.avg_execution_time_5min,
                300000,
                jsonb_build_object(
                    'execution_count', v_workflow.execution_count_5min,
                    'time_window', '5 minutes'
                )
            );
            
            v_alerts_generated := v_alerts_generated + 1;
        END IF;
        
        -- Check cost alerts
        IF v_workflow.cost_1hour > 50 THEN -- $50 per hour threshold
            INSERT INTO public.workflow_performance_alerts (
                workflow_instance_id,
                alert_type,
                severity,
                title,
                description,
                metric_value,
                threshold_value,
                alert_data
            ) VALUES (
                v_workflow.id,
                'cost',
                CASE WHEN v_workflow.cost_1hour > 100 THEN 'critical' 
                     WHEN v_workflow.cost_1hour > 75 THEN 'warning' 
                     ELSE 'info' END,
                'High Cost Usage',
                'Workflow ' || v_workflow.name || ' has cost $' || v_workflow.cost_1hour::text || ' in the last hour',
                v_workflow.cost_1hour,
                50,
                jsonb_build_object(
                    'execution_count', v_workflow.execution_count_1hour,
                    'time_window', '1 hour'
                )
            );
            
            v_alerts_generated := v_alerts_generated + 1;
        END IF;
        
        -- Check resource utilization alerts
        IF v_workflow.active_executions > 10 THEN
            INSERT INTO public.workflow_performance_alerts (
                workflow_instance_id,
                alert_type,
                severity,
                title,
                description,
                metric_value,
                threshold_value,
                alert_data
            ) VALUES (
                v_workflow.id,
                'resource',
                CASE WHEN v_workflow.active_executions > 20 THEN 'critical' 
                     WHEN v_workflow.active_executions > 15 THEN 'warning' 
                     ELSE 'info' END,
                'High Resource Utilization',
                'Workflow ' || v_workflow.name || ' has ' || v_workflow.active_executions::text || ' active executions',
                v_workflow.active_executions,
                10,
                jsonb_build_object(
                    'active_executions', v_workflow.active_executions,
                    'check_time', NOW()
                )
            );
            
            v_alerts_generated := v_alerts_generated + 1;
        END IF;
    END LOOP;
    
    RETURN jsonb_build_object(
        'success', true,
        'alerts_generated', v_alerts_generated,
        'checked_at', NOW()
    );

EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', SQLERRM
        );
END;
$;

-- Function to generate optimization recommendations
CREATE OR REPLACE FUNCTION generate_workflow_optimization_recommendations(
    p_workflow_instance_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $
DECLARE
    v_performance RECORD;
    v_recommendations_generated integer := 0;
BEGIN
    -- Get recent performance data
    SELECT 
        wpa.*,
        wi.name as workflow_name,
        wrm.success_rate_1hour,
        wrm.avg_execution_time_1hour,
        wrm.cost_1hour,
        wrm.error_count_1hour,
        wrm.execution_count_1hour
    INTO v_performance
    FROM public.workflow_performance_analytics wpa
    JOIN public.workflow_instances wi ON wpa.workflow_instance_id = wi.id
    LEFT JOIN public.workflow_realtime_metrics wrm ON wi.id = wrm.workflow_instance_id
    WHERE wpa.workflow_instance_id = p_workflow_instance_id
    ORDER BY wpa.created_at DESC
    LIMIT 1;
    
    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'No performance data found for workflow'
        );
    END IF;
    
    -- Performance optimization recommendations
    IF v_performance.avg_execution_time_ms > 180000 THEN -- 3 minutes
        INSERT INTO public.workflow_optimization_recommendations (
            workflow_instance_id,
            recommendation_type,
            priority,
            title,
            description,
            impact_description,
            implementation_effort,
            estimated_improvement,
            implementation_steps
        ) VALUES (
            p_workflow_instance_id,
            'performance',
            CASE WHEN v_performance.avg_execution_time_ms > 600000 THEN 'high' ELSE 'medium' END,
            'Optimize Execution Performance',
            'Average execution time is ' || (v_performance.avg_execution_time_ms/1000)::text || ' seconds, which is above optimal range',
            'Reducing execution time will improve user experience and reduce resource costs',
            'medium',
            jsonb_build_object(
                'execution_time_reduction', '30-50%',
                'cost_savings', '15-25%',
                'user_experience', 'Significantly improved'
            ),
            jsonb_build_array(
                'Analyze slow nodes using node performance data',
                'Optimize database queries and API calls',
                'Implement parallel processing where possible',
                'Add caching for frequently accessed data',
                'Consider workflow splitting for complex operations'
            )
        );
        
        v_recommendations_generated := v_recommendations_generated + 1;
    END IF;
    
    -- Cost optimization recommendations
    IF v_performance.avg_cost_per_execution > 0.25 THEN
        INSERT INTO public.workflow_optimization_recommendations (
            workflow_instance_id,
            recommendation_type,
            priority,
            title,
            description,
            impact_description,
            implementation_effort,
            estimated_improvement,
            implementation_steps
        ) VALUES (
            p_workflow_instance_id,
            'cost',
            'medium',
            'Reduce Execution Costs',
            'Average cost per execution is $' || v_performance.avg_cost_per_execution::text || ', which can be optimized',
            'Cost optimization will reduce operational expenses and improve ROI',
            'low',
            jsonb_build_object(
                'cost_reduction', '20-40%',
                'monthly_savings', '$' || (v_performance.avg_cost_per_execution * v_performance.execution_count_1hour * 24 * 30 * 0.3)::text,
                'roi_improvement', 'Significant'
            ),
            jsonb_build_array(
                'Review AI model usage and switch to cost-effective alternatives',
                'Implement request batching to reduce API calls',
                'Add intelligent caching to avoid redundant operations',
                'Optimize data processing to reduce compute time',
                'Consider using cheaper AI models for non-critical operations'
            )
        );
        
        v_recommendations_generated := v_recommendations_generated + 1;
    END IF;
    
    -- Reliability optimization recommendations
    IF v_performance.error_rate > 5 THEN
        INSERT INTO public.workflow_optimization_recommendations (
            workflow_instance_id,
            recommendation_type,
            priority,
            title,
            description,
            impact_description,
            implementation_effort,
            estimated_improvement,
            implementation_steps
        ) VALUES (
            p_workflow_instance_id,
            'reliability',
            'high',
            'Improve Workflow Reliability',
            'Error rate is ' || v_performance.error_rate::text || '%, which is above acceptable threshold',
            'Improving reliability will reduce manual interventions and improve user satisfaction',
            'medium',
            jsonb_build_object(
                'error_rate_reduction', '60-80%',
                'uptime_improvement', '99.5%+',
                'manual_intervention_reduction', '70-90%'
            ),
            jsonb_build_array(
                'Add comprehensive error handling and retry logic',
                'Implement circuit breakers for external API calls',
                'Add input validation and sanitization',
                'Implement graceful degradation for non-critical failures',
                'Add monitoring and alerting for early issue detection'
            )
        );
        
        v_recommendations_generated := v_recommendations_generated + 1;
    END IF;
    
    -- Scalability recommendations
    IF v_performance.throughput_per_hour > 0 AND v_performance.throughput_per_hour < 50 THEN
        INSERT INTO public.workflow_optimization_recommendations (
            workflow_instance_id,
            recommendation_type,
            priority,
            title,
            description,
            impact_description,
            implementation_effort,
            estimated_improvement,
            implementation_steps
        ) VALUES (
            p_workflow_instance_id,
            'scalability',
            'medium',
            'Improve Workflow Scalability',
            'Current throughput is ' || v_performance.throughput_per_hour::text || ' executions/hour, which can be improved',
            'Better scalability will handle increased load and improve system capacity',
            'high',
            jsonb_build_object(
                'throughput_increase', '100-300%',
                'load_handling', 'Significantly improved',
                'future_proofing', 'Ready for 10x growth'
            ),
            jsonb_build_array(
                'Implement parallel execution for independent operations',
                'Add queue management and load balancing',
                'Optimize database connections and pooling',
                'Implement horizontal scaling capabilities',
                'Add auto-scaling based on load metrics'
            )
        );
        
        v_recommendations_generated := v_recommendations_generated + 1;
    END IF;
    
    RETURN jsonb_build_object(
        'success', true,
        'recommendations_generated', v_recommendations_generated,
        'workflow_instance_id', p_workflow_instance_id,
        'analysis_based_on', jsonb_build_object(
            'avg_execution_time_ms', v_performance.avg_execution_time_ms,
            'error_rate', v_performance.error_rate,
            'avg_cost_per_execution', v_performance.avg_cost_per_execution,
            'throughput_per_hour', v_performance.throughput_per_hour
        )
    );

EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', SQLERRM
        );
END;
$;

-- ============================================================
-- 3. WORKFLOW OPTIMIZATION FUNCTIONS
-- ============================================================

-- Function to get workflow health dashboard
CREATE OR REPLACE FUNCTION get_workflow_health_dashboard(
    p_tenant_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $
DECLARE
    v_dashboard jsonb;
    v_workflows jsonb;
    v_alerts jsonb;
    v_recommendations jsonb;
BEGIN
    -- Get workflow overview
    SELECT jsonb_agg(
        jsonb_build_object(
            'id', wi.id,
            'name', wi.name,
            'status', wi.status,
            'last_execution', wi.last_execution_at,
            'success_rate_1hour', COALESCE(wrm.success_rate_1hour, 0),
            'avg_execution_time_1hour', COALESCE(wrm.avg_execution_time_1hour, 0),
            'cost_1hour', COALESCE(wrm.cost_1hour, 0),
            'active_executions', COALESCE(wrm.active_executions, 0),
            'health_score', CASE 
                WHEN wrm.success_rate_1hour >= 95 AND wrm.avg_execution_time_1hour < 120000 THEN 'excellent'
                WHEN wrm.success_rate_1hour >= 90 AND wrm.avg_execution_time_1hour < 180000 THEN 'good'
                WHEN wrm.success_rate_1hour >= 80 AND wrm.avg_execution_time_1hour < 300000 THEN 'fair'
                ELSE 'poor'
            END
        )
    ) INTO v_workflows
    FROM public.workflow_instances wi
    LEFT JOIN public.workflow_realtime_metrics wrm ON wi.id = wrm.workflow_instance_id
    WHERE (p_tenant_id IS NULL OR wi.tenant_id = p_tenant_id)
        AND wi.status = 'active'
    ORDER BY wi.name;
    
    -- Get active alerts
    SELECT jsonb_agg(
        jsonb_build_object(
            'id', wpa.id,
            'workflow_name', wi.name,
            'alert_type', wpa.alert_type,
            'severity', wpa.severity,
            'title', wpa.title,
            'description', wpa.description,
            'created_at', wpa.created_at
        )
    ) INTO v_alerts
    FROM public.workflow_performance_alerts wpa
    JOIN public.workflow_instances wi ON wpa.workflow_instance_id = wi.id
    WHERE (p_tenant_id IS NULL OR wi.tenant_id = p_tenant_id)
        AND wpa.is_resolved = false
        AND wpa.created_at >= NOW() - INTERVAL '24 hours'
    ORDER BY wpa.severity DESC, wpa.created_at DESC
    LIMIT 20;
    
    -- Get pending recommendations
    SELECT jsonb_agg(
        jsonb_build_object(
            'id', wor.id,
            'workflow_name', wi.name,
            'recommendation_type', wor.recommendation_type,
            'priority', wor.priority,
            'title', wor.title,
            'description', wor.description,
            'estimated_improvement', wor.estimated_improvement,
            'created_at', wor.created_at
        )
    ) INTO v_recommendations
    FROM public.workflow_optimization_recommendations wor
    JOIN public.workflow_instances wi ON wor.workflow_instance_id = wi.id
    WHERE (p_tenant_id IS NULL OR wi.tenant_id = p_tenant_id)
        AND wor.is_implemented = false
    ORDER BY wor.priority DESC, wor.created_at DESC
    LIMIT 10;
    
    -- Build dashboard
    v_dashboard := jsonb_build_object(
        'success', true,
        'generated_at', NOW(),
        'summary', jsonb_build_object(
            'total_workflows', (SELECT COUNT(*) FROM public.workflow_instances WHERE (p_tenant_id IS NULL OR tenant_id = p_tenant_id) AND status = 'active'),
            'active_alerts', (SELECT COUNT(*) FROM public.workflow_performance_alerts wpa JOIN public.workflow_instances wi ON wpa.workflow_instance_id = wi.id WHERE (p_tenant_id IS NULL OR wi.tenant_id = p_tenant_id) AND wpa.is_resolved = false),
            'pending_recommendations', (SELECT COUNT(*) FROM public.workflow_optimization_recommendations wor JOIN public.workflow_instances wi ON wor.workflow_instance_id = wi.id WHERE (p_tenant_id IS NULL OR wi.tenant_id = p_tenant_id) AND wor.is_implemented = false),
            'total_executions_24h', (SELECT COUNT(*) FROM public.workflow_executions_enhanced wee JOIN public.workflow_instances wi ON wee.workflow_instance_id = wi.id WHERE (p_tenant_id IS NULL OR wi.tenant_id = p_tenant_id) AND wee.started_at >= NOW() - INTERVAL '24 hours'),
            'avg_success_rate_24h', (SELECT AVG(CASE WHEN wee.execution_status = 'success' THEN 100.0 ELSE 0.0 END) FROM public.workflow_executions_enhanced wee JOIN public.workflow_instances wi ON wee.workflow_instance_id = wi.id WHERE (p_tenant_id IS NULL OR wi.tenant_id = p_tenant_id) AND wee.started_at >= NOW() - INTERVAL '24 hours')
        ),
        'workflows', COALESCE(v_workflows, '[]'::jsonb),
        'active_alerts', COALESCE(v_alerts, '[]'::jsonb),
        'recommendations', COALESCE(v_recommendations, '[]'::jsonb)
    );
    
    RETURN v_dashboard;

EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', SQLERRM
        );
END;
$;

-- ============================================================
-- 4. AUTOMATED MONITORING TRIGGERS
-- ============================================================

-- Function to run automated monitoring (called by scheduler)
CREATE OR REPLACE FUNCTION run_automated_workflow_monitoring()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $
DECLARE
    v_workflow_id uuid;
    v_metrics_updated integer := 0;
    v_alerts_generated integer := 0;
    v_recommendations_generated integer := 0;
    v_result jsonb;
BEGIN
    -- Update metrics for all active workflows
    FOR v_workflow_id IN 
        SELECT id FROM public.workflow_instances WHERE status = 'active'
    LOOP
        SELECT update_workflow_realtime_metrics(v_workflow_id) INTO v_result;
        IF (v_result->>'success')::boolean THEN
            v_metrics_updated := v_metrics_updated + 1;
        END IF;
    END LOOP;
    
    -- Detect performance issues
    SELECT detect_workflow_performance_issues() INTO v_result;
    v_alerts_generated := (v_result->>'alerts_generated')::integer;
    
    -- Generate optimization recommendations for workflows with issues
    FOR v_workflow_id IN 
        SELECT DISTINCT workflow_instance_id 
        FROM public.workflow_performance_alerts 
        WHERE created_at >= NOW() - INTERVAL '1 hour' 
            AND is_resolved = false
    LOOP
        SELECT generate_workflow_optimization_recommendations(v_workflow_id) INTO v_result;
        IF (v_result->>'success')::boolean THEN
            v_recommendations_generated := v_recommendations_generated + (v_result->>'recommendations_generated')::integer;
        END IF;
    END LOOP;
    
    RETURN jsonb_build_object(
        'success', true,
        'monitoring_run_at', NOW(),
        'metrics_updated', v_metrics_updated,
        'alerts_generated', v_alerts_generated,
        'recommendations_generated', v_recommendations_generated
    );

EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', SQLERRM
        );
END;
$;

-- ============================================================
-- 5. GRANT PERMISSIONS
-- ============================================================

GRANT EXECUTE ON FUNCTION update_workflow_realtime_metrics TO service_role;
GRANT EXECUTE ON FUNCTION detect_workflow_performance_issues TO service_role;
GRANT EXECUTE ON FUNCTION generate_workflow_optimization_recommendations TO service_role;
GRANT EXECUTE ON FUNCTION get_workflow_health_dashboard TO service_role;
GRANT EXECUTE ON FUNCTION run_automated_workflow_monitoring TO service_role;

-- Enable RLS on monitoring tables
ALTER TABLE public.workflow_realtime_metrics ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workflow_performance_alerts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workflow_optimization_recommendations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workflow_node_performance ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workflow_execution_patterns ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- DEPLOYMENT COMPLETE!
-- 
-- Advanced monitoring features:
-- ✅ Real-time metrics collection and analysis
-- ✅ Automated performance issue detection
-- ✅ Intelligent optimization recommendations
-- ✅ Comprehensive health dashboard
-- ✅ Automated monitoring workflows
-- 
-- Key functions:
-- - update_workflow_realtime_metrics() - Real-time metrics
-- - detect_workflow_performance_issues() - Alert generation
-- - generate_workflow_optimization_recommendations() - AI recommendations
-- - get_workflow_health_dashboard() - Executive dashboard
-- - run_automated_workflow_monitoring() - Automated monitoring
-- ============================================================