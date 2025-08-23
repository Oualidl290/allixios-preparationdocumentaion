-- ============================================================================
-- CONTENT MANAGEMENT FUNCTIONS
-- Database functions for content lifecycle management
-- Based on BlackBox implementation with improvements
-- ============================================================================

-- Function to fetch content batch for processing
CREATE OR REPLACE FUNCTION fetch_content_batch(
  p_tenant_id UUID DEFAULT NULL,
  p_batch_size INTEGER DEFAULT 5,
  p_priority_filter TEXT[] DEFAULT NULL,
  p_niche_filters UUID[] DEFAULT NULL,
  p_category_filters UUID[] DEFAULT NULL,
  p_exclude_processing BOOLEAN DEFAULT true,
  p_worker_id TEXT DEFAULT NULL
) RETURNS TABLE (
  id UUID,
  topic TEXT,
  description TEXT,
  target_keywords TEXT[],
  niche_id UUID,
  niche_name TEXT,
  category_id UUID,
  category_name TEXT,
  suggested_author_id UUID,
  author_name TEXT,
  difficulty TEXT,
  estimated_word_count INTEGER,
  estimated_reading_time INTEGER,
  priority TEXT,
  ai_prompt TEXT,
  metadata JSONB,
  created_at TIMESTAMPTZ,
  retry_count INTEGER,
  hours_waiting NUMERIC
) LANGUAGE plpgsql SECURITY DEFINER AS $
DECLARE
  v_worker_id TEXT := COALESCE(p_worker_id, 'worker-' || gen_random_uuid()::text);
  v_lock_duration INTERVAL := '30 minutes';
BEGIN
  -- Lock and return topics atomically
  RETURN QUERY
  WITH locked_topics AS (
    UPDATE topics_queue tq
    SET 
      status = 'processing'::workflow_status,
      locked_by = v_worker_id::uuid,
      locked_at = NOW(),
      processing_started_at = NOW(),
      updated_at = NOW()
    WHERE tq.id IN (
      SELECT t.id
      FROM topics_queue t
      LEFT JOIN niches n ON t.niche_id = n.id
      LEFT JOIN categories c ON t.category_id = c.id
      LEFT JOIN authors a ON t.suggested_author_id = a.id
      WHERE t.status = 'queued'::workflow_status
        AND (p_tenant_id IS NULL OR t.tenant_id = p_tenant_id)
        AND (NOT p_exclude_processing OR t.processing_started_at IS NULL OR t.processing_started_at < NOW() - v_lock_duration)
        AND t.retry_count < 3
        AND (p_priority_filter IS NULL OR t.priority::text = ANY(p_priority_filter))
        AND (p_niche_filters IS NULL OR t.niche_id = ANY(p_niche_filters))
        AND (p_category_filters IS NULL OR t.category_id = ANY(p_category_filters))
      ORDER BY 
        CASE t.priority
          WHEN 'urgent' THEN 0 
          WHEN 'high' THEN 1 
          WHEN 'medium' THEN 2 
          WHEN 'low' THEN 3 
        END ASC,
        t.created_at ASC
      LIMIT p_batch_size
      FOR UPDATE SKIP LOCKED
    )
    RETURNING tq.*
  )
  SELECT 
    lt.id,
    lt.topic,
    lt.description,
    lt.target_keywords,
    lt.niche_id,
    COALESCE(n.name, 'General') as niche_name,
    lt.category_id,
    COALESCE(c.name, 'Uncategorized') as category_name,
    lt.suggested_author_id,
    COALESCE(a.display_name, 'AI Assistant') as author_name,
    lt.difficulty::text,
    lt.estimated_word_count,
    CEIL(lt.estimated_word_count::NUMERIC / 200) as estimated_reading_time,
    lt.priority::text,
    lt.ai_prompt,
    lt.metadata,
    lt.created_at,
    lt.retry_count,
    EXTRACT(EPOCH FROM (NOW() - lt.created_at)) / 3600 as hours_waiting
  FROM locked_topics lt
  LEFT JOIN niches n ON lt.niche_id = n.id
  LEFT JOIN categories c ON lt.category_id = c.id
  LEFT JOIN authors a ON lt.suggested_author_id = a.id;
END;
$;

