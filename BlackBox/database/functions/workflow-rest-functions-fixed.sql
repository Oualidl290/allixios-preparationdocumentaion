-- ============================================================================
-- WORKFLOW REST API FUNCTIONS - FIXED VERSION
-- Database functions to replace Edge Functions for n8n workflows
-- Fixed to handle custom enum types properly
-- ============================================================================

-- Function 1: Fetch Content Batch (replaces fetch-content-batch-v2)
CREATE OR REPLACE FUNCTION fetch_content_batch_v3(
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
) LANGUAGE plpgsql AS $$
DECLARE
  v_worker_id TEXT := COALESCE(p_worker_id, 'worker-' || gen_random_uuid()::text);
  v_lock_duration INTERVAL := '30 minutes';
BEGIN
  -- Lock and return topics atomically
  RETURN QUERY
  WITH locked_topics AS (
    UPDATE topics_queue tq
    SET 
      status = (
        CASE 
          WHEN EXISTS (SELECT 1 FROM pg_type WHERE typname = 'status_type') 
          THEN 'processing'::text::status_type
          ELSE 'processing'
        END
      ),
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
      WHERE (
        CASE 
          WHEN EXISTS (SELECT 1 FROM pg_type WHERE typname = 'status_type') 
          THEN t.status::text = 'queued'
          ELSE t.status = 'queued'
        END
      )
        AND (NOT p_exclude_processing OR t.processing_started_at IS NULL OR t.processing_started_at < NOW() - v_lock_duration)
        AND t.retry_count < 3
        AND (p_priority_filter IS NULL OR (
          CASE 
            WHEN EXISTS (SELECT 1 FROM pg_type WHERE typname = 'priority_level') 
            THEN t.priority::text = ANY(p_priority_filter)
            ELSE t.priority = ANY(p_priority_filter)
          END
        ))
        AND (p_niche_filters IS NULL OR t.niche_id = ANY(p_niche_filters))
        AND (p_category_filters IS NULL OR t.category_id = ANY(p_category_filters))
      ORDER BY 
        CASE 
          WHEN EXISTS (SELECT 1 FROM pg_type WHERE typname = 'priority_level') 
          THEN (
            CASE t.priority::text 
              WHEN 'urgent' THEN 0 
              WHEN 'high' THEN 1 
              WHEN 'medium' THEN 2 
              WHEN 'low' THEN 3 
              ELSE 4
            END
          )
          ELSE (
            CASE t.priority 
              WHEN 'urgent' THEN 0 
              WHEN 'high' THEN 1 
              WHEN 'medium' THEN 2 
              WHEN 'low' THEN 3 
              ELSE 4
            END
          )
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
    CASE 
      WHEN EXISTS (SELECT 1 FROM pg_type WHERE typname = 'difficulty_level') 
      THEN lt.difficulty::text
      ELSE lt.difficulty
    END as difficulty,
    lt.estimated_word_count,
    CEIL(lt.estimated_word_count::NUMERIC / 200) as estimated_reading_time,
    CASE 
      WHEN EXISTS (SELECT 1 FROM pg_type WHERE typname = 'priority_level') 
      THEN lt.priority::text
      ELSE lt.priority
    END as priority,
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
$$;

-- Function 2: Upsert Authors Batch (replaces upsert-authors-batch)
CREATE OR REPLACE FUNCTION upsert_authors_batch_v3(
  p_authors JSONB
) RETURNS TABLE (
  id UUID,
  display_name TEXT,
  email TEXT,
  action_taken TEXT,
  user_id UUID
) LANGUAGE plpgsql AS $$
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
    WHERE (v_author->>'email' IS NOT NULL AND a.email = v_author->>'email')
       OR (a.display_name = v_author->>'display_name')
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
        WHERE email = v_author->>'email';
        
        IF NOT FOUND THEN
          INSERT INTO users (email, full_name, created_at, updated_at)
          VALUES (
            v_author->>'email',
            v_author->>'display_name',
            NOW(),
            NOW()
          )
          RETURNING id INTO v_user_id;
        END IF;
      END IF;
      
      -- Create author record
      INSERT INTO authors (
        user_id,
        display_name,
        bio,
        email,
        expertise,
        social_links,
        is_active,
        created_at,
        updated_at
      ) VALUES (
        v_user_id,
        v_author->>'display_name',
        v_author->>'bio',
        v_author->>'email',
        (SELECT array_agg(value::text) FROM jsonb_array_elements_text(v_author->'expertise')),
        v_author->'social_links',
        true,
        NOW(),
        NOW()
      )
      RETURNING id INTO v_author_id;
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
$$;

-- Function 3: Upsert Tags Batch (replaces upsert-tags-batch)
CREATE OR REPLACE FUNCTION upsert_tags_batch_v3(
  p_tags JSONB
) RETURNS TABLE (
  id UUID,
  name TEXT,
  slug TEXT,
  action_taken TEXT,
  usage_count INTEGER
) LANGUAGE plpgsql AS $$
DECLARE
  v_tag JSONB;
  v_tag_id UUID;
  v_tag_name TEXT;
  v_slug TEXT;
  v_existing_tag tags%ROWTYPE;
  v_action TEXT;
BEGIN
  -- Process each tag in the batch
  FOR v_tag IN SELECT * FROM jsonb_array_elements(p_tags)
  LOOP
    v_tag_name := v_tag->>'name';
    v_slug := lower(regexp_replace(v_tag_name, '[^a-zA-Z0-9]+', '-', 'g'));
    v_action := 'created';
    
    -- Check if tag exists by name (case insensitive)
    SELECT * INTO v_existing_tag
    FROM tags t
    WHERE LOWER(t.name) = LOWER(v_tag_name)
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
      -- Create new tag
      INSERT INTO tags (
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
        v_tag_name,
        v_slug,
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
      v_slug,
      v_action,
      COALESCE(v_existing_tag.usage_count, 0);
  END LOOP;
END;
$$;

-- Function 4: Insert Article Complete (replaces insert-article-complete)
CREATE OR REPLACE FUNCTION insert_article_complete_v3(
  p_article JSONB
) RETURNS TABLE (
  id UUID,
  title TEXT,
  slug TEXT,
  status TEXT,
  content_quality_score NUMERIC,
  seo_score NUMERIC,
  published_at TIMESTAMPTZ
) LANGUAGE plpgsql AS $$
DECLARE
  v_article_id UUID;
  v_slug TEXT;
  v_tag_id UUID;
  v_tag_name TEXT;
  v_media_id UUID;
  v_quality_score NUMERIC;
  v_seo_score NUMERIC;
  v_published_at TIMESTAMPTZ;
  v_status TEXT;
BEGIN
  -- Generate unique slug
  v_slug := lower(regexp_replace(p_article->>'title', '[^a-zA-Z0-9\s-]', '', 'g'));
  v_slug := regexp_replace(v_slug, '\s+', '-', 'g');
  v_slug := regexp_replace(v_slug, '-+', '-', 'g');
  v_slug := trim(v_slug, '-');
  v_slug := substring(v_slug, 1, 50) || '-' || substring(gen_random_uuid()::text, 1, 6);
  
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
    p_article->>'title',
    v_slug,
    p_article->>'content',
    p_article->>'excerpt',
    p_article->>'meta_title',
    p_article->>'meta_description',
    p_article->>'featured_image_url',
    COALESCE((p_article->>'word_count')::INTEGER, 0),
    COALESCE((p_article->>'reading_time')::INTEGER, 5),
    v_quality_score,
    v_seo_score,
    CASE 
      WHEN EXISTS (SELECT 1 FROM pg_type WHERE typname = 'article_status') 
      THEN v_status::text::article_status
      ELSE v_status
    END,
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
  IF p_article ? 'media_ids' AND jsonb_array_length(p_article->'media_ids') > 0 THEN
    FOR v_media_id IN 
      SELECT (value::text)::UUID 
      FROM jsonb_array_elements_text(p_article->'media_ids')
    LOOP
      INSERT INTO article_media (article_id, media_id, usage_type, position, created_at)
      VALUES (v_article_id, v_media_id, 'content', 1, NOW())
      ON CONFLICT (article_id, media_id) DO NOTHING;
    END LOOP;
  END IF;
  
  -- Initialize SEO metrics if table exists
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'seo_metrics') THEN
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
      v_seo_score,
      NOW(),
      NOW()
    );
  END IF;
  
  -- Return article details
  RETURN QUERY SELECT 
    v_article_id,
    p_article->>'title',
    v_slug,
    v_status,
    v_quality_score,
    v_seo_score,
    v_published_at;
