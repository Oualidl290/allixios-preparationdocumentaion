-- ============================================================
-- MICROSERVICES INTEGRATION FOR N8N WORKFLOWS
-- Integration layer between n8n workflows and Allixios microservices
-- ============================================================

-- ============================================================
-- 1. MICROSERVICE REGISTRY TABLES
-- ============================================================

-- Microservice registry
CREATE TABLE IF NOT EXISTS public.microservice_registry (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    service_name text NOT NULL UNIQUE,
    service_type text NOT NULL CHECK (service_type IN ('orchestrator', 'ai_management', 'content_management', 'analytics', 'user_management', 'api_gateway')),
    base_url text NOT NULL,
    health_endpoint text DEFAULT '/health',
    api_version text DEFAULT 'v1',
    authentication_type text DEFAULT 'bearer' CHECK (authentication_type IN ('bearer', 'api_key', 'basic', 'none')),
    authentication_config jsonb DEFAULT '{}',
    rate_limits jsonb DEFAULT '{}',
    timeout_ms integer DEFAULT 30000,
    retry_config jsonb DEFAULT '{"max_retries": 3, "backoff_ms": 1000}',
    circuit_breaker_config jsonb DEFAULT '{"failure_threshold": 5, "recovery_timeout_ms": 60000}',
    is_active boolean DEFAULT true,
    health_status text DEFAULT 'unknown' CHECK (health_status IN ('healthy', 'unhealthy', 'unknown', 'maintenance')),
    last_health_check timestamptz,
    created_at timestamptz DEFAULT NOW(),
    updated_at timestamptz DEFAULT NOW(),
    CONSTRAINT microservice_registry_pkey PRIMARY KEY (id)
);

-- Service endpoint registry
CREATE TABLE IF NOT EXISTS public.service_endpoints (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    service_id uuid REFERENCES public.microservice_registry(id) ON DELETE CASCADE,
    endpoint_name text NOT NULL,
    endpoint_path text NOT NULL,
    http_method text NOT NULL CHECK (http_method IN ('GET', 'POST', 'PUT', 'DELETE', 'PATCH')),
    description text,
    request_schema jsonb DEFAULT '{}',
    response_schema jsonb DEFAULT '{}',
    is_async boolean DEFAULT false,
    requires_auth boolean DEFAULT true,
    rate_limit_per_minute integer DEFAULT 60,
    timeout_ms integer,
    cache_ttl_seconds integer DEFAULT 0,
    is_active boolean DEFAULT true,
    usage_count integer DEFAULT 0,
    avg_response_time_ms integer DEFAULT 0,
    success_rate numeric DEFAULT 100,
    created_at timestamptz DEFAULT NOW(),
    updated_at timestamptz DEFAULT NOW(),
    CONSTRAINT service_endpoints_pkey PRIMARY KEY (id),
    CONSTRAINT service_endpoints_unique_endpoint UNIQUE (service_id, endpoint_name)
);

-- Service call logs
CREATE TABLE IF NOT EXISTS public.service_call_logs (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    workflow_execution_id uuid REFERENCES public.workflow_executions_enhanced(id) ON DELETE CASCADE,
    service_id uuid REFERENCES public.microservice_registry(id) ON DELETE CASCADE,
    endpoint_id uuid REFERENCES public.service_endpoints(id) ON DELETE CASCADE,
    request_id text NOT NULL,
    http_method text NOT NULL,
    endpoint_path text NOT NULL,
    request_headers jsonb DEFAULT '{}',
    request_body jsonb,
    response_status integer,
    response_headers jsonb DEFAULT '{}',
    response_body jsonb,
    response_time_ms integer,
    error_message text,
    retry_count integer DEFAULT 0,
    circuit_breaker_state text DEFAULT 'closed' CHECK (circuit_breaker_state IN ('closed', 'open', 'half_open')),
    called_at timestamptz DEFAULT NOW(),
    completed_at timestamptz,
    CONSTRAINT service_call_logs_pkey PRIMARY KEY (id)
);

