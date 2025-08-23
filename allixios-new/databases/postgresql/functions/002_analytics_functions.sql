-- ============================================================================
-- ANALYTICS & SEO FUNCTIONS
-- Functions for tracking, metrics, and performance analysis
-- Based on BlackBox implementation with improvements
-- ============================================================================

-- Function to update SEO metrics for an article
CREATE OR REPLACE FUNCTION update_seo_metrics(
  p_article_id UUID,
  p_metrics JSONB
) RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER AS $
DECLARE
  v_metric_id UUID;
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
    target_keywords,
    current_rankings,
    last_updated,
    created_at
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
    COALESCE(
      (SELECT array_agg(value::text) FROM jsonb_array_elements_text(p_metrics->'target_keywords')),
      ARRAY[]::TEXT[]
    ),
    COALESCE(p_metrics->'current_rankings', '{}'::JSONB),
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
    target_keywords = EXCLUDED.target_keywords,
    current_rankings = EXCLUDED.current_rankings,
    last_updated = NOW()
  RETURNING id INTO v_metric_id;
  
  -- Update article SEO score
  UPDATE articles 
  SET 
    seo_score = (p_metrics->>'seo_score')::NUMERIC,
    updated_at = NOW()
  WHERE id = p_article_id;
  
  RETURN v_metric_id;
END;
$;

-- Function to track article view
CREATE OR REPLACE FUNCTION track_article_view(
  p_article_id UUID,
  p_user_id UUID DEFAULT NULL,
  p_session_id TEXT DEFAULT NULL,
  p_referrer TEXT DEFAULT NULL,
  p_user_agent TEXT DEFAULT NULL,
  p_ip_address INET DEFAULT NULL
) RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER AS $
DECLARE
  v_tenant_id UUID;
BEGIN
  -- Get tenant_id from article
  SELECT tenant_id INTO v_tenant_id FROM articles WHERE id = p_article_id;
  
  -- Insert analytics event
  INSERT INTO analytics_events (
    tenant_id,
    event_type,
    article_id,
    user_id,
    session_id,
    event_data,
    ip_address,
    user_agent,
    referrer,
    created_at
  ) VALUES (
    v_tenant_id,
    'article_view',
    p_article_id,
    p_user_id,
    p_session_id,
    jsonb_build_object(
      'referrer', p_referrer,
      'user_agent', p_user_agent,
      'timestamp', NOW()
    ),
    p_ip_address,
    p_user_agent,
    p_referrer,
    NOW()
  );
  
  -- Update article view count and last viewed timestamp
  UPDATE articles 
  SET 
    view_count = view_count + 1,
    last_viewed_at = NOW(),
    updated_at = NOW()
  WHERE id = p_article_id;
  
  -- Update daily stats
  INSERT INTO daily_stats (
    tenant_id,
    date,
    metric_type,
    metric_value,
    entity_type,
    entity_id,
    created_at,
    updated_at
  ) VALUES (
    v_tenant_id,
    CURRENT_DATE,
    'views',
    1,
    'article',
    p_article_id,
    NOW(),
    NOW()
  ) ON CONFLICT (tenant_id, date, metric_type, entity_type, entity_id)
  DO UPDATE SET
    metric_value = daily_stats.metric_value + 1,
    updated_at = NOW();
END;
$;