END;
$$;

-- Function 5: Update Topic Status (replaces update-topic-status)
CREATE OR REPLACE FUNCTION update_topic_status_v3(
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
) LANGUAGE plpgsql AS $$
DECLARE
  v_retry_count INTEGER;
  v_status_value TEXT;
BEGIN
  -- Handle different status updates
  CASE p_status
    WHEN 'completed' THEN
      UPDATE topics_queue 
      SET 
        status = CASE 
          WHEN EXISTS (SELECT 1 FROM pg_type WHERE typname = 'status_type') 
          THEN 'completed'::text::status_type
          ELSE 'completed'
        END,
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
        status = CASE 
          WHEN EXISTS (SELECT 1 FROM pg_type WHERE typname = 'status_type') 
          THEN 'failed'::text::status_type
          ELSE 'failed'
        END,
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
        status = CASE 
          WHEN EXISTS (SELECT 1 FROM pg_type WHERE typname = 'status_type') 
          THEN 'queued'::text::status_type
          ELSE 'queued'
        END,
        locked_by = NULL,
        locked_at = NULL,
        processing_started_at = NULL,
        updated_at = NOW()
      WHERE id = p_topic_id
      RETURNING retry_count INTO v_retry_count;
      
    ELSE
      UPDATE topics_queue 
      SET 
        status = CASE 
          WHEN EXISTS (SELECT 1 FROM pg_type WHERE typname = 'status_type') 
          THEN p_status::text::status_type
          ELSE p_status
        END,
        updated_at = NOW()
      WHERE id = p_topic_id
      RETURNING retry_count INTO v_retry_count;
  END CASE;
  
  -- Return updated topic info
  RETURN QUERY 
  SELECT 
    tq.id,
    CASE 
      WHEN EXISTS (SELECT 1 FROM pg_type WHERE typname = 'status_type') 
      THEN tq.status::text
      ELSE tq.status
    END as status,
    tq.updated_at,
    tq.retry_count
  FROM topics_queue tq
  WHERE tq.id = p_topic_id;
