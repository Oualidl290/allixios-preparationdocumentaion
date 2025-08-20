-- Performance Intelligence Database Functions
-- Supporting functions for Workflow 4: Performance Intelligence Engine

-- ============================================================================
-- PERFORMANCE METRICS TABLES
-- ============================================================================

-- SEO Metrics table (if not exists)
CREATE TABLE IF NOT EXISTS seo_metrics (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  article_id UUID NOT NULL REFERENCES articles(id) ON DELETE CASCADE,
  seo_score INTEGER DEFAULT 0 CHECK (seo_score >= 0 AND seo_score <= 100),
  accessibility_score INTEGER DEFAULT 0 CHECK (accessibility_score >= 0 AND accessibility_score <= 100),
  page_speed_score INTEGER DEFAULT 0 CHECK (page_speed_score >= 0 AND page_speed_score <= 100),
  meta_tags_complete BOOLEAN DEFAULT FALSE,
  structured_data_valid BOOLEAN DEFAULT FALSE,
  keyword_density DECIMAL(5,2) DEFAULT 0.0,
  internal_links_count INTEGER DEFAULT 0,
  external_links_count INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(article_id)
);

-- Revenue Metrics table (if not exists)
CREATE TABLE IF NOT EXISTS revenue_metrics (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  article_id UUID NOT NULL REFERENCES articles(id) ON DELETE CASCADE,
  total_revenue DECIMAL(10,2) DEFAULT 0.00,
  affiliate_revenue DECIMAL(10,2) DEFAULT 0.00,
  ad_revenue DECIMAL(10,2) DEFAULT 0.00,
  premium_revenue DECIMAL(10,2) DEFAULT 0.00,
  conversion_rate DECIMAL(5,2) DEFAULT 0.00,
  revenue_per_visitor DECIMAL(8,4) DEFAULT 0.0000,
  monetization_efficiency DECIMAL(5,2) DEFAULT 0.00,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(article_id)
);

