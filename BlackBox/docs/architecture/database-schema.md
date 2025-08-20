# 🗄️ Database Schema Documentation

## Overview

The Allixios platform uses a comprehensive PostgreSQL schema designed for scalable content management, advanced analytics, and enterprise-grade performance. The schema supports multi-language content, AI-powered features, monetization, and extensive workflow automation.

## 📊 Schema Statistics

- **Total Tables**: 35+
- **Custom Types**: 7 enums for type safety
- **Indexes**: 20+ optimized indexes including vector search
- **Views**: Performance-optimized views for common queries
- **Languages Supported**: 50+ with full translation system
- **Vector Dimensions**: 1536 (OpenAI/Gemini compatible)

## 🏗️ Core Architecture

### Content Hierarchy
```
niches (top-level domains)
├── categories (subcategories with nesting)
│   └── articles (main content entities)
└── tags (cross-cutting labels)
```

### User Management
```
users (system users)
├── authors (content creators)
├── roles (access control)
└── user_* tables (bookmarks, comments, etc.)
```

### Workflow System
```
topics_queue → content_plans → articles → content_versions
                                    ├── translations
                                    └── analytics_events
```

## 📋 Table Categories

### 🎯 Core Content Tables
- `articles` - Main content entities with full metadata
- `niches` - Top-level content domains
- `categories` - Hierarchical content organization
- `tags` - Flexible content labeling
- `media` - Asset management with AI analysis
- `authors` - Content creator profiles

### 👥 User & Access Management
- `users` - System user accounts
- `user_bookmarks` - User saved content
- `user_comments` - User-generated comments
- `newsletter_subscribers` - Email subscription management

### 🔄 Content Workflow
- `topics_queue` - Content ideas and planning
- `content_plans` - Strategic content creation
- `content_versions` - Version control for content
- `translations` - Multi-language content support

### 💰 Monetization
- `affiliate_programs` - Partner program definitions
- `affiliate_links` - Article-specific monetization
- `affiliate_clicks` - Performance tracking
- `revenue_metrics` - Revenue analysis per article

### 📈 Analytics & SEO
- `analytics_events` - User behavior tracking
- `seo_metrics` - SEO performance per article
- `ab_experiments` - A/B testing framework
- `ab_assignments` - Test variant assignments

### 📧 Newsletter System
- `newsletter_subscribers` - Subscriber management
- `newsletter_campaigns` - Email campaign management

### 🤖 Automation & Workflows
- `workflow_states` - n8n workflow state tracking
- `n8n_executions` - Execution monitoring
- `n8n_execution_nodes` - Node-level performance
- `n8n_performance_profiles` - Performance analytics

### 🛠️ System & Performance
- `smart_cache` - Intelligent caching system
- `performance_logs` - System performance tracking
- `api_rate_limits` - Rate limiting management
- `dead_letter_queue` - Error handling and recovery

## 🔍 Key Features

### Vector Search
- **Embedding Storage**: 1536-dimensional vectors for semantic search
- **Index Type**: IVFFlat for efficient similarity search
- **Use Cases**: Content recommendations, semantic search, topic clustering

### Multi-Language Support
- **Language Enum**: 50+ supported languages
- **Translation System**: Dedicated translations table
- **Quality Tracking**: Translation quality scoring and human review flags

### Performance Optimization
- **Smart Indexing**: Comprehensive index strategy for all query patterns
- **Caching System**: Multi-level caching with dependency tracking
- **Batch Processing**: Optimized for high-volume content operations

### Analytics & Insights
- **Event Tracking**: Comprehensive user behavior analytics
- **Performance Metrics**: Real-time performance monitoring
- **A/B Testing**: Built-in experimentation framework

## 📊 Performance Considerations

### Indexing Strategy
```sql
-- Core content indexes
CREATE INDEX idx_articles_slug ON articles(slug);
CREATE INDEX idx_articles_status ON articles(status);
CREATE INDEX idx_articles_published_at ON articles(published_at);

-- Vector similarity search
CREATE INDEX idx_articles_vector_embedding ON articles 
USING ivfflat (vector_embedding vector_cosine_ops) WITH (lists = 100);

-- Full-text search
CREATE INDEX idx_articles_title_fts ON articles 
USING gin(to_tsvector('english', title));
```

### Query Optimization
- **Materialized Views**: Pre-computed aggregations for dashboards
- **Partial Indexes**: Filtered indexes for common query patterns
- **Composite Indexes**: Multi-column indexes for complex queries

## 🔐 Security Features

### Row Level Security (RLS)
- **User Data Protection**: Users can only access their own data
- **Content Visibility**: Published content visible to all, drafts to authors only
- **Role-Based Access**: Different access levels based on user roles

### Data Validation
- **Email Validation**: Regex-based email format validation
- **Constraint Checks**: Range checks for scores and percentages
- **Foreign Key Integrity**: Referential integrity across all relationships

## 🚀 Scaling Considerations

### Horizontal Scaling
- **UUID Primary Keys**: Distributed system compatibility
- **Partitioning Ready**: Tables designed for future partitioning
- **Connection Pooling**: Optimized for connection pool usage

### Performance Monitoring
- **Execution Tracking**: Detailed workflow execution monitoring
- **Performance Profiling**: Node-level performance analysis
- **Resource Usage**: Memory and CPU usage tracking

## 📝 Migration Strategy

### Version Control
- **Schema Versioning**: Tracked schema changes
- **Migration Scripts**: Automated migration procedures
- **Rollback Support**: Safe rollback procedures

### Data Migration
- **Batch Processing**: Large dataset migration support
- **Zero Downtime**: Online migration capabilities
- **Data Validation**: Post-migration data integrity checks

## 🔧 Development Guidelines

### Adding New Tables
1. Follow UUID primary key pattern
2. Include created_at/updated_at timestamps
3. Add appropriate indexes for query patterns
4. Consider RLS policies for security
5. Document relationships and constraints

### Performance Best Practices
1. Use appropriate index types (B-tree, GIN, GiST, IVFFlat)
2. Implement proper foreign key constraints
3. Use JSONB for flexible metadata storage
4. Consider partitioning for large tables
5. Monitor query performance regularly

## 📚 Related Documentation

- [API Documentation](../api/README.md)
- [Workflow Documentation](../workflows/README.md)
- [Deployment Guide](../deployment/README.md)
- [Performance Tuning](./performance-tuning.md)

---

*This schema supports enterprise-scale content operations with advanced AI features, comprehensive analytics, and robust performance monitoring.*