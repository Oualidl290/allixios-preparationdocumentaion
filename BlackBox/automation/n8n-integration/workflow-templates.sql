-- ============================================================
-- N8N WORKFLOW TEMPLATES FOR COMMON OPERATIONS
-- Pre-built templates for content operations, SEO, analytics
-- ============================================================

-- ============================================================
-- 1. WORKFLOW TEMPLATE DEFINITIONS
-- ============================================================

-- Insert common workflow templates
INSERT INTO public.workflow_templates (
    tenant_id,
    name,
    description,
    category,
    template_data,
    version,
    is_public,
    created_by
) VALUES 
-- Content Pipeline Template
(
    NULL, -- Public template
    'AI Content Generation Pipeline',
    'Complete AI-powered content generation with quality scoring and SEO optimization',
    'content',
    'See automation/n8n-integration/workflows/ai-content-generation.json',
    '1.0.0',
    true,
    NULL
),

-- SEO Analysis Template
(
    NULL,
    'SEO Analysis and Optimization',
    'Comprehensive SEO analysis with optimization recommendations',
    'seo',
    'See automation/n8n-integration/workflows/seo-analysis.json',
    '1.0.0',
    true,
    NULL
),

-- Analytics Processing Template
(
    NULL,
    'Real-time Analytics Processing',
    'Process user events and generate analytics insights',
    'analytics',
    'See automation/n8n-integration/workflows/analytics-processing.json',
    '1.0.0',
    true,
    NULL
)
ON CONFLICT (tenant_id, name, version) DO NOTHING;

-- ============================================================
-- 2. TEMPLATE DEPLOYMENT FUNCTIONS
-- ============================================================

-- Function to deploy template by name
CREATE OR REPLACE FUNCTION deploy_template_by_name(
    p_template_name text,
    p_instance_name text,
    p_tenant_id uuid DEFAULT NULL,
    p_environment text DEFAULT 'production',
    p_configuration jsonb DEFAULT '{}',
    p_deployed_by uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $
DECLARE
    v_template_id uuid;
    v_result jsonb;
BEGIN
    -- Find template by name
    SELECT id INTO v_template_id
    FROM public.workflow_templates
    WHERE name = p_template_name
        AND (tenant_id = p_tenant_id OR is_public = true)
        AND is_active = true
    ORDER BY CASE WHEN tenant_id = p_tenant_id THEN 0 ELSE 1 END
    LIMIT 1;
    
    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Template not found: ' || p_template_name
        );
    END IF;
    
    -- Deploy template
    SELECT deploy_workflow_from_template(
        v_template_id,
        p_instance_name,
        p_environment,
        p_configuration,
        p_deployed_by
    ) INTO v_result;
    
    RETURN v_result;

EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', SQLERRM
        );
END;
$;

-- Function to get available templates
CREATE OR REPLACE FUNCTION get_available_templates(
    p_tenant_id uuid DEFAULT NULL,
    p_category text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $
DECLARE
    v_templates jsonb;
BEGIN
    SELECT jsonb_agg(
        jsonb_build_object(
            'id', id,
            'name', name,
            'description', description,
            'category', category,
            'version', version,
            'is_public', is_public,
            'usage_count', usage_count,
            'success_rate', success_rate,
            'avg_execution_time_ms', avg_execution_time_ms,
            'created_at', created_at
        )
    ) INTO v_templates
    FROM public.workflow_templates
    WHERE (tenant_id = p_tenant_id OR is_public = true)
        AND is_active = true
        AND (p_category IS NULL OR category = p_category)
    ORDER BY usage_count DESC, name;
    
    RETURN jsonb_build_object(
        'success', true,
        'templates', COALESCE(v_templates, '[]'::jsonb),
        'total_count', (
            SELECT COUNT(*)
            FROM public.workflow_templates
            WHERE (tenant_id = p_tenant_id OR is_public = true)
                AND is_active = true
                AND (p_category IS NULL OR category = p_category)
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
-- 3. GRANT PERMISSIONS
-- ============================================================

GRANT EXECUTE ON FUNCTION deploy_template_by_name TO service_role;
GRANT EXECUTE ON FUNCTION get_available_templates TO service_role;

-- ============================================================
-- DEPLOYMENT COMPLETE!
-- 
-- Available workflow templates:
-- 1. "AI Content Generation Pipeline" - Complete content creation
-- 2. "SEO Analysis and Optimization" - Automated SEO analysis
-- 3. "Real-time Analytics Processing" - Event processing
-- 
-- Deploy templates with:
-- SELECT deploy_template_by_name('AI Content Generation Pipeline', 'my-content-pipeline');
-- 
-- List available templates:
-- SELECT get_available_templates();
-- ============================================================