-- Function to upsert authors in batch
CREATE OR REPLACE FUNCTION upsert_authors_batch(
  p_tenant_id UUID,
  p_authors JSONB
) RETURNS TABLE (
  id UUID,
  display_name TEXT,
  email TEXT,
  action_taken TEXT,
  user_id UUID
) LANGUAGE plpgsql SECURITY DEFINER AS $
DECLARE
  v_author JSONB;
  v_author_id UUID;
  v_user_id UUID;
  v_existing_author authors%ROWTYPE;
  v_action TEXT;
BEGIN
  -- Process each author in the batch
  FOR v_author IN SELECT * FROM jsonb_array_elements(p_authors)
  LOOP
    v_action := 'created';
    v_user_id := NULL;
    
    -- Check if author exists by email or display_name
    SELECT * INTO v_existing_author
    FROM authors a
    WHERE a.tenant_id = p_tenant_id
      AND ((v_author->>'email' IS NOT NULL AND a.email = v_author->>'email')
           OR (a.display_name = v_author->>'display_name'))
    LIMIT 1;
    
    IF FOUND THEN
      -- Update existing author
      v_author_id := v_existing_author.id;
      v_user_id := v_existing_author.user_id;
      v_action := 'updated';
      
      UPDATE authors 
      SET 
        bio = COALESCE(v_author->>'bio', bio),
        expertise = COALESCE(
          (SELECT array_agg(value::text) FROM jsonb_array_elements_text(v_author->'expertise')), 
          expertise
        ),
        social_links = COALESCE(v_author->'social_links', social_links),
        updated_at = NOW()
      WHERE id = v_author_id;
    ELSE
      -- Create new author
      -- First try to find or create user account
      IF v_author->>'email' IS NOT NULL THEN
        SELECT id INTO v_user_id 
        FROM users 
        WHERE tenant_id = p_tenant_id AND email = v_author->>'email';
        
        IF NOT FOUND THEN
          INSERT INTO users (tenant_id, email, full_name, created_at, updated_at)
          VALUES (
            p_tenant_id,
            v_author->>'email',
            v_author->>'display_name',
            NOW(),
            NOW()
          )
          RETURNING id INTO v_user_id;
        END IF;
      END IF;
      
      -- Generate slug
      DECLARE
        v_slug TEXT := lower(regexp_replace(v_author->>'display_name', '[^a-zA-Z0-9]+', '-', 'g'));
        v_counter INTEGER := 0;
        v_final_slug TEXT;
      BEGIN
        v_final_slug := v_slug;
        
        -- Ensure unique slug
        WHILE EXISTS (SELECT 1 FROM authors WHERE tenant_id = p_tenant_id AND slug = v_final_slug) LOOP
          v_counter := v_counter + 1;
          v_final_slug := v_slug || '-' || v_counter;
        END LOOP;
        
        -- Create author record
        INSERT INTO authors (
          tenant_id,
          user_id,
          display_name,
          slug,
          bio,
          email,
          expertise,
          social_links,
          is_active,
          created_at,
          updated_at
        ) VALUES (
          p_tenant_id,
          v_user_id,
          v_author->>'display_name',
          v_final_slug,
          v_author->>'bio',
          v_author->>'email',
          (SELECT array_agg(value::text) FROM jsonb_array_elements_text(v_author->'expertise')),
          v_author->'social_links',
          true,
          NOW(),
          NOW()
        )
        RETURNING id INTO v_author_id;
      END;
    END IF;
    
    -- Return result for this author
    RETURN QUERY SELECT 
      v_author_id,
      v_author->>'display_name',
      v_author->>'email',
      v_action,
      v_user_id;
  END LOOP;
END;
$;

-- Function to upsert tags in batch
CREATE OR REPLACE FUNCTION upsert_tags_batch(
  p_tenant_id UUID,
  p_tags JSONB
) RETURNS TABLE (
  id UUID,
  name TEXT,
  slug TEXT,
  action_taken TEXT,
  usage_count INTEGER
) LANGUAGE plpgsql SECURITY DEFINER AS $
DECLARE
  v_tag JSONB;
  v_tag_id UUID;
  v_tag_name TEXT;
  v_slug TEXT;
  v_existing_tag tags%ROWTYPE;
  v_action TEXT;
  v_counter INTEGER;
  v_final_slug TEXT;
