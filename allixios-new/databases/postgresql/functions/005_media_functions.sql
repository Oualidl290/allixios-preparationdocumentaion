-- ============================================================================
-- MEDIA MANAGEMENT FUNCTIONS
-- Functions for comprehensive media handling, processing, and optimization
-- ============================================================================

-- Function to upload and process media
CREATE OR REPLACE FUNCTION upload_media(
  p_tenant_id UUID,
  p_media_data JSONB
) RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER AS $
DECLARE
  v_media_id UUID;
  v_processing_id UUID;
BEGIN
  -- Insert media record
  INSERT INTO media (
    tenant_id,
    filename,
    original_filename,
    mime_type,
    media_type,
    file_size,
    width,
    height,
    duration,
    alt_text,
    caption,
    description,
    title,
    metadata,
    storage_path,
    cdn_url,
    processing_status,
    is_processed,
    created_at,
    updated_at
  ) VALUES (
    p_tenant_id,
    p_media_data->>'filename',
    p_media_data->>'original_filename',
    p_media_data->>'mime_type',
    COALESCE(p_media_data->>'media_type', 
      CASE 
        WHEN p_media_data->>'mime_type' LIKE 'image/%' THEN 'image'
        WHEN p_media_data->>'mime_type' LIKE 'video/%' THEN 'video'
        WHEN p_media_data->>'mime_type' LIKE 'audio/%' THEN 'audio'
        ELSE 'document'
      END
    ),
    COALESCE((p_media_data->>'file_size')::BIGINT, 0),
    (p_media_data->>'width')::INTEGER,
    (p_media_data->>'height')::INTEGER,
    (p_media_data->>'duration')::INTEGER,
    p_media_data->>'alt_text',
    p_media_data->>'caption',
    p_media_data->>'description',
    p_media_data->>'title',
    COALESCE(p_media_data->'metadata', '{}'::JSONB),
    p_media_data->>'storage_path',
    p_media_data->>'cdn_url',
    'pending',
    false,
    NOW(),
    NOW()
  ) RETURNING id INTO v_media_id;
  
  -- Queue for processing if it's an image or video
  IF p_media_data->>'media_type' IN ('image', 'video') OR 
     p_media_data->>'mime_type' LIKE 'image/%' OR 
     p_media_data->>'mime_type' LIKE 'video/%' THEN
    
    -- Queue thumbnail generation
    INSERT INTO media_processing_queue (
      media_id,
      processing_type,
      priority,
      parameters,
      created_at
    ) VALUES (
      v_media_id,
      'thumbnail',
      8,
      jsonb_build_object(
        'width', 300,
        'height', 300,
        'quality', 85
      ),
      NOW()
    );
    
    -- Queue compression for large files
    IF COALESCE((p_media_data->>'file_size')::BIGINT, 0) > 1048576 THEN -- > 1MB
      INSERT INTO media_processing_queue (
        media_id,
        processing_type,
        priority,
        parameters,
        created_at
      ) VALUES (
        v_media_id,
        'compress',
        6,
        jsonb_build_object(
          'quality', 80,
          'max_width', 1920,
          'max_height', 1080
        ),
        NOW()
      );
    END IF;
    
    -- Queue format conversion for modern formats
    IF p_media_data->>'mime_type' LIKE 'image/%' THEN
      INSERT INTO media_processing_queue (
        media_id,
        processing_type,
        priority,
        parameters,
        created_at
      ) VALUES (
        v_media_id,
        'format_convert',
        5,
        jsonb_build_object(
          'formats', '["webp", "avif"]',
          'quality', 85
        ),
        NOW()
      );
    END IF;
  END IF;
  
  RETURN v_media_id;
END;
$;

-- Function to attach media to article
CREATE OR REPLACE FUNCTION attach_media_to_article(
  p_article_id UUID,
  p_media_id UUID,
  p_usage_type VARCHAR DEFAULT 'content',
  p_position INTEGER DEFAULT 1,
  p_section VARCHAR DEFAULT NULL,
  p_alignment VARCHAR DEFAULT 'center',
  p_size VARCHAR DEFAULT 'medium',
  p_caption_override TEXT DEFAULT NULL,
  p_alt_text_override TEXT DEFAULT NULL
) RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER AS $
DECLARE
  v_attachment_id UUID;
