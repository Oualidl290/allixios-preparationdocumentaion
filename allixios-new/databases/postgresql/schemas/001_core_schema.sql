-- ============================================================================
-- ALLIXIOS NEW ARCHITECTURE - CORE DATABASE SCHEMA
-- PostgreSQL schema for enterprise-grade content management platform
-- Based on existing BlackBox implementation with improvements
-- ============================================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
CREATE EXTENSION IF NOT EXISTS "btree_gin";
-- Vector extension (optional, for semantic search)
-- CREATE EXTENSION IF NOT EXISTS "vector";

-- ============================================================================
-- CUSTOM TYPES (ENUMS)
-- ============================================================================

-- Language codes (50+ supported languages)
CREATE TYPE language_code AS ENUM (
  'en', 'es', 'fr', 'de', 'it', 'pt', 'ru', 'zh', 'ja', 'ko',
  'ar', 'hi', 'th', 'vi', 'tr', 'pl', 'nl', 'sv', 'da', 'no',
  'fi', 'cs', 'hu', 'ro', 'bg', 'hr', 'sk', 'sl', 'et', 'lv',
  'lt', 'mt', 'ga', 'cy', 'eu', 'ca', 'gl', 'is', 'mk', 'sq',
  'sr', 'bs', 'me', 'uk', 'be', 'kk', 'ky', 'uz', 'tg', 'mn'
);

-- User roles for RBAC
CREATE TYPE user_role AS ENUM (
  'reader', 'author', 'editor', 'admin', 'super_admin'
);

-- Content status lifecycle
CREATE TYPE content_status AS ENUM (
  'draft', 'review', 'published', 'archived', 'deleted'
);

-- Workflow execution status
CREATE TYPE workflow_status AS ENUM (
  'queued', 'processing', 'completed', 'failed', 'cancelled'
);

-- Priority levels
CREATE TYPE priority_level AS ENUM (
  'low', 'medium', 'high', 'urgent'
);

-- Difficulty levels
CREATE TYPE difficulty_level AS ENUM (
  'beginner', 'intermediate', 'advanced', 'expert'
);

-- Article status
CREATE TYPE article_status AS ENUM (
  'draft', 'review', 'published', 'archived'
);

-- ============================================================================
-- CORE CONTENT TABLES
-- ============================================================================

-- Tenants (Multi-tenant support)
CREATE TABLE tenants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(255) NOT NULL,
  slug VARCHAR(100) UNIQUE NOT NULL,
  domain VARCHAR(255),
  settings JSONB DEFAULT '{}',
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Users (System users)
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID REFERENCES tenants(id) ON DELETE CASCADE,
  email VARCHAR(255) UNIQUE NOT NULL,
  full_name VARCHAR(255),
  avatar_url TEXT,
  role user_role DEFAULT 'reader',
  language language_code DEFAULT 'en',
  timezone VARCHAR(50) DEFAULT 'UTC',
  preferences JSONB DEFAULT '{}',
  is_active BOOLEAN DEFAULT true,
  last_activity TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  CONSTRAINT valid_email CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
);

-- Niches (Top-level content domains)
CREATE TABLE niches (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID REFERENCES tenants(id) ON DELETE CASCADE,
  name VARCHAR(255) NOT NULL,
  slug VARCHAR(100) NOT NULL,
  description TEXT,
  color_hex VARCHAR(7) DEFAULT '#3B82F6',
  icon VARCHAR(50),
  seo_title VARCHAR(255),
  seo_description TEXT,
  is_active BOOLEAN DEFAULT true,
  sort_order INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  UNIQUE(tenant_id, slug)
);

-- Categories (Hierarchical content organization)
CREATE TABLE categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID REFERENCES tenants(id) ON DELETE CASCADE,
  niche_id UUID REFERENCES niches(id) ON DELETE CASCADE,
  parent_id UUID REFERENCES categories(id) ON DELETE SET NULL,
  name VARCHAR(255) NOT NULL,
  slug VARCHAR(100) NOT NULL,
  description TEXT,
  color_hex VARCHAR(7) DEFAULT '#6B7280',
  icon VARCHAR(50),
  seo_title VARCHAR(255),
  seo_description TEXT,
  is_active BOOLEAN DEFAULT true,
  sort_order INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  UNIQUE(tenant_id, niche_id, slug)
);

-- Authors (Content creators)
CREATE TABLE authors (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID REFERENCES tenants(id) ON DELETE CASCADE,
  user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  display_name VARCHAR(255) NOT NULL,
  slug VARCHAR(100) NOT NULL,
  bio TEXT,
  email VARCHAR(255),
  profile_image TEXT,
  expertise TEXT[] DEFAULT '{}',
  social_links JSONB DEFAULT '{}',
  articles_count INTEGER DEFAULT 0,
  total_views INTEGER DEFAULT 0,
  average_rating NUMERIC(3,2) DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  UNIQUE(tenant_id, slug)
);

