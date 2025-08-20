# 🔄 Database Migration Guide

## Overview

This guide covers migrating to the new comprehensive Allixios database schema with enhanced features including advanced analytics, monetization, A/B testing, and workflow automation.

## 🚨 Pre-Migration Checklist

### 1. Backup Current Database
```bash
# Create full database backup
pg_dump -h your-db-host -U postgres -d your-database > backup_$(date +%Y%m%d_%H%M%S).sql

# Verify backup integrity
psql -h your-db-host -U postgres -d test_restore < backup_file.sql
```

### 2. Environment Preparation
```bash
# Set environment variables
export SUPABASE_DB_HOST="your-db-host"
export SUPABASE_DB_USER="postgres"
export SUPABASE_DB_NAME="postgres"

# Test connection
psql -h $SUPABASE_DB_HOST -U $SUPABASE_DB_USER -d $SUPABASE_DB_NAME -c "SELECT version();"
```

### 3. Extension Requirements
```sql
-- Ensure required extensions are available
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS btree_gin;
```

## 📋 Migration Steps

### Step 1: Deploy New Schema
```bash
# Deploy the complete new schema
npm run deploy:schema

# Or manually:
psql -h $SUPABASE_DB_HOST -U postgres -d postgres -f core/database/schema/complete-schema.sql
```

### Step 2: Data Migration Scripts

#### Migrate Existing Articles
```sql
-- Update articles table with new fields
UPDATE articles SET 
    content_quality_score = COALESCE(content_score, 0),
    time_on_page = COALESCE(avg_time_on_page, 0),
    social_shares = COALESCE(share_count, 0),
    is_active = true
WHERE content_quality_score IS NULL;
```

#### Migrate User Data
```sql
-- Ensure all users have required fields
UPDATE users SET 
    language = 'en'::language_code,
    timezone = 'UTC',
    is_active = true,
    last_activity = COALESCE(last_login, created_at)
WHERE language IS NULL;
```

#### Create Default Niches and Categories
```sql
-- Insert default niche if none exist
INSERT INTO niches (slug, name, description, is_active)
SELECT 'general', 'General', 'General content category', true
WHERE NOT EXISTS (SELECT 1 FROM niches);

-- Create default category
INSERT INTO categories (niche_id, slug, name, description, is_active)
SELECT n.id, 'uncategorized', 'Uncategorized', 'Default category for uncategorized content', true
FROM niches n
WHERE n.slug = 'general'
AND NOT EXISTS (SELECT 1 FROM categories);
```

### Step 3: Initialize New Tables

#### Set Up Default Affiliate Programs
```sql
-- Example affiliate program setup
INSERT INTO affiliate_programs (name, description, network, commission_type, commission_rate, base_url, is_active)
VALUES 
    ('Amazon Associates', 'Amazon affiliate program', 'Amazon', 'percentage', 4.0, 'https://amazon.com', true),
    ('Generic Affiliate', 'Default affiliate program', 'Direct', 'percentage', 5.0, 'https://example.com', true);
```

#### Initialize SEO Metrics
```sql
-- Create SEO metrics entries for existing articles
INSERT INTO seo_metrics (article_id, seo_score, accessibility_score, mobile_friendly)
SELECT id, 50, 80, true
FROM articles 
WHERE status = 'published'
AND NOT EXISTS (SELECT 1 FROM seo_metrics WHERE article_id = articles.id);
```

#### Initialize Revenue Metrics
```sql
-- Create revenue metrics entries for existing articles
INSERT INTO revenue_metrics (article_id, total_revenue, affiliate_revenue, conversion_rate)
SELECT id, 0.00, 0.00, 0.00
FROM articles 
WHERE status = 'published'
AND NOT EXISTS (SELECT 1 FROM revenue_metrics WHERE article_id = articles.id);
```

### Step 4: Update Indexes and Performance
```sql
-- Rebuild statistics
ANALYZE;

-- Update index statistics
REINDEX DATABASE postgres;

-- Vacuum to reclaim space
VACUUM ANALYZE;
```

## 🔧 Post-Migration Tasks

### 1. Verify Data Integrity
```sql
-- Check foreign key constraints
SELECT conname, conrelid::regclass, confrelid::regclass
FROM pg_constraint
WHERE contype = 'f'
AND NOT EXISTS (
    SELECT 1 FROM information_schema.referential_constraints
    WHERE constraint_name = conname
);

-- Verify article relationships
SELECT COUNT(*) as orphaned_articles
FROM articles a
LEFT JOIN niches n ON a.niche_id = n.id
WHERE n.id IS NULL;
```

