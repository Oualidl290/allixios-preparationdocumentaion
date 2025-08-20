-- ============================================================
-- ENHANCED N8N WORKFLOW INTEGRATION
-- Advanced workflow management, monitoring, and optimization
-- ============================================================

-- ============================================================
-- 1. WORKFLOW MANAGEMENT TABLES
-- ============================================================

-- Workflow templates registry
CREATE TABLE IF NOT EXISTS public.workflow_templates (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    tenant_id uuid REFERENCES public.tenants(id) ON DELETE CASCADE,
    name text NOT NULL,
    description text,
    category text NOT NULL CHECK (category IN ('content', 'seo', 'analytics', 'user_management', 'integration', 'custom')),
    template_data jsonb NOT NULL, -- n8n workflow JSON
    version text NOT NULL DEFAULT '1.0.0',
    is_active boolean DEFAULT true,
    is_public boolean DEFAULT false, -- Can be used by other tenants
    usage_count integer DEFAULT 0,
    success_rate numeric DEFAULT 0,
    avg_execution_time_ms integer DEFAULT 0,
    created_by uuid REFERENCES public.users(id),
    created_at timestamptz DEFAULT NOW(),
    updated_at timestamptz DEFAULT NOW(),
    CONSTRAINT workflow_templates_pkey PRIMARY KEY (id),
    CONSTRAINT workflow_templates_unique_name UNIQUE (tenant_id, name, version)
);

-- Workflow instances (deployed workflows)
CREATE TABLE IF NOT EXISTS public.workflow_instances (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    tenant_id uuid REFERENCES public.tenants(id) ON DELETE CASCADE,
    template_id uuid REFERENCES public.workflow_templates(id) ON DELETE SET NULL,
    n8n_workflow_id text NOT NULL, -- n8n internal workflow ID
    name text NOT NULL,
    description text,
    status text NOT NULL DEFAULT 'inactive' CHECK (status IN ('active', 'inactive', 'error', 'maintenance')),
    configuration jsonb DEFAULT '{}',
    environment text NOT NULL DEFAULT 'production' CHECK (environment IN ('development', 'staging', 'production')),
    webhook_url text,
    trigger_type text CHECK (trigger_type IN ('webhook', 'schedule', 'manual', 'event')),
    schedule_expression text, -- Cron expression for scheduled workflows
    is_monitored boolean DEFAULT true,
    created_by uuid REFERENCES public.users(id),
    deployed_at timestamptz DEFAULT NOW(),
    last_execution_at timestamptz,
    created_at timestamptz DEFAULT NOW(),
    updated_at timestamptz DEFAULT NOW(),
    CONSTRAINT workflow_instances_pkey PRIMARY KEY (id),
    CONSTRAINT workflow_instances_unique_n8n_id UNIQUE (n8n_workflow_id)
);

-- Enhanced workflow executions (extends existing n8n_executions)
CREATE TABLE IF NOT EXISTS public.workflow_executions_enhanced (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    workflow_instance_id uuid REFERENCES public.workflow_instances(id) ON DELETE CASCADE,
    n8n_execution_id text NOT NULL,
    execution_status text NOT NULL CHECK (execution_status IN ('running', 'success', 'error', 'waiting', 'cancelled')),
    trigger_data jsonb,
    input_data jsonb,
    output_data jsonb,
    error_data jsonb,
    performance_metrics jsonb DEFAULT '{}',
    resource_usage jsonb DEFAULT '{}',
    execution_time_ms integer,
    nodes_executed integer DEFAULT 0,
    nodes_failed integer DEFAULT 0,
    cost_usd numeric DEFAULT 0,
    started_at timestamptz DEFAULT NOW(),
    completed_at timestamptz,
    created_at timestamptz DEFAULT NOW(),
    CONSTRAINT workflow_executions_enhanced_pkey PRIMARY KEY (id),
    CONSTRAINT workflow_executions_enhanced_unique_n8n_id UNIQUE (n8n_execution_id)
);