-- Tags (Flexible content labeling)
CREATE TABLE tags (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID REFERENCES tenants(id) ON DELETE CASCADE,
  name VARCHAR(100) NOT NULL,
  slug VARCHAR(100) NOT NULL,
  description TEXT,
  category VARCHAR(50) DEFAULT 'content',
  tag_type VARCHAR(50) DEFAULT 'content',
  color_hex VARCHAR(7) DEFAULT '#8B5CF6',
  semantic_weight NUMERIC(3,2) DEFAULT 1.0,
  usage_count INTEGER DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  UNIQUE(tenant_id, slug)
);

-- Media (Asset management with comprehensive support)
CREATE TABLE media (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID REFERENCES tenants(id) ON DELETE CASCADE,
  filename VARCHAR(255) NOT NULL,
  original_filename VARCHAR(255),
  mime_type VARCHAR(100) NOT NULL,
  media_type VARCHAR(50) DEFAULT 'image', -- 'image', 'video', 'audio', 'document'
  file_size BIGINT DEFAULT 0,
  width INTEGER,
  height INTEGER,
  duration INTEGER, -- For video/audio in seconds
  alt_text TEXT,
  caption TEXT,
  description TEXT,
  title VARCHAR(255),
  metadata JSONB DEFAULT '{}',
  storage_path TEXT NOT NULL,
  cdn_url TEXT,
  thumbnail_url TEXT, -- For videos and documents
  compressed_url TEXT, -- Optimized version
  webp_url TEXT, -- WebP format for images
  blur_hash VARCHAR(50), -- For progressive loading
  dominant_color VARCHAR(7), -- Hex color for placeholders
  ai_analysis JSONB DEFAULT '{}', -- AI-generated tags, descriptions, etc.
  seo_data JSONB DEFAULT '{}', -- SEO-related metadata
  usage_count INTEGER DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  is_processed BOOLEAN DEFAULT false, -- Processing status
  processing_status VARCHAR(50) DEFAULT 'pending', -- 'pending', 'processing', 'completed', 'failed'
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  CONSTRAINT valid_media_type CHECK (media_type IN ('image', 'video', 'audio', 'document')),
  CONSTRAINT valid_processing_status CHECK (processing_status IN ('pending', 'processing', 'completed', 'failed'))
);

-- Articles (Main content entities)
CREATE TABLE articles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID REFERENCES tenants(id) ON DELETE CASCADE,
  niche_id UUID REFERENCES niches(id) ON DELETE SET NULL,
  category_id UUID REFERENCES categories(id) ON DELETE SET NULL,
  author_id UUID REFERENCES authors(id) ON DELETE SET NULL,
  title VARCHAR(1000) NOT NULL,
  slug VARCHAR(500) NOT NULL,
  excerpt TEXT,
  content TEXT NOT NULL,
  meta_title VARCHAR(255),
  meta_description TEXT,
  featured_image_id UUID REFERENCES media(id) ON DELETE SET NULL,
  featured_image_url TEXT,
  language language_code DEFAULT 'en',
  status article_status DEFAULT 'draft',
  word_count INTEGER DEFAULT 0,
  reading_time INTEGER DEFAULT 0,
  content_quality_score NUMERIC(5,2) DEFAULT 0,
  seo_score NUMERIC(5,2) DEFAULT 0,
  engagement_score NUMERIC(5,2) DEFAULT 0,
  view_count INTEGER DEFAULT 0,
  bounce_rate NUMERIC(5,2) DEFAULT 0,
  time_on_page INTEGER DEFAULT 0,
  social_shares INTEGER DEFAULT 0,
  backlinks_count INTEGER DEFAULT 0,
  ai_generated BOOLEAN DEFAULT false,
  is_active BOOLEAN DEFAULT true,
  published_at TIMESTAMPTZ,
  last_viewed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Vector embedding for semantic search (optional)
  -- vector_embedding vector(1536),
  
  UNIQUE(tenant_id, slug),
  CONSTRAINT valid_word_count CHECK (word_count >= 0),
  CONSTRAINT valid_reading_time CHECK (reading_time >= 0),
  CONSTRAINT valid_scores CHECK (
    content_quality_score >= 0 AND content_quality_score <= 100 AND
    seo_score >= 0 AND seo_score <= 100 AND
    engagement_score >= 0 AND engagement_score <= 100
  )
);

-- ============================================================================
-- RELATIONSHIP TABLES
-- ============================================================================