BEGIN
  -- Process each tag in the batch
  FOR v_tag IN SELECT * FROM jsonb_array_elements(p_tags)
  LOOP
    v_tag_name := v_tag->>'name';
    v_slug := lower(regexp_replace(v_tag_name, '[^a-zA-Z0-9]+', '-', 'g'));
    v_action := 'created';
    v_counter := 0;
    v_final_slug := v_slug;
    
    -- Check if tag exists by name (case insensitive)
    SELECT * INTO v_existing_tag
    FROM tags t
    WHERE t.tenant_id = p_tenant_id AND LOWER(t.name) = LOWER(v_tag_name)
    LIMIT 1;
    
    IF FOUND THEN
      -- Update existing tag
      v_tag_id := v_existing_tag.id;
      v_action := 'updated';
      
      UPDATE tags 
      SET 
        description = COALESCE(v_tag->>'description', description),
        category = COALESCE(v_tag->>'category', category),
        semantic_weight = COALESCE((v_tag->>'semantic_weight')::NUMERIC, semantic_weight),
        updated_at = NOW()
      WHERE id = v_tag_id;
    ELSE
      -- Ensure unique slug
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
        semantic_weight,
        is_active,
        usage_count,
        created_at,
        updated_at
      ) VALUES (
        p_tenant_id,
        v_tag_name,
        v_final_slug,
        v_tag->>'description',
        COALESCE(v_tag->>'category', 'content'),
        COALESCE((v_tag->>'semantic_weight')::NUMERIC, 1.0),
        true,
        0,
        NOW(),
        NOW()
      )
      RETURNING id INTO v_tag_id;
    END IF;
    
    -- Return result for this tag
    SELECT usage_count INTO v_existing_tag.usage_count FROM tags WHERE id = v_tag_id;
    
    RETURN QUERY SELECT 
      v_tag_id,
      v_tag_name,
      v_final_slug,
      v_action,
      COALESCE(v_existing_tag.usage_count, 0);
  END LOOP;
END;
$;

-- Function to insert complete article with all relationships
CREATE OR REPLACE FUNCTION insert_article_complete(
  p_tenant_id UUID,
  p_article JSONB
) RETURNS TABLE (
  id UUID,
  title TEXT,
  slug TEXT,
  status TEXT,
  content_quality_score NUMERIC,
  seo_score NUMERIC,
  published_at TIMESTAMPTZ
) LANGUAGE plpgsql SECURITY DEFINER AS $
DECLARE
  v_article_id UUID;
  v_slug TEXT;
  v_tag_id UUID;
  v_media_id UUID;
  v_quality_score NUMERIC;
  v_seo_score NUMERIC;
  v_published_at TIMESTAMPTZ;
  v_status article_status;
  v_counter INTEGER := 0;
  v_final_slug TEXT;
