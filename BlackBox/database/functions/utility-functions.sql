-- =====================================================
-- UTILITY FUNCTIONS
-- General purpose functions for locks, validation, and system operations
-- =====================================================

-- Function to release processing locks
DROP FUNCTION IF EXISTS release_processing_lock(TEXT, UUID);
CREATE OR REPLACE FUNCTION release_processing_lock(
  p_resource_type TEXT,
  p_resource_id UUID
) RETURNS BOOLEAN
LANGUAGE plpgsql AS $$
DECLARE
  v_updated BOOLEAN := FALSE;
BEGIN
  UPDATE processing_locks
  SET 
    released_at = NOW(),
    updated_at = NOW()
  WHERE resource_type = p_resource_type
    AND resource_id = p_resource_id
    AND released_at IS NULL;
  
  -- Use FOUND variable directly, not GET DIAGNOSTICS
  v_updated := FOUND;
  
  IF p_resource_type = 'topic' AND v_updated THEN
    UPDATE topics_queue
    SET 
      locked_by = NULL,
      locked_at = NULL,
      updated_at = NOW()
    WHERE id = p_resource_id
      AND status = 'processing';
  END IF;
  
  RETURN v_updated;
END;
$$;

-- Function to cleanup expired locks
DROP FUNCTION IF EXISTS cleanup_expired_locks(INTERVAL);
CREATE OR REPLACE FUNCTION cleanup_expired_locks(
  p_older_than INTERVAL DEFAULT '1 hour'
) RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
  v_cleaned_count INTEGER;
BEGIN
  -- Release expired locks
  UPDATE processing_locks
  SET 
    released_at = NOW(),
    updated_at = NOW()
  WHERE expires_at < NOW() - p_older_than
    AND released_at IS NULL;
  
  GET DIAGNOSTICS v_cleaned_count = ROW_COUNT;
  
  -- Reset topic statuses for expired locks
  UPDATE topics_queue
  SET 
    status = 'queued',
    locked_by = NULL,
    locked_at = NULL,
    retry_count = retry_count + 1,
    next_retry_at = NOW() + INTERVAL '5 minutes',
    updated_at = NOW()
  WHERE status = 'processing'
    AND locked_at < NOW() - p_older_than;
  
  RETURN v_cleaned_count;
END;
$$;

-- Function to generate unique slug
DROP FUNCTION IF EXISTS generate_unique_slug(TEXT, TEXT, UUID);
CREATE OR REPLACE FUNCTION generate_unique_slug(
  p_base_text TEXT,
  p_table_name TEXT,
  p_exclude_id UUID DEFAULT NULL
) RETURNS TEXT
LANGUAGE plpgsql AS $$
DECLARE
  v_base_slug TEXT;
  v_final_slug TEXT;
  v_counter INTEGER := 0;
  v_exists BOOLEAN;
BEGIN
  -- Create base slug
  v_base_slug := lower(trim(regexp_replace(p_base_text, '[^a-zA-Z0-9\s-]', '', 'g')));
  v_base_slug := regexp_replace(v_base_slug, '\s+', '-', 'g');
  v_base_slug := regexp_replace(v_base_slug, '-+', '-', 'g');
  v_base_slug := trim(v_base_slug, '-');
  v_base_slug := substring(v_base_slug, 1, 50);
  
  v_final_slug := v_base_slug;
  
  -- Check for uniqueness
  LOOP
    EXECUTE format('SELECT EXISTS(SELECT 1 FROM %I WHERE slug = $1 AND ($2 IS NULL OR id != $2))', 
                   p_table_name) 
    INTO v_exists 
    USING v_final_slug, p_exclude_id;
    
    IF NOT v_exists THEN
      EXIT;
    END IF;
    
    v_counter := v_counter + 1;
    v_final_slug := v_base_slug || '-' || v_counter;
  END LOOP;
  
  RETURN v_final_slug;
END;
$$;

-- Function to validate JSON schema
DROP FUNCTION IF EXISTS validate_json_schema(JSONB, TEXT[], TEXT[]);
CREATE OR REPLACE FUNCTION validate_json_schema(
  p_json_data JSONB,
  p_required_fields TEXT[],
  p_optional_fields TEXT[] DEFAULT '{}'
) RETURNS JSONB
LANGUAGE plpgsql AS $$
DECLARE
  v_field TEXT;
  v_errors TEXT[] := '{}';
  v_warnings TEXT[] := '{}';