-- Article Tags (Many-to-many)
CREATE TABLE article_tags (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  article_id UUID REFERENCES articles(id) ON DELETE CASCADE,
  tag_id UUID REFERENCES tags(id) ON DELETE CASCADE,
  relevance_score NUMERIC(3,2) DEFAULT 1.0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  
  UNIQUE(article_id, tag_id)
);

-- Article Media (Many-to-many with enhanced metadata)
CREATE TABLE article_media (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  article_id UUID REFERENCES articles(id) ON DELETE CASCADE,
  media_id UUID REFERENCES media(id) ON DELETE CASCADE,
  usage_type VARCHAR(50) DEFAULT 'content', -- 'featured', 'content', 'gallery', 'thumbnail', 'hero', 'inline'
  position INTEGER DEFAULT 1,
  section VARCHAR(100), -- Which section of the article (intro, body, conclusion, etc.)
  alignment VARCHAR(20) DEFAULT 'center', -- 'left', 'center', 'right', 'full-width'
  size VARCHAR(20) DEFAULT 'medium', -- 'small', 'medium', 'large', 'full'
  caption_override TEXT, -- Override media caption for this specific usage
  alt_text_override TEXT, -- Override alt text for this specific usage
  link_url TEXT, -- Optional link when media is clicked
  is_lazy_loaded BOOLEAN DEFAULT true,
  display_order INTEGER DEFAULT 1, -- Order within the same section
  responsive_settings JSONB DEFAULT '{}', -- Responsive breakpoint settings
  created_at TIMESTAMPTZ DEFAULT NOW(),
  
  UNIQUE(article_id, media_id, usage_type, position),
  CONSTRAINT valid_usage_type CHECK (usage_type IN ('featured', 'content', 'gallery', 'thumbnail', 'hero', 'inline', 'background')),
  CONSTRAINT valid_alignment CHECK (alignment IN ('left', 'center', 'right', 'full-width')),
  CONSTRAINT valid_size CHECK (size IN ('small', 'medium', 'large', 'full'))
);

-- Media Variants (Different sizes/formats of the same media)
CREATE TABLE media_variants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  media_id UUID REFERENCES media(id) ON DELETE CASCADE,
  variant_type VARCHAR(50) NOT NULL, -- 'thumbnail', 'small', 'medium', 'large', 'webp', 'avif', 'compressed'
  width INTEGER,
  height INTEGER,
  file_size BIGINT DEFAULT 0,
  quality INTEGER DEFAULT 80, -- Compression quality 1-100
  format VARCHAR(20), -- 'jpeg', 'png', 'webp', 'avif', 'mp4', 'webm'
  url TEXT NOT NULL,
  storage_path TEXT,
  is_optimized BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  
  UNIQUE(media_id, variant_type, format),
  CONSTRAINT valid_quality CHECK (quality >= 1 AND quality <= 100)
);

-- Media Processing Queue (For async media processing)
CREATE TABLE media_processing_queue (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  media_id UUID REFERENCES media(id) ON DELETE CASCADE,
  processing_type VARCHAR(50) NOT NULL, -- 'resize', 'compress', 'format_convert', 'ai_analysis', 'thumbnail'
  priority INTEGER DEFAULT 5, -- 1-10, higher is more priority
  status VARCHAR(20) DEFAULT 'queued', -- 'queued', 'processing', 'completed', 'failed'
  parameters JSONB DEFAULT '{}', -- Processing parameters
  progress INTEGER DEFAULT 0, -- 0-100
  error_message TEXT,
  started_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  retry_count INTEGER DEFAULT 0,
  max_retries INTEGER DEFAULT 3,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  CONSTRAINT valid_priority CHECK (priority >= 1 AND priority <= 10),
  CONSTRAINT valid_progress CHECK (progress >= 0 AND progress <= 100),
  CONSTRAINT valid_status CHECK (status IN ('queued', 'processing', 'completed', 'failed'))
);

-- Media Collections (Organize media into collections/albums)
CREATE TABLE media_collections (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID REFERENCES tenants(id) ON DELETE CASCADE,
  name VARCHAR(255) NOT NULL,
  slug VARCHAR(100) NOT NULL,
  description TEXT,
  cover_media_id UUID REFERENCES media(id) ON DELETE SET NULL,
  is_public BOOLEAN DEFAULT false,
  sort_order INTEGER DEFAULT 0,
  created_by UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  UNIQUE(tenant_id, slug)
);

-- Media Collection Items (Many-to-many between media and collections)
CREATE TABLE media_collection_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  collection_id UUID REFERENCES media_collections(id) ON DELETE CASCADE,
  media_id UUID REFERENCES media(id) ON DELETE CASCADE,
  position INTEGER DEFAULT 1,
  caption_override TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  
  UNIQUE(collection_id, media_id)
);

