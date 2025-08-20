# Allixios Content Management Platform - Project Context

## 🎯 Project Overview

**Allixios** is an AI-powered, fully automated content publishing platform built on Supabase with n8n workflow orchestration. The platform supports multi-niche content strategy, multi-author collaboration, SEO optimization, affiliate monetization, and comprehensive analytics tracking.

### Core Mission
Transform content creation from manual, time-intensive processes into fully automated, AI-driven workflows that can scale to produce 100+ high-quality articles per day across multiple languages and niches.

## 🏗️ Architecture Overview

### Technology Stack
- **Database**: PostgreSQL with Supabase (Public, Auth, Storage schemas)
- **Backend**: Supabase Edge Functions for serverless operations
- **Orchestration**: n8n workflows for content automation
- **AI Integration**: Gemini 2.0 Flash/Pro, OpenAI GPT-4, Claude
- **Storage**: Supabase Storage with CDN optimization
- **Search**: pgvector for semantic search and embeddings
- **Authentication**: Supabase Auth with Row-Level Security (RLS)

### Core Components
1. **Content Generation Engine**: AI-powered article creation with quality scoring
2. **SEO Optimization System**: Automated SEO monitoring and optimization
3. **Revenue Optimization Engine**: Affiliate marketing and monetization automation
4. **Performance Intelligence**: Advanced analytics and predictive insights
5. **Multi-language Support**: Full translation and localization capabilities

## 📊 Database Architecture

### Core Entity Hierarchy
```
niches (top-level content categories)
├── categories (subcategories within niches)
│   └── articles (individual content pieces)
└── tags (cross-cutting content labels)
```

### User & Access Management
```
users (system users)
├── authors (content creators)
├── roles (access control)
└── user_* tables (bookmarks, comments, etc.)
```

### Content Workflow Pipeline
```
topics_queue → content_plans → articles → content_versions
                                    ├── editorial_reviews
                                    └── translations
```

### Key Database Tables (29 total)

**Content Management:**
- `articles` - Main content storage with full metadata
- `niches` - Top-level content domains (travel, tech, health, etc.)
- `categories` - Hierarchical content classification
- `tags` - Flexible content labeling system
- `media` - Asset management with AI tagging

**User & Access:**
- `users` - Core user profiles
- `authors` - Extended creator profiles
- `user_bookmarks` - Saved content
- `user_comments` - Community engagement

**Workflow & Automation:**
- `topics_queue` - Content generation queue
- `content_plans` - Strategic content roadmaps
- `workflow_executions` - Automation tracking
- `content_versions` - Revision history

**Analytics & Performance:**
- `analytics_events` - User interaction tracking
- `seo_metrics` - SEO performance data
- `performance_logs` - System performance metrics
- `smart_cache` - Intelligent caching layer

**Monetization:**
- `affiliate_programs` - Partner program definitions
- `affiliate_links` - Article monetization links
- `affiliate_clicks` - Revenue tracking

**Marketing:**
- `newsletter_subscribers` - Email list management
- `newsletter_campaigns` - Email marketing campaigns
- `ab_experiments` - A/B testing framework
- `ab_assignments` - Test participant tracking

**Localization:**
- `translations` - Multi-language content support

### Database Extensions
- **vector (0.8.0)** - Vector similarity search for semantic content discovery
- **pg_stat_statements** - Query performance monitoring
- **uuid-ossp** - UUID generation for distributed system compatibility
- **pgcrypto** - Cryptographic functions for security
- **pg_trgm** - Fuzzy text matching and search

## 🔄 Workflow System Architecture

### Workflow 1: Master Content Pipeline
- **Schedule**: Every 15 minutes
- **Purpose**: Core content automation from topic to published article
- **Process**: Topic validation → Entity preparation → AI generation → Publishing
- **Target**: 3-5 articles per cycle with 85%+ quality score

### Workflow 2: SEO Performance Monitor
- **Schedule**: Every 2 hours
- **Purpose**: Rankings monitoring and content optimization
- **Process**: Ranking checks → Performance analysis → Auto-optimization
- **Target**: 80%+ top-10 rankings within 6 months

### Workflow 3: Revenue Optimization Engine
- **Schedule**: Every 6 hours
- **Purpose**: Monetization management and A/B testing
- **Process**: Performance analysis → A/B test management → Revenue optimization
- **Target**: 3%+ conversion rate on affiliate links

### Workflow 4: Performance Intelligence System
- **Schedule**: Hourly
- **Purpose**: Business intelligence and monitoring
- **Process**: Metrics collection → KPI calculation → Predictive analytics
- **Target**: Real-time business insights and proactive issue detection

## 🚀 Database-First Architecture (v3.0)

