# 🔧 Database Functions API

## Overview

This document outlines the database functions available for the Allixios platform, organized by functional area. All functions are designed for high performance and enterprise-scale operations.

## 📊 Content Management Functions

### Article Operations

#### `create_article_with_metadata()`
Creates a new article with full metadata and relationships.

```sql
SELECT create_article_with_metadata(
    title := 'Sample Article',
    content := 'Article content...',
    niche_id := 'uuid-here',
    author_id := 'uuid-here',
    meta_data := '{"seo_score": 85, "target_keywords": ["keyword1", "keyword2"]}'::jsonb
);
```

**Parameters:**
- `title` (text): Article title
- `content` (text): Article content
- `niche_id` (uuid): Associated niche
- `author_id` (uuid): Author ID
- `meta_data` (jsonb): Additional metadata

**Returns:** Article UUID

#### `update_article_metrics()`
Updates article performance metrics in batch.

```sql
SELECT update_article_metrics(
    article_id := 'uuid-here',
    metrics := '{
        "view_count": 1500,
        "engagement_score": 0.75,
        "time_on_page": 180,
        "bounce_rate": 0.25
    }'::jsonb
);
```

#### `get_article_with_relations()`
Retrieves article with all related data (tags, media, metrics).

```sql
SELECT * FROM get_article_with_relations('article-uuid-here');
```

**Returns:** Complete article data with relationships

### Content Discovery

#### `search_articles_semantic()`
Performs semantic search using vector embeddings.

```sql
SELECT * FROM search_articles_semantic(
    query_embedding := '[0.1, 0.2, ...]'::vector,
    limit_count := 10,
    similarity_threshold := 0.8
);
```

#### `search_articles_fulltext()`
Full-text search with ranking.

```sql
SELECT * FROM search_articles_fulltext(
    search_query := 'artificial intelligence',
    language_code := 'en',
    limit_count := 20
);
```

#### `get_related_articles()`
Gets related articles based on content similarity and user behavior.

```sql
SELECT * FROM get_related_articles(
    article_id := 'uuid-here',
    limit_count := 5,
    include_metrics := true
);
```

## 🎯 Analytics Functions

### Performance Analytics

#### `get_article_performance_summary()`
Comprehensive performance metrics for articles.

```sql
SELECT * FROM get_article_performance_summary(
    date_from := '2024-01-01',
    date_to := '2024-12-31',
    niche_id := 'uuid-here' -- optional
);
```

#### `track_user_event()`
Records user interaction events for analytics.

```sql
SELECT track_user_event(
    event_type := 'page_view',
    article_id := 'uuid-here',
    user_id := 'uuid-here', -- optional
    metadata := '{"source": "organic", "device": "mobile"}'::jsonb
);
```

#### `get_engagement_metrics()`
Calculates engagement metrics for content.

```sql
SELECT * FROM get_engagement_metrics(
    entity_type := 'article',
    entity_id := 'uuid-here',
    time_period := '30 days'
);
```

### SEO Analytics

#### `update_seo_metrics()`
Updates SEO performance data for articles.

```sql
SELECT update_seo_metrics(
    article_id := 'uuid-here',
    metrics := '{
        "seo_score": 92,
        "backlinks_count": 45,
        "ranking_keywords_count": 23,
        "mobile_speed_score": 88
    }'::jsonb
);
```

#### `get_seo_opportunities()`
Identifies SEO improvement opportunities.

```sql
SELECT * FROM get_seo_opportunities(
    niche_id := 'uuid-here',
    min_traffic_potential := 1000
);
```

## 💰 Monetization Functions

### Affiliate Management

#### `create_affiliate_link()`
Creates and tracks affiliate links.

```sql
SELECT create_affiliate_link(
    article_id := 'uuid-here',
    program_id := 'uuid-here',
    product_data := '{
        "product_name": "Sample Product",
        "product_url": "https://example.com/product",
        "placement_type": "inline"
    }'::jsonb
);
```

#### `track_affiliate_click()`
Records affiliate link clicks with attribution.

