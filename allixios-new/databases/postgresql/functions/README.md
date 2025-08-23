# Database Functions Documentation

This directory contains all database functions for the Allixios platform, organized by functionality.

## 📁 Function Files

### 001_content_functions.sql
**Content Management Functions**
- `fetch_content_batch()` - Batch processing for content queue
- `upsert_authors_batch()` - Bulk author management
- `upsert_tags_batch()` - Bulk tag management  
- `insert_article_complete()` - Complete article creation with relationships
- `update_topic_status()` - Workflow status management
- `generate_media_batch()` - Media generation for content
- `get_article_details()` - Comprehensive article data retrieval

### 002_analytics_functions.sql
**Analytics & SEO Functions**
- `update_seo_metrics()` - SEO performance tracking
- `track_article_view()` - User behavior analytics
- `calculate_engagement_metrics()` - Engagement scoring
- `generate_performance_report()` - Performance reporting
- `track_affiliate_click()` - Monetization tracking
- `fetch_performance_data()` - AI analysis data
- `update_revenue_metrics()` - Revenue optimization

### 003_entity_functions.sql
**Entity Management Functions**
- `resolve_or_create_entity()` - Smart entity resolution
- `batch_resolve_entities()` - Bulk entity processing
- `update_author_stats()` - Author statistics
- `get_entity_suggestions()` - Auto-complete suggestions
- `merge_entities()` - Duplicate entity management
- `cleanup_entity_cache()` - Cache maintenance
- `get_category_hierarchy()` - Hierarchical data retrieval

### 004_workflow_functions.sql
**Workflow & Automation Functions**
- `create_content_topic()` - Content planning
- `get_workflow_status()` - Execution monitoring
- `track_n8n_execution()` - n8n integration
- `track_n8n_node_execution()` - Node-level tracking
- `get_workflow_performance()` - Performance analytics
- `update_workflow_state()` - State management
- `get_queue_statistics()` - Queue monitoring
- `cleanup_workflow_data()` - Data maintenance

### 005_media_functions.sql
**Media Management Functions**
- `upload_media()` - Media upload and processing queue
- `attach_media_to_article()` - Content-media relationships
- `get_article_media()` - Media retrieval with variants
- `process_media_queue()` - Async media processing
- `complete_media_processing()` - Processing completion
- `create_media_collection()` - Media organization
- `add_media_to_collection()` - Collection management
- `get_media_details()` - Comprehensive media data
- `cleanup_unused_media()` - Storage optimization

## 🚀 Usage Examples

### Content Management
```sql
-- Create a complete article with media
SELECT insert_article_complete(
  '00000000-0000-0000-0000-000000000001'::UUID,
  '{
    "title": "AI-Powered Content Creation",
    "content": "Article content here...",
    "niche_id": "niche-uuid",
    "author_id": "author-uuid",
    "media_data": [
      {
        "media_id": "media-uuid",
        "usage_type": "featured",
        "position": 1,
        "alignment": "center",
        "size": "large"
      }
    ]
  }'::JSONB
);

-- Get article with all media
SELECT get_article_details('article-uuid');
```

### Media Management
```sql
-- Upload and process media
SELECT upload_media(
  'tenant-uuid'::UUID,
  '{
    "filename": "hero-image.jpg",
    "mime_type": "image/jpeg",
    "file_size": 2048000,
    "width": 1920,
    "height": 1080,
    "storage_path": "/uploads/2024/01/hero-image.jpg",
    "cdn_url": "https://cdn.example.com/hero-image.jpg"
  }'::JSONB
);

-- Attach media to article with specific configuration
SELECT attach_media_to_article(
  'article-uuid'::UUID,
  'media-uuid'::UUID,
  'hero',
  1,
  'header',
  'full-width',
  'large',
  'Custom caption for this usage',
  'Custom alt text'
);

-- Get all media for an article
SELECT get_article_media('article-uuid');
```

### Analytics & Performance
```sql
-- Track article view with media analytics
SELECT track_article_view(
  'article-uuid'::UUID,
  'user-uuid'::UUID,
  'session-id',
  'https://referrer.com',
  'Mozilla/5.0...',
  '192.168.1.1'::INET
);

-- Generate performance report
SELECT generate_performance_report(
  'tenant-uuid'::UUID,
  CURRENT_DATE - INTERVAL '30 days',
  CURRENT_DATE
);
```

### Workflow Management
```sql
-- Create content topic with media requirements
SELECT create_content_topic(
  'tenant-uuid'::UUID,
  '{
    "topic": "Future of AI in Healthcare",
    "description": "Comprehensive guide...",
    "niche_name": "Technology",
    "priority": "high",
    "metadata": {
      "media_requirements": {
        "featured_image": true,
        "inline_images": 3,
        "infographics": 1
      }
    }
  }'::JSONB
);

-- Get workflow performance
SELECT get_workflow_performance('content-generation-workflow', 24);
```

## 🔧 Function Categories

### **Content Functions**
- Article lifecycle management
- Author and tag management
- Content relationships
- Media integration

### **Analytics Functions**  
- Performance tracking
- User behavior analysis
- SEO optimization
- Revenue analytics

### **Entity Functions**
- Smart entity resolution
- Duplicate management
- Hierarchical data
- Auto-suggestions

### **Workflow Functions**
- n8n integration
- Queue management
- Performance monitoring
- State tracking

### **Media Functions**
- Upload processing
- Format optimization
- Variant generation
- Usage tracking
- Collection management

## 🛡️ Security Features

All functions include:
- **Parameter validation** - Input sanitization and type checking
- **Permission checks** - Role-based access control
- **Audit logging** - Complete operation tracking
- **Error handling** - Graceful failure management
- **Performance optimization** - Efficient query patterns

## 📊 Performance Considerations

### Indexing
All functions are optimized with appropriate indexes:
- **Composite indexes** for multi-column queries
- **Partial indexes** for filtered operations
- **GIN indexes** for JSONB and array operations
- **Unique indexes** for constraint enforcement

### Caching
Functions utilize multiple caching layers:
- **Entity resolution cache** for repeated lookups
- **Smart cache** for computed results
- **Performance intelligence cache** for AI insights
- **Media variant cache** for optimized delivery

### Batch Processing
Bulk operations are optimized for performance:
- **Batch inserts** with conflict resolution
- **Atomic transactions** for data consistency
- **Queue processing** for async operations
- **Parallel execution** where possible

## 🔍 Monitoring & Debugging

### Function Performance
```sql
-- Monitor function execution times
SELECT 
  schemaname,
  funcname,
  calls,
  total_time,
  mean_time,
  stddev_time
FROM pg_stat_user_functions
WHERE schemaname = 'public'
ORDER BY total_time DESC;
```

### Error Tracking
```sql
-- Check function errors in logs
SELECT * FROM application_logs 
WHERE level = 'error' 
  AND service LIKE '%function%'
ORDER BY timestamp DESC;
```

### Cache Performance
```sql
-- Monitor cache hit rates
SELECT 
  cache_type,
  COUNT(*) as entries,
  AVG(hit_count) as avg_hits,
  SUM(CASE WHEN hit_count > 0 THEN 1 ELSE 0 END)::FLOAT / COUNT(*) * 100 as hit_rate
FROM smart_cache
GROUP BY cache_type;
```

## 📚 Related Documentation

- [Database Schema](../schemas/README.md)
- [Migration Guide](../migrations/README.md)
- [API Documentation](../../../docs/api/README.md)
- [Performance Tuning](../../../docs/performance/README.md)

---

*These functions provide enterprise-grade functionality for content management, analytics, and media processing with optimal performance and security.*