-- Function to calculate engagement metrics
CREATE OR REPLACE FUNCTION calculate_engagement_metrics(
  p_article_id UUID,
  p_time_period INTERVAL DEFAULT '30 days'
) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER AS $
DECLARE
  v_metrics JSONB;
  v_views INTEGER;
  v_unique_views INTEGER;
  v_avg_time_on_page NUMERIC;
  v_bounce_rate NUMERIC;
  v_social_shares INTEGER;
  v_comments INTEGER;
  v_engagement_score NUMERIC;
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
  
  -- Calculate engagement score
  v_engagement_score := COALESCE(
    (v_unique_views * 10 + v_social_shares * 50 + v_comments * 100) / 
    GREATEST(v_views, 1), 0
  );
  
  -- Build metrics object
  v_metrics := jsonb_build_object(
    'views', COALESCE(v_views, 0),
    'unique_views', COALESCE(v_unique_views, 0),
    'avg_time_on_page', COALESCE(v_avg_time_on_page, 0),
    'bounce_rate', COALESCE(v_bounce_rate, 0),
    'social_shares', COALESCE(v_social_shares, 0),
    'comments', COALESCE(v_comments, 0),
    'engagement_score', v_engagement_score,
    'calculated_at', NOW(),
    'period_days', EXTRACT(DAYS FROM p_time_period)
  );
  
  -- Update article engagement score
  UPDATE articles 
  SET 
    engagement_score = v_engagement_score,
    bounce_rate = COALESCE(v_bounce_rate, bounce_rate),
    social_shares = COALESCE(v_social_shares, social_shares),
    updated_at = NOW()
  WHERE id = p_article_id;
  
  RETURN v_metrics;
END;
$;

-- Function to generate performance report
CREATE OR REPLACE FUNCTION generate_performance_report(
  p_tenant_id UUID,
  p_start_date DATE DEFAULT CURRENT_DATE - INTERVAL '30 days',
  p_end_date DATE DEFAULT CURRENT_DATE,
  p_niche_id UUID DEFAULT NULL,
  p_limit INTEGER DEFAULT 10
) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER AS $
DECLARE
  v_report JSONB;
  v_top_articles JSONB;
  v_author_stats JSONB;
  v_niche_stats JSONB;
  v_summary JSONB;
BEGIN
  -- Get top performing articles
  SELECT jsonb_agg(
    jsonb_build_object(
      'id', a.id,
      'title', a.title,
      'slug', a.slug,
      'views', a.view_count,
      'engagement_score', a.engagement_score,
      'seo_score', a.seo_score,
      'revenue', COALESCE(rm.total_revenue, 0),
      'author', au.display_name,
      'niche', n.name,
      'published_at', a.published_at
    )
  ) INTO v_top_articles
  FROM articles a
  LEFT JOIN authors au ON a.author_id = au.id
  LEFT JOIN niches n ON a.niche_id = n.id
  LEFT JOIN revenue_metrics rm ON a.id = rm.article_id
  WHERE a.tenant_id = p_tenant_id
    AND a.published_at BETWEEN p_start_date AND p_end_date + INTERVAL '1 day'
    AND (p_niche_id IS NULL OR a.niche_id = p_niche_id)
    AND a.status = 'published'
  ORDER BY a.view_count DESC, a.engagement_score DESC
  LIMIT p_limit;
  
  -- Get author performance stats
  SELECT jsonb_agg(
    jsonb_build_object(
      'author_id', au.id,
      'display_name', au.display_name,
      'articles_count', COUNT(a.id),
      'total_views', SUM(a.view_count),
      'avg_engagement', AVG(a.engagement_score),
      'avg_seo_score', AVG(a.seo_score),
      'total_revenue', SUM(COALESCE(rm.total_revenue, 0))
    )
  ) INTO v_author_stats
  FROM authors au
  JOIN articles a ON au.id = a.author_id
  LEFT JOIN revenue_metrics rm ON a.id = rm.article_id
  WHERE au.tenant_id = p_tenant_id
    AND a.published_at BETWEEN p_start_date AND p_end_date + INTERVAL '1 day'
    AND (p_niche_id IS NULL OR a.niche_id = p_niche_id)
    AND a.status = 'published'
  GROUP BY au.id, au.display_name
  ORDER BY SUM(a.view_count) DESC
  LIMIT p_limit;
  
  -- Get niche performance stats
  SELECT jsonb_agg(
    jsonb_build_object(
      'niche_id', n.id,
      'name', n.name,
      'articles_count', COUNT(a.id),
      'total_views', SUM(a.view_count),
      'avg_quality_score', AVG(a.content_quality_score),
      'avg_seo_score', AVG(a.seo_score),
      'total_revenue', SUM(COALESCE(rm.total_revenue, 0))
    )
  ) INTO v_niche_stats
  FROM niches n
  JOIN articles a ON n.id = a.niche_id
  LEFT JOIN revenue_metrics rm ON a.id = rm.article_id
  WHERE n.tenant_id = p_tenant_id
    AND a.published_at BETWEEN p_start_date AND p_end_date + INTERVAL '1 day'
    AND (p_niche_id IS NULL OR a.niche_id = p_niche_id)
    AND a.status = 'published'
  GROUP BY n.id, n.name
  ORDER BY SUM(a.view_count) DESC;
  
  -- Generate summary statistics
  SELECT jsonb_build_object(
    'total_articles', COUNT(a.id),
    'total_views', SUM(a.view_count),
    'avg_engagement_score', AVG(a.engagement_score),
    'avg_seo_score', AVG(a.seo_score),
    'total_revenue', SUM(COALESCE(rm.total_revenue, 0)),
    'avg_revenue_per_article', AVG(COALESCE(rm.total_revenue, 0))
  ) INTO v_summary
  FROM articles a
  LEFT JOIN revenue_metrics rm ON a.id = rm.article_id
  WHERE a.tenant_id = p_tenant_id
    AND a.published_at BETWEEN p_start_date AND p_end_date + INTERVAL '1 day'
    AND (p_niche_id IS NULL OR a.niche_id = p_niche_id)
    AND a.status = 'published';
  
  -- Build final report
  v_report := jsonb_build_object(
    'period', jsonb_build_object(
      'start_date', p_start_date,
      'end_date', p_end_date,
      'days', p_end_date - p_start_date + 1
    ),
    'summary', COALESCE(v_summary, '{}'::jsonb),
    'top_articles', COALESCE(v_top_articles, '[]'::jsonb),
    'author_performance', COALESCE(v_author_stats, '[]'::jsonb),
    'niche_performance', COALESCE(v_niche_stats, '[]'::jsonb),
    'generated_at', NOW(),
    'tenant_id', p_tenant_id
  );
  
  RETURN v_report;
