-- ============================================================================
-- INITIAL MIGRATION - ALLIXIOS NEW ARCHITECTURE
-- Creates the complete database schema with all tables, functions, and indexes
-- ============================================================================

-- Migration metadata
INSERT INTO schema_migrations (version, description, applied_at) 
VALUES ('001', 'Initial schema creation', NOW())
ON CONFLICT (version) DO NOTHING;

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
CREATE EXTENSION IF NOT EXISTS "btree_gin";

-- Create schema migrations table if it doesn't exist
CREATE TABLE IF NOT EXISTS schema_migrations (
  version VARCHAR(50) PRIMARY KEY,
  description TEXT,
  applied_at TIMESTAMPTZ DEFAULT NOW()
);

-- Apply core schema
\i 001_core_schema.sql

-- Apply functions
\i ../functions/001_content_functions.sql
\i ../functions/002_analytics_functions.sql
\i ../functions/003_entity_functions.sql
\i ../functions/004_workflow_functions.sql
\i ../functions/005_media_functions.sql

-- ============================================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================================================

-- Enable RLS on all tables
ALTER TABLE tenants ENABLE ROW LEVEL SECURITY;
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE niches ENABLE ROW LEVEL SECURITY;
ALTER TABLE categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE authors ENABLE ROW LEVEL SECURITY;
ALTER TABLE tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE media ENABLE ROW LEVEL SECURITY;
ALTER TABLE articles ENABLE ROW LEVEL SECURITY;
ALTER TABLE article_tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE article_media ENABLE ROW LEVEL SECURITY;
ALTER TABLE topics_queue ENABLE ROW LEVEL SECURITY;
ALTER TABLE content_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE content_versions ENABLE ROW LEVEL SECURITY;
ALTER TABLE translations ENABLE ROW LEVEL SECURITY;
ALTER TABLE analytics_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE seo_metrics ENABLE ROW LEVEL SECURITY;
ALTER TABLE affiliate_programs ENABLE ROW LEVEL SECURITY;
ALTER TABLE affiliate_links ENABLE ROW LEVEL SECURITY;
ALTER TABLE affiliate_clicks ENABLE ROW LEVEL SECURITY;
ALTER TABLE revenue_metrics ENABLE ROW LEVEL SECURITY;
ALTER TABLE ab_experiments ENABLE ROW LEVEL SECURITY;
ALTER TABLE ab_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_bookmarks ENABLE ROW LEVEL SECURITY;
ALTER TABLE newsletter_subscribers ENABLE ROW LEVEL SECURITY;
ALTER TABLE newsletter_campaigns ENABLE ROW LEVEL SECURITY;
ALTER TABLE smart_cache ENABLE ROW LEVEL SECURITY;
ALTER TABLE performance_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE api_rate_limits ENABLE ROW LEVEL SECURITY;
ALTER TABLE dead_letter_queue ENABLE ROW LEVEL SECURITY;
ALTER TABLE daily_stats ENABLE ROW LEVEL SECURITY;
ALTER TABLE entity_resolution_cache ENABLE ROW LEVEL SECURITY;
ALTER TABLE workflow_states ENABLE ROW LEVEL SECURITY;
ALTER TABLE n8n_executions ENABLE ROW LEVEL SECURITY;
ALTER TABLE n8n_execution_nodes ENABLE ROW LEVEL SECURITY;
ALTER TABLE n8n_performance_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE performance_intelligence_cache ENABLE ROW LEVEL SECURITY;
ALTER TABLE media_variants ENABLE ROW LEVEL SECURITY;
ALTER TABLE media_processing_queue ENABLE ROW LEVEL SECURITY;
ALTER TABLE media_collections ENABLE ROW LEVEL SECURITY;
ALTER TABLE media_collection_items ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- BASIC RLS POLICIES
-- ============================================================================

-- Tenants: Users can only see their own tenant
CREATE POLICY "Users can access their tenant" ON tenants
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM users 
      WHERE users.tenant_id = tenants.id 
      AND users.id::text = auth.uid()::text
    )
  );

-- Users: Users can see their own data and public profiles
CREATE POLICY "Users can view their own data" ON users
  FOR SELECT USING (id::text = auth.uid()::text);