### 2. Performance Validation
```sql
-- Test vector search performance
EXPLAIN ANALYZE 
SELECT title, vector_embedding <-> '[0,1,0,...]'::vector as similarity
FROM articles 
ORDER BY similarity 
LIMIT 10;

-- Test full-text search
EXPLAIN ANALYZE
SELECT title, ts_rank(to_tsvector('english', title || ' ' || content), plainto_tsquery('search term'))
FROM articles
WHERE to_tsvector('english', title || ' ' || content) @@ plainto_tsquery('search term');
```

### 3. Update Application Configuration

#### Environment Variables
```env
# Add new environment variables
ENABLE_VECTOR_SEARCH=true
ENABLE_AB_TESTING=true
ENABLE_ANALYTICS=true
ENABLE_MONETIZATION=true
DEFAULT_LANGUAGE=en
MAX_TRANSLATION_LANGUAGES=10
```

#### Feature Flags
```json
{
  "features": {
    "vectorSearch": true,
    "abTesting": true,
    "analytics": true,
    "monetization": true,
    "multiLanguage": true,
    "newsletter": true,
    "smartCache": true
  }
}
```

## 🚨 Rollback Procedure

### Emergency Rollback
```bash
# Stop all applications
systemctl stop your-app

# Restore from backup
psql -h $SUPABASE_DB_HOST -U postgres -d postgres < backup_file.sql

# Restart applications
systemctl start your-app
```

### Partial Rollback (Table-by-Table)
```sql
-- Drop new tables if needed
DROP TABLE IF EXISTS ab_experiments CASCADE;
DROP TABLE IF EXISTS ab_assignments CASCADE;
DROP TABLE IF EXISTS newsletter_campaigns CASCADE;
-- ... continue for other new tables

-- Restore specific tables from backup
\i backup_specific_table.sql
```

## 📊 Migration Monitoring

### Performance Metrics
```sql
-- Monitor migration progress
SELECT 
    schemaname,
    tablename,
    n_tup_ins as inserts,
    n_tup_upd as updates,
    n_tup_del as deletes
FROM pg_stat_user_tables
ORDER BY n_tup_ins + n_tup_upd + n_tup_del DESC;
```

### Error Monitoring
```sql
-- Check for constraint violations
SELECT conname, conrelid::regclass
FROM pg_constraint
WHERE NOT convalidated;

-- Monitor locks during migration
SELECT 
    locktype,
    database,
    relation::regclass,
    mode,
    granted
FROM pg_locks
WHERE NOT granted;
```

## 🔍 Validation Queries

### Data Completeness
```sql
-- Verify all articles have required relationships
SELECT 
    COUNT(*) as total_articles,
    COUNT(niche_id) as with_niche,
    COUNT(author_id) as with_author,
    COUNT(vector_embedding) as with_embeddings
FROM articles;

-- Check translation coverage
SELECT 
    language,
    COUNT(*) as article_count
FROM articles
GROUP BY language
ORDER BY article_count DESC;
```

### Performance Validation
```sql
-- Test query performance on large tables
EXPLAIN (ANALYZE, BUFFERS)
SELECT a.title, n.name as niche, c.name as category
FROM articles a
JOIN niches n ON a.niche_id = n.id
LEFT JOIN categories c ON a.category_id = c.id
WHERE a.status = 'published'
ORDER BY a.published_at DESC
LIMIT 100;
```

## 📚 Troubleshooting

### Common Issues

#### Vector Extension Not Available
```sql
-- Install vector extension
CREATE EXTENSION IF NOT EXISTS vector;

-- If not available, install from source or package manager
-- Ubuntu/Debian: apt install postgresql-15-pgvector
-- CentOS/RHEL: yum install pgvector
```

#### Memory Issues During Migration
```sql
-- Increase work_mem temporarily
SET work_mem = '256MB';

-- Process in smaller batches
UPDATE articles SET content_quality_score = 0 
WHERE id IN (
    SELECT id FROM articles 
    WHERE content_quality_score IS NULL 
    LIMIT 1000
);
```

#### Lock Timeouts
```sql
-- Increase lock timeout
SET lock_timeout = '30s';

-- Use smaller transactions
BEGIN;
-- Smaller batch operations
COMMIT;
```

## 📞 Support

For migration issues:
1. Check logs: `tail -f /var/log/postgresql/postgresql.log`
2. Monitor performance: Use `pg_stat_activity` and `pg_locks`
3. Validate data: Run validation queries after each step
4. Document issues: Keep detailed logs of any problems encountered

---

*Migration completed successfully! Your Allixios platform now has enterprise-grade features and performance capabilities.*