BEGIN
  -- Generate unique slug
  v_slug := lower(regexp_replace(p_article->>'title', '[^a-zA-Z0-9\s-]', '', 'g'));
  v_slug := regexp_replace(v_slug, '\s+', '-', 'g');
  v_slug := regexp_replace(v_slug, '-+', '-', 'g');
  v_slug := trim(v_slug, '-');
  v_slug := substring(v_slug, 1, 50);
  v_final_slug := v_slug;
  
  -- Ensure unique slug
  WHILE EXISTS (SELECT 1 FROM articles WHERE tenant_id = p_tenant_id AND slug = v_final_slug) LOOP
    v_counter := v_counter + 1;
    v_final_slug := v_slug || '-' || v_counter;
  END LOOP;
  
  -- Calculate quality and SEO scores
  v_quality_score := COALESCE((p_article->>'overall_score')::NUMERIC, 75);
  v_seo_score := COALESCE((p_article->'quality_metrics'->>'seo_score')::NUMERIC, 70);
  
  -- Determine if should be published
  v_published_at := CASE 
    WHEN v_quality_score >= 75 THEN NOW()
    ELSE NULL
  END;
  
  v_status := CASE WHEN v_published_at IS NOT NULL THEN 'published' ELSE 'draft' END;
  
  -- Insert main article
  INSERT INTO articles (
    tenant_id,
    title,
    slug,
    content,
    excerpt,
    meta_title,
    meta_description,
    featured_image_url,
    word_count,
    reading_time,
    content_quality_score,
    seo_score,
    status,
    niche_id,
    category_id,
    author_id,
    ai_generated,
    published_at,
    created_at,
    updated_at
  ) VALUES (
    p_tenant_id,
    p_article->>'title',
    v_final_slug,
    p_article->>'content',
    p_article->>'excerpt',
    p_article->>'meta_title',
    p_article->>'meta_description',
    p_article->>'featured_image_url',
    COALESCE((p_article->>'word_count')::INTEGER, 0),
    COALESCE((p_article->>'reading_time')::INTEGER, 5),
    v_quality_score,
    v_seo_score,
    v_status,
    (p_article->>'niche_id')::UUID,
    (p_article->>'category_id')::UUID,
    (p_article->>'author_id')::UUID,
    COALESCE((p_article->>'ai_generated')::BOOLEAN, true),
    v_published_at,
    NOW(),
    NOW()
  )
  RETURNING id INTO v_article_id;
  
  -- Handle tags if provided
  IF p_article ? 'tag_ids' AND jsonb_array_length(p_article->'tag_ids') > 0 THEN
    FOR v_tag_id IN 
      SELECT (value::text)::UUID 
      FROM jsonb_array_elements_text(p_article->'tag_ids')
    LOOP
      INSERT INTO article_tags (article_id, tag_id, relevance_score, created_at)
      VALUES (v_article_id, v_tag_id, 1.0, NOW())
      ON CONFLICT (article_id, tag_id) DO NOTHING;
      
      -- Update tag usage count
      UPDATE tags 
      SET usage_count = usage_count + 1, updated_at = NOW()
      WHERE id = v_tag_id;
    END LOOP;
  END IF;
  
  -- Handle media if provided
  IF p_article ? 'media_data' AND jsonb_array_length(p_article->'media_data') > 0 THEN
    DECLARE
      v_media_item JSONB;
      v_position INTEGER := 1;
    BEGIN
      FOR v_media_item IN 
        SELECT * FROM jsonb_array_elements(p_article->'media_data')
      LOOP
        -- Attach media with detailed configuration
        PERFORM attach_media_to_article(
          v_article_id,
          (v_media_item->>'media_id')::UUID,
          COALESCE(v_media_item->>'usage_type', 'content'),
          COALESCE((v_media_item->>'position')::INTEGER, v_position),
          v_media_item->>'section',
          COALESCE(v_media_item->>'alignment', 'center'),
          COALESCE(v_media_item->>'size', 'medium'),
          v_media_item->>'caption_override',
          v_media_item->>'alt_text_override'
        );
        
        v_position := v_position + 1;
      END LOOP;
    END;
  END IF;
  
  -- Handle legacy media_ids format for backward compatibility
  IF p_article ? 'media_ids' AND jsonb_array_length(p_article->'media_ids') > 0 THEN
    DECLARE
      v_legacy_position INTEGER := 1;
    BEGIN
      FOR v_media_id IN 
        SELECT (value::text)::UUID 
        FROM jsonb_array_elements_text(p_article->'media_ids')
      LOOP
        PERFORM attach_media_to_article(
          v_article_id,
          v_media_id,
          'content',
          v_legacy_position
        );
        
        v_legacy_position := v_legacy_position + 1;
      END LOOP;
    END;
  END IF;
  
  -- Initialize SEO metrics
  INSERT INTO seo_metrics (
    article_id,
    target_keywords,
    current_rankings,
    seo_score,
    last_updated,
    created_at
  ) VALUES (
    v_article_id,
    COALESCE(
      (SELECT array_agg(value::text) FROM jsonb_array_elements_text(p_article->'key_topics')),
      ARRAY[]::TEXT[]
    ),
    '{}'::JSONB,
    v_seo_score::INTEGER,
    NOW(),
    NOW()
  );
  
  -- Initialize revenue metrics
  INSERT INTO revenue_metrics (
    article_id,
    total_revenue,
    affiliate_revenue,
    conversion_rate,
    created_at,
    updated_at
  ) VALUES (
    v_article_id,
    0.00,
    0.00,
    0.00,
    NOW(),
    NOW()
  );
  
  -- Return article details
  RETURN QUERY SELECT 
    v_article_id,
    p_article->>'title',
    v_final_slug,
    v_status::text,
    v_quality_score,
    v_seo_score,
    v_published_at;
END;
$;

-- Function to update topic status
CREATE OR REPLACE FUNCTION update_topic_status(
  p_topic_id UUID,
  p_status TEXT,
  p_error_message TEXT DEFAULT NULL,
  p_article_id UUID DEFAULT NULL,
  p_execution_time_ms INTEGER DEFAULT NULL
) RETURNS TABLE (
  id UUID,
  status TEXT,
  updated_at TIMESTAMPTZ,
  retry_count INTEGER
) LANGUAGE plpgsql SECURITY DEFINER AS $
DECLARE
  v_retry_count INTEGER;
