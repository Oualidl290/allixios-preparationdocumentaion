-- ============================================================================
-- WORKFLOW & AUTOMATION FUNCTIONS
-- Functions for n8n workflow management and orchestration
-- Based on BlackBox implementation with improvements
-- ============================================================================

-- Function to create content topic in queue
CREATE OR REPLACE FUNCTION create_content_topic(
  p_tenant_id UUID,
  p_topic_data JSONB
) RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER AS $
DECLARE
  v_topic_id UUID;
  v_niche_id UUID;
  v_category_id UUID;
  v_author_id UUID;
BEGIN
  -- Resolve entities if needed
  IF p_topic_data ? 'niche_name' AND NOT (p_topic_data ? 'niche_id') THEN
    v_niche_id := resolve_or_create_entity(
      p_tenant_id,
      'niche',
      p_topic_data->>'niche_name',
      jsonb_build_object('name', p_topic_data->>'niche_name')
    );
  ELSE
    v_niche_id := (p_topic_data->>'niche_id')::UUID;
  END IF;
  
  IF p_topic_data ? 'category_name' AND NOT (p_topic_data ? 'category_id') THEN
    v_category_id := resolve_or_create_entity(
      p_tenant_id,
      'category',
      p_topic_data->>'category_name',
      jsonb_build_object(
        'name', p_topic_data->>'category_name',
        'niche_id', v_niche_id
      )
    );
  ELSE
    v_category_id := (p_topic_data->>'category_id')::UUID;
  END IF;
  
  IF p_topic_data ? 'author_name' AND NOT (p_topic_data ? 'suggested_author_id') THEN
    v_author_id := resolve_or_create_entity(
      p_tenant_id,
      'author',
      p_topic_data->>'author_name',
      jsonb_build_object('display_name', p_topic_data->>'author_name')
    );
  ELSE
    v_author_id := (p_topic_data->>'suggested_author_id')::UUID;
  END IF;
  
  -- Insert topic into queue
  INSERT INTO topics_queue (
    tenant_id,
    topic,
    description,
    target_keywords,
    niche_id,
    category_id,
    suggested_author_id,
    difficulty,
    estimated_word_count,
    priority,
    ai_prompt,
    metadata,
    status,
    created_at,
    updated_at
  ) VALUES (
    p_tenant_id,
    p_topic_data->>'topic',
    p_topic_data->>'description',
    COALESCE(
      (SELECT array_agg(value::text) FROM jsonb_array_elements_text(p_topic_data->'target_keywords')),
      ARRAY[]::TEXT[]
    ),
    v_niche_id,
    v_category_id,
    v_author_id,
    COALESCE((p_topic_data->>'difficulty')::difficulty_level, 'intermediate'),
    COALESCE((p_topic_data->>'estimated_word_count')::INTEGER, 1000),
    COALESCE((p_topic_data->>'priority')::priority_level, 'medium'),
    p_topic_data->>'ai_prompt',
    COALESCE(p_topic_data->'metadata', '{}'::JSONB),
    'queued'::workflow_status,
    NOW(),
    NOW()
  ) RETURNING id INTO v_topic_id;
  
  RETURN v_topic_id;
END;
$;

-- Function to get workflow execution status
CREATE OR REPLACE FUNCTION get_workflow_status(
  p_tenant_id UUID DEFAULT NULL,
  p_workflow_name TEXT DEFAULT NULL,
  p_limit INTEGER DEFAULT 50
) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER AS $
DECLARE
  v_executions JSONB;
  v_summary JSONB;
BEGIN
  -- Get recent executions
  SELECT jsonb_agg(
    jsonb_build_object(
      'id', ws.id,
      'workflow_name', ws.workflow_name,
      'execution_id', ws.execution_id,
      'status', ws.status,
      'started_at', ws.started_at,
      'completed_at', ws.completed_at,
      'execution_time_ms', ws.execution_time_ms,
      'input_data', ws.input_data,
      'output_data', ws.output_data,
      'error_data', ws.error_data
    ) ORDER BY ws.started_at DESC
  ) INTO v_executions
  FROM workflow_states ws
  WHERE (p_workflow_name IS NULL OR ws.workflow_name = p_workflow_name)
  ORDER BY ws.started_at DESC
  LIMIT p_limit;
  
  -- Get summary statistics
  SELECT jsonb_build_object(
    'total_executions', COUNT(*),
    'successful_executions', COUNT(*) FILTER (WHERE status = 'completed'),
    'failed_executions', COUNT(*) FILTER (WHERE status = 'failed'),
    'running_executions', COUNT(*) FILTER (WHERE status = 'processing'),
    'avg_execution_time_ms', AVG(execution_time_ms) FILTER (WHERE execution_time_ms IS NOT NULL),
    'success_rate', CASE 
      WHEN COUNT(*) > 0 THEN 
        (COUNT(*) FILTER (WHERE status = 'completed')::NUMERIC / COUNT(*)) * 100
      ELSE 0 
    END
  ) INTO v_summary
  FROM workflow_states ws
  WHERE (p_workflow_name IS NULL OR ws.workflow_name = p_workflow_name)
    AND ws.started_at >= NOW() - INTERVAL '24 hours';
  
  RETURN jsonb_build_object(
    'executions', COALESCE(v_executions, '[]'::JSONB),
    'summary', COALESCE(v_summary, '{}'::JSONB),
    'generated_at', NOW()
  );