CREATE POLICY "Users can update their own data" ON users
  FOR UPDATE USING (id::text = auth.uid()::text);

-- Articles: Published articles are public, drafts are author-only
CREATE POLICY "Published articles are viewable by all" ON articles
  FOR SELECT USING (
    status = 'published' 
    OR author_id IN (
      SELECT a.id FROM authors a 
      JOIN users u ON a.user_id = u.id 
      WHERE u.id::text = auth.uid()::text
    )
  );

CREATE POLICY "Authors can manage their articles" ON articles
  FOR ALL USING (
    author_id IN (
      SELECT a.id FROM authors a 
      JOIN users u ON a.user_id = u.id 
      WHERE u.id::text = auth.uid()::text
    )
  );

-- Niches, Categories, Tags: Public read, authenticated write
CREATE POLICY "Public can view niches" ON niches FOR SELECT USING (true);
CREATE POLICY "Authenticated can manage niches" ON niches 
  FOR ALL USING (auth.uid() IS NOT NULL);

CREATE POLICY "Public can view categories" ON categories FOR SELECT USING (true);
CREATE POLICY "Authenticated can manage categories" ON categories 
  FOR ALL USING (auth.uid() IS NOT NULL);

CREATE POLICY "Public can view tags" ON tags FOR SELECT USING (true);
CREATE POLICY "Authenticated can manage tags" ON tags 
  FOR ALL USING (auth.uid() IS NOT NULL);

-- Authors: Public read, own data write
CREATE POLICY "Public can view authors" ON authors FOR SELECT USING (true);
CREATE POLICY "Authors can update their profile" ON authors
  FOR UPDATE USING (
    user_id IN (
      SELECT id FROM users WHERE id::text = auth.uid()::text
    )
  );

-- Media: Public read for active media, authenticated write
CREATE POLICY "Public can view active media" ON media 
  FOR SELECT USING (is_active = true);
CREATE POLICY "Authenticated can manage media" ON media 
  FOR ALL USING (auth.uid() IS NOT NULL);

-- Media Variants: Follow media access
CREATE POLICY "Media variants follow media access" ON media_variants
  FOR ALL USING (
    media_id IN (
      SELECT id FROM media WHERE is_active = true
    )
  );

-- Media Processing Queue: System and authenticated users
CREATE POLICY "System can manage media processing" ON media_processing_queue
  FOR ALL USING (auth.uid() IS NOT NULL);

-- Media Collections: Public read, authenticated write
CREATE POLICY "Public can view public collections" ON media_collections
  FOR SELECT USING (is_public = true);
CREATE POLICY "Users can manage their collections" ON media_collections
  FOR ALL USING (
    created_by IN (
      SELECT id FROM users WHERE id::text = auth.uid()::text
    )
  );

-- Media Collection Items: Follow collection access
CREATE POLICY "Collection items follow collection access" ON media_collection_items
  FOR ALL USING (
    collection_id IN (
      SELECT id FROM media_collections WHERE 
        is_public = true 
        OR created_by IN (
          SELECT id FROM users WHERE id::text = auth.uid()::text
        )
    )
  );

-- Analytics: System can insert, admins can view
CREATE POLICY "System can insert analytics" ON analytics_events
  FOR INSERT WITH CHECK (true);
CREATE POLICY "Admins can view analytics" ON analytics_events
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM users 
      WHERE id::text = auth.uid()::text 
      AND role IN ('admin', 'super_admin')
    )
  );

-- SEO Metrics: Linked to articles
CREATE POLICY "SEO metrics follow article access" ON seo_metrics
  FOR ALL USING (
    article_id IN (
      SELECT id FROM articles WHERE 
        status = 'published' 
        OR author_id IN (
          SELECT a.id FROM authors a 
          JOIN users u ON a.user_id = u.id 
          WHERE u.id::text = auth.uid()::text
        )
    )
  );

-- Revenue Metrics: Restricted to authorized users
CREATE POLICY "Revenue metrics for authorized users" ON revenue_metrics
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM users 
      WHERE id::text = auth.uid()::text 
      AND role IN ('admin', 'super_admin')
    )
    OR article_id IN (
      SELECT a.id FROM articles a
      JOIN authors au ON a.author_id = au.id
      JOIN users u ON au.user_id = u.id
      WHERE u.id::text = auth.uid()::text
    )
  );

