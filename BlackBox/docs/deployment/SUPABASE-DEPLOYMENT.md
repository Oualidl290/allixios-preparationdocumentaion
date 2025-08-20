# 🚀 Supabase Deployment Guide

## Overview

This guide covers deploying the Allixios platform to Supabase with the complete database schema, including advanced features like vector search, analytics, and monetization.

## 📋 Prerequisites

### 1. Supabase Project Setup
- [ ] **Supabase Account**: Create account at [supabase.com](https://supabase.com)
- [ ] **New Project**: Create a new Supabase project
- [ ] **Database Access**: Note your database connection details
- [ ] **API Keys**: Save your project URL and service role key

### 2. Required Extensions
- [ ] **pgvector**: For semantic search (may need manual installation)
- [ ] **pg_trgm**: For full-text search (usually available)
- [ ] **btree_gin**: For advanced indexing (usually available)

### 3. Environment Variables
```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
```

## 🗄️ Database Schema Deployment

### Step 1: Deploy the Schema
```bash
# Using the Supabase-optimized schema
psql -h db.your-project.supabase.co -U postgres -d postgres -f core/database/schema/supabase-schema.sql

# Or using npm script (update package.json first)
npm run deploy:supabase-schema
```

### Step 2: Verify Deployment
```sql
-- Check tables created
SELECT COUNT(*) as table_count 
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name NOT LIKE 'pg_%';

-- Check extensions
SELECT extname, extversion 
FROM pg_extension 
WHERE extname IN ('vector', 'pg_trgm', 'btree_gin', 'uuid-ossp');

-- Check custom types
SELECT typname 
FROM pg_type 
WHERE typname IN ('language_code', 'user_role', 'content_status', 'workflow_status');
```

### Step 3: Vector Extension Setup (If Needed)
If pgvector is not available, you may need to request it:

```sql
-- Check if vector extension is available
SELECT * FROM pg_available_extensions WHERE name = 'vector';

-- If not available, contact Supabase support or use alternative approach
-- The schema will work without vector search, but semantic features will be limited
```

## 🔐 Row Level Security (RLS) Configuration

### Understanding RLS in Supabase
Supabase uses PostgreSQL's Row Level Security with `auth.uid()` for user identification.

### Default Policies Included
The schema includes basic RLS policies:

```sql
-- Users can only see their own data
CREATE POLICY "Users can view their own data" ON public.users
    FOR SELECT USING (auth.uid()::text = id::text);

-- Published articles are public, drafts are author-only
CREATE POLICY "Published articles are viewable by all" ON public.articles
    FOR SELECT USING (status = 'published' OR auth.uid()::text = author_id::text);
```

### Customizing RLS Policies
Add more specific policies based on your needs:

```sql
-- Allow authors to update their own articles
CREATE POLICY "Authors can update their articles" ON public.articles
    FOR UPDATE USING (auth.uid()::text = author_id::text);

-- Allow admins to see everything
CREATE POLICY "Admins can see all articles" ON public.articles
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.users 
            WHERE id::text = auth.uid()::text 
            AND role IN ('admin', 'super_admin')
        )
    );
```

## 📊 Initial Data Setup

### Step 1: Create Default Data
The schema automatically creates:
- Default "General" niche
- Default "Uncategorized" category

### Step 2: Add Sample Data (Optional)
```sql
-- Insert sample author
INSERT INTO public.authors (display_name, slug, bio, is_active)
VALUES ('System Author', 'system', 'Default system author for automated content', true);

-- Insert sample affiliate program
INSERT INTO public.affiliate_programs (name, description, base_url, commission_rate, is_active)
VALUES ('Sample Program', 'Sample affiliate program for testing', 'https://example.com', 5.0, true);
```

## 🔧 Supabase-Specific Configuration

### 1. API Settings
In your Supabase dashboard:
- **Settings > API**: Configure API settings
- **Authentication > Settings**: Set up auth providers
- **Database > Extensions**: Enable required extensions

### 2. Storage Setup (For Media)
```sql
-- Create storage bucket for media
INSERT INTO storage.buckets (id, name, public)
VALUES ('media', 'media', true);

-- Create storage policies
CREATE POLICY "Public media access" ON storage.objects
    FOR SELECT USING (bucket_id = 'media');

CREATE POLICY "Authenticated users can upload" ON storage.objects
    FOR INSERT WITH CHECK (bucket_id = 'media' AND auth.role() = 'authenticated');
```

### 3. Edge Functions (Optional)
If using Supabase Edge Functions:
```typescript
// Example Edge Function for AI content generation
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
  )
  
  // Your AI content generation logic here
  
  return new Response(JSON.stringify({ success: true }), {
    headers: { 'Content-Type': 'application/json' }
  })
})
```

## 📈 Performance Optimization

### 1. Database Configuration
In Supabase dashboard > Settings > Database:
- **Connection Pooling**: Enable for better performance
- **Read Replicas**: Consider for high-traffic scenarios

### 2. Index Optimization
The schema includes optimized indexes, but monitor performance:
```sql
-- Check index usage
SELECT schemaname, tablename, indexname, idx_scan, idx_tup_read, idx_tup_fetch
FROM pg_stat_user_indexes
ORDER BY idx_scan DESC;

-- Check slow queries
SELECT query, 
       COALESCE(mean_exec_time, mean_time) as mean_time, 
       calls, 
       total_exec_time as total_time
FROM pg_stat_statements
ORDER BY COALESCE(mean_exec_time, mean_time) DESC
LIMIT 10;
```

### 3. Connection Management
```typescript
// Optimal Supabase client configuration
import { createClient } from '@supabase/supabase-js'

const supabase = createClient(
  process.env.SUPABASE_URL!,
  process.env.SUPABASE_ANON_KEY!,
  {
    db: {
      schema: 'public',
    },
    auth: {
      autoRefreshToken: true,
      persistSession: true,
      detectSessionInUrl: true
    },
    global: {
      headers: { 'x-my-custom-header': 'my-app-name' },
    },
  }
)
```

## 🔍 Testing & Validation

### 1. Schema Validation
```sql
-- Test basic functionality
SELECT 'Schema validation' as test_name, 
       CASE WHEN COUNT(*) > 30 THEN 'PASS' ELSE 'FAIL' END as result
FROM information_schema.tables 
WHERE table_schema = 'public';

-- Test relationships
SELECT 'Foreign keys' as test_name,
       CASE WHEN COUNT(*) > 20 THEN 'PASS' ELSE 'FAIL' END as result
FROM information_schema.table_constraints 
WHERE constraint_type = 'FOREIGN KEY';
```

### 2. Performance Testing
```sql
-- Test article insertion
INSERT INTO public.articles (slug, title, content, niche_id, author_id)
SELECT 
    'test-article-' || generate_series,
    'Test Article ' || generate_series,
    'Test content for article ' || generate_series,
    (SELECT id FROM public.niches LIMIT 1),
    (SELECT id FROM public.authors LIMIT 1)
FROM generate_series(1, 100);

-- Test query performance
EXPLAIN ANALYZE 
SELECT a.title, n.name as niche_name
FROM public.articles a
JOIN public.niches n ON a.niche_id = n.id
WHERE a.status = 'published'
ORDER BY a.created_at DESC
LIMIT 20;
```

### 3. RLS Testing
```sql
-- Test RLS policies (run as different users)
SET ROLE authenticated;
SELECT COUNT(*) FROM public.articles; -- Should respect RLS

RESET ROLE;
SELECT COUNT(*) FROM public.articles; -- Should see all (as service role)
```

## 🚨 Troubleshooting

### Common Issues

#### 1. Vector Extension Not Available
```sql
-- Check if vector extension exists
SELECT * FROM pg_available_extensions WHERE name = 'vector';

-- If not available, disable vector features temporarily
-- The schema will work without vector search
```

#### 2. Permission Errors
```sql
-- Grant necessary permissions
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO authenticated;
```

#### 3. RLS Policy Conflicts
```sql
-- Check existing policies
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual
FROM pg_policies
WHERE schemaname = 'public';

-- Drop conflicting policies if needed
DROP POLICY IF EXISTS "policy_name" ON table_name;
```

#### 4. Index Creation Failures
```sql
-- Check for index creation errors
SELECT schemaname, tablename, indexname
FROM pg_indexes
WHERE schemaname = 'public'
AND indexname LIKE 'idx_%';

-- Recreate failed indexes manually
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_articles_slug ON public.articles(slug);
```

## 📊 Monitoring & Maintenance

### 1. Database Health Monitoring
```sql
-- Monitor table sizes
SELECT schemaname, tablename, 
       pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size
FROM pg_tables 
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;

-- Monitor connection usage
SELECT state, COUNT(*) 
FROM pg_stat_activity 
GROUP BY state;
```

### 2. Performance Monitoring
```sql
-- Check cache hit ratios
SELECT 'index hit rate' as name, 
       (sum(idx_blks_hit)) / nullif(sum(idx_blks_hit + idx_blks_read),0) as ratio
FROM pg_statio_user_indexes
UNION ALL
SELECT 'table hit rate' as name,
       sum(heap_blks_hit) / nullif(sum(heap_blks_hit) + sum(heap_blks_read),0) as ratio
FROM pg_statio_user_tables;
```

### 3. Regular Maintenance
```sql
-- Update statistics (run weekly)
ANALYZE;

-- Vacuum tables (run as needed)
VACUUM ANALYZE public.articles;
VACUUM ANALYZE public.analytics_events;
```

## 🔄 Backup & Recovery

### 1. Automated Backups
Supabase provides automated backups, but for critical data:
```bash
# Manual backup
pg_dump -h db.your-project.supabase.co -U postgres -d postgres > backup_$(date +%Y%m%d).sql

# Restore from backup
psql -h db.your-project.supabase.co -U postgres -d postgres < backup_file.sql
```

### 2. Point-in-Time Recovery
Supabase Pro plans include point-in-time recovery. Configure retention period in dashboard.

## 📚 Next Steps

### 1. Application Integration
- Set up your application to use the Supabase client
- Implement authentication flows
- Create API endpoints for content management

### 2. Advanced Features
- Set up real-time subscriptions for live updates
- Implement vector search for semantic content discovery
- Configure webhook endpoints for n8n integration

### 3. Production Optimization
- Monitor query performance and optimize as needed
- Set up alerting for database metrics
- Implement caching strategies for frequently accessed data

## 📞 Support Resources

- **Supabase Documentation**: [docs.supabase.com](https://docs.supabase.com)
- **Community Support**: [github.com/supabase/supabase/discussions](https://github.com/supabase/supabase/discussions)
- **Discord Community**: [discord.supabase.com](https://discord.supabase.com)

---

## ✅ Deployment Checklist

- [ ] Supabase project created
- [ ] Environment variables configured
- [ ] Schema deployed successfully
- [ ] Extensions enabled (vector, pg_trgm, btree_gin)
- [ ] RLS policies configured
- [ ] Initial data inserted
- [ ] Performance indexes created
- [ ] Storage buckets configured (if using media)
- [ ] API settings configured
- [ ] Authentication providers set up
- [ ] Backup strategy implemented
- [ ] Monitoring configured

**Deployment Status**: ✅ Ready for production!

---

*Your Allixios platform is now deployed on Supabase with enterprise-grade features and performance optimization.*