END;
$$;

-- Function 6: Generate Media Batch (simplified version)
CREATE OR REPLACE FUNCTION generate_media_batch_v3(
  p_media_requests JSONB,
  p_topic_context TEXT DEFAULT NULL
) RETURNS TABLE (
  id UUID,
  url TEXT,
  alt_text TEXT,
  media_type TEXT,
  status TEXT
) LANGUAGE plpgsql AS $$
DECLARE
  v_media_request JSONB;
  v_media_id UUID;
BEGIN
  -- Process each media request
  FOR v_media_request IN SELECT * FROM jsonb_array_elements(p_media_requests)
  LOOP
    -- Create placeholder media record (actual generation would be handled externally)
    INSERT INTO media (
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
$$;

-- Create indexes for performance
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_topics_queue_status_priority 
ON topics_queue(
  CASE 
    WHEN EXISTS (SELECT 1 FROM pg_type WHERE typname = 'status_type') 
    THEN status::text
    ELSE status
  END,
  CASE 
    WHEN EXISTS (SELECT 1 FROM pg_type WHERE typname = 'priority_level') 
    THEN priority::text
    ELSE priority
  END,
  created_at
) WHERE (
  CASE 
    WHEN EXISTS (SELECT 1 FROM pg_type WHERE typname = 'status_type') 
    THEN status::text IN ('queued', 'processing')
    ELSE status IN ('queued', 'processing')
  END
);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_topics_queue_locked_by 
ON topics_queue(locked_by, locked_at) WHERE locked_by IS NOT NULL;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_authors_email_name 
ON authors(email, display_name);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_tags_name_lower 
ON tags(LOWER(name));

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION fetch_content_batch_v3 TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION upsert_authors_batch_v3 TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION upsert_tags_batch_v3 TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION insert_article_complete_v3 TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION update_topic_status_v3 TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION generate_media_batch_v3 TO authenticated, service_role;