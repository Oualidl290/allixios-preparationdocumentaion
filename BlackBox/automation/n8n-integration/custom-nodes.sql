-- ============================================================
-- CUSTOM N8N NODES FOR ALLIXIOS OPERATIONS
-- Specialized nodes for content management, AI operations, and analytics
-- ============================================================

-- ============================================================
-- 1. CUSTOM NODE DEFINITIONS
-- ============================================================

-- Insert custom n8n nodes
INSERT INTO public.custom_n8n_nodes (
    name,
    display_name,
    description,
    category,
    node_type,
    node_code,
    node_schema,
    version,
    is_active,
    created_by
) VALUES 

-- Allixios Content Generator Node
(
    'allixios-content-generator',
    'Allixios Content Generator',
    'Generate high-quality AI content with Allixios optimization',
    'Allixios',
    'regular',
    'See automation/n8n-integration/custom-nodes/AllixiosContentGenerator.node.ts',
    '{
        "displayName": "Allixios Content Generator",
        "name": "allixiosContentGenerator",
        "icon": "file:allixios.svg",
        "group": ["transform"],
        "version": 1,
        "description": "Generate optimized content using Allixios AI engine",
        "properties": [
            {
                "displayName": "Topic",
                "name": "topic",
                "type": "string",
                "required": true
            },
            {
                "displayName": "Niche ID",
                "name": "nicheId", 
                "type": "string",
                "required": true
            },
            {
                "displayName": "Word Count",
                "name": "wordCount",
                "type": "number",
                "default": 2000
            }
        ]
    }',
    '1.0.0',
    true,
    NULL
),

-- Allixios SEO Analyzer Node
(
    'allixios-seo-analyzer',
    'Allixios SEO Analyzer',
    'Comprehensive SEO analysis with Allixios optimization engine',
    'Allixios',
    'regular',
    'See automation/n8n-integration/custom-nodes/AllixiosSeoAnalyzer.node.ts',
    '{
        "displayName": "Allixios SEO Analyzer",
        "name": "allixiosSeoAnalyzer",
        "properties": [
            {
                "displayName": "Article ID",
                "name": "articleId",
                "type": "string",
                "required": true
            },
            {
                "displayName": "Analysis Type",
                "name": "analysisType",
                "type": "options",
                "options": [
                    { "name": "Full Analysis", "value": "full" },
                    { "name": "Quick Check", "value": "quick" }
                ]
            }
        ]
    }',
    '1.0.0',
    true,
    NULL
),

-- Allixios Analytics Processor Node
(
    'allixios-analytics-processor',
    'Allixios Analytics Processor',
    'Process and analyze user events with Allixios analytics engine',
    'Allixios',
    'regular',
    'See automation/n8n-integration/custom-nodes/AllixiosAnalyticsProcessor.node.ts',
    '{
        "displayName": "Allixios Analytics Processor",
        "name": "allixiosAnalyticsProcessor",
        "properties": [
            {
                "displayName": "Event Type",
                "name": "eventType",
                "type": "options",
                "required": true,
                "options": [
                    { "name": "Page View", "value": "page_view" },
                    { "name": "Article Read", "value": "article_read" }
                ]
            },
            {
                "displayName": "User ID",
                "name": "userId",
                "type": "string",
                "required": true
            }
        ]
    }',
    '1.0.0',
    true,
    NULL
),

-- Allixios Workflow Monitor Node
(
    'allixios-workflow-monitor',
    'Allixios Workflow Monitor',
    'Monitor and optimize workflow performance with Allixios intelligence',
    'Allixios',
    'regular',
    'See automation/n8n-integration/custom-nodes/AllixiosWorkflowMonitor.node.ts',
    '{
        "displayName": "Allixios Workflow Monitor",
        "name": "allixiosWorkflowMonitor",
        "properties": [
            {
                "displayName": "Workflow Instance ID",
                "name": "workflowInstanceId",
                "type": "string",
                "required": true
            },
            {
                "displayName": "Analysis Period (Hours)",
                "name": "analysisPeriodHours",
                "type": "number",
                "default": 24
            }
        ]
    }',
    '1.0.0',
    true,
    NULL
)
ON CONFLICT (name) DO NOTHING;

-- ============================================================
-- 2. CUSTOM NODE MANAGEMENT FUNCTIONS
-- ============================================================

-- Function to get custom nodes by category
CREATE OR REPLACE FUNCTION get_custom_nodes_by_category(
    p_category text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $
DECLARE
    v_nodes jsonb;
BEGIN
    SELECT jsonb_agg(
        jsonb_build_object(
            'id', id,
            'name', name,
            'display_name', display_name,
            'description', description,
            'category', category,
            'node_type', node_type,
            'version', version,
            'usage_count', usage_count,
            'is_active', is_active,
            'created_at', created_at
        )
    ) INTO v_nodes
    FROM public.custom_n8n_nodes
    WHERE is_active = true
        AND (p_category IS NULL OR category = p_category)
    ORDER BY usage_count DESC, display_name;
    
    RETURN jsonb_build_object(
        'success', true,
        'nodes', COALESCE(v_nodes, '[]'::jsonb),
        'total_count', (
            SELECT COUNT(*)
            FROM public.custom_n8n_nodes
            WHERE is_active = true
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

-- Function to increment node usage
CREATE OR REPLACE FUNCTION increment_node_usage(
    p_node_name text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $
BEGIN
    UPDATE public.custom_n8n_nodes
    SET usage_count = usage_count + 1,
        updated_at = NOW()
    WHERE name = p_node_name AND is_active = true;
    
    IF FOUND THEN
        RETURN jsonb_build_object(
            'success', true,
            'node_name', p_node_name,
            'usage_incremented', true
        );
    ELSE
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Node not found or inactive: ' || p_node_name
        );
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', SQLERRM
        );
END;
$;

-- Function to get node installation code
CREATE OR REPLACE FUNCTION get_node_installation_code(
    p_node_name text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $
DECLARE
    v_node RECORD;
BEGIN
    SELECT * INTO v_node
    FROM public.custom_n8n_nodes
    WHERE name = p_node_name AND is_active = true;
    
    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Node not found: ' || p_node_name
        );
    END IF;
    
    RETURN jsonb_build_object(
        'success', true,
        'node_name', v_node.name,
        'display_name', v_node.display_name,
        'node_code', v_node.node_code,
        'node_schema', v_node.node_schema,
        'version', v_node.version,
        'installation_instructions', jsonb_build_object(
            'step1', 'Copy the node code to your n8n custom nodes directory',
            'step2', 'Restart your n8n instance',
            'step3', 'The node will appear in the Allixios category',
            'directory', '~/.n8n/custom/',
            'filename', v_node.name || '.node.ts'
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

GRANT EXECUTE ON FUNCTION get_custom_nodes_by_category TO service_role;
GRANT EXECUTE ON FUNCTION increment_node_usage TO service_role;
GRANT EXECUTE ON FUNCTION get_node_installation_code TO service_role;

-- ============================================================
-- DEPLOYMENT COMPLETE!
-- 
-- Available custom n8n nodes:
-- 1. allixios-content-generator - AI content generation
-- 2. allixios-seo-analyzer - SEO analysis and optimization
-- 3. allixios-analytics-processor - Analytics event processing
-- 4. allixios-workflow-monitor - Workflow performance monitoring
-- 
-- Get nodes by category:
-- SELECT get_custom_nodes_by_category('Allixios');
-- 
-- Get installation code:
-- SELECT get_node_installation_code('allixios-content-generator');
-- ============================================================