-- User Comments: Users can manage their own comments
CREATE POLICY "Users can view approved comments" ON user_comments
  FOR SELECT USING (status = 'approved');
CREATE POLICY "Users can manage their comments" ON user_comments
  FOR ALL USING (user_id::text = auth.uid()::text);

-- User Bookmarks: Users can only see their own bookmarks
CREATE POLICY "Users can manage their bookmarks" ON user_bookmarks
  FOR ALL USING (user_id::text = auth.uid()::text);

-- Workflow data: Authenticated users only
CREATE POLICY "Authenticated can access workflows" ON topics_queue
  FOR ALL USING (auth.uid() IS NOT NULL);
CREATE POLICY "Authenticated can access workflow states" ON workflow_states
  FOR ALL USING (auth.uid() IS NOT NULL);

-- ============================================================================
-- TRIGGERS FOR AUTOMATIC UPDATES
-- ============================================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$ LANGUAGE plpgsql;

-- Apply updated_at triggers to relevant tables
CREATE TRIGGER update_tenants_updated_at BEFORE UPDATE ON tenants
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_niches_updated_at BEFORE UPDATE ON niches
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_categories_updated_at BEFORE UPDATE ON categories
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_authors_updated_at BEFORE UPDATE ON authors
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_tags_updated_at BEFORE UPDATE ON tags
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_media_updated_at BEFORE UPDATE ON media
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_articles_updated_at BEFORE UPDATE ON articles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_topics_queue_updated_at BEFORE UPDATE ON topics_queue
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_content_plans_updated_at BEFORE UPDATE ON content_plans
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_translations_updated_at BEFORE UPDATE ON translations
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_affiliate_programs_updated_at BEFORE UPDATE ON affiliate_programs
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_affiliate_links_updated_at BEFORE UPDATE ON affiliate_links
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_revenue_metrics_updated_at BEFORE UPDATE ON revenue_metrics
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_ab_experiments_updated_at BEFORE UPDATE ON ab_experiments
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_user_comments_updated_at BEFORE UPDATE ON user_comments
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_newsletter_subscribers_updated_at BEFORE UPDATE ON newsletter_subscribers
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_newsletter_campaigns_updated_at BEFORE UPDATE ON newsletter_campaigns
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_smart_cache_updated_at BEFORE UPDATE ON smart_cache
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_api_rate_limits_updated_at BEFORE UPDATE ON api_rate_limits
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_dead_letter_queue_updated_at BEFORE UPDATE ON dead_letter_queue
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_daily_stats_updated_at BEFORE UPDATE ON daily_stats
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_workflow_states_updated_at BEFORE UPDATE ON workflow_states
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- INITIAL DATA SEEDING
-- ============================================================================

-- Create default tenant (for single-tenant deployments)
INSERT INTO tenants (id, name, slug, domain, is_active, created_at, updated_at)
VALUES (
  '00000000-0000-0000-0000-000000000001',
  'Default Tenant',
  'default',
  'localhost',
  true,
  NOW(),
  NOW()
) ON CONFLICT (id) DO NOTHING;

-- Create default niches
INSERT INTO niches (tenant_id, name, slug, description, is_active, created_at, updated_at)
VALUES 
  ('00000000-0000-0000-0000-000000000001', 'Technology', 'technology', 'Technology and software content', true, NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000001', 'Health & Wellness', 'health-wellness', 'Health, fitness, and wellness content', true, NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000001', 'Business', 'business', 'Business and entrepreneurship content', true, NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000001', 'Lifestyle', 'lifestyle', 'Lifestyle and personal development content', true, NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000001', 'Finance', 'finance', 'Finance and investment content', true, NOW(), NOW())
ON CONFLICT (tenant_id, slug) DO NOTHING;

-- Create default categories
WITH niche_ids AS (
  SELECT id, slug FROM niches WHERE tenant_id = '00000000-0000-0000-0000-000000000001'
)
INSERT INTO categories (tenant_id, niche_id, name, slug, description, is_active, created_at, updated_at)
SELECT 
  '00000000-0000-0000-0000-000000000001',
  n.id,
  category_data.name,
  category_data.slug,
  category_data.description,
  true,
  NOW(),
  NOW()