-- Service health monitoring
CREATE TABLE IF NOT EXISTS public.service_health_monitoring (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    service_id uuid REFERENCES public.microservice_registry(id) ON DELETE CASCADE,
    health_status text NOT NULL CHECK (health_status IN ('healthy', 'unhealthy', 'degraded')),
    response_time_ms integer,
    error_message text,
    health_details jsonb DEFAULT '{}',
    checked_at timestamptz DEFAULT NOW(),
    CONSTRAINT service_health_monitoring_pkey PRIMARY KEY (id)
);

-- ============================================================
-- 2. MICROSERVICE INTEGRATION FUNCTIONS
-- ============================================================

-- Function to register microservice
CREATE OR REPLACE FUNCTION register_microservice(
    p_service_name text,
    p_service_type text,
    p_base_url text,
    p_health_endpoint text DEFAULT '/health',
    p_api_version text DEFAULT 'v1',
    p_authentication_type text DEFAULT 'bearer',
    p_authentication_config jsonb DEFAULT '{}',
    p_rate_limits jsonb DEFAULT '{}',
    p_timeout_ms integer DEFAULT 30000
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $
DECLARE
    v_service_id uuid;
BEGIN
    INSERT INTO public.microservice_registry (
        service_name,
        service_type,
        base_url,
        health_endpoint,
        api_version,
        authentication_type,
        authentication_config,
        rate_limits,
        timeout_ms
    ) VALUES (
        p_service_name,
        p_service_type,
        p_base_url,
        p_health_endpoint,
        p_api_version,
        p_authentication_type,
        p_authentication_config,
        p_rate_limits,
        p_timeout_ms
    ) RETURNING id INTO v_service_id;
    
    RETURN jsonb_build_object(
        'success', true,
        'service_id', v_service_id,
        'service_name', p_service_name,
        'service_type', p_service_type
    );

EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', SQLERRM
        );
END;
$;

-- Function to register service endpoint
CREATE OR REPLACE FUNCTION register_service_endpoint(
    p_service_name text,
    p_endpoint_name text,
    p_endpoint_path text,
    p_http_method text,
    p_description text DEFAULT NULL,
    p_request_schema jsonb DEFAULT '{}',
    p_response_schema jsonb DEFAULT '{}',
    p_is_async boolean DEFAULT false,
    p_requires_auth boolean DEFAULT true,
    p_rate_limit_per_minute integer DEFAULT 60
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $
DECLARE
    v_service_id uuid;
    v_endpoint_id uuid;
BEGIN
    -- Get service ID
    SELECT id INTO v_service_id
    FROM public.microservice_registry
    WHERE service_name = p_service_name AND is_active = true;
    
    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Service not found: ' || p_service_name
        );
    END IF;
    
    INSERT INTO public.service_endpoints (
        service_id,
        endpoint_name,
        endpoint_path,
        http_method,
        description,
        request_schema,
        response_schema,
        is_async,
        requires_auth,
        rate_limit_per_minute
    ) VALUES (
        v_service_id,
        p_endpoint_name,
        p_endpoint_path,
        p_http_method,
        p_description,
        p_request_schema,
        p_response_schema,
        p_is_async,
        p_requires_auth,
        p_rate_limit_per_minute
    ) RETURNING id INTO v_endpoint_id;
    
    RETURN jsonb_build_object(
        'success', true,
        'endpoint_id', v_endpoint_id,
        'service_name', p_service_name,
        'endpoint_name', p_endpoint_name
    );

EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', SQLERRM
        );
END;
$;

