-- ============================================================================
-- ENTITY MANAGEMENT FUNCTIONS
-- Functions for authors, tags, categories, and entity resolution
-- Based on BlackBox implementation with improvements
-- ============================================================================

-- Function to resolve or create entities (authors, tags, etc.)
CREATE OR REPLACE FUNCTION resolve_or_create_entity(
  p_tenant_id UUID,
  p_entity_type TEXT,
  p_lookup_key TEXT,
  p_entity_data JSONB
) RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER AS $
DECLARE
  v_entity_id UUID;
  v_cache_hit BOOLEAN := FALSE;
  v_slug TEXT;
  v_counter INTEGER := 0;
  v_final_slug TEXT;
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
      WHERE tenant_id = p_tenant_id 
        AND LOWER(display_name) = LOWER(p_lookup_key)
      LIMIT 1;
            
      IF v_entity_id IS NULL THEN
        -- Generate unique slug
        v_slug := lower(regexp_replace(p_entity_data->>'display_name', '[^a-zA-Z0-9]+', '-', 'g'));
        v_final_slug := v_slug;
        
        WHILE EXISTS (SELECT 1 FROM authors WHERE tenant_id = p_tenant_id AND slug = v_final_slug) LOOP
          v_counter := v_counter + 1;
          v_final_slug := v_slug || '-' || v_counter;
        END LOOP;
        
        -- Create new author
        INSERT INTO authors (
          tenant_id,
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
          p_tenant_id,
          p_entity_data->>'display_name',
          v_final_slug,
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
      WHERE tenant_id = p_tenant_id 
        AND LOWER(name) = LOWER(p_lookup_key)
      LIMIT 1;
            
      IF v_entity_id IS NULL THEN
        -- Generate unique slug
        v_slug := lower(regexp_replace(p_entity_data->>'name', '[^a-zA-Z0-9]+', '-', 'g'));
        v_final_slug := v_slug;
        
        WHILE EXISTS (SELECT 1 FROM tags WHERE tenant_id = p_tenant_id AND slug = v_final_slug) LOOP
          v_counter := v_counter + 1;
          v_final_slug := v_slug || '-' || v_counter;
        END LOOP;
        
        -- Create new tag
        INSERT INTO tags (
          tenant_id,
          name,
          slug,
          description,
          category,
          tag_type,
          semantic_weight,
          is_active,
          created_at,
          updated_at
        ) VALUES (
          p_tenant_id,
          p_entity_data->>'name',
          v_final_slug,
          p_entity_data->>'description',
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
      WHERE tenant_id = p_tenant_id 
        AND LOWER(name) = LOWER(p_lookup_key)
        AND niche_id = (p_entity_data->>'niche_id')::UUID
      LIMIT 1;
            
      IF v_entity_id IS NULL THEN
        -- Generate unique slug
        v_slug := lower(regexp_replace(p_entity_data->>'name', '[^a-zA-Z0-9]+', '-', 'g'));
        v_final_slug := v_slug;
        
        WHILE EXISTS (
          SELECT 1 FROM categories 
          WHERE tenant_id = p_tenant_id 
            AND niche_id = (p_entity_data->>'niche_id')::UUID 
            AND slug = v_final_slug
        ) LOOP
          v_counter := v_counter + 1;
          v_final_slug := v_slug || '-' || v_counter;
        END LOOP;
        
        -- Create new category
        INSERT INTO categories (
          tenant_id,
          name,
          slug,
          description,
          niche_id,
          parent_id,
          is_active,
          created_at,
          updated_at
        ) VALUES (
          p_tenant_id,
          p_entity_data->>'name',
          v_final_slug,
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
      WHERE tenant_id = p_tenant_id 
        AND LOWER(name) = LOWER(p_lookup_key)
      LIMIT 1;
            
      IF v_entity_id IS NULL THEN
        -- Generate unique slug
        v_slug := lower(regexp_replace(p_entity_data->>'name', '[^a-zA-Z0-9]+', '-', 'g'));
        v_final_slug := v_slug;
        
        WHILE EXISTS (SELECT 1 FROM niches WHERE tenant_id = p_tenant_id AND slug = v_final_slug) LOOP
          v_counter := v_counter + 1;
          v_final_slug := v_slug || '-' || v_counter;
        END LOOP;
        
        -- Create new niche
        INSERT INTO niches (
          tenant_id,
          name,
          slug,
          description,
          is_active,
          created_at,
          updated_at
        ) VALUES (
          p_tenant_id,
          p_entity_data->>'name',
          v_final_slug,
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
$;

-- Function to batch resolve multiple entities
CREATE OR REPLACE FUNCTION batch_resolve_entities(
  p_tenant_id UUID,
  p_entities JSONB
) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER AS $
DECLARE
  v_entity JSONB;
  v_result JSONB := '[]'::JSONB;
  v_entity_id UUID;
BEGIN
  FOR v_entity IN SELECT * FROM jsonb_array_elements(p_entities)
  LOOP
    v_entity_id := resolve_or_create_entity(
      p_tenant_id,
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
$;

-- Function to update author statistics
CREATE OR REPLACE FUNCTION update_author_stats(
  p_author_id UUID
) RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER AS $
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
$;

-- Function to get entity suggestions based on partial match
CREATE OR REPLACE FUNCTION get_entity_suggestions(
  p_tenant_id UUID,
  p_entity_type TEXT,
  p_query TEXT,
  p_limit INTEGER DEFAULT 10
) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER AS $
DECLARE
  v_suggestions JSONB;
BEGIN
  CASE p_entity_type
    WHEN 'author' THEN
      SELECT jsonb_agg(
        jsonb_build_object(
          'id', id,
          'display_name', display_name,
          'slug', slug,
          'articles_count', articles_count,
          'total_views', total_views
        )
      ) INTO v_suggestions
      FROM authors
      WHERE tenant_id = p_tenant_id
        AND is_active = true
        AND (
          display_name ILIKE '%' || p_query || '%'
          OR slug ILIKE '%' || p_query || '%'
        )
      ORDER BY 
        CASE WHEN display_name ILIKE p_query || '%' THEN 1 ELSE 2 END,
        articles_count DESC,
        display_name
      LIMIT p_limit;
      
    WHEN 'tag' THEN
      SELECT jsonb_agg(
        jsonb_build_object(
          'id', id,
          'name', name,
          'slug', slug,
          'category', category,
          'usage_count', usage_count
        )
      ) INTO v_suggestions
      FROM tags
      WHERE tenant_id = p_tenant_id
        AND is_active = true
        AND (
          name ILIKE '%' || p_query || '%'
          OR slug ILIKE '%' || p_query || '%'
        )
      ORDER BY 
        CASE WHEN name ILIKE p_query || '%' THEN 1 ELSE 2 END,
        usage_count DESC,
        name
      LIMIT p_limit;
      
    WHEN 'category' THEN
      SELECT jsonb_agg(
        jsonb_build_object(
          'id', c.id,
          'name', c.name,
          'slug', c.slug,
          'niche_name', n.name,
          'niche_id', c.niche_id
        )
      ) INTO v_suggestions
      FROM categories c
      LEFT JOIN niches n ON c.niche_id = n.id
      WHERE c.tenant_id = p_tenant_id
        AND c.is_active = true
        AND (
          c.name ILIKE '%' || p_query || '%'
          OR c.slug ILIKE '%' || p_query || '%'
        )
      ORDER BY 
        CASE WHEN c.name ILIKE p_query || '%' THEN 1 ELSE 2 END,
        c.name
      LIMIT p_limit;
      
    WHEN 'niche' THEN
      SELECT jsonb_agg(
        jsonb_build_object(
          'id', id,
          'name', name,
          'slug', slug,
          'description', description
        )
      ) INTO v_suggestions
      FROM niches
      WHERE tenant_id = p_tenant_id
        AND is_active = true
        AND (
          name ILIKE '%' || p_query || '%'
          OR slug ILIKE '%' || p_query || '%'
        )
      ORDER BY 
        CASE WHEN name ILIKE p_query || '%' THEN 1 ELSE 2 END,
        name
      LIMIT p_limit;
      
    ELSE
      v_suggestions := '[]'::JSONB;
  END CASE;
  
  RETURN COALESCE(v_suggestions, '[]'::JSONB);
END;
$;

-- Function to merge duplicate entities
CREATE OR REPLACE FUNCTION merge_entities(
  p_entity_type TEXT,
  p_primary_id UUID,
  p_duplicate_ids UUID[]
) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER AS $
DECLARE
  v_duplicate_id UUID;
  v_merged_count INTEGER := 0;
  v_result JSONB;
BEGIN
  -- Process each duplicate entity
  FOREACH v_duplicate_id IN ARRAY p_duplicate_ids
  LOOP
    CASE p_entity_type
      WHEN 'author' THEN
        -- Update articles to use primary author
        UPDATE articles 
        SET author_id = p_primary_id, updated_at = NOW()
        WHERE author_id = v_duplicate_id;
        
        -- Merge statistics
        UPDATE authors 
        SET 
          articles_count = articles_count + (
            SELECT articles_count FROM authors WHERE id = v_duplicate_id
          ),
          total_views = total_views + (
            SELECT total_views FROM authors WHERE id = v_duplicate_id
          ),
          updated_at = NOW()
        WHERE id = p_primary_id;
        
        -- Delete duplicate
        DELETE FROM authors WHERE id = v_duplicate_id;
        
      WHEN 'tag' THEN
        -- Update article_tags to use primary tag
        UPDATE article_tags 
        SET tag_id = p_primary_id
        WHERE tag_id = v_duplicate_id
        ON CONFLICT (article_id, tag_id) DO NOTHING;
        
        -- Delete conflicting relationships
        DELETE FROM article_tags WHERE tag_id = v_duplicate_id;
        
        -- Merge usage count
        UPDATE tags 
        SET 
          usage_count = usage_count + (
            SELECT usage_count FROM tags WHERE id = v_duplicate_id
          ),
          updated_at = NOW()
        WHERE id = p_primary_id;
        
        -- Delete duplicate
        DELETE FROM tags WHERE id = v_duplicate_id;
        
      WHEN 'category' THEN
        -- Update articles to use primary category
        UPDATE articles 
        SET category_id = p_primary_id, updated_at = NOW()
        WHERE category_id = v_duplicate_id;
        
        -- Update child categories
        UPDATE categories 
        SET parent_id = p_primary_id, updated_at = NOW()
        WHERE parent_id = v_duplicate_id;
        
        -- Delete duplicate
        DELETE FROM categories WHERE id = v_duplicate_id;
        
      WHEN 'niche' THEN
        -- Update articles to use primary niche
        UPDATE articles 
        SET niche_id = p_primary_id, updated_at = NOW()
        WHERE niche_id = v_duplicate_id;
        
        -- Update categories to use primary niche
        UPDATE categories 
        SET niche_id = p_primary_id, updated_at = NOW()
        WHERE niche_id = v_duplicate_id;
        
        -- Delete duplicate
        DELETE FROM niches WHERE id = v_duplicate_id;
        
      ELSE
        RAISE EXCEPTION 'Unknown entity type for merge: %', p_entity_type;
    END CASE;
    
    v_merged_count := v_merged_count + 1;
  END LOOP;
  
  -- Clear entity resolution cache for affected entities
  DELETE FROM entity_resolution_cache 
  WHERE entity_type = p_entity_type 
    AND resolved_id = ANY(p_duplicate_ids);
  
  v_result := jsonb_build_object(
    'entity_type', p_entity_type,
    'primary_id', p_primary_id,
    'merged_count', v_merged_count,
    'merged_at', NOW()
  );
  
  RETURN v_result;
END;
$;

-- Function to clean expired entity cache
CREATE OR REPLACE FUNCTION cleanup_entity_cache(
  p_older_than INTERVAL DEFAULT '7 days'
) RETURNS INTEGER
LANGUAGE plpgsql SECURITY DEFINER AS $
DECLARE
  v_deleted_count INTEGER;
BEGIN
  DELETE FROM entity_resolution_cache
  WHERE expires_at < NOW() - p_older_than
    OR (last_hit_at IS NOT NULL AND last_hit_at < NOW() - p_older_than);
  
  GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
  
  RETURN v_deleted_count;
END;
$;

-- Function to get entity hierarchy (for categories)
CREATE OR REPLACE FUNCTION get_category_hierarchy(
  p_tenant_id UUID,
  p_niche_id UUID DEFAULT NULL
) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER AS $
DECLARE
  v_hierarchy JSONB;
BEGIN
  WITH RECURSIVE category_tree AS (
    -- Base case: root categories
    SELECT 
      c.id,
      c.name,
      c.slug,
      c.parent_id,
      c.niche_id,
      n.name as niche_name,
      0 as level,
      ARRAY[c.id] as path
    FROM categories c
    LEFT JOIN niches n ON c.niche_id = n.id
    WHERE c.tenant_id = p_tenant_id
      AND c.parent_id IS NULL
      AND c.is_active = true
      AND (p_niche_id IS NULL OR c.niche_id = p_niche_id)
    
    UNION ALL
    
    -- Recursive case: child categories
    SELECT 
      c.id,
      c.name,
      c.slug,
      c.parent_id,
      c.niche_id,
      ct.niche_name,
      ct.level + 1,
      ct.path || c.id
    FROM categories c
    JOIN category_tree ct ON c.parent_id = ct.id
    WHERE c.tenant_id = p_tenant_id
      AND c.is_active = true
      AND NOT c.id = ANY(ct.path) -- Prevent cycles
  )
  SELECT jsonb_agg(
    jsonb_build_object(
      'id', id,
      'name', name,
      'slug', slug,
      'parent_id', parent_id,
      'niche_id', niche_id,
      'niche_name', niche_name,
      'level', level,
      'path', path
    ) ORDER BY level, name
  ) INTO v_hierarchy
  FROM category_tree;
  
  RETURN COALESCE(v_hierarchy, '[]'::JSONB);
END;
$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION resolve_or_create_entity TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION batch_resolve_entities TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION update_author_stats TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION get_entity_suggestions TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION merge_entities TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION cleanup_entity_cache TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION get_category_hierarchy TO authenticated, service_role;