-- Workflow performance analytics
CREATE TABLE IF NOT EXISTS public.workflow_performance_analytics (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    workflow_instance_id uuid REFERENCES public.workflow_instances(id) ON DELETE CASCADE,
    analysis_period_start timestamptz NOT NULL,
    analysis_period_end timestamptz NOT NULL,
    total_executions integer DEFAULT 0,
    successful_executions integer DEFAULT 0,
    failed_executions integer DEFAULT 0,
    avg_execution_time_ms integer DEFAULT 0,
    p95_execution_time_ms integer DEFAULT 0,
    total_cost_usd numeric DEFAULT 0,
    avg_cost_per_execution numeric DEFAULT 0,
    throughput_per_hour numeric DEFAULT 0,
    error_rate numeric DEFAULT 0,
    performance_score integer DEFAULT 0, -- 0-100 score
    bottleneck_nodes jsonb DEFAULT '[]',
    optimization_recommendations jsonb DEFAULT '[]',
    created_at timestamptz DEFAULT NOW(),
    CONSTRAINT workflow_performance_analytics_pkey PRIMARY KEY (id)
);

-- Workflow version control
CREATE TABLE IF NOT EXISTS public.workflow_versions (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    workflow_instance_id uuid REFERENCES public.workflow_instances(id) ON DELETE CASCADE,
    version_number text NOT NULL,
    workflow_data jsonb NOT NULL, -- Complete n8n workflow JSON
    change_description text,
    is_active boolean DEFAULT false,
    performance_comparison jsonb DEFAULT '{}',
    rollback_data jsonb, -- Data needed for rollback
    created_by uuid REFERENCES public.users(id),
    created_at timestamptz DEFAULT NOW(),
    activated_at timestamptz,
    CONSTRAINT workflow_versions_pkey PRIMARY KEY (id),
    CONSTRAINT workflow_versions_unique_version UNIQUE (workflow_instance_id, version_number)
);

-- Custom n8n nodes registry
CREATE TABLE IF NOT EXISTS public.custom_n8n_nodes (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    name text NOT NULL UNIQUE,
    display_name text NOT NULL,
    description text,
    category text NOT NULL,
    node_type text NOT NULL CHECK (node_type IN ('regular', 'trigger', 'webhook')),
    node_code text NOT NULL, -- JavaScript/TypeScript code
    node_schema jsonb NOT NULL, -- Node definition schema
    version text NOT NULL DEFAULT '1.0.0',
    is_active boolean DEFAULT true,
    usage_count integer DEFAULT 0,
    created_by uuid REFERENCES public.users(id),
    created_at timestamptz DEFAULT NOW(),
    updated_at timestamptz DEFAULT NOW(),
    CONSTRAINT custom_n8n_nodes_pkey PRIMARY KEY (id)
);

-- ============================================================
-- 2. WORKFLOW TEMPLATE MANAGEMENT
-- ============================================================

-- Function to create workflow template
CREATE OR REPLACE FUNCTION create_workflow_template(
    p_tenant_id uuid,
    p_name text,
    p_description text,
    p_category text,
    p_template_data jsonb,
    p_version text DEFAULT '1.0.0',
    p_is_public boolean DEFAULT false,
    p_created_by uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $
DECLARE
    v_template_id uuid;
BEGIN
    -- Validate template data
    IF NOT (p_template_data ? 'nodes' AND p_template_data ? 'connections') THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Invalid template data: missing nodes or connections'
        );
    END IF;
    
    -- Insert workflow template
    INSERT INTO public.workflow_templates (
        tenant_id,
        name,
        description,
        category,
        template_data,
        version,
        is_public,
        created_by
    ) VALUES (
        p_tenant_id,
        p_name,
        p_description,
        p_category,
        p_template_data,
        p_version,
        p_is_public,
        p_created_by
    ) RETURNING id INTO v_template_id;
    
    RETURN jsonb_build_object(
        'success', true,
        'template_id', v_template_id,
        'name', p_name,
        'version', p_version
    );

EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', SQLERRM
        );
END;
$;

-- Function to deploy workflow from template
CREATE OR REPLACE FUNCTION deploy_workflow_from_template(
    p_template_id uuid,
    p_name text,
    p_environment text DEFAULT 'production',
    p_configuration jsonb DEFAULT '{}',
    p_deployed_by uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $
DECLARE
    v_template RECORD;
    v_instance_id uuid;
    v_n8n_workflow_id text;
    v_webhook_url text;
BEGIN
    -- Get template data
    SELECT * INTO v_template
    FROM public.workflow_templates
    WHERE id = p_template_id AND is_active = true;
    
    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Template not found or inactive'
        );
    END IF;
    
    -- Generate n8n workflow ID (in production, this would call n8n API)
    v_n8n_workflow_id := 'n8n_' || gen_random_uuid()::text;
    
    -- Generate webhook URL if template contains webhook trigger
    IF v_template.template_data->'nodes' @> '[{"type": "n8n-nodes-base.webhook"}]' THEN
        v_webhook_url := 'https://n8n.yourdomain.com/webhook/' || substring(v_n8n_workflow_id from 1 for 8);
    END IF;
    
    -- Create workflow instance
    INSERT INTO public.workflow_instances (
        tenant_id,
        template_id,
        n8n_workflow_id,
        name,
        description,
        status,
        configuration,
        environment,
        webhook_url,
        trigger_type,
        created_by
    ) VALUES (
        v_template.tenant_id,
        p_template_id,
        v_n8n_workflow_id,
        p_name,
        v_template.description,
        'active',
        p_configuration,
        p_environment,
        v_webhook_url,
        CASE 
            WHEN v_template.template_data->'nodes' @> '[{"type": "n8n-nodes-base.webhook"}]' THEN 'webhook'
            WHEN v_template.template_data->'nodes' @> '[{"type": "n8n-nodes-base.scheduleTrigger"}]' THEN 'schedule'
            ELSE 'manual'
        END,
        p_deployed_by
    ) RETURNING id INTO v_instance_id;
    
    -- Create initial version
    INSERT INTO public.workflow_versions (
        workflow_instance_id,
        version_number,
        workflow_data,
        change_description,
        is_active,
        created_by
    ) VALUES (
        v_instance_id,
        '1.0.0',
        v_template.template_data,
        'Initial deployment from template',
        true,
        p_deployed_by
    );
    
    -- Update template usage count
    UPDATE public.workflow_templates
    SET usage_count = usage_count + 1,
        updated_at = NOW()
    WHERE id = p_template_id;
    
    RETURN jsonb_build_object(
        'success', true,
        'instance_id', v_instance_id,
        'n8n_workflow_id', v_n8n_workflow_id,
        'webhook_url', v_webhook_url,
        'status', 'active'
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
-- 3. WORKFLOW MONITORING AND ANALYTICS
-- ============================================================

-- Function to log workflow execution
CREATE OR REPLACE FUNCTION log_workflow_execution(
    p_n8n_workflow_id text,
    p_n8n_execution_id text,
    p_execution_status text,
    p_trigger_data jsonb DEFAULT NULL,
    p_input_data jsonb DEFAULT NULL,
    p_output_data jsonb DEFAULT NULL,
    p_error_data jsonb DEFAULT NULL,
    p_execution_time_ms integer DEFAULT NULL,
    p_nodes_executed integer DEFAULT 0,
    p_nodes_failed integer DEFAULT 0,
    p_cost_usd numeric DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $
DECLARE
    v_instance_id uuid;
    v_execution_id uuid;
BEGIN
    -- Get workflow instance
    SELECT id INTO v_instance_id
    FROM public.workflow_instances
    WHERE n8n_workflow_id = p_n8n_workflow_id;
    
    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Workflow instance not found'
        );
    END IF;
    
    -- Insert or update execution record
    INSERT INTO public.workflow_executions_enhanced (
        workflow_instance_id,
        n8n_execution_id,
        execution_status,
        trigger_data,
        input_data,
        output_data,
        error_data,
        execution_time_ms,
        nodes_executed,
        nodes_failed,
        cost_usd,
        completed_at
    ) VALUES (
        v_instance_id,
        p_n8n_execution_id,
        p_execution_status,
        p_trigger_data,
        p_input_data,
        p_output_data,
        p_error_data,
        p_execution_time_ms,
        p_nodes_executed,
        p_nodes_failed,
        p_cost_usd,
        CASE WHEN p_execution_status IN ('success', 'error', 'cancelled') THEN NOW() ELSE NULL END
    )
    ON CONFLICT (n8n_execution_id)
    DO UPDATE SET
        execution_status = EXCLUDED.execution_status,
        output_data = EXCLUDED.output_data,
        error_data = EXCLUDED.error_data,
        execution_time_ms = EXCLUDED.execution_time_ms,
        nodes_executed = EXCLUDED.nodes_executed,
        nodes_failed = EXCLUDED.nodes_failed,
        cost_usd = EXCLUDED.cost_usd,
        completed_at = EXCLUDED.completed_at
    RETURNING id INTO v_execution_id;
    
    -- Update workflow instance last execution time
    UPDATE public.workflow_instances
    SET last_execution_at = NOW(),
        updated_at = NOW()
    WHERE id = v_instance_id;
    
    RETURN jsonb_build_object(
        'success', true,
        'execution_id', v_execution_id,
        'workflow_instance_id', v_instance_id
    );

EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', SQLERRM
        );