END;
$;

-- Function to track affiliate link click
CREATE OR REPLACE FUNCTION track_affiliate_click(
  p_link_id UUID,
  p_article_id UUID,
  p_user_id UUID DEFAULT NULL,
  p_session_id TEXT DEFAULT NULL,
  p_ip_address INET DEFAULT NULL,
  p_user_agent TEXT DEFAULT NULL,
  p_referrer TEXT DEFAULT NULL
) RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER AS $
DECLARE
  v_tenant_id UUID;
BEGIN
  -- Get tenant_id from article
  SELECT tenant_id INTO v_tenant_id FROM articles WHERE id = p_article_id;
  
  -- Insert click record
  INSERT INTO affiliate_clicks (
    link_id,
    article_id,
    user_id,
    session_id,
    ip_address,
    user_agent,
    referrer,
    clicked_at
  ) VALUES (
    p_link_id,
    p_article_id,
    p_user_id,
    p_session_id,
    p_ip_address,
    p_user_agent,
    p_referrer,
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
    tenant_id,
    event_type,
    article_id,
    user_id,
    session_id,
    event_data,
    ip_address,
    user_agent,
    referrer,
    created_at
  ) VALUES (
    v_tenant_id,
    'affiliate_click',
    p_article_id,
    p_user_id,
    p_session_id,
    jsonb_build_object(
      'link_id', p_link_id,
      'timestamp', NOW()
    ),
    p_ip_address,
    p_user_agent,
    p_referrer,
    NOW()
  );
END;
$;

-- Function to fetch performance data for AI analysis
CREATE OR REPLACE FUNCTION fetch_performance_data(
  p_tenant_id UUID,
  p_content_limit INTEGER DEFAULT 100,
  p_seo_limit INTEGER DEFAULT 75,
  p_revenue_limit INTEGER DEFAULT 75,
  p_days_back INTEGER DEFAULT 30
) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER AS $
DECLARE
  v_result JSONB;
  v_content_data JSONB;
  v_seo_data JSONB;
  v_revenue_data JSONB;