END;
$;

-- Function to track n8n execution
CREATE OR REPLACE FUNCTION track_n8n_execution(
  p_workflow_id TEXT,
  p_execution_id TEXT,
  p_status TEXT,
  p_mode TEXT DEFAULT 'trigger',
  p_started_at TIMESTAMPTZ DEFAULT NOW(),
  p_finished_at TIMESTAMPTZ DEFAULT NULL,
  p_execution_time INTEGER DEFAULT NULL,
  p_data JSONB DEFAULT '{}'
) RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER AS $
DECLARE
  v_execution_uuid UUID;
BEGIN
  INSERT INTO n8n_executions (
    workflow_id,
    execution_id,
    status,
    mode,
    started_at,
    finished_at,
    execution_time,
    data,
    created_at
  ) VALUES (
    p_workflow_id,
    p_execution_id,
    p_status,
    p_mode,
    p_started_at,
    p_finished_at,
    p_execution_time,
    p_data,
    NOW()
  ) ON CONFLICT (execution_id)
  DO UPDATE SET
    status = EXCLUDED.status,
    finished_at = EXCLUDED.finished_at,
    execution_time = EXCLUDED.execution_time,
    data = EXCLUDED.data
  RETURNING id INTO v_execution_uuid;
  
  RETURN v_execution_uuid;
END;
$;

-- Function to track n8n node execution
CREATE OR REPLACE FUNCTION track_n8n_node_execution(
  p_execution_id TEXT,
  p_node_name TEXT,
  p_node_type TEXT,
  p_status TEXT,
  p_execution_time INTEGER DEFAULT NULL,
  p_input_data JSONB DEFAULT '{}',
  p_output_data JSONB DEFAULT '{}',
  p_error_data JSONB DEFAULT '{}'
) RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER AS $
DECLARE
  v_node_uuid UUID;
BEGIN
  INSERT INTO n8n_execution_nodes (
    execution_id,
    node_name,
    node_type,
    status,
    execution_time,
    input_data,
    output_data,
    error_data,
    created_at
  ) VALUES (
    p_execution_id,
    p_node_name,
    p_node_type,
    p_status,
    p_execution_time,
    p_input_data,
    p_output_data,
    p_error_data,
    NOW()
  ) RETURNING id INTO v_node_uuid;
  
  -- Update performance profile
  INSERT INTO n8n_performance_profiles (
    workflow_id,
    node_name,
    avg_execution_time,
    min_execution_time,
    max_execution_time,
    success_rate,
    error_count,
    total_executions,
    last_updated,
    created_at
  ) 
  SELECT 
    ne.workflow_id,
    p_node_name,
    AVG(nen.execution_time),
    MIN(nen.execution_time),
    MAX(nen.execution_time),
    (COUNT(*) FILTER (WHERE nen.status = 'success')::NUMERIC / COUNT(*)) * 100,
    COUNT(*) FILTER (WHERE nen.status = 'error'),
    COUNT(*),
    NOW(),
    NOW()
  FROM n8n_execution_nodes nen
  JOIN n8n_executions ne ON nen.execution_id = ne.execution_id
  WHERE nen.node_name = p_node_name
    AND nen.execution_time IS NOT NULL
  GROUP BY ne.workflow_id
  ON CONFLICT (workflow_id, node_name)
  DO UPDATE SET
    avg_execution_time = EXCLUDED.avg_execution_time,
    min_execution_time = EXCLUDED.min_execution_time,
    max_execution_time = EXCLUDED.max_execution_time,
    success_rate = EXCLUDED.success_rate,
    error_count = EXCLUDED.error_count,
    total_executions = EXCLUDED.total_executions,
    last_updated = NOW();
  
  RETURN v_node_uuid;
END;
$;

-- Function to get workflow performance analytics
CREATE OR REPLACE FUNCTION get_workflow_performance(
  p_workflow_id TEXT DEFAULT NULL,
  p_hours_back INTEGER DEFAULT 24
) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER AS $
DECLARE
  v_performance JSONB;
  v_node_performance JSONB;
  v_execution_trends JSONB;