BEGIN
  -- Handle different status updates
  CASE p_status
    WHEN 'completed' THEN
      UPDATE topics_queue 
      SET 
        status = 'completed'::workflow_status,
        generated_article_id = p_article_id,
        processed_at = NOW(),
        execution_time_ms = p_execution_time_ms,
        locked_by = NULL,
        locked_at = NULL,
        processing_started_at = NULL,
        updated_at = NOW()
      WHERE id = p_topic_id
      RETURNING retry_count INTO v_retry_count;
      
    WHEN 'failed' THEN
      UPDATE topics_queue 
      SET 
        status = 'failed'::workflow_status,
        error_message = p_error_message,
        last_error_at = NOW(),
        retry_count = retry_count + 1,
        next_retry_at = CASE 
          WHEN retry_count < 2 THEN NOW() + INTERVAL '5 minutes'
          ELSE NOW() + INTERVAL '1 hour'
        END,
        locked_by = NULL,
        locked_at = NULL,
        processing_started_at = NULL,
        updated_at = NOW()
      WHERE id = p_topic_id
      RETURNING retry_count INTO v_retry_count;
      
    WHEN 'queued' THEN
      UPDATE topics_queue 
      SET 
        status = 'queued'::workflow_status,
        locked_by = NULL,
        locked_at = NULL,
        processing_started_at = NULL,
        updated_at = NOW()
      WHERE id = p_topic_id
      RETURNING retry_count INTO v_retry_count;
      
    ELSE
      UPDATE topics_queue 
      SET 
        status = p_status::workflow_status,
        updated_at = NOW()
      WHERE id = p_topic_id
      RETURNING retry_count INTO v_retry_count;
  END CASE;
  
  -- Return updated topic info
  RETURN QUERY 
  SELECT 
    tq.id,
    tq.status::text,
    tq.updated_at,
    tq.retry_count
  FROM topics_queue tq
  WHERE tq.id = p_topic_id;
END;
$;

-- Function to generate media batch (placeholder for AI image generation)
CREATE OR REPLACE FUNCTION generate_media_batch(
  p_tenant_id UUID,
  p_media_requests JSONB,
  p_topic_context TEXT DEFAULT NULL
) RETURNS TABLE (
  id UUID,
  url TEXT,
  alt_text TEXT,
  media_type TEXT,
  status TEXT
) LANGUAGE plpgsql SECURITY DEFINER AS $
DECLARE
  v_media_request JSONB;
  v_media_id UUID;
BEGIN
  -- Process each media request
  FOR v_media_request IN SELECT * FROM jsonb_array_elements(p_media_requests)
  LOOP
    -- Create placeholder media record (actual generation would be handled externally)
    INSERT INTO media (
      tenant_id,
      filename,
      original_filename,
      mime_type,
      file_size,
      alt_text,
      caption,
      metadata,
      storage_path,
      cdn_url,
      is_active,
      created_at,
      updated_at
    ) VALUES (
      p_tenant_id,
      'placeholder-' || gen_random_uuid()::text || '.jpg',
      v_media_request->>'prompt',
      'image/jpeg',
      0,
      COALESCE(v_media_request->>'alt_text', p_topic_context),
      v_media_request->>'prompt',
      jsonb_build_object(
        'type', v_media_request->>'type',
        'prompt', v_media_request->>'prompt',
        'generated', true,
        'status', 'pending'
      ),
      '/media/generated/',
      'https://placeholder.example.com/image.jpg',
      true,
      NOW(),
      NOW()
    )
    RETURNING id INTO v_media_id;
    
    -- Return media info
    RETURN QUERY SELECT 
      v_media_id,
      'https://placeholder.example.com/image.jpg'::TEXT,
      COALESCE(v_media_request->>'alt_text', p_topic_context)::TEXT,
      COALESCE(v_media_request->>'type', 'featured_image')::TEXT,
      'pending'::TEXT;
  END LOOP;
END;
$;

-- Function to get article with full details
CREATE OR REPLACE FUNCTION get_article_details(
  p_article_id UUID,
  p_tenant_id UUID DEFAULT NULL
) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER AS $
DECLARE
  v_result JSONB;