BEGIN
  -- Fetch content performance data
  SELECT jsonb_agg(
    jsonb_build_object(
      'id', a.id,
      'slug', a.slug,
      'title', a.title,
      'published_at', a.published_at,
      'updated_at', a.updated_at,
      'view_count', a.view_count,
      'engagement_score', a.engagement_score,
      'content_quality_score', a.content_quality_score,
      'word_count', a.word_count,
      'reading_time', a.reading_time,
      'bounce_rate', a.bounce_rate,
      'time_on_page', a.time_on_page,
      'social_shares', a.social_shares,
      'backlinks_count', a.backlinks_count,
      'niche_id', a.niche_id,
      'category_id', a.category_id,
      'niche_name', n.name,
      'category_name', c.name,
      'author_name', au.display_name,
      'daily_views', CASE 
        WHEN a.published_at IS NOT NULL THEN
          a.view_count / GREATEST(EXTRACT(EPOCH FROM (NOW() - a.published_at)) / 86400, 1)
        ELSE 0
      END,
      'share_rate', CASE 
        WHEN a.view_count > 0 THEN (a.social_shares::DECIMAL / a.view_count) * 100
        ELSE 0
      END
    )
  ) INTO v_content_data
  FROM articles a
  LEFT JOIN niches n ON a.niche_id = n.id
  LEFT JOIN categories c ON a.category_id = c.id
  LEFT JOIN authors au ON a.author_id = au.id
  WHERE a.tenant_id = p_tenant_id
    AND a.status = 'published'
    AND a.is_active = true
    AND a.published_at >= NOW() - INTERVAL '1 day' * p_days_back
  ORDER BY a.view_count DESC, a.engagement_score DESC
  LIMIT p_content_limit;

  -- Fetch SEO performance data
  SELECT jsonb_agg(
    jsonb_build_object(
      'id', a.id,
      'slug', a.slug,
      'title', a.title,
      'meta_title', a.meta_title,
      'meta_description', a.meta_description,
      'view_count', a.view_count,
      'engagement_score', a.engagement_score,
      'seo_score', COALESCE(sm.seo_score, 0),
      'accessibility_score', COALESCE(sm.accessibility_score, 0),
      'page_speed_score', COALESCE(sm.page_speed_score, 0),
      'meta_tags_complete', COALESCE(sm.meta_tags_complete, false),
      'structured_data_valid', COALESCE(sm.structured_data_valid, false),
      'keyword_density', COALESCE(sm.keyword_density, 0),
      'internal_links_count', COALESCE(sm.internal_links_count, 0),
      'external_links_count', COALESCE(sm.external_links_count, 0),
      'target_keywords', COALESCE(sm.target_keywords, ARRAY[]::TEXT[])
    )
  ) INTO v_seo_data
  FROM articles a
  LEFT JOIN seo_metrics sm ON a.id = sm.article_id
  WHERE a.tenant_id = p_tenant_id
    AND a.status = 'published'
    AND a.is_active = true
    AND a.published_at >= NOW() - INTERVAL '1 day' * p_days_back
  ORDER BY COALESCE(sm.seo_score, 0) ASC, a.view_count DESC
  LIMIT p_seo_limit;

  -- Fetch revenue performance data
  SELECT jsonb_agg(
    jsonb_build_object(
      'id', a.id,
      'slug', a.slug,
      'title', a.title,
      'view_count', a.view_count,
      'published_at', a.published_at,
      'total_revenue', COALESCE(rm.total_revenue, 0),
      'affiliate_revenue', COALESCE(rm.affiliate_revenue, 0),
      'ad_revenue', COALESCE(rm.ad_revenue, 0),
      'premium_revenue', COALESCE(rm.premium_revenue, 0),
      'conversion_rate', COALESCE(rm.conversion_rate, 0),
      'revenue_per_visitor', COALESCE(rm.revenue_per_visitor, 0),
      'monetization_efficiency', COALESCE(rm.monetization_efficiency, 0)
    )
  ) INTO v_revenue_data
  FROM articles a
  LEFT JOIN revenue_metrics rm ON a.id = rm.article_id
  WHERE a.tenant_id = p_tenant_id
    AND a.status = 'published'
    AND a.is_active = true
    AND a.published_at >= NOW() - INTERVAL '1 day' * p_days_back
  ORDER BY COALESCE(rm.total_revenue, 0) DESC, a.view_count DESC
  LIMIT p_revenue_limit;

  -- Build final result
  v_result := jsonb_build_object(
    'content_data', COALESCE(v_content_data, '[]'::jsonb),
    'seo_data', COALESCE(v_seo_data, '[]'::jsonb),
    'revenue_data', COALESCE(v_revenue_data, '[]'::jsonb),
    'metadata', jsonb_build_object(
      'timestamp', NOW(),
      'tenant_id', p_tenant_id,
      'content_limit', p_content_limit,
      'seo_limit', p_seo_limit,
      'revenue_limit', p_revenue_limit,
      'days_back', p_days_back
    )
  );

  RETURN v_result;