```sql
SELECT track_affiliate_click(
    link_id := 'uuid-here',
    user_data := '{
        "ip_address": "192.168.1.1",
        "user_agent": "Mozilla/5.0...",
        "referrer": "https://google.com"
    }'::jsonb
);
```

#### `calculate_revenue_metrics()`
Calculates revenue performance for articles/niches.

```sql
SELECT * FROM calculate_revenue_metrics(
    entity_type := 'article',
    entity_id := 'uuid-here',
    date_range := '30 days'
);
```

### A/B Testing

#### `create_ab_experiment()`
Sets up A/B testing experiments.

```sql
SELECT create_ab_experiment(
    name := 'Headline Test',
    variants := '[
        {"name": "control", "weight": 0.5},
        {"name": "variant_a", "weight": 0.5}
    ]'::jsonb,
    target_metric := 'conversion_rate'
);
```

#### `assign_ab_variant()`
Assigns users to A/B test variants.

```sql
SELECT assign_ab_variant(
    experiment_id := 'uuid-here',
    user_id := 'uuid-here', -- optional
    session_id := 'session-id'
);
```

#### `record_ab_conversion()`
Records conversion events for A/B tests.

```sql
SELECT record_ab_conversion(
    assignment_id := 'uuid-here',
    conversion_value := 29.99
);
```

## 🌍 Multi-Language Functions

### Translation Management

#### `create_translation()`
Creates translations for content entities.

```sql
SELECT create_translation(
    entity_type := 'article',
    entity_id := 'uuid-here',
    target_language := 'es',
    translation_data := '{
        "title": "Título en Español",
        "content": "Contenido en español...",
        "meta_description": "Descripción meta"
    }'::jsonb
);
```

#### `get_translation_coverage()`
Analyzes translation coverage across languages.

```sql
SELECT * FROM get_translation_coverage(
    entity_type := 'article',
    target_languages := ARRAY['es', 'fr', 'de']
);
```

#### `update_translation_quality()`
Updates translation quality scores.

```sql
SELECT update_translation_quality(
    translation_id := 'uuid-here',
    quality_score := 0.95,
    human_reviewed := true,
    reviewer_id := 'uuid-here'
);
```

## 🔄 Workflow Functions

### Content Workflow

#### `queue_content_topic()`
Adds topics to the content creation queue.

```sql
SELECT queue_content_topic(
    topic := 'AI in Healthcare',
    niche_id := 'uuid-here',
    priority := 'high',
    metadata := '{
        "target_keywords": ["AI", "healthcare", "medical"],
        "estimated_word_count": 2000
    }'::jsonb
);
```

#### `process_content_queue()`
Processes queued content topics in batches.

```sql
SELECT * FROM process_content_queue(
    batch_size := 10,
    priority_filter := 'high'
);
```

#### `update_workflow_state()`
Updates workflow execution states.

```sql
SELECT update_workflow_state(
    workflow_name := 'content_generation',
    execution_id := 'n8n-execution-id',
    entity_id := 'uuid-here',
    new_state := 'processing',
    state_data := '{"progress": 50}'::jsonb
);
```

### N8N Integration

#### `log_n8n_execution()`
Logs n8n workflow executions.

```sql
SELECT log_n8n_execution(
    workflow_id := 'workflow-id',
    execution_id := 'execution-id',
    status := 'success',
    metrics := '{
        "duration_ms": 5000,
        "nodes_executed": 8,
        "memory_usage_mb": 128
    }'::jsonb
);
```

#### `get_workflow_performance()`
Analyzes workflow performance metrics.

```sql
SELECT * FROM get_workflow_performance(
    workflow_name := 'content_generation',
    date_range := '7 days'
);
```

## 🛡️ System Functions

### Cache Management

#### `invalidate_smart_cache()`
Invalidates cache entries based on tags or dependencies.

```sql
SELECT invalidate_smart_cache(
    cache_tags := ARRAY['article', 'uuid-here'],
    cascade_dependencies := true
);
```

#### `get_cache_statistics()`
Retrieves cache performance statistics.

```sql
SELECT * FROM get_cache_statistics(
    cache_type := 'article_data',
    time_period := '24 hours'
);
```

### Performance Monitoring

#### `log_performance_metric()`
Records system performance metrics.

