-- =====================================================
-- ANALYTICS & SEO FUNCTIONS
-- Functions for tracking, metrics, and performance analysis
-- =====================================================

-- Function to update SEO metrics for an article
CREATE OR REPLACE FUNCTION update_seo_metrics(
  p_article_id UUID,
  p_metrics JSONB
) RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
  INSERT INTO seo_metrics (
    article_id,
    seo_score,
    accessibility_score,
    mobile_friendly,
    page_speed_score,
    meta_tags_complete,
    structured_data_valid,
    keyword_density,
    internal_links_count,
    external_links_count,
    image_alt_tags_complete,
    created_at,
    updated_at
  ) VALUES (
    p_article_id,
    COALESCE((p_metrics->>'seo_score')::INTEGER, 0),
    COALESCE((p_metrics->>'accessibility_score')::INTEGER, 0),
    COALESCE((p_metrics->>'mobile_friendly')::BOOLEAN, false),
    COALESCE((p_metrics->>'page_speed_score')::INTEGER, 0),
    COALESCE((p_metrics->>'meta_tags_complete')::BOOLEAN, false),
    COALESCE((p_metrics->>'structured_data_valid')::BOOLEAN, false),
    COALESCE((p_metrics->>'keyword_density')::NUMERIC, 0),
    COALESCE((p_metrics->>'internal_links_count')::INTEGER, 0),
    COALESCE((p_metrics->>'external_links_count')::INTEGER, 0),
    COALESCE((p_metrics->>'image_alt_tags_complete')::BOOLEAN, false),
    NOW(),
    NOW()
  ) ON CONFLICT (article_id)
  DO UPDATE SET
    seo_score = EXCLUDED.seo_score,
    accessibility_score = EXCLUDED.accessibility_score,
    mobile_friendly = EXCLUDED.mobile_friendly,
    page_speed_score = EXCLUDED.page_speed_score,
    meta_tags_complete = EXCLUDED.meta_tags_complete,
    structured_data_valid = EXCLUDED.structured_data_valid,
    keyword_density = EXCLUDED.keyword_density,
    internal_links_count = EXCLUDED.internal_links_count,
    external_links_count = EXCLUDED.external_links_count,
    image_alt_tags_complete = EXCLUDED.image_alt_tags_complete,
    updated_at = NOW();
END;
$$;

-- Function to track article view
CREATE OR REPLACE FUNCTION track_article_view(
  p_article_id UUID,
  p_user_id UUID DEFAULT NULL,
  p_session_id TEXT DEFAULT NULL,
  p_referrer TEXT DEFAULT NULL,
  p_user_agent TEXT DEFAULT NULL
) RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
  -- Insert analytics event
  INSERT INTO analytics_events (
    event_type,
    article_id,
    user_id,
    session_id,
    event_data,
    created_at
  ) VALUES (
    'article_view',
    p_article_id,
    p_user_id,
    p_session_id,
    jsonb_build_object(
      'referrer', p_referrer,
      'user_agent', p_user_agent
    ),
    NOW()
  );
  
  -- Update article view count
  UPDATE articles 
  SET 
    view_count = view_count + 1,
    last_viewed_at = NOW(),
    updated_at = NOW()
  WHERE id = p_article_id;
  
  -- Update daily stats
  INSERT INTO daily_stats (
    date,
    metric_type,
    metric_value,
    entity_type,
    entity_id
  ) VALUES (
    CURRENT_DATE,
    'views',
    1,
    'article',
    p_article_id
  ) ON CONFLICT (date, metric_type, entity_type, entity_id)
  DO UPDATE SET
    metric_value = daily_stats.metric_value + 1,
    updated_at = NOW();
END;
$$;

-- Function to calculate engagement metrics
CREATE OR REPLACE FUNCTION calculate_engagement_metrics(
  p_article_id UUID,
  p_time_period INTERVAL DEFAULT '30 days'
) RETURNS JSONB
LANGUAGE plpgsql AS $$
DECLARE
  v_metrics JSONB;
  v_views INTEGER;
  v_unique_views INTEGER;
  v_avg_time_on_page NUMERIC;
  v_bounce_rate NUMERIC;
  v_social_shares INTEGER;
  v_comments INTEGER;
BEGIN
  -- Get view metrics
  SELECT 
    COUNT(*),
    COUNT(DISTINCT COALESCE(user_id, session_id))
  INTO v_views, v_unique_views
  FROM analytics_events
  WHERE article_id = p_article_id
    AND event_type = 'article_view'
    AND created_at >= NOW() - p_time_period;
  
  -- Calculate average time on page
  SELECT AVG((event_data->>'time_on_page')::NUMERIC)
  INTO v_avg_time_on_page
  FROM analytics_events
  WHERE article_id = p_article_id
    AND event_type = 'page_exit'
    AND event_data ? 'time_on_page'
    AND created_at >= NOW() - p_time_period;
  
  -- Calculate bounce rate
  WITH session_events AS (
    SELECT session_id, COUNT(*) as event_count
    FROM analytics_events
    WHERE article_id = p_article_id
      AND created_at >= NOW() - p_time_period
    GROUP BY session_id
  )
  SELECT 
    CASE 
      WHEN COUNT(*) > 0 THEN 
        (COUNT(*) FILTER (WHERE event_count = 1)::NUMERIC / COUNT(*)) * 100
      ELSE 0 
    END
  INTO v_bounce_rate
  FROM session_events;
  
  -- Get social shares
  SELECT COUNT(*)
  INTO v_social_shares
  FROM analytics_events
  WHERE article_id = p_article_id
    AND event_type = 'social_share'
    AND created_at >= NOW() - p_time_period;
  
  -- Get comments count
  SELECT COUNT(*)
  INTO v_comments
  FROM user_comments
  WHERE article_id = p_article_id
    AND status = 'approved'
    AND created_at >= NOW() - p_time_period;
  
  -- Build metrics object
  v_metrics := jsonb_build_object(
    'views', COALESCE(v_views, 0),
    'unique_views', COALESCE(v_unique_views, 0),
    'avg_time_on_page', COALESCE(v_avg_time_on_page, 0),
    'bounce_rate', COALESCE(v_bounce_rate, 0),
    'social_shares', COALESCE(v_social_shares, 0),
    'comments', COALESCE(v_comments, 0),
    'engagement_score', COALESCE(
      (v_unique_views * 10 + v_social_shares * 50 + v_comments * 100) / 
      GREATEST(v_views, 1), 0
    ),
    'calculated_at', NOW()
  );
  
  -- Update article engagement score
  UPDATE articles 
  SET 
    engagement_score = (v_metrics->>'engagement_score')::NUMERIC,
    updated_at = NOW()
  WHERE id = p_article_id;
  
  RETURN v_metrics;