END;
$;

-- Function to update revenue metrics
CREATE OR REPLACE FUNCTION update_revenue_metrics(
  p_article_id UUID,
  p_total_revenue NUMERIC DEFAULT NULL,
  p_affiliate_revenue NUMERIC DEFAULT NULL,
  p_ad_revenue NUMERIC DEFAULT NULL,
  p_premium_revenue NUMERIC DEFAULT NULL,
  p_conversion_rate NUMERIC DEFAULT NULL,
  p_revenue_per_visitor NUMERIC DEFAULT NULL,
  p_monetization_efficiency NUMERIC DEFAULT NULL
) RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER AS $
DECLARE
  v_metric_id UUID;
BEGIN
  INSERT INTO revenue_metrics (
    article_id,
    total_revenue,
    affiliate_revenue,
    ad_revenue,
    premium_revenue,
    conversion_rate,
    revenue_per_visitor,
    monetization_efficiency,
    updated_at
  ) VALUES (
    p_article_id,
    COALESCE(p_total_revenue, 0),
    COALESCE(p_affiliate_revenue, 0),
    COALESCE(p_ad_revenue, 0),
    COALESCE(p_premium_revenue, 0),
    COALESCE(p_conversion_rate, 0),
    COALESCE(p_revenue_per_visitor, 0),
    COALESCE(p_monetization_efficiency, 0),
    NOW()
  ) ON CONFLICT (article_id)
  DO UPDATE SET
    total_revenue = COALESCE(EXCLUDED.total_revenue, revenue_metrics.total_revenue),
    affiliate_revenue = COALESCE(EXCLUDED.affiliate_revenue, revenue_metrics.affiliate_revenue),
    ad_revenue = COALESCE(EXCLUDED.ad_revenue, revenue_metrics.ad_revenue),
    premium_revenue = COALESCE(EXCLUDED.premium_revenue, revenue_metrics.premium_revenue),
    conversion_rate = COALESCE(EXCLUDED.conversion_rate, revenue_metrics.conversion_rate),
    revenue_per_visitor = COALESCE(EXCLUDED.revenue_per_visitor, revenue_metrics.revenue_per_visitor),
    monetization_efficiency = COALESCE(EXCLUDED.monetization_efficiency, revenue_metrics.monetization_efficiency),
    updated_at = NOW()
  RETURNING id INTO v_metric_id;

  RETURN v_metric_id;
END;
$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION update_seo_metrics TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION track_article_view TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION calculate_engagement_metrics TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION generate_performance_report TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION track_affiliate_click TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION fetch_performance_data TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION update_revenue_metrics TO authenticated, service_role;