### Core Database Functions (10 REST endpoints)
1. **fetch_content_batch_v3** - Intelligent topic retrieval with load balancing
2. **insert_article_complete_v3** - Atomic article creation with relationships  
3. **update_topic_status_v3** - Workflow state management with metadata
4. **upsert_authors_batch_v3** - Smart author management with deduplication
5. **upsert_tags_batch_v3** - Tag creation with hierarchy support
6. **log_analytics_events_v3** - Performance tracking and metrics
7. **collect_system_metrics_v3** - System health monitoring
8. **get_performance_dashboard_v3** - Comprehensive analytics dashboard
9. **manage_seo_operations_v3** - SEO operations (initialize/update/analyze)
10. **manage_revenue_operations_v3** - Revenue tracking and optimization

### Remaining Edge Functions (AI/External APIs only)
- **generate-media-batch** - AI image generation (DALL-E, Midjourney)
- **generate-translations-batch** - Multi-language content generation
- **apply-seo-optimizations** - External SEO API integrations
- **create-affiliate-links-smart** - External affiliate API integrations
- **setup-article-ab-tests** - A/B testing platform integrations
- **generate-internal-links-ai** - AI-powered semantic link analysis

### Architecture Benefits
- **10x Performance**: Direct database calls vs Edge Function cold starts
- **Zero Cost**: Database functions included in Supabase plan
- **Atomic Operations**: Full transaction support with rollback
- **Unlimited Execution**: No 25-second timeout limits
- **Simplified Debugging**: Standard SQL debugging tools

## 📈 Performance Targets & KPIs

### Content Production KPIs
| Metric | Week 2 | Week 4 | Week 6 | Week 8 |
|--------|--------|--------|--------|--------|
| Articles/Day | 10 | 25 | 50 | 100+ |
| Content Quality | 80+ | 85+ | 87+ | 90+ |
| Languages | 1 | 3 | 10 | 20 |
| Niches | 3 | 8 | 20 | 50+ |

### Business Impact KPIs
| Metric | Week 2 | Week 4 | Week 6 | Week 8 |
|--------|--------|--------|--------|--------|
| Monthly Traffic | 10K | 50K | 200K | 500K+ |
| Revenue/Month | $100 | $1K | $5K | $10K+ |
| Top-10 Rankings | 20% | 40% | 60% | 80% |
| Conversion Rate | 1% | 2% | 3% | 4%+ |

## 🔐 Security & Access Control

### Row Level Security (RLS) Policies
- Users can manage their own data (`auth.uid() = user_id`)
- Public read access for published content
- Role-based access using JWT claims
- Author-specific content management
- Editor/Admin elevated permissions

### Authentication Flow
```
User Request → Supabase Auth → JWT Validation → RLS Policy Check → Data Access
```

## 🛠️ Development Patterns & Conventions

### Database Patterns
- **UUID Primary Keys**: All tables use UUID for distributed system compatibility
- **Soft Deletes**: Prefer status flags over hard deletes for audit trails
- **Hierarchical Data**: Parent-child relationships for niches, categories, and tags
- **JSONB Fields**: Flexible metadata storage (social_links, structured_data, etc.)
- **Audit Trails**: created_at/updated_at timestamps on all entities
- **Indexing Strategy**: Comprehensive indexes on foreign keys and query columns

### Content Management Patterns
- **Content Versioning**: Track all content changes with version history
- **Editorial Workflow**: Status-based content lifecycle (draft → review → published)
- **Quality Scoring**: Numeric quality scores (0-100) for content assessment
- **Caching Strategy**: Denormalized fields for performance (tags_cache, related_articles_cache)

### Naming Conventions
- **Tables**: Plural nouns (articles, users, categories)
- **Foreign Keys**: `{table}_id` format (niche_id, category_id)
- **Junction Tables**: `{table1}_{table2}` format (article_tags, article_media)
- **Timestamps**: `created_at`, `updated_at`, `published_at` patterns

## 🚨 Migration to Database-First Architecture

### Current State Analysis
1. **Edge Function Redundancy**: 80% of Edge Functions can be replaced with database functions
2. **Performance Bottlenecks**: Cold starts and timeout limits affecting workflow reliability
3. **Cost Optimization**: Database functions eliminate Edge Function execution costs
4. **Maintenance Complexity**: Multiple function versions across directories

### Migration Strategy (v3.0)
- **Phase 1**: Deploy 10 core database functions as REST endpoints
- **Phase 2**: Update n8n workflows to use REST API calls instead of Edge Functions
- **Phase 3**: Keep only AI/External API Edge Functions (6 functions)
- **Phase 4**: Remove redundant Edge Functions and consolidate codebase