BEGIN
  -- Get overall workflow performance
  SELECT jsonb_build_object(
    'total_executions', COUNT(*),
    'successful_executions', COUNT(*) FILTER (WHERE status = 'success'),
    'failed_executions', COUNT(*) FILTER (WHERE status = 'error'),
    'running_executions', COUNT(*) FILTER (WHERE status = 'running'),
    'avg_execution_time', AVG(execution_time) FILTER (WHERE execution_time IS NOT NULL),
    'min_execution_time', MIN(execution_time) FILTER (WHERE execution_time IS NOT NULL),
    'max_execution_time', MAX(execution_time) FILTER (WHERE execution_time IS NOT NULL),
    'success_rate', CASE 
      WHEN COUNT(*) > 0 THEN 
        (COUNT(*) FILTER (WHERE status = 'success')::NUMERIC / COUNT(*)) * 100
      ELSE 0 
    END,
    'executions_per_hour', COUNT(*)::NUMERIC / p_hours_back
  ) INTO v_performance
  FROM n8n_executions
  WHERE (p_workflow_id IS NULL OR workflow_id = p_workflow_id)
    AND started_at >= NOW() - INTERVAL '1 hour' * p_hours_back;
  
  -- Get node-level performance
  SELECT jsonb_agg(
    jsonb_build_object(
      'node_name', npp.node_name,
      'avg_execution_time', npp.avg_execution_time,
      'min_execution_time', npp.min_execution_time,
      'max_execution_time', npp.max_execution_time,
      'success_rate', npp.success_rate,
      'error_count', npp.error_count,
      'total_executions', npp.total_executions,
      'last_updated', npp.last_updated
    ) ORDER BY npp.avg_execution_time DESC
  ) INTO v_node_performance
  FROM n8n_performance_profiles npp
  WHERE (p_workflow_id IS NULL OR npp.workflow_id = p_workflow_id)
    AND npp.last_updated >= NOW() - INTERVAL '1 hour' * p_hours_back;
  
  -- Get execution trends (hourly breakdown)
  SELECT jsonb_agg(
    jsonb_build_object(
      'hour', hour_bucket,
      'executions', execution_count,
      'success_count', success_count,
      'error_count', error_count,
      'avg_execution_time', avg_execution_time
    ) ORDER BY hour_bucket
  ) INTO v_execution_trends
  FROM (
    SELECT 
      date_trunc('hour', started_at) as hour_bucket,
      COUNT(*) as execution_count,
      COUNT(*) FILTER (WHERE status = 'success') as success_count,
      COUNT(*) FILTER (WHERE status = 'error') as error_count,
      AVG(execution_time) FILTER (WHERE execution_time IS NOT NULL) as avg_execution_time
    FROM n8n_executions
    WHERE (p_workflow_id IS NULL OR workflow_id = p_workflow_id)
      AND started_at >= NOW() - INTERVAL '1 hour' * p_hours_back
    GROUP BY date_trunc('hour', started_at)
  ) trends;
  
  RETURN jsonb_build_object(
    'workflow_performance', COALESCE(v_performance, '{}'::JSONB),
    'node_performance', COALESCE(v_node_performance, '[]'::JSONB),
    'execution_trends', COALESCE(v_execution_trends, '[]'::JSONB),
    'analysis_period_hours', p_hours_back,
    'generated_at', NOW()
  );
END;
$;

-- Function to manage workflow state
CREATE OR REPLACE FUNCTION update_workflow_state(
  p_workflow_name TEXT,
  p_execution_id TEXT,
  p_status workflow_status,
  p_input_data JSONB DEFAULT '{}',
  p_output_data JSONB DEFAULT '{}',
  p_error_data JSONB DEFAULT '{}'
) RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER AS $
DECLARE
  v_state_id UUID;
  v_execution_time_ms INTEGER;
BEGIN
  -- Calculate execution time if completing
  IF p_status IN ('completed', 'failed') THEN
    SELECT EXTRACT(EPOCH FROM (NOW() - started_at)) * 1000
    INTO v_execution_time_ms
    FROM workflow_states
    WHERE workflow_name = p_workflow_name AND execution_id = p_execution_id;
  END IF;
  
  INSERT INTO workflow_states (
    workflow_name,
    execution_id,
    status,
    input_data,
    output_data,
    error_data,
    started_at,
    completed_at,
    execution_time_ms,
    created_at,
    updated_at
  ) VALUES (
    p_workflow_name,
    p_execution_id,
    p_status,
    p_input_data,
    p_output_data,
    p_error_data,
    CASE WHEN p_status = 'processing' THEN NOW() ELSE NULL END,
    CASE WHEN p_status IN ('completed', 'failed') THEN NOW() ELSE NULL END,
    v_execution_time_ms,
    NOW(),
    NOW()
  ) ON CONFLICT (workflow_name, execution_id)
  DO UPDATE SET
    status = EXCLUDED.status,
    output_data = EXCLUDED.output_data,
    error_data = EXCLUDED.error_data,
    completed_at = EXCLUDED.completed_at,
    execution_time_ms = EXCLUDED.execution_time_ms,
    updated_at = NOW()
  RETURNING id INTO v_state_id;
  
  RETURN v_state_id;