BEGIN
  -- Insert or update article media relationship
  INSERT INTO article_media (
    article_id,
    media_id,
    usage_type,
    position,
    section,
    alignment,
    size,
    caption_override,
    alt_text_override,
    display_order,
    created_at
  ) VALUES (
    p_article_id,
    p_media_id,
    p_usage_type,
    p_position,
    p_section,
    p_alignment,
    p_size,
    p_caption_override,
    p_alt_text_override,
    p_position,
    NOW()
  ) ON CONFLICT (article_id, media_id, usage_type, position)
  DO UPDATE SET
    section = EXCLUDED.section,
    alignment = EXCLUDED.alignment,
    size = EXCLUDED.size,
    caption_override = EXCLUDED.caption_override,
    alt_text_override = EXCLUDED.alt_text_override,
    display_order = EXCLUDED.display_order
  RETURNING id INTO v_attachment_id;
  
  -- Update media usage count
  UPDATE media 
  SET 
    usage_count = usage_count + 1,
    updated_at = NOW()
  WHERE id = p_media_id;
  
  -- Update article updated_at
  UPDATE articles 
  SET updated_at = NOW()
  WHERE id = p_article_id;
  
  RETURN v_attachment_id;
END;
$;

-- Function to get article media with all variants
CREATE OR REPLACE FUNCTION get_article_media(
  p_article_id UUID,
  p_usage_type VARCHAR DEFAULT NULL
) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER AS $
DECLARE
  v_media_data JSONB;
BEGIN
  SELECT jsonb_agg(
    jsonb_build_object(
      'id', m.id,
      'filename', m.filename,
      'original_filename', m.original_filename,
      'mime_type', m.mime_type,
      'media_type', m.media_type,
      'file_size', m.file_size,
      'width', m.width,
      'height', m.height,
      'duration', m.duration,
      'alt_text', COALESCE(am.alt_text_override, m.alt_text),
      'caption', COALESCE(am.caption_override, m.caption),
      'description', m.description,
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
            'file_size', mv.file_size,
            'quality', mv.quality,
            'format', mv.format,
            'url', mv.url,
            'is_optimized', mv.is_optimized
          )
        )
        FROM media_variants mv
        WHERE mv.media_id = m.id),
        '[]'::JSONB
      ),
      'ai_analysis', m.ai_analysis,
      'seo_data', m.seo_data,
      'created_at', am.created_at
    ) ORDER BY am.display_order, am.position
  ) INTO v_media_data
  FROM article_media am
  JOIN media m ON am.media_id = m.id
  WHERE am.article_id = p_article_id
    AND (p_usage_type IS NULL OR am.usage_type = p_usage_type)
    AND m.is_active = true;
  
  RETURN COALESCE(v_media_data, '[]'::JSONB);
END;
$;

-- Function to process media queue
CREATE OR REPLACE FUNCTION process_media_queue(
  p_batch_size INTEGER DEFAULT 5
) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER AS $
DECLARE
  v_processing_item RECORD;
  v_processed_count INTEGER := 0;
  v_results JSONB := '[]'::JSONB;