BEGIN
  SELECT jsonb_build_object(
    'id', a.id,
    'title', a.title,
    'slug', a.slug,
    'excerpt', a.excerpt,
    'content', a.content,
    'meta_title', a.meta_title,
    'meta_description', a.meta_description,
    'featured_image_url', a.featured_image_url,
    'language', a.language,
    'status', a.status,
    'word_count', a.word_count,
    'reading_time', a.reading_time,
    'content_quality_score', a.content_quality_score,
    'seo_score', a.seo_score,
    'engagement_score', a.engagement_score,
    'view_count', a.view_count,
    'social_shares', a.social_shares,
    'ai_generated', a.ai_generated,
    'published_at', a.published_at,
    'created_at', a.created_at,
    'updated_at', a.updated_at,
    'niche', jsonb_build_object(
      'id', n.id,
      'name', n.name,
      'slug', n.slug
    ),
    'category', jsonb_build_object(
      'id', c.id,
      'name', c.name,
      'slug', c.slug
    ),
    'author', jsonb_build_object(
      'id', au.id,
      'display_name', au.display_name,
      'slug', au.slug,
      'bio', au.bio
    ),
    'tags', COALESCE(
      (SELECT jsonb_agg(
        jsonb_build_object(
          'id', t.id,
          'name', t.name,
          'slug', t.slug,
          'relevance_score', at.relevance_score
        )
      )
      FROM article_tags at
      JOIN tags t ON at.tag_id = t.id
      WHERE at.article_id = a.id),
      '[]'::jsonb
    ),
    'seo_metrics', COALESCE(
      (SELECT jsonb_build_object(
        'seo_score', sm.seo_score,
        'accessibility_score', sm.accessibility_score,
        'page_speed_score', sm.page_speed_score,
        'target_keywords', sm.target_keywords,
        'last_updated', sm.last_updated
      )
      FROM seo_metrics sm
      WHERE sm.article_id = a.id),
      '{}'::jsonb
    ),
    'revenue_metrics', COALESCE(
      (SELECT jsonb_build_object(
        'total_revenue', rm.total_revenue,
        'affiliate_revenue', rm.affiliate_revenue,
        'conversion_rate', rm.conversion_rate,
        'revenue_per_visitor', rm.revenue_per_visitor
      )
      FROM revenue_metrics rm
      WHERE rm.article_id = a.id),
      '{}'::jsonb
    ),
    'media', COALESCE(
      (SELECT jsonb_agg(
        jsonb_build_object(
          'id', m.id,
          'filename', m.filename,
          'mime_type', m.mime_type,
          'media_type', m.media_type,
          'file_size', m.file_size,
          'width', m.width,
          'height', m.height,
          'duration', m.duration,
          'alt_text', COALESCE(am.alt_text_override, m.alt_text),
          'caption', COALESCE(am.caption_override, m.caption),
          'title', m.title,
          'cdn_url', m.cdn_url,
          'thumbnail_url', m.thumbnail_url,
          'compressed_url', m.compressed_url,
          'webp_url', m.webp_url,
          'blur_hash', m.blur_hash,
          'dominant_color', m.dominant_color,
          'usage_type', am.usage_type,
          'position', am.position,
          'section', am.section,
          'alignment', am.alignment,
          'size', am.size,
          'display_order', am.display_order,
          'link_url', am.link_url,
          'is_lazy_loaded', am.is_lazy_loaded,
          'responsive_settings', am.responsive_settings,
          'variants', COALESCE(
            (SELECT jsonb_agg(
              jsonb_build_object(
                'variant_type', mv.variant_type,
                'width', mv.width,
                'height', mv.height,
                'format', mv.format,
                'url', mv.url,
                'is_optimized', mv.is_optimized
              )
            )
            FROM media_variants mv
            WHERE mv.media_id = m.id),
            '[]'::jsonb
          )
        ) ORDER BY am.display_order, am.position
      )
      FROM article_media am
      JOIN media m ON am.media_id = m.id
      WHERE am.article_id = a.id AND m.is_active = true),
      '[]'::jsonb
    )
  ) INTO v_result
  FROM articles a
  LEFT JOIN niches n ON a.niche_id = n.id
  LEFT JOIN categories c ON a.category_id = c.id
  LEFT JOIN authors au ON a.author_id = au.id
  WHERE a.id = p_article_id
    AND (p_tenant_id IS NULL OR a.tenant_id = p_tenant_id);
  
  RETURN v_result;
END;
$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION fetch_content_batch TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION upsert_authors_batch TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION upsert_tags_batch TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION insert_article_complete TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION update_topic_status TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION generate_media_batch TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION get_article_details TO authenticated, service_role;