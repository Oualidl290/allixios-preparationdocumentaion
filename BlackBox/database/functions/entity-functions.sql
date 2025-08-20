-- =====================================================
-- ENTITY MANAGEMENT FUNCTIONS
-- Functions for authors, tags, categories, and entity resolution
-- =====================================================

-- Function to resolve or create entities (authors, tags, etc.)
CREATE OR REPLACE FUNCTION resolve_or_create_entity(
  p_entity_type TEXT,
  p_lookup_key TEXT,
  p_entity_data JSONB
) RETURNS UUID
LANGUAGE plpgsql AS $$
DECLARE
  v_entity_id UUID;
  v_cache_hit BOOLEAN := FALSE;
BEGIN
  -- Check cache first
  SELECT resolved_id INTO v_entity_id
  FROM entity_resolution_cache
  WHERE entity_type = p_entity_type
    AND lookup_key = LOWER(p_lookup_key)
    AND (expires_at IS NULL OR expires_at > NOW());
    
  IF v_entity_id IS NOT NULL THEN
    -- Update cache hits
    UPDATE entity_resolution_cache
    SET 
      hit_count = hit_count + 1,
      last_hit_at = NOW()
    WHERE entity_type = p_entity_type
      AND lookup_key = LOWER(p_lookup_key);
        
    RETURN v_entity_id;
  END IF;
    
  -- Entity-specific resolution
  CASE p_entity_type
    WHEN 'author' THEN
      -- Try to find existing author
      SELECT id INTO v_entity_id
      FROM authors
      WHERE LOWER(display_name) = LOWER(p_lookup_key)
      LIMIT 1;
            
      IF v_entity_id IS NULL THEN
        -- Create new author
        INSERT INTO authors (
          display_name,
          slug,
          bio,
          expertise,
          profile_image,
          social_links,
          is_active,
          created_at,
          updated_at
        ) VALUES (
          p_entity_data->>'display_name',
          p_entity_data->>'slug',
          COALESCE(p_entity_data->>'bio', 'Content creator'),
          COALESCE(
            ARRAY(SELECT jsonb_array_elements_text(p_entity_data->'expertise')),
            '{}'::TEXT[]
          ),
          p_entity_data->>'profile_image',
          COALESCE(p_entity_data->'social_links', '{}'::JSONB),
          true,
          NOW(),
          NOW()
        ) RETURNING id INTO v_entity_id;
      END IF;
          
    WHEN 'tag' THEN
      -- Try to find existing tag
      SELECT id INTO v_entity_id
      FROM tags
      WHERE LOWER(name) = LOWER(p_lookup_key)
      LIMIT 1;
            
      IF v_entity_id IS NULL THEN
        -- Create new tag
        INSERT INTO tags (
          name,
          slug,
          category,
          tag_type,
          semantic_weight,
          is_active,
          created_at,
          updated_at
        ) VALUES (
          p_entity_data->>'name',
          p_entity_data->>'slug',
          COALESCE(p_entity_data->>'category', 'content'),
          COALESCE(p_entity_data->>'tag_type', 'content'),
          COALESCE((p_entity_data->>'semantic_weight')::NUMERIC, 1.0),
          true,
          NOW(),
          NOW()
        ) RETURNING id INTO v_entity_id;
      END IF;

    WHEN 'category' THEN
      -- Try to find existing category
      SELECT id INTO v_entity_id
      FROM categories
      WHERE LOWER(name) = LOWER(p_lookup_key)
      LIMIT 1;
            
      IF v_entity_id IS NULL THEN
        -- Create new category
        INSERT INTO categories (
          name,
          slug,
          description,
          niche_id,
          parent_id,
          is_active,
          created_at,
          updated_at
        ) VALUES (
          p_entity_data->>'name',
          p_entity_data->>'slug',
          p_entity_data->>'description',
          (p_entity_data->>'niche_id')::UUID,
          (p_entity_data->>'parent_id')::UUID,
          true,
          NOW(),
          NOW()
        ) RETURNING id INTO v_entity_id;
      END IF;

    WHEN 'niche' THEN
      -- Try to find existing niche
      SELECT id INTO v_entity_id
      FROM niches
      WHERE LOWER(name) = LOWER(p_lookup_key)
      LIMIT 1;
            
      IF v_entity_id IS NULL THEN
        -- Create new niche
        INSERT INTO niches (
          name,
          slug,
          description,
          is_active,
          created_at,
          updated_at
        ) VALUES (
          p_entity_data->>'name',
          p_entity_data->>'slug',
          p_entity_data->>'description',
          true,
          NOW(),
          NOW()
        ) RETURNING id INTO v_entity_id;
      END IF;
          
    ELSE
      RAISE EXCEPTION 'Unknown entity type: %', p_entity_type;
  END CASE;
    
  -- Cache the resolution
  INSERT INTO entity_resolution_cache (
    entity_type,
    lookup_key,
    resolved_id,
    confidence_score,
    expires_at,
    created_at
  ) VALUES (
    p_entity_type,
    LOWER(p_lookup_key),
    v_entity_id,
    1.0,
    NOW() + INTERVAL '24 hours',
    NOW()
  ) ON CONFLICT (entity_type, lookup_key) 
  DO UPDATE SET
    resolved_id = EXCLUDED.resolved_id,
    hit_count = entity_resolution_cache.hit_count + 1,
    last_hit_at = NOW(),
    expires_at = EXCLUDED.expires_at;
    
  RETURN v_entity_id;