BEGIN
  -- Get items to process
  FOR v_processing_item IN
    SELECT mpq.*, m.filename, m.mime_type, m.storage_path, m.cdn_url
    FROM media_processing_queue mpq
    JOIN media m ON mpq.media_id = m.id
    WHERE mpq.status = 'queued'
      AND mpq.retry_count < mpq.max_retries
    ORDER BY mpq.priority DESC, mpq.created_at ASC
    LIMIT p_batch_size
    FOR UPDATE SKIP LOCKED
  LOOP
    -- Update status to processing
    UPDATE media_processing_queue
    SET 
      status = 'processing',
      started_at = NOW(),
      updated_at = NOW()
    WHERE id = v_processing_item.id;
    
    -- Add to results (actual processing would be done by external service)
    v_results := v_results || jsonb_build_object(
      'processing_id', v_processing_item.id,
      'media_id', v_processing_item.media_id,
      'processing_type', v_processing_item.processing_type,
      'parameters', v_processing_item.parameters,
      'filename', v_processing_item.filename,
      'mime_type', v_processing_item.mime_type,
      'storage_path', v_processing_item.storage_path,
      'cdn_url', v_processing_item.cdn_url
    );
    
    v_processed_count := v_processed_count + 1;
  END LOOP;
  
  RETURN jsonb_build_object(
    'processed_count', v_processed_count,
    'items', v_results,
    'timestamp', NOW()
  );
END;
$;

-- Function to complete media processing
CREATE OR REPLACE FUNCTION complete_media_processing(
  p_processing_id UUID,
  p_success BOOLEAN,
  p_result_data JSONB DEFAULT '{}',
  p_error_message TEXT DEFAULT NULL
) RETURNS BOOLEAN
LANGUAGE plpgsql SECURITY DEFINER AS $
DECLARE
  v_processing_record RECORD;
  v_variant_id UUID;
BEGIN
  -- Get processing record
  SELECT * INTO v_processing_record
  FROM media_processing_queue
  WHERE id = p_processing_id;
  
  IF NOT FOUND THEN
    RETURN FALSE;
  END IF;
  
  IF p_success THEN
    -- Update processing status to completed
    UPDATE media_processing_queue
    SET 
      status = 'completed',
      progress = 100,
      completed_at = NOW(),
      updated_at = NOW()
    WHERE id = p_processing_id;
    
    -- Handle different processing types
    CASE v_processing_record.processing_type
      WHEN 'thumbnail' THEN
        UPDATE media
        SET 
          thumbnail_url = p_result_data->>'url',
          updated_at = NOW()
        WHERE id = v_processing_record.media_id;
        
      WHEN 'compress' THEN
        UPDATE media
        SET 
          compressed_url = p_result_data->>'url',
          updated_at = NOW()
        WHERE id = v_processing_record.media_id;
        
      WHEN 'format_convert' THEN
        -- Create media variants for different formats
        IF p_result_data ? 'variants' THEN
          FOR v_variant_id IN 
            SELECT jsonb_array_elements(p_result_data->'variants')
          LOOP
            INSERT INTO media_variants (
              media_id,
              variant_type,
              width,
              height,
              file_size,
              quality,
              format,
              url,
              storage_path,
              is_optimized,
              created_at
            ) VALUES (
              v_processing_record.media_id,
              (v_variant_id->>'format')::TEXT,
              (v_variant_id->>'width')::INTEGER,
              (v_variant_id->>'height')::INTEGER,
              (v_variant_id->>'file_size')::BIGINT,
              (v_variant_id->>'quality')::INTEGER,
              (v_variant_id->>'format')::TEXT,
              v_variant_id->>'url',
              v_variant_id->>'storage_path',
              true,
              NOW()
            ) ON CONFLICT (media_id, variant_type, format) DO NOTHING;
          END LOOP;
        END IF;
        
        -- Update WebP URL if available
        IF p_result_data ? 'webp_url' THEN
          UPDATE media
          SET 
            webp_url = p_result_data->>'webp_url',
            updated_at = NOW()
          WHERE id = v_processing_record.media_id;
        END IF;
        
      WHEN 'ai_analysis' THEN
        UPDATE media
        SET 
          ai_analysis = p_result_data,
          updated_at = NOW()
        WHERE id = v_processing_record.media_id;
    END CASE;
    
    -- Check if all processing is complete for this media
    IF NOT EXISTS (
      SELECT 1 FROM media_processing_queue
      WHERE media_id = v_processing_record.media_id
        AND status IN ('queued', 'processing')
    ) THEN
      UPDATE media
      SET 
        is_processed = true,
        processing_status = 'completed',
        updated_at = NOW()
      WHERE id = v_processing_record.media_id;
    END IF;
    
  ELSE
    -- Handle failure
    UPDATE media_processing_queue
    SET 
      status = 'failed',
      error_message = p_error_message,
      retry_count = retry_count + 1,
      updated_at = NOW()
    WHERE id = p_processing_id;
    
    -- If max retries reached, mark media processing as failed
    IF v_processing_record.retry_count + 1 >= v_processing_record.max_retries THEN
      UPDATE media
      SET 
        processing_status = 'failed',
        updated_at = NOW()
      WHERE id = v_processing_record.media_id;
    END IF;
  END IF;
  
  RETURN TRUE;