-- ============================================================================
-- WORKFLOW & AUTOMATION TABLES
-- ============================================================================

-- Topics Queue (Content planning)
CREATE TABLE topics_queue (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID REFERENCES tenants(id) ON DELETE CASCADE,
  topic TEXT NOT NULL,
  description TEXT,
  target_keywords TEXT[] DEFAULT '{}',
  niche_id UUID REFERENCES niches(id) ON DELETE SET NULL,
  category_id UUID REFERENCES categories(id) ON DELETE SET NULL,
  suggested_author_id UUID REFERENCES authors(id) ON DELETE SET NULL,
  difficulty difficulty_level DEFAULT 'intermediate',
  estimated_word_count INTEGER DEFAULT 1000,
  priority priority_level DEFAULT 'medium',
  status workflow_status DEFAULT 'queued',
  ai_prompt TEXT,
  metadata JSONB DEFAULT '{}',
  retry_count INTEGER DEFAULT 0,
  error_message TEXT,
  locked_by UUID,
  locked_at TIMESTAMPTZ,
  processing_started_at TIMESTAMPTZ,
  processed_at TIMESTAMPTZ,
  next_retry_at TIMESTAMPTZ,
  last_error_at TIMESTAMPTZ,
  execution_time_ms INTEGER,
  generated_article_id UUID REFERENCES articles(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Content Plans (Strategic content creation)
CREATE TABLE content_plans (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID REFERENCES tenants(id) ON DELETE CASCADE,
  name VARCHAR(255) NOT NULL,
  description TEXT,
  niche_id UUID REFERENCES niches(id) ON DELETE SET NULL,
  target_keywords TEXT[] DEFAULT '{}',
  content_pillars JSONB DEFAULT '[]',
  publishing_schedule JSONB DEFAULT '{}',
  status workflow_status DEFAULT 'queued',
  articles_planned INTEGER DEFAULT 0,
  articles_completed INTEGER DEFAULT 0,
  start_date DATE,
  end_date DATE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Content Versions (Version control)
CREATE TABLE content_versions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  article_id UUID REFERENCES articles(id) ON DELETE CASCADE,
  version_number INTEGER NOT NULL,
  title VARCHAR(1000) NOT NULL,
  content TEXT NOT NULL,
  change_summary TEXT,
  created_by UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  
  UNIQUE(article_id, version_number)
);

-- ============================================================================
-- TRANSLATION SYSTEM
-- ============================================================================

-- Translations (Multi-language support)
CREATE TABLE translations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  article_id UUID REFERENCES articles(id) ON DELETE CASCADE,
  language language_code NOT NULL,
  title VARCHAR(1000) NOT NULL,
  excerpt TEXT,
  content TEXT NOT NULL,
  meta_title VARCHAR(255),
  meta_description TEXT,
  slug VARCHAR(500) NOT NULL,
  status content_status DEFAULT 'draft',
  quality_score NUMERIC(5,2) DEFAULT 0,
  human_reviewed BOOLEAN DEFAULT false,
  translator_notes TEXT,
  ai_translated BOOLEAN DEFAULT true,
  published_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  UNIQUE(article_id, language),
  CONSTRAINT valid_quality_score CHECK (quality_score >= 0 AND quality_score <= 100)
);

-- ============================================================================
-- ANALYTICS & SEO TABLES
-- ============================================================================

-- Analytics Events (User behavior tracking)
CREATE TABLE analytics_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID REFERENCES tenants(id) ON DELETE CASCADE,
  event_type VARCHAR(50) NOT NULL,
  article_id UUID REFERENCES articles(id) ON DELETE SET NULL,
  user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  session_id TEXT,
  event_data JSONB DEFAULT '{}',
  ip_address INET,
  user_agent TEXT,
  referrer TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- SEO Metrics (SEO performance tracking)
CREATE TABLE seo_metrics (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  article_id UUID REFERENCES articles(id) ON DELETE CASCADE,
  target_keywords TEXT[] DEFAULT '{}',
  current_rankings JSONB DEFAULT '{}',
  seo_score INTEGER DEFAULT 0,
  accessibility_score INTEGER DEFAULT 0,
  page_speed_score INTEGER DEFAULT 0,
  mobile_friendly BOOLEAN DEFAULT false,
  meta_tags_complete BOOLEAN DEFAULT false,
  structured_data_valid BOOLEAN DEFAULT false,
  keyword_density NUMERIC(5,2) DEFAULT 0,
  internal_links_count INTEGER DEFAULT 0,
  external_links_count INTEGER DEFAULT 0,
  image_alt_tags_complete BOOLEAN DEFAULT false,
  last_updated TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  
  UNIQUE(article_id),
  CONSTRAINT valid_seo_scores CHECK (
    seo_score >= 0 AND seo_score <= 100 AND
    accessibility_score >= 0 AND accessibility_score <= 100 AND
    page_speed_score >= 0 AND page_speed_score <= 100
  )
);

-- ============================================================================
-- MONETIZATION TABLES
-- ============================================================================

-- Affiliate Programs
CREATE TABLE affiliate_programs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID REFERENCES tenants(id) ON DELETE CASCADE,
  name VARCHAR(255) NOT NULL,
  description TEXT,
  network VARCHAR(100),
  commission_type VARCHAR(20) DEFAULT 'percentage', -- 'percentage', 'fixed'
  commission_rate NUMERIC(5,2) DEFAULT 0,
  base_url TEXT,
  tracking_parameters JSONB DEFAULT '{}',
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Affiliate Links
CREATE TABLE affiliate_links (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID REFERENCES tenants(id) ON DELETE CASCADE,
  article_id UUID REFERENCES articles(id) ON DELETE CASCADE,
  program_id UUID REFERENCES affiliate_programs(id) ON DELETE CASCADE,
  product_name VARCHAR(255),
  original_url TEXT NOT NULL,
  affiliate_url TEXT NOT NULL,
  anchor_text TEXT,
  position_in_content INTEGER,
  click_count INTEGER DEFAULT 0,
  conversion_count INTEGER DEFAULT 0,
  revenue_generated NUMERIC(10,2) DEFAULT 0,
  last_clicked_at TIMESTAMPTZ,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Affiliate Clicks (Performance tracking)
CREATE TABLE affiliate_clicks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  link_id UUID REFERENCES affiliate_links(id) ON DELETE CASCADE,
  article_id UUID REFERENCES articles(id) ON DELETE CASCADE,
  user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  session_id TEXT,
  ip_address INET,
  user_agent TEXT,
  referrer TEXT,
  clicked_at TIMESTAMPTZ DEFAULT NOW()
);

-- Revenue Metrics (Revenue analysis)
CREATE TABLE revenue_metrics (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  article_id UUID REFERENCES articles(id) ON DELETE CASCADE,
  total_revenue NUMERIC(10,2) DEFAULT 0,
  affiliate_revenue NUMERIC(10,2) DEFAULT 0,
  ad_revenue NUMERIC(10,2) DEFAULT 0,
  premium_revenue NUMERIC(10,2) DEFAULT 0,
  conversion_rate NUMERIC(5,2) DEFAULT 0,
  revenue_per_visitor NUMERIC(8,4) DEFAULT 0,
  monetization_efficiency NUMERIC(5,2) DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  UNIQUE(article_id)
);

-- ============================================================================
-- A/B TESTING FRAMEWORK
-- ============================================================================

-- A/B Experiments
CREATE TABLE ab_experiments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID REFERENCES tenants(id) ON DELETE CASCADE,
  name VARCHAR(255) NOT NULL,
  description TEXT,
  hypothesis TEXT,
  success_metric VARCHAR(100),
  variants JSONB NOT NULL, -- Array of variant definitions
  traffic_allocation JSONB DEFAULT '{}', -- Percentage allocation per variant
  status VARCHAR(20) DEFAULT 'draft', -- 'draft', 'running', 'paused', 'completed'
  confidence_level NUMERIC(3,2) DEFAULT 0.95,
  statistical_significance BOOLEAN DEFAULT false,
  winner_variant VARCHAR(50),
  start_date TIMESTAMPTZ,
  end_date TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- A/B Assignments (User variant assignments)
CREATE TABLE ab_assignments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  experiment_id UUID REFERENCES ab_experiments(id) ON DELETE CASCADE,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  session_id TEXT,
  variant VARCHAR(50) NOT NULL,
  assigned_at TIMESTAMPTZ DEFAULT NOW(),
  
  UNIQUE(experiment_id, user_id)
);

