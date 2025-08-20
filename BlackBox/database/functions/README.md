# Database Functions - Allixios Platform

This directory contains all database functions organized by functionality for better maintainability and deployment.

## 📁 Function Categories

### 🔧 **content-functions.sql**
Functions for content management and article processing:
- `fetch_and_lock_topics()` - Atomic topic fetching with locking
- `create_article_complete()` - Complete article creation with relationships
- `update_article_content()` - Content updates with versioning

### 👥 **entity-functions.sql**
Functions for entity management and resolution:
- `resolve_or_create_entity()` - Smart entity resolution with caching
- `batch_resolve_entities()` - Batch entity processing
- `update_author_stats()` - Author statistics maintenance
- `cleanup_entity_cache()` - Cache maintenance

### 🛠️ **utility-functions.sql**
General purpose utility functions:
- `release_processing_lock()` - Lock management
- `cleanup_expired_locks()` - Lock maintenance
- `generate_unique_slug()` - Slug generation
- `validate_json_schema()` - JSON validation
- `calculate_content_quality_score()` - Content scoring
- `log_system_event()` - System logging

### 📊 **analytics-functions.sql**
Analytics, SEO, and performance tracking:
- `update_seo_metrics()` - SEO metrics management
- `track_article_view()` - View tracking
- `calculate_engagement_metrics()` - Engagement analysis
- `generate_performance_report()` - Performance reporting
- `track_affiliate_click()` - Affiliate tracking

## 🚀 Deployment Order

Deploy functions in this order to handle dependencies:

1. **utility-functions.sql** (base utilities)
2. **entity-functions.sql** (entity management)
3. **content-functions.sql** (content operations)
4. **analytics-functions.sql** (tracking and metrics)

## 📋 Usage Examples

### Content Creation
```sql
-- Create a complete article with tags
SELECT create_article_complete(
  '{"title": "AI in Healthcare", "content": "...", "niche_id": "uuid", "author_id": "uuid"}'::jsonb,
  ARRAY['AI', 'Healthcare', 'Technology']
);
```

### Entity Resolution
```sql
-- Resolve or create an author
SELECT resolve_or_create_entity(
  'author',
  'John Doe',
  '{"display_name": "John Doe", "bio": "Tech writer"}'::jsonb
);
```

### Analytics Tracking
```sql
-- Track article view
SELECT track_article_view(
  'article-uuid',
  'user-uuid',
  'session-id',
  'https://google.com'
);
```

### Performance Monitoring
```sql
-- Generate performance report
SELECT generate_performance_report(
  CURRENT_DATE - INTERVAL '30 days',
  CURRENT_DATE
);
```

## 🔒 Security & Permissions

All functions are granted to:
- `authenticated` role (for user operations)
- `service_role` role (for system operations)

## 🧹 Maintenance

### Regular Cleanup Tasks
```sql
-- Clean expired locks (run hourly)
SELECT cleanup_expired_locks();

-- Clean entity cache (run daily)
SELECT cleanup_entity_cache();
```

### Performance Monitoring
```sql
-- Check function performance
SELECT schemaname, funcname, calls, total_time, 
       CASE WHEN calls > 0 THEN total_time/calls ELSE 0 END as mean_time
FROM pg_stat_user_functions
ORDER BY total_time DESC;
```

## 🔄 Migration Strategy

When updating functions:
1. Test in development environment
2. Deploy during low-traffic periods
3. Monitor function performance
4. Rollback if issues occur

## 📝 Function Documentation

Each function includes:
- Purpose and usage description
- Parameter documentation
- Return value specification
- Error handling details
- Performance considerations

## 🎯 Best Practices

- **Atomic Operations**: All functions handle transactions properly
- **Error Handling**: Comprehensive exception handling
- **Performance**: Optimized queries with proper indexing
- **Security**: Input validation and SQL injection prevention
- **Logging**: System events tracked for debugging
- **Caching**: Entity resolution caching for performance