END;
$$;

-- Function to generate content performance report
CREATE OR REPLACE FUNCTION generate_performance_report(
  p_start_date DATE DEFAULT CURRENT_DATE - INTERVAL '30 days',
  p_end_date DATE DEFAULT CURRENT_DATE,
  p_niche_id UUID DEFAULT NULL
) RETURNS JSONB
LANGUAGE plpgsql AS $$
DECLARE
  v_report JSONB;
  v_top_articles JSONB;
  v_author_stats JSONB;
  v_niche_stats JSONB;
BEGIN
  -- Get top performing articles
  SELECT jsonb_agg(
    jsonb_build_object(
      'id', a.id,
      'title', a.title,
      'slug', a.slug,
      'views', a.view_count,
      'engagement_score', a.engagement_score,
      'author', au.display_name,
      'niche', n.name
    )
  ) INTO v_top_articles
  FROM articles a
  JOIN authors au ON a.author_id = au.id
  JOIN niches n ON a.niche_id = n.id
  WHERE a.published_at BETWEEN p_start_date AND p_end_date + INTERVAL '1 day'
    AND (p_niche_id IS NULL OR a.niche_id = p_niche_id)
    AND a.status = 'published'
  ORDER BY a.view_count DESC, a.engagement_score DESC
  LIMIT 10;
  
  -- Get author performance stats
  SELECT jsonb_agg(
    jsonb_build_object(
      'author_id', au.id,
      'display_name', au.display_name,
      'articles_count', COUNT(a.id),
      'total_views', SUM(a.view_count),
      'avg_engagement', AVG(a.engagement_score)
    )
  ) INTO v_author_stats
  FROM authors au
  JOIN articles a ON au.id = a.author_id
  WHERE a.published_at BETWEEN p_start_date AND p_end_date + INTERVAL '1 day'
    AND (p_niche_id IS NULL OR a.niche_id = p_niche_id)
    AND a.status = 'published'
  GROUP BY au.id, au.display_name
  ORDER BY SUM(a.view_count) DESC
  LIMIT 10;
  
  -- Get niche performance stats
  SELECT jsonb_agg(
    jsonb_build_object(
      'niche_id', n.id,
      'name', n.name,
      'articles_count', COUNT(a.id),
      'total_views', SUM(a.view_count),
      'avg_quality_score', AVG(a.content_quality_score)
    )
  ) INTO v_niche_stats
  FROM niches n
  JOIN articles a ON n.id = a.niche_id
  WHERE a.published_at BETWEEN p_start_date AND p_end_date + INTERVAL '1 day'
    AND (p_niche_id IS NULL OR a.niche_id = p_niche_id)
    AND a.status = 'published'
  GROUP BY n.id, n.name
  ORDER BY SUM(a.view_count) DESC;
  
  -- Build final report
  v_report := jsonb_build_object(
    'period', jsonb_build_object(
      'start_date', p_start_date,
      'end_date', p_end_date
    ),
    'top_articles', COALESCE(v_top_articles, '[]'::jsonb),
    'author_performance', COALESCE(v_author_stats, '[]'::jsonb),
    'niche_performance', COALESCE(v_niche_stats, '[]'::jsonb),
    'generated_at', NOW()
  );
  
  RETURN v_report;
END;
$$;

-- Function to update affiliate link performance
CREATE OR REPLACE FUNCTION track_affiliate_click(
  p_link_id UUID,
  p_article_id UUID,
  p_user_id UUID DEFAULT NULL,
  p_session_id TEXT DEFAULT NULL
) RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
  -- Insert click record
  INSERT INTO affiliate_clicks (
    link_id,
    article_id,
    user_id,
    session_id,
    clicked_at
  ) VALUES (
    p_link_id,
    p_article_id,
    p_user_id,
    p_session_id,
    NOW()
  );
  
  -- Update link statistics
  UPDATE affiliate_links
  SET 
    click_count = click_count + 1,
    last_clicked_at = NOW(),
    updated_at = NOW()
  WHERE id = p_link_id;
  
  -- Track analytics event
  INSERT INTO analytics_events (
    event_type,
    article_id,
    user_id,
    session_id,
    event_data,
    created_at
  ) VALUES (
    'affiliate_click',
    p_article_id,
    p_user_id,
    p_session_id,
    jsonb_build_object('link_id', p_link_id),
    NOW()
  );
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION update_seo_metrics TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION track_article_view TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION calculate_engagement_metrics TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION generate_performance_report TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION track_affiliate_click TO authenticated, service_role;