### Database Functions Deployment
```sql
-- Core functions replace most Edge Functions
fetch_content_batch_v3()      -- Replaces fetch-content-batch-v2
insert_article_complete_v3()  -- Replaces insert-article-complete-v2  
update_topic_status_v3()      -- Replaces update-topic-status
upsert_authors_batch_v3()     -- Replaces upsert-authors-batch-v2
upsert_tags_batch_v3()        -- Replaces upsert-tags-batch
log_analytics_events_v3()     -- Replaces log-analytics-batch
collect_system_metrics_v3()   -- Replaces collect-system-metrics
get_performance_dashboard_v3() -- Replaces fetch-performance-data
manage_seo_operations_v3()    -- Replaces multiple SEO functions
manage_revenue_operations_v3() -- Replaces multiple revenue functions
```

## 🔧 Environment Configuration

### Required Environment Variables
```env
# Supabase Configuration
SUPABASE_URL=your_supabase_url
SUPABASE_SERVICE_ROLE_KEY=your_service_role_key

# AI API Keys
GEMINI_API_KEY=your_gemini_key
OPENAI_API_KEY=your_openai_key

# n8n Integration
N8N_WEBHOOK_URL=your_n8n_webhook_url

# Slack Integration
SLACK_BOT_TOKEN=your_slack_bot_token
SLACK_WEBHOOK_URL=your_slack_webhook_url
```

## 📊 Data Flow Architecture

### n8n ↔ Supabase REST API ↔ PostgreSQL Flow (v3.0)
```
n8n Workflow (Orchestration)
    ↓ HTTP POST to /rest/v1/rpc/function_name
Supabase REST API (Direct)
    ↓ Direct Function Call
PostgreSQL Function (Data processing)
    ↓ JSON Response (Results)
Supabase REST API (Response)
    ↓ HTTP Response (Processed data)
n8n Workflow (Next steps)
```

### Performance Improvements (v3.0)
- **Cold Start**: 0ms (eliminated)
- **Processing Time**: 10-50ms (10x faster)
- **Transfer Time**: 50-200ms (4x faster)
- **Total Time**: 60-250ms vs 1-5 seconds (20x improvement)
- **Cost**: $0 vs $0.40/million requests (100% savings)
- **Timeout**: None vs 25 seconds (unlimited)

## 🎯 Business Model & Monetization

### Revenue Streams
1. **Affiliate Marketing**: Contextual product recommendations
2. **Display Advertising**: Optimized ad placements
3. **Newsletter Monetization**: Subscriber-based revenue
4. **SEO Services**: Organic traffic monetization

### Target Markets
- Content creators and publishers
- Digital marketing agencies
- Multi-language content operations
- SEO-focused content teams
- Affiliate marketers

## 🔍 Monitoring & Analytics

### Key Metrics Tracked
- **Content Production**: Articles generated, quality scores, processing times
- **SEO Performance**: Rankings, organic traffic, Core Web Vitals
- **Revenue Tracking**: Affiliate clicks, conversions, revenue per article
- **System Health**: Workflow success rates, API response times, error rates

### Alert System
- **Critical Alerts**: Revenue drops > 15%, traffic anomalies > 20%
- **Opportunity Alerts**: Viral content detection, ranking breakthroughs
- **Maintenance Alerts**: System health monitoring, performance degradation

## 🚀 Deployment Strategy

### Phase 1: Foundation (Week 1-2)
- Deploy database schema and Edge Functions
- Implement Master Content Pipeline
- Test with 10 sample topics
- Achieve 80%+ content quality

### Phase 2: Intelligence & Optimization (Week 3-4)
- Deploy SEO monitoring and revenue optimization
- Add analytics and monitoring dashboards
- Scale to 25 articles/day
- Implement A/B testing

### Phase 3: Scaling & Localization (Week 5-6)
- Multi-language expansion (10 languages)
- Niche expansion (20 niches)
- Scale to 50 articles/day
- Advanced AI features

### Phase 4: Enterprise Scale (Week 7-8)
- Global deployment (50+ niches)
- Advanced personalization
- Scale to 100+ articles/day
- Target $10K+/month revenue

## 📝 Development Guidelines

### When Adding New Features
1. **Follow UUID pattern** for all new primary keys
2. **Add audit timestamps** (created_at, updated_at) to all tables
3. **Include status fields** for workflow management
4. **Consider multi-language** implications for content tables
5. **Add appropriate indexes** for query performance

### Performance Considerations
- **Vector Indexes**: Use ivfflat indexes for vector similarity searches
- **Pagination**: Always use cursor-based pagination for large datasets
- **Batch Operations**: Prefer bulk inserts/updates for content operations
- **Connection Pooling**: Use Supabase connection pooling for scalability

### Security Patterns
- **Row Level Security**: Implement RLS policies for multi-tenant data access
- **Input Validation**: Validate all user inputs, especially for content fields
- **API Rate Limiting**: Implement rate limiting for AI content generation
- **Audit Logging**: Track all content modifications and user actions

This context document provides a comprehensive understanding of the Allixios platform architecture, capabilities, and development patterns. It serves as the foundation for any development work, feature additions, or system modifications.