-- Performance Intelligence Cache table
CREATE TABLE IF NOT EXISTS performance_intelligence_cache (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  cache_key TEXT NOT NULL UNIQUE,
  analysis_data JSONB NOT NULL,
  confidence_scores JSONB,
  predictions JSONB,
  anomalies JSONB,
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- PERFORMANCE INDEXES
-- ============================================================================

-- SEO Metrics indexes
CREATE INDEX IF NOT EXISTS idx_seo_metrics_article_id ON seo_metrics(article_id);
CREATE INDEX IF NOT EXISTS idx_seo_metrics_score ON seo_metrics(seo_score DESC);
CREATE INDEX IF NOT EXISTS idx_seo_metrics_updated ON seo_metrics(updated_at DESC);

-- Revenue Metrics indexes
CREATE INDEX IF NOT EXISTS idx_revenue_metrics_article_id ON revenue_metrics(article_id);
CREATE INDEX IF NOT EXISTS idx_revenue_metrics_total ON revenue_metrics(total_revenue DESC);
CREATE INDEX IF NOT EXISTS idx_revenue_metrics_efficiency ON revenue_metrics(monetization_efficiency DESC);

-- Performance cache indexes
CREATE INDEX IF NOT EXISTS idx_performance_cache_key ON performance_intelligence_cache(cache_key);
CREATE INDEX IF NOT EXISTS idx_performance_cache_expires ON performance_intelligence_cache(expires_at);

-- ============================================================================
-- PERFORMANCE INTELLIGENCE FUNCTIONS
-- ============================================================================

-- Function to fetch performance data (RPC endpoint)
CREATE OR REPLACE FUNCTION fetch_performance_data(
  p_content_limit INTEGER DEFAULT 100,
  p_seo_limit INTEGER DEFAULT 75,
  p_revenue_limit INTEGER DEFAULT 75,
  p_days_back INTEGER DEFAULT 30
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  result JSON;
  content_data JSON;
  seo_data JSON;
  revenue_data JSON;
BEGIN
  -- Fetch content performance data
  SELECT json_agg(
    json_build_object(
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
  ) INTO content_data
  FROM articles a
  LEFT JOIN niches n ON a.niche_id = n.id
  LEFT JOIN categories c ON a.category_id = c.id
  LEFT JOIN authors au ON a.author_id = au.id
  WHERE a.status = 'published'
    AND a.is_active = true
    AND a.published_at >= NOW() - INTERVAL '1 day' * p_days_back
  ORDER BY a.view_count DESC, a.engagement_score DESC
  LIMIT p_content_limit;

  -- Fetch SEO performance data
  SELECT json_agg(
    json_build_object(
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
      'external_links_count', COALESCE(sm.external_links_count, 0)
    )
  ) INTO seo_data
  FROM articles a
  LEFT JOIN seo_metrics sm ON a.id = sm.article_id
  WHERE a.status = 'published'
    AND a.is_active = true
    AND a.published_at >= NOW() - INTERVAL '1 day' * p_days_back
  ORDER BY COALESCE(sm.seo_score, 0) ASC, a.view_count DESC
  LIMIT p_seo_limit;

  -- Fetch revenue performance data
  SELECT json_agg(
    json_build_object(
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
  ) INTO revenue_data
  FROM articles a
  LEFT JOIN revenue_metrics rm ON a.id = rm.article_id
  WHERE a.status = 'published'
    AND a.is_active = true
    AND a.published_at >= NOW() - INTERVAL '1 day' * p_days_back
  ORDER BY COALESCE(rm.total_revenue, 0) DESC, a.view_count DESC
  LIMIT p_revenue_limit;

  -- Build final result
  result := json_build_object(
    'content_data', COALESCE(content_data, '[]'::json),
    'seo_data', COALESCE(seo_data, '[]'::json),
    'revenue_data', COALESCE(revenue_data, '[]'::json),
    'metadata', json_build_object(
      'timestamp', NOW(),
      'content_limit', p_content_limit,
      'seo_limit', p_seo_limit,
      'revenue_limit', p_revenue_limit,
      'days_back', p_days_back
    )
  );

  RETURN result;
END;
$$;

-- Function to update SEO metrics
CREATE OR REPLACE FUNCTION upsert_seo_metrics(
  p_article_id UUID,
  p_seo_score INTEGER,
  p_accessibility_score INTEGER DEFAULT NULL,
  p_page_speed_score INTEGER DEFAULT NULL,
  p_meta_tags_complete BOOLEAN DEFAULT NULL,
  p_structured_data_valid BOOLEAN DEFAULT NULL,
  p_keyword_density DECIMAL DEFAULT NULL,
  p_internal_links_count INTEGER DEFAULT NULL,
  p_external_links_count INTEGER DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  metric_id UUID;
BEGIN
  INSERT INTO seo_metrics (
    article_id, seo_score, accessibility_score, page_speed_score,
    meta_tags_complete, structured_data_valid, keyword_density,
    internal_links_count, external_links_count, updated_at
  )
  VALUES (
    p_article_id, p_seo_score, p_accessibility_score, p_page_speed_score,
    p_meta_tags_complete, p_structured_data_valid, p_keyword_density,
    p_internal_links_count, p_external_links_count, NOW()
  )
  ON CONFLICT (article_id) DO UPDATE SET
    seo_score = EXCLUDED.seo_score,
    accessibility_score = COALESCE(EXCLUDED.accessibility_score, seo_metrics.accessibility_score),
    page_speed_score = COALESCE(EXCLUDED.page_speed_score, seo_metrics.page_speed_score),
    meta_tags_complete = COALESCE(EXCLUDED.meta_tags_complete, seo_metrics.meta_tags_complete),
    structured_data_valid = COALESCE(EXCLUDED.structured_data_valid, seo_metrics.structured_data_valid),
    keyword_density = COALESCE(EXCLUDED.keyword_density, seo_metrics.keyword_density),
    internal_links_count = COALESCE(EXCLUDED.internal_links_count, seo_metrics.internal_links_count),
    external_links_count = COALESCE(EXCLUDED.external_links_count, seo_metrics.external_links_count),
    updated_at = NOW()
  RETURNING id INTO metric_id;

  RETURN metric_id;
END;
$$;

-- Function to update revenue metrics
CREATE OR REPLACE FUNCTION upsert_revenue_metrics(
  p_article_id UUID,
  p_total_revenue DECIMAL DEFAULT NULL,
  p_affiliate_revenue DECIMAL DEFAULT NULL,
  p_ad_revenue DECIMAL DEFAULT NULL,
  p_premium_revenue DECIMAL DEFAULT NULL,
  p_conversion_rate DECIMAL DEFAULT NULL,
  p_revenue_per_visitor DECIMAL DEFAULT NULL,
  p_monetization_efficiency DECIMAL DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  metric_id UUID;
BEGIN
  INSERT INTO revenue_metrics (
    article_id, total_revenue, affiliate_revenue, ad_revenue, premium_revenue,
    conversion_rate, revenue_per_visitor, monetization_efficiency, updated_at
  )
  VALUES (
    p_article_id, p_total_revenue, p_affiliate_revenue, p_ad_revenue, p_premium_revenue,
    p_conversion_rate, p_revenue_per_visitor, p_monetization_efficiency, NOW()
  )
  ON CONFLICT (article_id) DO UPDATE SET
    total_revenue = COALESCE(EXCLUDED.total_revenue, revenue_metrics.total_revenue),
    affiliate_revenue = COALESCE(EXCLUDED.affiliate_revenue, revenue_metrics.affiliate_revenue),
    ad_revenue = COALESCE(EXCLUDED.ad_revenue, revenue_metrics.ad_revenue),
    premium_revenue = COALESCE(EXCLUDED.premium_revenue, revenue_metrics.premium_revenue),
    conversion_rate = COALESCE(EXCLUDED.conversion_rate, revenue_metrics.conversion_rate),
    revenue_per_visitor = COALESCE(EXCLUDED.revenue_per_visitor, revenue_metrics.revenue_per_visitor),
    monetization_efficiency = COALESCE(EXCLUDED.monetization_efficiency, revenue_metrics.monetization_efficiency),
    updated_at = NOW()
  RETURNING id INTO metric_id;

  RETURN metric_id;
END;
$$;

-- Function to cache performance intelligence results
CREATE OR REPLACE FUNCTION cache_performance_intelligence(
  p_cache_key TEXT,
  p_analysis_data JSONB,
  p_confidence_scores JSONB DEFAULT NULL,
  p_predictions JSONB DEFAULT NULL,
  p_anomalies JSONB DEFAULT NULL,
  p_ttl_hours INTEGER DEFAULT 1
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  cache_id UUID;
BEGIN
  INSERT INTO performance_intelligence_cache (
    cache_key, analysis_data, confidence_scores, predictions, anomalies,
    expires_at, updated_at
  )
  VALUES (
    p_cache_key, p_analysis_data, p_confidence_scores, p_predictions, p_anomalies,
    NOW() + INTERVAL '1 hour' * p_ttl_hours, NOW()
  )
  ON CONFLICT (cache_key) DO UPDATE SET
    analysis_data = EXCLUDED.analysis_data,
    confidence_scores = EXCLUDED.confidence_scores,
    predictions = EXCLUDED.predictions,
    anomalies = EXCLUDED.anomalies,
    expires_at = EXCLUDED.expires_at,
    updated_at = NOW()
  RETURNING id INTO cache_id;

  RETURN cache_id;
END;
$$;

-- Function to get cached performance intelligence
CREATE OR REPLACE FUNCTION get_cached_performance_intelligence(p_cache_key TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  cached_data JSONB;
BEGIN
  SELECT json_build_object(
    'analysis_data', analysis_data,
    'confidence_scores', confidence_scores,
    'predictions', predictions,
    'anomalies', anomalies,
    'cached_at', created_at,
    'expires_at', expires_at
  )
  INTO cached_data
  FROM performance_intelligence_cache
  WHERE cache_key = p_cache_key
    AND expires_at > NOW();

  RETURN cached_data;
END;
$$;

-- Cleanup function for expired cache entries
CREATE OR REPLACE FUNCTION cleanup_expired_performance_cache()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  deleted_count INTEGER;
BEGIN
  DELETE FROM performance_intelligence_cache
  WHERE expires_at <= NOW();
  
  GET DIAGNOSTICS deleted_count = ROW_COUNT;
  
  RETURN deleted_count;
END;
$$;

-- ============================================================================
-- TRIGGERS AND AUTOMATION
-- ============================================================================

-- Trigger to update article updated_at when metrics change
CREATE OR REPLACE FUNCTION update_article_metrics_timestamp()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  UPDATE articles 
  SET updated_at = NOW() 
  WHERE id = NEW.article_id;
  
  RETURN NEW;
END;
$$;

-- Apply triggers
DROP TRIGGER IF EXISTS trigger_seo_metrics_update ON seo_metrics;
CREATE TRIGGER trigger_seo_metrics_update
  AFTER INSERT OR UPDATE ON seo_metrics
  FOR EACH ROW
  EXECUTE FUNCTION update_article_metrics_timestamp();

DROP TRIGGER IF EXISTS trigger_revenue_metrics_update ON revenue_metrics;
CREATE TRIGGER trigger_revenue_metrics_update
  AFTER INSERT OR UPDATE ON revenue_metrics
  FOR EACH ROW
  EXECUTE FUNCTION update_article_metrics_timestamp();

-- ============================================================================
-- GRANTS AND PERMISSIONS
-- ============================================================================

-- Grant necessary permissions for the service role
GRANT USAGE ON SCHEMA public TO service_role;
GRANT ALL ON ALL TABLES IN SCHEMA public TO service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO service_role;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO service_role;

COMMIT;