END;
$;

-- Function to create media collection
CREATE OR REPLACE FUNCTION create_media_collection(
  p_tenant_id UUID,
  p_name TEXT,
  p_description TEXT DEFAULT NULL,
  p_is_public BOOLEAN DEFAULT false,
  p_created_by UUID DEFAULT NULL
) RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER AS $
DECLARE
  v_collection_id UUID;
  v_slug TEXT;
  v_counter INTEGER := 0;
  v_final_slug TEXT;
BEGIN
  -- Generate unique slug
  v_slug := lower(regexp_replace(p_name, '[^a-zA-Z0-9]+', '-', 'g'));
  v_final_slug := v_slug;
  
  WHILE EXISTS (SELECT 1 FROM media_collections WHERE tenant_id = p_tenant_id AND slug = v_final_slug) LOOP
    v_counter := v_counter + 1;
    v_final_slug := v_slug || '-' || v_counter;
  END LOOP;
  
  INSERT INTO media_collections (
    tenant_id,
    name,
    slug,
    description,
    is_public,
    created_by,
    created_at,
    updated_at
  ) VALUES (
    p_tenant_id,
    p_name,
    v_final_slug,
    p_description,
    p_is_public,
    p_created_by,
    NOW(),
    NOW()
  ) RETURNING id INTO v_collection_id;
  
  RETURN v_collection_id;
END;
$;

-- Function to add media to collection
CREATE OR REPLACE FUNCTION add_media_to_collection(
  p_collection_id UUID,
  p_media_id UUID,
  p_position INTEGER DEFAULT NULL,
  p_caption_override TEXT DEFAULT NULL
) RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER AS $
DECLARE
  v_item_id UUID;
  v_next_position INTEGER;
BEGIN
  -- Get next position if not specified
  IF p_position IS NULL THEN
    SELECT COALESCE(MAX(position), 0) + 1 INTO v_next_position
    FROM media_collection_items
    WHERE collection_id = p_collection_id;
  ELSE
    v_next_position := p_position;
  END IF;
  
  INSERT INTO media_collection_items (
    collection_id,
    media_id,
    position,
    caption_override,
    created_at
  ) VALUES (
    p_collection_id,
    p_media_id,
    v_next_position,
    p_caption_override,
    NOW()
  ) ON CONFLICT (collection_id, media_id)
  DO UPDATE SET
    position = EXCLUDED.position,
    caption_override = EXCLUDED.caption_override
  RETURNING id INTO v_item_id;
  
  RETURN v_item_id;
END;
$;

-- Function to get media with all details
CREATE OR REPLACE FUNCTION get_media_details(
  p_media_id UUID
) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER AS $
DECLARE
  v_media_data JSONB;