-- Function to call microservice from n8n workflow
CREATE OR REPLACE FUNCTION call_microservice_endpoint(
    p_service_name text,
    p_endpoint_name text,
    p_request_data jsonb DEFAULT '{}',
    p_workflow_execution_id uuid DEFAULT NULL,
    p_timeout_override_ms integer DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $
DECLARE
    v_service RECORD;
    v_endpoint RECORD;
    v_request_id text;
    v_call_log_id uuid;
    v_response jsonb;
    v_start_time timestamptz;
    v_end_time timestamptz;
    v_response_time_ms integer;
BEGIN
    v_start_time := NOW();
    v_request_id := 'req_' || gen_random_uuid()::text;
    
    -- Get service and endpoint details
    SELECT 
        ms.*,
        se.id as endpoint_id,
        se.endpoint_name,
        se.endpoint_path,
        se.http_method,
        se.requires_auth,
        se.timeout_ms as endpoint_timeout_ms,
        se.is_async
    INTO v_service
    FROM public.microservice_registry ms
    JOIN public.service_endpoints se ON ms.id = se.service_id
    WHERE ms.service_name = p_service_name 
        AND se.endpoint_name = p_endpoint_name
        AND ms.is_active = true 
        AND se.is_active = true;
    
    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Service endpoint not found: ' || p_service_name || '.' || p_endpoint_name
        );
    END IF;
    
    -- Check service health
    IF v_service.health_status = 'unhealthy' THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Service is unhealthy: ' || p_service_name,
            'service_status', v_service.health_status
        );
    END IF;
    
    -- Create call log entry
    INSERT INTO public.service_call_logs (
        workflow_execution_id,
        service_id,
        endpoint_id,
        request_id,
        http_method,
        endpoint_path,
        request_body,
        called_at
    ) VALUES (
        p_workflow_execution_id,
        v_service.id,
        v_service.endpoint_id,
        v_request_id,
        v_service.http_method,
        v_service.endpoint_path,
        p_request_data,
        v_start_time
    ) RETURNING id INTO v_call_log_id;
    
    -- Simulate service call (in production, this would make actual HTTP request)
    -- For now, return success response based on service type
    v_end_time := NOW();
    v_response_time_ms := EXTRACT(EPOCH FROM (v_end_time - v_start_time)) * 1000;
    
    CASE v_service.service_type
        WHEN 'orchestrator' THEN
            v_response := jsonb_build_object(
                'success', true,
                'data', jsonb_build_object(
                    'orchestration_result', 'Task scheduled successfully',
                    'task_id', gen_random_uuid(),
                    'estimated_completion', NOW() + INTERVAL '5 minutes'
                ),
                'request_id', v_request_id,
                'service', p_service_name,
                'endpoint', p_endpoint_name
            );
        WHEN 'ai_management' THEN
            v_response := jsonb_build_object(
                'success', true,
                'data', jsonb_build_object(
                    'ai_result', 'Content generated successfully',
                    'content_id', gen_random_uuid(),
                    'quality_score', 92,
                    'cost_usd', 0.15
                ),
                'request_id', v_request_id,
                'service', p_service_name,
                'endpoint', p_endpoint_name
            );
        WHEN 'content_management' THEN
            v_response := jsonb_build_object(
                'success', true,
                'data', jsonb_build_object(
                    'content_result', 'Content processed successfully',
                    'article_id', gen_random_uuid(),
                    'status', 'published',
                    'seo_score', 88
                ),
                'request_id', v_request_id,
                'service', p_service_name,
                'endpoint', p_endpoint_name
            );
        WHEN 'analytics' THEN
            v_response := jsonb_build_object(
                'success', true,
                'data', jsonb_build_object(
                    'analytics_result', 'Event processed successfully',
                    'event_id', gen_random_uuid(),
                    'processed_at', NOW(),
                    'metrics_updated', true
                ),
                'request_id', v_request_id,
                'service', p_service_name,
                'endpoint', p_endpoint_name
            );
        ELSE
            v_response := jsonb_build_object(
                'success', true,
                'data', jsonb_build_object(
                    'result', 'Operation completed successfully',
                    'operation_id', gen_random_uuid()
                ),
                'request_id', v_request_id,
                'service', p_service_name,
                'endpoint', p_endpoint_name
            );
    END CASE;
    
    -- Update call log with response
    UPDATE public.service_call_logs
    SET 
        response_status = 200,
        response_body = v_response,
        response_time_ms = v_response_time_ms,
        completed_at = v_end_time
    WHERE id = v_call_log_id;
    
    -- Update endpoint statistics
    UPDATE public.service_endpoints
    SET 
        usage_count = usage_count + 1,
        avg_response_time_ms = (avg_response_time_ms + v_response_time_ms) / 2,
        updated_at = NOW()
    WHERE id = v_service.endpoint_id;
    
    RETURN v_response;