```sql
SELECT log_performance_metric(
    endpoint := '/api/articles',
    method := 'GET',
    response_time_ms := 150,
    user_id := 'uuid-here'
);
```

#### `get_system_health()`
Comprehensive system health check.

```sql
SELECT * FROM get_system_health();
```

**Returns:**
- Database connection status
- Cache hit rates
- Queue depths
- Error rates
- Performance metrics

### Rate Limiting

#### `check_rate_limit()`
Checks and updates rate limiting counters.

```sql
SELECT check_rate_limit(
    identifier := 'user-id-or-ip',
    identifier_type := 'user',
    endpoint := '/api/content/generate',
    limit_per_window := 100
);
```

#### `get_rate_limit_status()`
Retrieves current rate limit status.

```sql
SELECT * FROM get_rate_limit_status(
    identifier := 'user-id',
    identifier_type := 'user'
);
```

## 📊 Reporting Functions

### Business Intelligence

#### `generate_content_report()`
Comprehensive content performance report.

```sql
SELECT * FROM generate_content_report(
    date_from := '2024-01-01',
    date_to := '2024-12-31',
    grouping := 'niche',
    metrics := ARRAY['views', 'engagement', 'revenue']
);
```

#### `get_revenue_dashboard()`
Revenue analytics dashboard data.

```sql
SELECT * FROM get_revenue_dashboard(
    time_period := '30 days',
    breakdown := 'daily'
);
```

#### `analyze_user_behavior()`
User behavior analysis and insights.

```sql
SELECT * FROM analyze_user_behavior(
    user_segment := 'active_readers',
    analysis_type := 'content_preferences'
);
```

## 🔧 Utility Functions

### Data Maintenance

#### `cleanup_expired_data()`
Removes expired cache entries and temporary data.

```sql
SELECT cleanup_expired_data(
    table_types := ARRAY['cache', 'logs', 'temp'],
    retention_days := 30
);
```

#### `rebuild_search_indexes()`
Rebuilds full-text search indexes.

```sql
SELECT rebuild_search_indexes(
    table_name := 'articles',
    language := 'english'
);
```

#### `update_content_statistics()`
Updates denormalized statistics across tables.

```sql
SELECT update_content_statistics(
    entity_types := ARRAY['niches', 'categories', 'authors']
);
```

## 📈 Performance Considerations

### Batch Operations
- Use batch functions for bulk operations
- Process large datasets in chunks
- Monitor memory usage during operations

### Indexing Strategy
- Vector indexes for similarity search
- GIN indexes for full-text search
- Composite indexes for complex queries

### Caching
- Smart cache with dependency tracking
- Automatic cache invalidation
- Performance-based cache warming

## 🔍 Error Handling

All functions include comprehensive error handling:
- Input validation
- Constraint checking
- Rollback on failure
- Detailed error messages
- Dead letter queue for failed operations

## 📚 Examples

### Complete Content Creation Workflow
```sql
-- 1. Create article
SELECT create_article_with_metadata(
    title := 'AI Revolution in 2024',
    content := 'Comprehensive article content...',
    niche_id := (SELECT id FROM niches WHERE slug = 'technology'),
    author_id := (SELECT id FROM authors WHERE slug = 'john-doe'),
    meta_data := '{"target_keywords": ["AI", "2024", "technology"]}'::jsonb
) AS article_id \gset

-- 2. Add SEO metrics
SELECT update_seo_metrics(
    article_id := :'article_id',
    metrics := '{"seo_score": 85, "target_keywords": ["AI", "technology"]}'::jsonb
);

-- 3. Create affiliate links
SELECT create_affiliate_link(
    article_id := :'article_id',
    program_id := (SELECT id FROM affiliate_programs WHERE name = 'Amazon Associates'),
    product_data := '{"product_name": "AI Book", "placement_type": "inline"}'::jsonb
);

-- 4. Track performance
SELECT track_user_event(
    event_type := 'article_published',
    article_id := :'article_id',
    metadata := '{"source": "cms"}'::jsonb
);
```

---

*These functions provide enterprise-grade content management capabilities with comprehensive analytics, monetization, and performance monitoring.*