BEGIN
  SELECT jsonb_build_object(
    'id', m.id,
    'filename', m.filename,
    'original_filename', m.original_filename,
    'mime_type', m.mime_type,
    'media_type', m.media_type,
    'file_size', m.file_size,
    'width', m.width,
    'height', m.height,
    'duration', m.duration,
    'alt_text', m.alt_text,
    'caption', m.caption,
    'description', m.description,
    'title', m.title,
    'metadata', m.metadata,
    'storage_path', m.storage_path,
    'cdn_url', m.cdn_url,
    'thumbnail_url', m.thumbnail_url,
    'compressed_url', m.compressed_url,
    'webp_url', m.webp_url,
    'blur_hash', m.blur_hash,
    'dominant_color', m.dominant_color,
    'ai_analysis', m.ai_analysis,
    'seo_data', m.seo_data,
    'usage_count', m.usage_count,
    'is_active', m.is_active,
    'is_processed', m.is_processed,
    'processing_status', m.processing_status,
    'created_at', m.created_at,
    'updated_at', m.updated_at,
    'variants', COALESCE(
      (SELECT jsonb_agg(
        jsonb_build_object(
          'id', mv.id,
          'variant_type', mv.variant_type,
          'width', mv.width,
          'height', mv.height,
          'file_size', mv.file_size,
          'quality', mv.quality,
          'format', mv.format,
          'url', mv.url,
          'storage_path', mv.storage_path,
          'is_optimized', mv.is_optimized,
          'created_at', mv.created_at
        )
      )
      FROM media_variants mv
      WHERE mv.media_id = m.id),
      '[]'::JSONB
    ),
    'processing_queue', COALESCE(
      (SELECT jsonb_agg(
        jsonb_build_object(
          'id', mpq.id,
          'processing_type', mpq.processing_type,
          'priority', mpq.priority,
          'status', mpq.status,
          'parameters', mpq.parameters,
          'progress', mpq.progress,
          'error_message', mpq.error_message,
          'retry_count', mpq.retry_count,
          'created_at', mpq.created_at
        )
      )
      FROM media_processing_queue mpq
      WHERE mpq.media_id = m.id
        AND mpq.status IN ('queued', 'processing')),
      '[]'::JSONB
    ),
    'usage_in_articles', COALESCE(
      (SELECT jsonb_agg(
        jsonb_build_object(
          'article_id', a.id,
          'article_title', a.title,
          'article_slug', a.slug,
          'usage_type', am.usage_type,
          'position', am.position,
          'section', am.section
        )
      )
      FROM article_media am
      JOIN articles a ON am.article_id = a.id
      WHERE am.media_id = m.id
        AND a.is_active = true),
      '[]'::JSONB
    )
  ) INTO v_media_data
  FROM media m
  WHERE m.id = p_media_id;
  
  RETURN v_media_data;
END;
$;

-- Function to cleanup unused media
CREATE OR REPLACE FUNCTION cleanup_unused_media(
  p_days_old INTEGER DEFAULT 30,
  p_dry_run BOOLEAN DEFAULT true
) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER AS $
DECLARE
  v_unused_media UUID[];
  v_deleted_count INTEGER := 0;
  v_total_size BIGINT := 0;
BEGIN
  -- Find unused media older than specified days
  SELECT array_agg(m.id), SUM(m.file_size)
  INTO v_unused_media, v_total_size
  FROM media m
  WHERE m.created_at < NOW() - INTERVAL '1 day' * p_days_old
    AND m.usage_count = 0
    AND NOT EXISTS (
      SELECT 1 FROM article_media am WHERE am.media_id = m.id
    )
    AND NOT EXISTS (
      SELECT 1 FROM media_collection_items mci WHERE mci.media_id = m.id
    )
    AND NOT EXISTS (
      SELECT 1 FROM articles a WHERE a.featured_image_id = m.id
    );
  
  IF NOT p_dry_run AND v_unused_media IS NOT NULL THEN
    -- Delete unused media
    DELETE FROM media WHERE id = ANY(v_unused_media);
    GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
  END IF;
  
  RETURN jsonb_build_object(
    'unused_media_count', COALESCE(array_length(v_unused_media, 1), 0),
    'total_size_bytes', COALESCE(v_total_size, 0),
    'deleted_count', v_deleted_count,
    'dry_run', p_dry_run,
    'cleanup_date', NOW()
  );
END;
$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION upload_media TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION attach_media_to_article TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION get_article_media TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION process_media_queue TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION complete_media_processing TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION create_media_collection TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION add_media_to_collection TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION get_media_details TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION cleanup_unused_media TO authenticated, service_role;