FROM niche_ids n
CROSS JOIN (
  VALUES 
    ('Programming', 'programming', 'Software development and programming'),
    ('AI & Machine Learning', 'ai-machine-learning', 'Artificial intelligence and ML content'),
    ('Web Development', 'web-development', 'Web development tutorials and guides'),
    ('Mobile Apps', 'mobile-apps', 'Mobile application development'),
    ('DevOps', 'devops', 'DevOps and infrastructure content')
) AS category_data(name, slug, description)
WHERE n.slug = 'technology'

UNION ALL

SELECT 
  '00000000-0000-0000-0000-000000000001',
  n.id,
  category_data.name,
  category_data.slug,
  category_data.description,
  true,
  NOW(),
  NOW()
FROM niche_ids n
CROSS JOIN (
  VALUES 
    ('Nutrition', 'nutrition', 'Nutrition and diet content'),
    ('Fitness', 'fitness', 'Exercise and fitness guides'),
    ('Mental Health', 'mental-health', 'Mental health and wellness'),
    ('Medical', 'medical', 'Medical information and health tips'),
    ('Wellness', 'wellness', 'General wellness and lifestyle')
) AS category_data(name, slug, description)
WHERE n.slug = 'health-wellness'
ON CONFLICT (tenant_id, niche_id, slug) DO NOTHING;

-- Create default tags
INSERT INTO tags (tenant_id, name, slug, description, category, is_active, created_at, updated_at)
VALUES 
  ('00000000-0000-0000-0000-000000000001', 'Tutorial', 'tutorial', 'Step-by-step tutorials', 'content', true, NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000001', 'Guide', 'guide', 'Comprehensive guides', 'content', true, NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000001', 'Tips', 'tips', 'Quick tips and tricks', 'content', true, NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000001', 'Review', 'review', 'Product and service reviews', 'content', true, NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000001', 'News', 'news', 'Latest news and updates', 'content', true, NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000001', 'Beginner', 'beginner', 'Beginner-friendly content', 'difficulty', true, NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000001', 'Advanced', 'advanced', 'Advanced level content', 'difficulty', true, NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000001', 'JavaScript', 'javascript', 'JavaScript programming', 'technology', true, NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000001', 'Python', 'python', 'Python programming', 'technology', true, NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000001', 'React', 'react', 'React framework', 'technology', true, NOW(), NOW())
ON CONFLICT (tenant_id, slug) DO NOTHING;

-- Create default author
INSERT INTO authors (tenant_id, display_name, slug, bio, is_active, created_at, updated_at)
VALUES (
  '00000000-0000-0000-0000-000000000001',
  'AI Assistant',
  'ai-assistant',
  'AI-powered content creator specializing in technology and business content.',
  true,
  NOW(),
  NOW()
) ON CONFLICT (tenant_id, slug) DO NOTHING;

-- ============================================================================
-- PERFORMANCE OPTIMIZATIONS
-- ============================================================================

-- Analyze tables for query planner
ANALYZE;

-- Update table statistics
UPDATE pg_stat_user_tables SET n_tup_ins = 0, n_tup_upd = 0, n_tup_del = 0;

-- ============================================================================
-- COMPLETION LOG
-- ============================================================================

-- Log successful migration
INSERT INTO schema_migrations (version, description, applied_at) 
VALUES ('001_complete', 'Initial migration completed successfully', NOW())
ON CONFLICT (version) DO UPDATE SET applied_at = NOW();

-- Migration summary
DO $
BEGIN
  RAISE NOTICE 'Migration 001 completed successfully!';
  RAISE NOTICE 'Created % tables', (
    SELECT COUNT(*) FROM information_schema.tables 
    WHERE table_schema = 'public' AND table_type = 'BASE TABLE'
  );
  RAISE NOTICE 'Created % functions', (
    SELECT COUNT(*) FROM information_schema.routines 
    WHERE routine_schema = 'public' AND routine_type = 'FUNCTION'
  );
  RAISE NOTICE 'Created % indexes', (
    SELECT COUNT(*) FROM pg_indexes WHERE schemaname = 'public'
  );
END;
$;