END;
$$;

-- Function to batch resolve multiple entities
CREATE OR REPLACE FUNCTION batch_resolve_entities(
  p_entities JSONB
) RETURNS JSONB
LANGUAGE plpgsql AS $$
DECLARE
  v_entity JSONB;
  v_result JSONB := '[]'::JSONB;
  v_entity_id UUID;
BEGIN
  FOR v_entity IN SELECT * FROM jsonb_array_elements(p_entities)
  LOOP
    v_entity_id := resolve_or_create_entity(
      v_entity->>'entity_type',
      v_entity->>'lookup_key',
      v_entity->'entity_data'
    );
    
    v_result := v_result || jsonb_build_object(
      'entity_type', v_entity->>'entity_type',
      'lookup_key', v_entity->>'lookup_key',
      'resolved_id', v_entity_id
    );
  END LOOP;
  
  RETURN v_result;
END;
$$;

-- Function to update author statistics
CREATE OR REPLACE FUNCTION update_author_stats(
  p_author_id UUID
) RETURNS VOID
LANGUAGE plpgsql AS $$
DECLARE
  v_article_count INTEGER;
  v_total_views INTEGER;
  v_avg_rating NUMERIC;
BEGIN
  -- Count articles
  SELECT COUNT(*) INTO v_article_count
  FROM articles
  WHERE author_id = p_author_id AND status = 'published';
  
  -- Calculate total views
  SELECT COALESCE(SUM(view_count), 0) INTO v_total_views
  FROM articles
  WHERE author_id = p_author_id AND status = 'published';
  
  -- Calculate average rating
  SELECT COALESCE(AVG(content_quality_score), 0) INTO v_avg_rating
  FROM articles
  WHERE author_id = p_author_id AND status = 'published';
  
  -- Update author statistics
  UPDATE authors SET
    articles_count = v_article_count,
    total_views = v_total_views,
    average_rating = v_avg_rating,
    updated_at = NOW()
  WHERE id = p_author_id;
END;
$$;

-- Function to clean expired entity cache
CREATE OR REPLACE FUNCTION cleanup_entity_cache(
  p_older_than INTERVAL DEFAULT '7 days'
) RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
  v_deleted_count INTEGER;
BEGIN
  DELETE FROM entity_resolution_cache
  WHERE expires_at < NOW() - p_older_than
    OR (last_hit_at IS NOT NULL AND last_hit_at < NOW() - p_older_than);
  
  GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
  
  RETURN v_deleted_count;
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION resolve_or_create_entity TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION batch_resolve_entities TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION update_author_stats TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION cleanup_entity_cache TO authenticated, service_role;