BEGIN
  -- Check required fields
  FOREACH v_field IN ARRAY p_required_fields
  LOOP
    IF NOT (p_json_data ? v_field) OR (p_json_data->>v_field IS NULL) THEN
      v_errors := array_append(v_errors, format('Missing required field: %s', v_field));
    END IF;
  END LOOP;
  
  -- Check for unexpected fields
  FOR v_field IN SELECT jsonb_object_keys(p_json_data)
  LOOP
    IF NOT (v_field = ANY(p_required_fields || p_optional_fields)) THEN
      v_warnings := array_append(v_warnings, format('Unexpected field: %s', v_field));
    END IF;
  END LOOP;
  
  RETURN jsonb_build_object(
    'valid', array_length(v_errors, 1) IS NULL,
    'errors', v_errors,
    'warnings', v_warnings
  );
END;
$$;

-- Function to calculate content quality score
DROP FUNCTION IF EXISTS calculate_content_quality_score(UUID);
CREATE OR REPLACE FUNCTION calculate_content_quality_score(
  p_article_id UUID
) RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
  v_article RECORD;
  v_score INTEGER := 0;
  v_word_count INTEGER;
  v_has_images BOOLEAN;
  v_has_links BOOLEAN;
  v_readability_score NUMERIC;
BEGIN
  -- Get article data
  SELECT * INTO v_article
  FROM articles
  WHERE id = p_article_id;
  
  IF NOT FOUND THEN
    RETURN 0;
  END IF;
  
  -- Base score for having content
  v_score := 20;
  
  -- Word count scoring (0-25 points)
  v_word_count := v_article.word_count;
  CASE
    WHEN v_word_count >= 1500 THEN v_score := v_score + 25;
    WHEN v_word_count >= 1000 THEN v_score := v_score + 20;
    WHEN v_word_count >= 500 THEN v_score := v_score + 15;
    WHEN v_word_count >= 300 THEN v_score := v_score + 10;
    ELSE v_score := v_score + 5;
  END CASE;
  
  -- Meta data completeness (0-20 points)
  IF v_article.meta_title IS NOT NULL AND length(v_article.meta_title) > 10 THEN
    v_score := v_score + 10;
  END IF;
  
  IF v_article.meta_description IS NOT NULL AND length(v_article.meta_description) > 50 THEN
    v_score := v_score + 10;
  END IF;
  
  -- Content structure (0-15 points)
  IF v_article.content ~ '<h[1-6]>' OR v_article.content ~ '#{1,6}\s' THEN
    v_score := v_score + 10; -- Has headings
  END IF;
  
  IF length(v_article.excerpt) > 100 THEN
    v_score := v_score + 5; -- Good excerpt
  END IF;
  
  -- SEO elements (0-10 points)
  IF array_length(v_article.meta_keywords, 1) > 0 THEN
    v_score := v_score + 5;
  END IF;
  
  IF array_length(v_article.key_topics, 1) > 0 THEN
    v_score := v_score + 5;
  END IF;
  
  -- Engagement potential (0-10 points)
  IF v_article.is_featured THEN
    v_score := v_score + 5;
  END IF;
  
  IF v_article.is_evergreen THEN
    v_score := v_score + 5;
  END IF;
  
  -- Cap at 100
  v_score := LEAST(v_score, 100);
  
  -- Update the article
  UPDATE articles 
  SET content_quality_score = v_score, updated_at = NOW()
  WHERE id = p_article_id;
  
  RETURN v_score;
END;
$$;

-- Function to log system events
DROP FUNCTION IF EXISTS log_system_event(TEXT, JSONB, UUID, TEXT);
CREATE OR REPLACE FUNCTION log_system_event(
  p_event_type TEXT,
  p_event_data JSONB,
  p_user_id UUID DEFAULT NULL,
  p_severity TEXT DEFAULT 'info'
) RETURNS UUID
LANGUAGE plpgsql AS $$
DECLARE
  v_log_id UUID;
BEGIN
  INSERT INTO system_logs (
    event_type,
    event_data,
    user_id,
    severity,
    created_at
  ) VALUES (
    p_event_type,
    p_event_data,
    p_user_id,
    p_severity,
    NOW()
  ) RETURNING id INTO v_log_id;
  
  RETURN v_log_id;
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION release_processing_lock TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION cleanup_expired_locks TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION generate_unique_slug TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION validate_json_schema TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION calculate_content_quality_score TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION log_system_event TO authenticated, service_role;