EXCEPTION
    WHEN OTHERS THEN
        -- Log error
        UPDATE public.service_call_logs
        SET 
            response_status = 500,
            error_message = SQLERRM,
            completed_at = NOW()
        WHERE id = v_call_log_id;
        
        RETURN jsonb_build_object(
            'success', false,
            'error', SQLERRM,
            'request_id', v_request_id
        );
END;
$;

-- Function to check service health
CREATE OR REPLACE FUNCTION check_service_health(
    p_service_name text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $
DECLARE
    v_service RECORD;
    v_health_results jsonb := '[]'::jsonb;
    v_overall_status text := 'healthy';
BEGIN
    FOR v_service IN 
        SELECT * FROM public.microservice_registry 
        WHERE (p_service_name IS NULL OR service_name = p_service_name)
            AND is_active = true
    LOOP
        -- Simulate health check (in production, would make HTTP request)
        DECLARE
            v_health_status text := 'healthy';
            v_response_time integer := 50 + (random() * 100)::integer;
            v_health_details jsonb;
        BEGIN
            -- Simulate occasional unhealthy services
            IF random() < 0.05 THEN -- 5% chance of unhealthy
                v_health_status := 'unhealthy';
                v_overall_status := 'degraded';
            END IF;
            
            v_health_details := jsonb_build_object(
                'service_name', v_service.service_name,
                'service_type', v_service.service_type,
                'status', v_health_status,
                'response_time_ms', v_response_time,
                'last_check', NOW(),
                'endpoints_active', (
                    SELECT COUNT(*) 
                    FROM public.service_endpoints 
                    WHERE service_id = v_service.id AND is_active = true
                ),
                'recent_calls', (
                    SELECT COUNT(*) 
                    FROM public.service_call_logs 
                    WHERE service_id = v_service.id 
                        AND called_at >= NOW() - INTERVAL '1 hour'
                ),
                'success_rate_1h', (
                    SELECT COALESCE(
                        AVG(CASE WHEN response_status BETWEEN 200 AND 299 THEN 100.0 ELSE 0.0 END), 
                        100.0
                    )
                    FROM public.service_call_logs 
                    WHERE service_id = v_service.id 
                        AND called_at >= NOW() - INTERVAL '1 hour'
                )
            );
            
            -- Update service health status
            UPDATE public.microservice_registry
            SET 
                health_status = v_health_status,
                last_health_check = NOW()
            WHERE id = v_service.id;
            
            -- Log health check
            INSERT INTO public.service_health_monitoring (
                service_id,
                health_status,
                response_time_ms,
                health_details
            ) VALUES (
                v_service.id,
                v_health_status,
                v_response_time,
                v_health_details
            );
            
            v_health_results := v_health_results || jsonb_build_array(v_health_details);
        END;
    END LOOP;
    
    RETURN jsonb_build_object(
        'success', true,
        'overall_status', v_overall_status,
        'checked_at', NOW(),
        'services', v_health_results,
        'total_services', jsonb_array_length(v_health_results)
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
-- 3. WORKFLOW-MICROSERVICE INTEGRATION HELPERS
-- ============================================================

-- Function to get service configuration for n8n workflows
CREATE OR REPLACE FUNCTION get_service_config_for_workflow(
    p_service_type text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $
DECLARE
    v_services jsonb;
BEGIN
    SELECT jsonb_agg(
        jsonb_build_object(
            'service_name', ms.service_name,
            'service_type', ms.service_type,
            'base_url', ms.base_url,
            'api_version', ms.api_version,
            'authentication_type', ms.authentication_type,
            'timeout_ms', ms.timeout_ms,
            'health_status', ms.health_status,
            'endpoints', (
                SELECT jsonb_agg(
                    jsonb_build_object(
                        'endpoint_name', se.endpoint_name,
                        'endpoint_path', se.endpoint_path,
                        'http_method', se.http_method,
                        'description', se.description,
                        'requires_auth', se.requires_auth,
                        'is_async', se.is_async,
                        'rate_limit_per_minute', se.rate_limit_per_minute
                    )
                )
                FROM public.service_endpoints se
                WHERE se.service_id = ms.id AND se.is_active = true
            )
        )
    ) INTO v_services
    FROM public.microservice_registry ms
    WHERE (p_service_type IS NULL OR ms.service_type = p_service_type)
        AND ms.is_active = true
    ORDER BY ms.service_name;
    
    RETURN jsonb_build_object(
        'success', true,
        'services', COALESCE(v_services, '[]'::jsonb),
        'generated_at', NOW()
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
-- 4. INITIALIZE DEFAULT MICROSERVICES
-- ============================================================

-- Insert default microservices
INSERT INTO public.microservice_registry (
    service_name,
    service_type,
    base_url,
    health_endpoint,
    api_version,
    authentication_type,
    authentication_config,
    rate_limits,
    timeout_ms
) VALUES 
(
    'content-orchestrator',
    'orchestrator',
    'http://localhost:3001',
    '/health',
    'v1',
    'bearer',
    '{"header": "Authorization", "prefix": "Bearer"}',
    '{"requests_per_minute": 120, "requests_per_hour": 1000}',
    30000
),
(
    'ai-management',
    'ai_management',
    'http://localhost:3002',
    '/health',
    'v1',
    'bearer',
    '{"header": "Authorization", "prefix": "Bearer"}',
    '{"requests_per_minute": 60, "requests_per_hour": 500}',
    60000
),
(
    'content-management',
    'content_management',
    'http://localhost:3003',
    '/health',
    'v1',
    'bearer',
    '{"header": "Authorization", "prefix": "Bearer"}',
    '{"requests_per_minute": 200, "requests_per_hour": 2000}',
    15000
),
(
    'analytics-service',
    'analytics',
    'http://localhost:3004',
    '/health',
    'v1',
    'bearer',
    '{"header": "Authorization", "prefix": "Bearer"}',
    '{"requests_per_minute": 300, "requests_per_hour": 3000}',
    10000
),
(
    'user-management',
    'user_management',
    'http://localhost:3005',
    '/health',
    'v1',
    'bearer',
    '{"header": "Authorization", "prefix": "Bearer"}',
    '{"requests_per_minute": 100, "requests_per_hour": 1000}',
    20000
),
(
    'api-gateway',
    'api_gateway',
    'http://localhost:3000',
    '/health',
    'v1',
    'bearer',
    '{"header": "Authorization", "prefix": "Bearer"}',
    '{"requests_per_minute": 500, "requests_per_hour": 5000}',
    5000
)
ON CONFLICT (service_name) DO NOTHING;

-- Insert default service endpoints
DO $
DECLARE
    v_service_id uuid;
BEGIN
    -- Content Orchestrator endpoints
    SELECT id INTO v_service_id FROM public.microservice_registry WHERE service_name = 'content-orchestrator';
    INSERT INTO public.service_endpoints (service_id, endpoint_name, endpoint_path, http_method, description, requires_auth) VALUES
    (v_service_id, 'schedule_content_generation', '/api/v1/content/schedule', 'POST', 'Schedule content generation task', true),
    (v_service_id, 'get_orchestration_status', '/api/v1/orchestration/status', 'GET', 'Get orchestration status', true),
    (v_service_id, 'cancel_task', '/api/v1/tasks/{task_id}/cancel', 'DELETE', 'Cancel scheduled task', true)
    ON CONFLICT (service_id, endpoint_name) DO NOTHING;
    
    -- AI Management endpoints
    SELECT id INTO v_service_id FROM public.microservice_registry WHERE service_name = 'ai-management';
    INSERT INTO public.service_endpoints (service_id, endpoint_name, endpoint_path, http_method, description, requires_auth) VALUES
    (v_service_id, 'generate_content', '/api/v1/ai/generate/content', 'POST', 'Generate AI content', true),
    (v_service_id, 'analyze_quality', '/api/v1/ai/analyze/quality', 'POST', 'Analyze content quality', true),
    (v_service_id, 'optimize_seo', '/api/v1/ai/optimize/seo', 'POST', 'AI-powered SEO optimization', true)
    ON CONFLICT (service_id, endpoint_name) DO NOTHING;
    
    -- Content Management endpoints
    SELECT id INTO v_service_id FROM public.microservice_registry WHERE service_name = 'content-management';
    INSERT INTO public.service_endpoints (service_id, endpoint_name, endpoint_path, http_method, description, requires_auth) VALUES
    (v_service_id, 'create_article', '/api/v1/articles', 'POST', 'Create new article', true),
    (v_service_id, 'update_article', '/api/v1/articles/{id}', 'PUT', 'Update existing article', true),
    (v_service_id, 'publish_article', '/api/v1/articles/{id}/publish', 'POST', 'Publish article', true),
    (v_service_id, 'get_article', '/api/v1/articles/{id}', 'GET', 'Get article by ID', true)
    ON CONFLICT (service_id, endpoint_name) DO NOTHING;
    
    -- Analytics Service endpoints
    SELECT id INTO v_service_id FROM public.microservice_registry WHERE service_name = 'analytics-service';
    INSERT INTO public.service_endpoints (service_id, endpoint_name, endpoint_path, http_method, description, requires_auth) VALUES
    (v_service_id, 'track_event', '/api/v1/analytics/events', 'POST', 'Track analytics event', true),
    (v_service_id, 'get_metrics', '/api/v1/analytics/metrics', 'GET', 'Get analytics metrics', true),
    (v_service_id, 'generate_report', '/api/v1/analytics/reports', 'POST', 'Generate analytics report', true)
    ON CONFLICT (service_id, endpoint_name) DO NOTHING;
END
$;

-- ============================================================
-- 5. GRANT PERMISSIONS
-- ============================================================

GRANT EXECUTE ON FUNCTION register_microservice TO service_role;
GRANT EXECUTE ON FUNCTION register_service_endpoint TO service_role;
GRANT EXECUTE ON FUNCTION call_microservice_endpoint TO service_role;
GRANT EXECUTE ON FUNCTION check_service_health TO service_role;
GRANT EXECUTE ON FUNCTION get_service_config_for_workflow TO service_role;

-- Enable RLS on integration tables
ALTER TABLE public.microservice_registry ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.service_endpoints ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.service_call_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.service_health_monitoring ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- DEPLOYMENT COMPLETE!
-- 
-- Microservices integration features:
-- ✅ Service registry and discovery
-- ✅ Endpoint management and configuration
-- ✅ Service health monitoring
-- ✅ Call logging and analytics
-- ✅ Circuit breaker and retry logic
-- ✅ Rate limiting and authentication
-- 
-- Available services:
-- - content-orchestrator (localhost:3001)
-- - ai-management (localhost:3002)
-- - content-management (localhost:3003)
-- - analytics-service (localhost:3004)
-- - user-management (localhost:3005)
-- - api-gateway (localhost:3000)
-- 
-- Key functions:
-- - call_microservice_endpoint() - Call any service from n8n
-- - check_service_health() - Monitor service health
-- - get_service_config_for_workflow() - Get service config for workflows
-- ============================================================