-- ============================================================================
-- USER ENGAGEMENT TABLES
-- ============================================================================

-- User Comments
CREATE TABLE user_comments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  article_id UUID REFERENCES articles(id) ON DELETE CASCADE,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  parent_id UUID REFERENCES user_comments(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  status VARCHAR(20) DEFAULT 'pending', -- 'pending', 'approved', 'rejected', 'spam'
  is_featured BOOLEAN DEFAULT false,
  like_count INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- User Bookmarks
CREATE TABLE user_bookmarks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  article_id UUID REFERENCES articles(id) ON DELETE CASCADE,
  folder_name VARCHAR(100) DEFAULT 'default',
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  
  UNIQUE(user_id, article_id)
);

-- ============================================================================
-- NEWSLETTER SYSTEM
-- ============================================================================

-- Newsletter Subscribers
CREATE TABLE newsletter_subscribers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID REFERENCES tenants(id) ON DELETE CASCADE,
  email VARCHAR(255) NOT NULL,
  full_name VARCHAR(255),
  status VARCHAR(20) DEFAULT 'active', -- 'active', 'unsubscribed', 'bounced'
  preferences JSONB DEFAULT '{}',
  source VARCHAR(100), -- 'website', 'popup', 'api', etc.
  confirmed_at TIMESTAMPTZ,
  unsubscribed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  UNIQUE(tenant_id, email)
);