END;
$;

-- Function to analyze workflow performance
CREATE OR REPLACE FUNCTION analyze_workflow_performance(
    p_workflow_instance_id uuid,
    p_analysis_period_hours integer DEFAULT 24
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $
DECLARE
    v_analysis_start timestamptz;
    v_analysis_end timestamptz;
    v_performance_data RECORD;
    v_bottlenecks jsonb := '[]'::jsonb;
    v_recommendations jsonb := '[]'::jsonb;
    v_performance_score integer;
    v_analytics_id uuid;
BEGIN
    v_analysis_end := NOW();
    v_analysis_start := v_analysis_end - (p_analysis_period_hours || ' hours')::INTERVAL;
    
    -- Calculate performance metrics
    SELECT 
        COUNT(*) as total_executions,
        COUNT(*) FILTER (WHERE execution_status = 'success') as successful_executions,
        COUNT(*) FILTER (WHERE execution_status = 'error') as failed_executions,
        COALESCE(AVG(execution_time_ms), 0) as avg_execution_time_ms,
        COALESCE(PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY execution_time_ms), 0) as p95_execution_time_ms,
        COALESCE(SUM(cost_usd), 0) as total_cost_usd,
        COALESCE(AVG(cost_usd), 0) as avg_cost_per_execution,
        COALESCE(COUNT(*) * 1.0 / NULLIF(p_analysis_period_hours, 0), 0) as throughput_per_hour
    INTO v_performance_data
    FROM public.workflow_executions_enhanced
    WHERE workflow_instance_id = p_workflow_instance_id
        AND started_at >= v_analysis_start
        AND started_at <= v_analysis_end;
    
    -- Calculate error rate
    v_performance_data.error_rate := CASE 
        WHEN v_performance_data.total_executions > 0 
        THEN v_performance_data.failed_executions * 100.0 / v_performance_data.total_executions
        ELSE 0
    END;
    
    -- Generate recommendations based on performance
    IF v_performance_data.error_rate > 5 THEN
        v_recommendations := v_recommendations || jsonb_build_array(
            jsonb_build_object(
                'type', 'error_rate',
                'priority', 'high',
                'message', 'Error rate is ' || v_performance_data.error_rate::text || '%. Consider adding error handling and retry logic.',
                'impact', 'reliability'
            )
        );
    END IF;
    
    IF v_performance_data.avg_execution_time_ms > 300000 THEN -- 5 minutes
        v_recommendations := v_recommendations || jsonb_build_array(
            jsonb_build_object(
                'type', 'performance',
                'priority', 'medium',
                'message', 'Average execution time is ' || (v_performance_data.avg_execution_time_ms/1000)::text || ' seconds. Consider optimizing slow nodes.',
                'impact', 'performance'
            )
        );
    END IF;
    
    IF v_performance_data.avg_cost_per_execution > 0.50 THEN
        v_recommendations := v_recommendations || jsonb_build_array(
            jsonb_build_object(
                'type', 'cost',
                'priority', 'medium',
                'message', 'Average cost per execution is $' || v_performance_data.avg_cost_per_execution::text || '. Consider optimizing AI API usage.',
                'impact', 'cost'
            )
        );
    END IF;
    
    -- Calculate performance score (0-100)
    v_performance_score := LEAST(100, GREATEST(0,
        100 - 
        (v_performance_data.error_rate * 2) - -- Error rate penalty
        (CASE WHEN v_performance_data.avg_execution_time_ms > 60000 THEN 10 ELSE 0 END) - -- Slow execution penalty
        (CASE WHEN v_performance_data.avg_cost_per_execution > 0.25 THEN 10 ELSE 0 END) -- High cost penalty
    ));
    
    -- Store analytics
    INSERT INTO public.workflow_performance_analytics (
        workflow_instance_id,
        analysis_period_start,
        analysis_period_end,
        total_executions,
        successful_executions,
        failed_executions,
        avg_execution_time_ms,
        p95_execution_time_ms,
        total_cost_usd,
        avg_cost_per_execution,
        throughput_per_hour,
        error_rate,
        performance_score,
        bottleneck_nodes,
        optimization_recommendations
    ) VALUES (
        p_workflow_instance_id,
        v_analysis_start,
        v_analysis_end,
        v_performance_data.total_executions,
        v_performance_data.successful_executions,
        v_performance_data.failed_executions,
        v_performance_data.avg_execution_time_ms::integer,
        v_performance_data.p95_execution_time_ms::integer,
        v_performance_data.total_cost_usd,
        v_performance_data.avg_cost_per_execution,
        v_performance_data.throughput_per_hour,
        v_performance_data.error_rate,
        v_performance_score,
        v_bottlenecks,
        v_recommendations
    ) RETURNING id INTO v_analytics_id;
    
    RETURN jsonb_build_object(
        'success', true,
        'analytics_id', v_analytics_id,
        'performance_score', v_performance_score,
        'metrics', row_to_json(v_performance_data),
        'recommendations', v_recommendations,
        'analysis_period', jsonb_build_object(
            'start', v_analysis_start,
            'end', v_analysis_end,
            'hours', p_analysis_period_hours
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
-- 4. WORKFLOW VERSION CONTROL
-- ============================================================

-- Function to create new workflow version
CREATE OR REPLACE FUNCTION create_workflow_version(
    p_workflow_instance_id uuid,
    p_version_number text,
    p_workflow_data jsonb,
    p_change_description text,
    p_created_by uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $
DECLARE
    v_version_id uuid;
    v_current_version RECORD;
BEGIN
    -- Get current active version for comparison
    SELECT * INTO v_current_version
    FROM public.workflow_versions
    WHERE workflow_instance_id = p_workflow_instance_id
        AND is_active = true;
    
    -- Deactivate current version
    UPDATE public.workflow_versions
    SET is_active = false
    WHERE workflow_instance_id = p_workflow_instance_id
        AND is_active = true;
    
    -- Create new version
    INSERT INTO public.workflow_versions (
        workflow_instance_id,
        version_number,
        workflow_data,
        change_description,
        is_active,
        rollback_data,
        created_by
    ) VALUES (
        p_workflow_instance_id,
        p_version_number,
        p_workflow_data,
        p_change_description,
        true,
        CASE WHEN v_current_version.id IS NOT NULL 
             THEN jsonb_build_object(
                 'previous_version', v_current_version.version_number,
                 'previous_data', v_current_version.workflow_data
             )
             ELSE NULL
        END,
        p_created_by
    ) RETURNING id INTO v_version_id;
    
    -- Update workflow instance
    UPDATE public.workflow_instances
    SET updated_at = NOW()
    WHERE id = p_workflow_instance_id;
    
    RETURN jsonb_build_object(
        'success', true,
        'version_id', v_version_id,
        'version_number', p_version_number,
        'previous_version', COALESCE(v_current_version.version_number, 'none')
    );

EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', SQLERRM
        );
END;
$;

-- Function to rollback workflow version
CREATE OR REPLACE FUNCTION rollback_workflow_version(
    p_workflow_instance_id uuid,
    p_target_version text,
    p_rollback_reason text,
    p_rolled_back_by uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $
DECLARE
    v_target_version RECORD;
    v_new_version_number text;
BEGIN
    -- Get target version
    SELECT * INTO v_target_version
    FROM public.workflow_versions
    WHERE workflow_instance_id = p_workflow_instance_id
        AND version_number = p_target_version;
    
    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Target version not found'
        );
    END IF;
    
    -- Generate new version number for rollback
    v_new_version_number := 'rollback-' || p_target_version || '-' || 
                           EXTRACT(EPOCH FROM NOW())::text;
    
    -- Create rollback version
    SELECT create_workflow_version(
        p_workflow_instance_id,
        v_new_version_number,
        v_target_version.workflow_data,
        'Rollback to version ' || p_target_version || ': ' || p_rollback_reason,
        p_rolled_back_by
    ) INTO v_target_version;
    
    RETURN jsonb_build_object(
        'success', true,
        'rollback_version', v_new_version_number,
        'target_version', p_target_version,
        'reason', p_rollback_reason
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

GRANT EXECUTE ON FUNCTION create_workflow_template TO service_role;
GRANT EXECUTE ON FUNCTION deploy_workflow_from_template TO service_role;
GRANT EXECUTE ON FUNCTION log_workflow_execution TO service_role;
GRANT EXECUTE ON FUNCTION analyze_workflow_performance TO service_role;
GRANT EXECUTE ON FUNCTION create_workflow_version TO service_role;
GRANT EXECUTE ON FUNCTION rollback_workflow_version TO service_role;

-- Enable RLS on all tables
ALTER TABLE public.workflow_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workflow_instances ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workflow_executions_enhanced ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workflow_performance_analytics ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workflow_versions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.custom_n8n_nodes ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- DEPLOYMENT COMPLETE!
-- 
-- New REST API endpoints available:
-- POST {SUPABASE_URL}/rest/v1/rpc/create_workflow_template
-- POST {SUPABASE_URL}/rest/v1/rpc/deploy_workflow_from_template
-- POST {SUPABASE_URL}/rest/v1/rpc/log_workflow_execution
-- POST {SUPABASE_URL}/rest/v1/rpc/analyze_workflow_performance
-- POST {SUPABASE_URL}/rest/v1/rpc/create_workflow_version
-- POST {SUPABASE_URL}/rest/v1/rpc/rollback_workflow_version
-- 
-- This enhanced n8n integration provides:
-- ✅ Workflow template management and deployment
-- ✅ Advanced performance monitoring and analytics
-- ✅ Version control with rollback capabilities
-- ✅ Custom node registry and management
-- ✅ Comprehensive execution tracking
-- ✅ Optimization recommendations
-- ============================================================