END;
$;

-- Function to get queue statistics
CREATE OR REPLACE FUNCTION get_queue_statistics(
  p_tenant_id UUID
) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER AS $
DECLARE
  v_stats JSONB;
BEGIN
  SELECT jsonb_build_object(
    'total_topics', COUNT(*),
    'queued_topics', COUNT(*) FILTER (WHERE status = 'queued'),
    'processing_topics', COUNT(*) FILTER (WHERE status = 'processing'),
    'completed_topics', COUNT(*) FILTER (WHERE status = 'completed'),
    'failed_topics', COUNT(*) FILTER (WHERE status = 'failed'),
    'avg_processing_time_ms', AVG(execution_time_ms) FILTER (WHERE execution_time_ms IS NOT NULL),
    'topics_by_priority', jsonb_build_object(
      'urgent', COUNT(*) FILTER (WHERE priority = 'urgent'),
      'high', COUNT(*) FILTER (WHERE priority = 'high'),
      'medium', COUNT(*) FILTER (WHERE priority = 'medium'),
      'low', COUNT(*) FILTER (WHERE priority = 'low')
    ),
    'topics_by_difficulty', jsonb_build_object(
      'beginner', COUNT(*) FILTER (WHERE difficulty = 'beginner'),
      'intermediate', COUNT(*) FILTER (WHERE difficulty = 'intermediate'),
      'advanced', COUNT(*) FILTER (WHERE difficulty = 'advanced'),
      'expert', COUNT(*) FILTER (WHERE difficulty = 'expert')
    ),
    'retry_statistics', jsonb_build_object(
      'no_retries', COUNT(*) FILTER (WHERE retry_count = 0),
      'one_retry', COUNT(*) FILTER (WHERE retry_count = 1),
      'two_retries', COUNT(*) FILTER (WHERE retry_count = 2),
      'max_retries', COUNT(*) FILTER (WHERE retry_count >= 3)
    ),
    'oldest_queued_topic', MIN(created_at) FILTER (WHERE status = 'queued'),
    'newest_topic', MAX(created_at),
    'success_rate', CASE 
      WHEN COUNT(*) FILTER (WHERE status IN ('completed', 'failed')) > 0 THEN
        (COUNT(*) FILTER (WHERE status = 'completed')::NUMERIC / 
         COUNT(*) FILTER (WHERE status IN ('completed', 'failed'))) * 100
      ELSE 0 
    END
  ) INTO v_stats
  FROM topics_queue
  WHERE tenant_id = p_tenant_id
    AND created_at >= NOW() - INTERVAL '7 days';
  
  RETURN v_stats;
END;
$;

-- Function to cleanup old workflow data
CREATE OR REPLACE FUNCTION cleanup_workflow_data(
  p_days_to_keep INTEGER DEFAULT 30
) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER AS $
DECLARE
  v_deleted_executions INTEGER;
  v_deleted_nodes INTEGER;
  v_deleted_states INTEGER;
  v_cutoff_date TIMESTAMPTZ;
BEGIN
  v_cutoff_date := NOW() - INTERVAL '1 day' * p_days_to_keep;
  
  -- Delete old execution nodes
  DELETE FROM n8n_execution_nodes 
  WHERE created_at < v_cutoff_date;
  GET DIAGNOSTICS v_deleted_nodes = ROW_COUNT;
  
  -- Delete old executions
  DELETE FROM n8n_executions 
  WHERE created_at < v_cutoff_date;
  GET DIAGNOSTICS v_deleted_executions = ROW_COUNT;
  
  -- Delete old workflow states
  DELETE FROM workflow_states 
  WHERE created_at < v_cutoff_date;
  GET DIAGNOSTICS v_deleted_states = ROW_COUNT;
  
  -- Delete completed topics older than cutoff
  DELETE FROM topics_queue 
  WHERE status = 'completed' 
    AND processed_at < v_cutoff_date;
  
  RETURN jsonb_build_object(
    'deleted_executions', v_deleted_executions,
    'deleted_nodes', v_deleted_nodes,
    'deleted_states', v_deleted_states,
    'cutoff_date', v_cutoff_date,
    'cleanup_completed_at', NOW()
  );
END;
$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION create_content_topic TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION get_workflow_status TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION track_n8n_execution TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION track_n8n_node_execution TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION get_workflow_performance TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION update_workflow_state TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION get_queue_statistics TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION cleanup_workflow_data TO authenticated, service_role;