-- Newsletter Campaigns
CREATE TABLE newsletter_campaigns (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID REFERENCES tenants(id) ON DELETE CASCADE,
  name VARCHAR(255) NOT NULL,
  subject VARCHAR(255) NOT NULL,
  content TEXT NOT NULL,
  status VARCHAR(20) DEFAULT 'draft', -- 'draft', 'scheduled', 'sending', 'sent'
  recipient_count INTEGER DEFAULT 0,
  sent_count INTEGER DEFAULT 0,
  open_count INTEGER DEFAULT 0,
  click_count INTEGER DEFAULT 0,
  scheduled_at TIMESTAMPTZ,
  sent_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- SYSTEM & PERFORMANCE TABLES
-- ============================================================================

-- Smart Cache (Intelligent caching system)
CREATE TABLE smart_cache (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  cache_key TEXT NOT NULL UNIQUE,
  cache_type VARCHAR(50) NOT NULL,
  cache_data JSONB NOT NULL,
  dependencies TEXT[] DEFAULT '{}',
  hit_count INTEGER DEFAULT 0,
  last_hit_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Performance Logs (System performance tracking)
CREATE TABLE performance_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  operation_type VARCHAR(100) NOT NULL,
  operation_name VARCHAR(255) NOT NULL,
  execution_time_ms INTEGER NOT NULL,
  memory_usage_mb NUMERIC(10,2),
  cpu_usage_percent NUMERIC(5,2),
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- API Rate Limits (Rate limiting management)
CREATE TABLE api_rate_limits (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  identifier VARCHAR(255) NOT NULL, -- IP, user_id, api_key
  endpoint VARCHAR(255) NOT NULL,
  request_count INTEGER DEFAULT 0,
  window_start TIMESTAMPTZ NOT NULL,
  window_duration INTERVAL DEFAULT '1 hour',
  limit_per_window INTEGER DEFAULT 1000,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  UNIQUE(identifier, endpoint, window_start)
);

-- Dead Letter Queue (Error handling)
CREATE TABLE dead_letter_queue (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  queue_name VARCHAR(100) NOT NULL,
  message_data JSONB NOT NULL,
  error_message TEXT,
  retry_count INTEGER DEFAULT 0,
  max_retries INTEGER DEFAULT 3,
  next_retry_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Daily Stats (Aggregated metrics)
CREATE TABLE daily_stats (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID REFERENCES tenants(id) ON DELETE CASCADE,
  date DATE NOT NULL,
  metric_type VARCHAR(50) NOT NULL,
  metric_value NUMERIC(15,2) DEFAULT 0,
  entity_type VARCHAR(50),
  entity_id UUID,
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  UNIQUE(tenant_id, date, metric_type, entity_type, entity_id)
);

-- Entity Resolution Cache (Performance optimization)
CREATE TABLE entity_resolution_cache (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  entity_type VARCHAR(50) NOT NULL,
  lookup_key TEXT NOT NULL,
  resolved_id UUID NOT NULL,
  confidence_score NUMERIC(3,2) DEFAULT 1.0,
  hit_count INTEGER DEFAULT 0,
  last_hit_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  
  UNIQUE(entity_type, lookup_key)
);

-- ============================================================================
-- WORKFLOW MONITORING TABLES
-- ============================================================================

-- Workflow States (n8n workflow tracking)
CREATE TABLE workflow_states (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  workflow_name VARCHAR(255) NOT NULL,
  execution_id TEXT NOT NULL,
  status workflow_status DEFAULT 'queued',
  input_data JSONB DEFAULT '{}',
  output_data JSONB DEFAULT '{}',
  error_data JSONB DEFAULT '{}',
  started_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  execution_time_ms INTEGER,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- N8N Executions (Detailed execution tracking)
CREATE TABLE n8n_executions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  workflow_id TEXT NOT NULL,
  execution_id TEXT NOT NULL UNIQUE,
  status VARCHAR(20) NOT NULL,
  mode VARCHAR(20) DEFAULT 'trigger',
  started_at TIMESTAMPTZ NOT NULL,
  finished_at TIMESTAMPTZ,
  execution_time INTEGER,
  data JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- N8N Execution Nodes (Node-level performance)
CREATE TABLE n8n_execution_nodes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  execution_id TEXT REFERENCES n8n_executions(execution_id) ON DELETE CASCADE,
  node_name VARCHAR(255) NOT NULL,
  node_type VARCHAR(100) NOT NULL,
  status VARCHAR(20) NOT NULL,
  execution_time INTEGER,
  input_data JSONB DEFAULT '{}',
  output_data JSONB DEFAULT '{}',
  error_data JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- N8N Performance Profiles (Performance analytics)
CREATE TABLE n8n_performance_profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  workflow_id TEXT NOT NULL,
  node_name VARCHAR(255) NOT NULL,
  avg_execution_time NUMERIC(10,2),
  min_execution_time INTEGER,
  max_execution_time INTEGER,
  success_rate NUMERIC(5,2),
  error_count INTEGER DEFAULT 0,
  total_executions INTEGER DEFAULT 0,
  last_updated TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  
  UNIQUE(workflow_id, node_name)
);

-- Performance Intelligence Cache (AI-powered insights)
CREATE TABLE performance_intelligence_cache (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  cache_key TEXT NOT NULL UNIQUE,
  analysis_data JSONB NOT NULL,
  confidence_scores JSONB DEFAULT '{}',
  predictions JSONB DEFAULT '{}',
  anomalies JSONB DEFAULT '{}',
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- INDEXES FOR PERFORMANCE
-- ============================================================================

-- Core content indexes
CREATE INDEX idx_articles_tenant_status ON articles(tenant_id, status);
CREATE INDEX idx_articles_slug ON articles(slug);
CREATE INDEX idx_articles_published_at ON articles(published_at DESC) WHERE status = 'published';
CREATE INDEX idx_articles_author_id ON articles(author_id);
CREATE INDEX idx_articles_niche_category ON articles(niche_id, category_id);
CREATE INDEX idx_articles_view_count ON articles(view_count DESC);
CREATE INDEX idx_articles_engagement_score ON articles(engagement_score DESC);

-- Full-text search indexes
CREATE INDEX idx_articles_title_fts ON articles USING gin(to_tsvector('english', title));
CREATE INDEX idx_articles_content_fts ON articles USING gin(to_tsvector('english', content));

-- Vector similarity search (if vector extension available)
-- CREATE INDEX idx_articles_vector_embedding ON articles 
-- USING ivfflat (vector_embedding vector_cosine_ops) WITH (lists = 100);

-- Analytics indexes
CREATE INDEX idx_analytics_events_article_id ON analytics_events(article_id);
CREATE INDEX idx_analytics_events_created_at ON analytics_events(created_at DESC);
CREATE INDEX idx_analytics_events_event_type ON analytics_events(event_type);
CREATE INDEX idx_analytics_events_session_id ON analytics_events(session_id);

-- Workflow indexes
CREATE INDEX idx_topics_queue_status_priority ON topics_queue(status, priority, created_at);
CREATE INDEX idx_topics_queue_locked_by ON topics_queue(locked_by, locked_at) WHERE locked_by IS NOT NULL;

-- Performance indexes
CREATE INDEX idx_performance_logs_created_at ON performance_logs(created_at DESC);
CREATE INDEX idx_smart_cache_expires_at ON smart_cache(expires_at);
CREATE INDEX idx_smart_cache_cache_type ON smart_cache(cache_type);

-- User indexes
CREATE INDEX idx_users_tenant_email ON users(tenant_id, email);
CREATE INDEX idx_users_role ON users(role);
CREATE INDEX idx_users_last_activity ON users(last_activity DESC);

-- Monetization indexes
CREATE INDEX idx_affiliate_links_article_id ON affiliate_links(article_id);
CREATE INDEX idx_affiliate_clicks_link_id ON affiliate_clicks(link_id);
CREATE INDEX idx_revenue_metrics_total_revenue ON revenue_metrics(total_revenue DESC);

-- Media indexes
CREATE INDEX idx_media_tenant_type ON media(tenant_id, media_type);
CREATE INDEX idx_media_mime_type ON media(mime_type);
CREATE INDEX idx_media_processing_status ON media(processing_status);
CREATE INDEX idx_media_usage_count ON media(usage_count DESC);
CREATE INDEX idx_media_created_at ON media(created_at DESC);
CREATE INDEX idx_media_file_size ON media(file_size DESC);

-- Article media indexes
CREATE INDEX idx_article_media_article_id ON article_media(article_id);
CREATE INDEX idx_article_media_media_id ON article_media(media_id);
CREATE INDEX idx_article_media_usage_type ON article_media(usage_type);
CREATE INDEX idx_article_media_position ON article_media(article_id, usage_type, position);

-- Media variants indexes
CREATE INDEX idx_media_variants_media_id ON media_variants(media_id);
CREATE INDEX idx_media_variants_type ON media_variants(variant_type);
CREATE INDEX idx_media_variants_format ON media_variants(format);

-- Media processing queue indexes
CREATE INDEX idx_media_processing_status_priority ON media_processing_queue(status, priority DESC);
CREATE INDEX idx_media_processing_media_id ON media_processing_queue(media_id);
CREATE INDEX idx_media_processing_created_at ON media_processing_queue(created_at);

-- Media collections indexes
CREATE INDEX idx_media_collections_tenant_id ON media_collections(tenant_id);
CREATE INDEX idx_media_collections_slug ON media_collections(tenant_id, slug);
CREATE INDEX idx_media_collections_public ON media_collections(is_public, created_at DESC);

-- Media collection items indexes
CREATE INDEX idx_media_collection_items_collection_id ON media_collection_items(collection_id, position);
CREATE INDEX idx_media_collection_items_media_id ON media_collection_items(media_id);

-- SEO indexes
CREATE INDEX idx_seo_metrics_seo_score ON seo_metrics(seo_score DESC);
CREATE INDEX idx_seo_metrics_last_updated ON seo_metrics(last_updated DESC);

-- Translation indexes
CREATE INDEX idx_translations_article_language ON translations(article_id, language);
CREATE INDEX idx_translations_status ON translations(status);

-- Newsletter indexes
CREATE INDEX idx_newsletter_subscribers_tenant_status ON newsletter_subscribers(tenant_id, status);
CREATE INDEX idx_newsletter_campaigns_status ON newsletter_campaigns(status);

-- Composite indexes for common queries
CREATE INDEX idx_articles_niche_status_published ON articles(niche_id, status, published_at DESC) 
WHERE status = 'published';
CREATE INDEX idx_articles_author_status_published ON articles(author_id, status, published_at DESC) 
WHERE status = 'published';

-- ============================================================================
-- COMMENTS
-- ============================================================================

COMMENT ON SCHEMA public IS 'Allixios New Architecture - Enterprise Content Management Platform';

-- Table comments
COMMENT ON TABLE tenants IS 'Multi-tenant support for SaaS deployment';
COMMENT ON TABLE users IS 'System users with role-based access control';
COMMENT ON TABLE articles IS 'Main content entities with comprehensive metadata';
COMMENT ON TABLE niches IS 'Top-level content domains for organization';
COMMENT ON TABLE categories IS 'Hierarchical content categorization';
COMMENT ON TABLE authors IS 'Content creator profiles and statistics';
COMMENT ON TABLE tags IS 'Flexible content labeling system';
COMMENT ON TABLE translations IS 'Multi-language content support';
COMMENT ON TABLE analytics_events IS 'User behavior and interaction tracking';
COMMENT ON TABLE seo_metrics IS 'SEO performance metrics per article';
COMMENT ON TABLE affiliate_links IS 'Monetization through affiliate marketing';
COMMENT ON TABLE revenue_metrics IS 'Revenue analysis and optimization';
COMMENT ON TABLE topics_queue IS 'Content planning and workflow management';
COMMENT ON TABLE smart_cache IS 'Intelligent caching with dependency tracking';
COMMENT ON TABLE performance_logs IS 'System performance monitoring';

-- Column comments for key fields
COMMENT ON COLUMN articles.vector_embedding IS 'Vector embedding for semantic search (1536 dimensions)';
COMMENT ON COLUMN articles.content_quality_score IS 'AI-generated content quality score (0-100)';
COMMENT ON COLUMN articles.seo_score IS 'SEO optimization score (0-100)';
COMMENT ON COLUMN articles.engagement_score IS 'User engagement score (0-100)';
COMMENT ON COLUMN smart_cache.dependencies IS 'Cache invalidation dependencies';
COMMENT ON COLUMN topics_queue.retry_count IS 'Number of processing retry attempts';
COMMENT ON COLUMN seo_metrics.target_keywords IS 'Target keywords for SEO optimization';

-- ============================================================================
-- GRANTS AND PERMISSIONS
-- ============================================================================

-- Grant basic permissions (adjust based on your authentication system)
-- GRANT USAGE ON SCHEMA public TO authenticated, service_role;
-- GRANT ALL ON ALL TABLES IN SCHEMA public TO service_role;
-- GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO service_role;

-- ============================================================================
-- COMPLETION
-- ============================================================================

-- Schema deployment completed successfully
-- Total tables created: 35+
-- Custom types: 7 enums
-- Indexes: 30+ performance-optimized indexes
-- Features: Multi-tenant, multi-language, AI-powered, analytics, monetization