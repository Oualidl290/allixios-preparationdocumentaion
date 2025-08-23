// ============================================================================
// MONGODB COLLECTIONS SETUP
// Initialize MongoDB collections and indexes for Allixios platform
// ============================================================================

// Switch to allixios database
use('allixios');

print('🚀 Setting up MongoDB collections for Allixios platform...');

// ============================================================================
// CONTENT DRAFTS COLLECTION
// ============================================================================

// Create content_drafts collection for work-in-progress content
db.createCollection('content_drafts', {
  validator: {
    $jsonSchema: {
      bsonType: 'object',
      required: ['tenant_id', 'title', 'content_type', 'status', 'created_at'],
      properties: {
        tenant_id: { bsonType: 'string' },
        title: { bsonType: 'string', minLength: 1, maxLength: 1000 },
        content_type: {
          enum: ['article', 'page', 'newsletter', 'social_post']
        },
        status: {
          enum: ['draft', 'in_progress', 'review', 'approved', 'rejected']
        },
        content: { bsonType: 'string' },
        metadata: { bsonType: 'object' },
        author_id: { bsonType: 'string' },
        niche_id: { bsonType: 'string' },
        category_id: { bsonType: 'string' },
        tags: { bsonType: 'array' },
        ai_generated: { bsonType: 'bool' },
        quality_score: { bsonType: 'number', minimum: 0, maximum: 100 },
        word_count: { bsonType: 'number', minimum: 0 },
        language: { bsonType: 'string' },
        created_at: { bsonType: 'date' },
        updated_at: { bsonType: 'date' },
        version: { bsonType: 'number', minimum: 1 }
      }
    }
  }
});

// Create indexes for content_drafts
db.content_drafts.createIndex({ tenant_id: 1, status: 1 });
db.content_drafts.createIndex({ tenant_id: 1, author_id: 1 });
db.content_drafts.createIndex({ tenant_id: 1, content_type: 1 });
db.content_drafts.createIndex({ created_at: -1 });
db.content_drafts.createIndex({ updated_at: -1 });
db.content_drafts.createIndex({
  title: 'text',
  content: 'text'
}, {
  weights: { title: 10, content: 1 },
  name: 'content_text_search'
});

print('✅ Created content_drafts collection with indexes');

// ============================================================================
// USER PREFERENCES COLLECTION
// ============================================================================

// Create user_preferences collection for dynamic user settings
db.createCollection('user_preferences', {
  validator: {
    $jsonSchema: {
      bsonType: 'object',
      required: ['tenant_id', 'user_id', 'created_at'],
      properties: {
        tenant_id: { bsonType: 'string' },
        user_id: { bsonType: 'string' },
        preferences: { bsonType: 'object' },
        notification_settings: { bsonType: 'object' },
        ui_settings: { bsonType: 'object' },
        content_preferences: { bsonType: 'object' },
        privacy_settings: { bsonType: 'object' },
        created_at: { bsonType: 'date' },
        updated_at: { bsonType: 'date' }
      }
    }
  }
});

// Create indexes for user_preferences
db.user_preferences.createIndex({ tenant_id: 1, user_id: 1 }, { unique: true });
db.user_preferences.createIndex({ updated_at: -1 });

print('✅ Created user_preferences collection with indexes');

// ============================================================================
// APPLICATION LOGS COLLECTION
// ============================================================================

// Create application_logs collection for system logs
db.createCollection('application_logs', {
  validator: {
    $jsonSchema: {
      bsonType: 'object',
      required: ['level', 'message', 'timestamp'],
      properties: {
        level: {
          enum: ['error', 'warn', 'info', 'debug', 'trace']
        },
        message: { bsonType: 'string' },
        timestamp: { bsonType: 'date' },
        service: { bsonType: 'string' },
        tenant_id: { bsonType: 'string' },
        user_id: { bsonType: 'string' },
        request_id: { bsonType: 'string' },
        metadata: { bsonType: 'object' },
        stack_trace: { bsonType: 'string' },
        tags: { bsonType: 'array' }
      }
    }
  }
});

// Create indexes for application_logs
db.application_logs.createIndex({ timestamp: -1 });
db.application_logs.createIndex({ level: 1, timestamp: -1 });
db.application_logs.createIndex({ service: 1, timestamp: -1 });
db.application_logs.createIndex({ tenant_id: 1, timestamp: -1 });
db.application_logs.createIndex({ request_id: 1 });

// Create TTL index to automatically delete old logs (30 days)
db.application_logs.createIndex({ timestamp: 1 }, { expireAfterSeconds: 2592000 });

print('✅ Created application_logs collection with indexes and TTL');

// ============================================================================
// WORKFLOW EXECUTIONS COLLECTION
// ============================================================================

// Create workflow_executions collection for n8n workflow data
db.createCollection('workflow_executions', {
  validator: {
    $jsonSchema: {
      bsonType: 'object',
      required: ['workflow_id', 'execution_id', 'status', 'started_at'],
      properties: {
        workflow_id: { bsonType: 'string' },
        execution_id: { bsonType: 'string' },
        status: {
          enum: ['running', 'success', 'error', 'waiting', 'canceled']
        },
        mode: {
          enum: ['trigger', 'manual', 'retry', 'webhook']
        },
        started_at: { bsonType: 'date' },
        finished_at: { bsonType: 'date' },
        execution_time: { bsonType: 'number' },
        data: { bsonType: 'object' },
        nodes: { bsonType: 'array' },
        error_message: { bsonType: 'string' },
        retry_count: { bsonType: 'number', minimum: 0 },
        tenant_id: { bsonType: 'string' }
      }
    }
  }
});

// Create indexes for workflow_executions
db.workflow_executions.createIndex({ execution_id: 1 }, { unique: true });
db.workflow_executions.createIndex({ workflow_id: 1, started_at: -1 });
db.workflow_executions.createIndex({ status: 1, started_at: -1 });
db.workflow_executions.createIndex({ tenant_id: 1, started_at: -1 });

// Create TTL index to automatically delete old executions (90 days)
db.workflow_executions.createIndex({ started_at: 1 }, { expireAfterSeconds: 7776000 });

print('✅ Created workflow_executions collection with indexes and TTL');

// ============================================================================
// CONTENT METADATA COLLECTION
// ============================================================================

// Create content_metadata collection for flexible content metadata
db.createCollection('content_metadata', {
  validator: {
    $jsonSchema: {
      bsonType: 'object',
      required: ['tenant_id', 'content_id', 'content_type', 'created_at'],
      properties: {
        tenant_id: { bsonType: 'string' },
        content_id: { bsonType: 'string' },
        content_type: {
          enum: ['article', 'media', 'page', 'category', 'tag']
        },
        metadata: { bsonType: 'object' },
        seo_data: { bsonType: 'object' },
        social_data: { bsonType: 'object' },
        analytics_data: { bsonType: 'object' },
        ai_analysis: { bsonType: 'object' },
        custom_fields: { bsonType: 'object' },
        created_at: { bsonType: 'date' },
        updated_at: { bsonType: 'date' }
      }
    }
  }
});

// Create indexes for content_metadata
db.content_metadata.createIndex({ tenant_id: 1, content_id: 1, content_type: 1 }, { unique: true });
db.content_metadata.createIndex({ content_type: 1, updated_at: -1 });
db.content_metadata.createIndex({ updated_at: -1 });

print('✅ Created content_metadata collection with indexes');

// ============================================================================
// USER SESSIONS COLLECTION
// ============================================================================

// Create user_sessions collection for session management
db.createCollection('user_sessions', {
  validator: {
    $jsonSchema: {
      bsonType: 'object',
      required: ['session_id', 'user_id', 'created_at'],
      properties: {
        session_id: { bsonType: 'string' },
        user_id: { bsonType: 'string' },
        tenant_id: { bsonType: 'string' },
        ip_address: { bsonType: 'string' },
        user_agent: { bsonType: 'string' },
        device_info: { bsonType: 'object' },
        location: { bsonType: 'object' },
        is_active: { bsonType: 'bool' },
        last_activity: { bsonType: 'date' },
        created_at: { bsonType: 'date' },
        expires_at: { bsonType: 'date' }
      }
    }
  }
});

// Create indexes for user_sessions
db.user_sessions.createIndex({ session_id: 1 }, { unique: true });
db.user_sessions.createIndex({ user_id: 1, is_active: 1 });
db.user_sessions.createIndex({ tenant_id: 1, last_activity: -1 });
db.user_sessions.createIndex({ last_activity: -1 });

// Create TTL index to automatically delete expired sessions
db.user_sessions.createIndex({ expires_at: 1 }, { expireAfterSeconds: 0 });

print('✅ Created user_sessions collection with indexes and TTL');

// ============================================================================
// SEARCH QUERIES COLLECTION
// ============================================================================

// Create search_queries collection for search analytics
db.createCollection('search_queries', {
  validator: {
    $jsonSchema: {
      bsonType: 'object',
      required: ['query', 'timestamp'],
      properties: {
        query: { bsonType: 'string', minLength: 1 },
        tenant_id: { bsonType: 'string' },
        user_id: { bsonType: 'string' },
        session_id: { bsonType: 'string' },
        results_count: { bsonType: 'number', minimum: 0 },
        clicked_results: { bsonType: 'array' },
        filters_applied: { bsonType: 'object' },
        search_type: {
          enum: ['content', 'users', 'tags', 'categories', 'global']
        },
        response_time_ms: { bsonType: 'number' },
        timestamp: { bsonType: 'date' },
        ip_address: { bsonType: 'string' },
        user_agent: { bsonType: 'string' }
      }
    }
  }
});

// Create indexes for search_queries
db.search_queries.createIndex({ timestamp: -1 });
db.search_queries.createIndex({ tenant_id: 1, timestamp: -1 });
db.search_queries.createIndex({ query: 1, timestamp: -1 });
db.search_queries.createIndex({ user_id: 1, timestamp: -1 });

// Create TTL index to automatically delete old search queries (180 days)
db.search_queries.createIndex({ timestamp: 1 }, { expireAfterSeconds: 15552000 });

print('✅ Created search_queries collection with indexes and TTL');

// ============================================================================
// MEDIA PROCESSING LOGS COLLECTION
// ============================================================================

// Create media_processing_logs collection for detailed media processing logs
db.createCollection('media_processing_logs', {
  validator: {
    $jsonSchema: {
      bsonType: 'object',
      required: ['media_id', 'processing_type', 'status', 'timestamp'],
      properties: {
        media_id: { bsonType: 'string' },
        processing_type: {
          enum: ['upload', 'resize', 'compress', 'format_convert', 'ai_analysis', 'thumbnail', 'optimization']
        },
        status: {
          enum: ['started', 'progress', 'completed', 'failed', 'cancelled']
        },
        progress: { bsonType: 'number', minimum: 0, maximum: 100 },
        input_params: { bsonType: 'object' },
        output_data: { bsonType: 'object' },
        error_details: { bsonType: 'object' },
        processing_time_ms: { bsonType: 'number' },
        file_size_before: { bsonType: 'number' },
        file_size_after: { bsonType: 'number' },
        quality_metrics: { bsonType: 'object' },
        timestamp: { bsonType: 'date' },
        worker_id: { bsonType: 'string' },
        tenant_id: { bsonType: 'string' }
      }
    }
  }
});

// Create indexes for media_processing_logs
db.media_processing_logs.createIndex({ media_id: 1, timestamp: -1 });
db.media_processing_logs.createIndex({ processing_type: 1, status: 1 });
db.media_processing_logs.createIndex({ timestamp: -1 });
db.media_processing_logs.createIndex({ tenant_id: 1, timestamp: -1 });

// Create TTL index to automatically delete old processing logs (60 days)
db.media_processing_logs.createIndex({ timestamp: 1 }, { expireAfterSeconds: 5184000 });

print('✅ Created media_processing_logs collection with indexes and TTL');

// ============================================================================
// MEDIA ANALYTICS COLLECTION
// ============================================================================

// Create media_analytics collection for media usage and performance tracking
db.createCollection('media_analytics', {
  validator: {
    $jsonSchema: {
      bsonType: 'object',
      required: ['media_id', 'event_type', 'timestamp'],
      properties: {
        media_id: { bsonType: 'string' },
        event_type: {
          enum: ['view', 'download', 'share', 'like', 'comment', 'embed', 'click']
        },
        article_id: { bsonType: 'string' },
        user_id: { bsonType: 'string' },
        session_id: { bsonType: 'string' },
        ip_address: { bsonType: 'string' },
        user_agent: { bsonType: 'string' },
        referrer: { bsonType: 'string' },
        device_info: { bsonType: 'object' },
        location: { bsonType: 'object' },
        viewport_size: { bsonType: 'object' },
        load_time_ms: { bsonType: 'number' },
        interaction_data: { bsonType: 'object' },
        timestamp: { bsonType: 'date' },
        tenant_id: { bsonType: 'string' }
      }
    }
  }
});

// Create indexes for media_analytics
db.media_analytics.createIndex({ media_id: 1, timestamp: -1 });
db.media_analytics.createIndex({ event_type: 1, timestamp: -1 });
db.media_analytics.createIndex({ article_id: 1, timestamp: -1 });
db.media_analytics.createIndex({ user_id: 1, timestamp: -1 });
db.media_analytics.createIndex({ tenant_id: 1, timestamp: -1 });

// Create TTL index to automatically delete old analytics (365 days)
db.media_analytics.createIndex({ timestamp: 1 }, { expireAfterSeconds: 31536000 });

print('✅ Created media_analytics collection with indexes and TTL');

// ============================================================================
// CACHE COLLECTION
// ============================================================================

// Create cache collection for application-level caching
db.createCollection('cache', {
  validator: {
    $jsonSchema: {
      bsonType: 'object',
      required: ['key', 'value', 'created_at'],
      properties: {
        key: { bsonType: 'string' },
        value: { bsonType: 'object' },
        tenant_id: { bsonType: 'string' },
        cache_type: { bsonType: 'string' },
        tags: { bsonType: 'array' },
        hit_count: { bsonType: 'number', minimum: 0 },
        created_at: { bsonType: 'date' },
        updated_at: { bsonType: 'date' },
        expires_at: { bsonType: 'date' }
      }
    }
  }
});

// Create indexes for cache
db.cache.createIndex({ key: 1 }, { unique: true });
db.cache.createIndex({ tenant_id: 1, cache_type: 1 });
db.cache.createIndex({ tags: 1 });
db.cache.createIndex({ hit_count: -1 });

// Create TTL index to automatically delete expired cache entries
db.cache.createIndex({ expires_at: 1 }, { expireAfterSeconds: 0 });

print('✅ Created cache collection with indexes and TTL');

// ============================================================================
// SAMPLE DATA INSERTION
// ============================================================================

print('📝 Inserting sample data...');

// Insert sample content draft
db.content_drafts.insertOne({
  tenant_id: '00000000-0000-0000-0000-000000000001',
  title: 'Getting Started with AI Content Creation',
  content_type: 'article',
  status: 'draft',
  content: 'This is a sample article about AI content creation...',
  metadata: {
    target_keywords: ['AI', 'content creation', 'automation'],
    estimated_reading_time: 5,
    difficulty_level: 'beginner'
  },
  author_id: '00000000-0000-0000-0000-000000000001',
  ai_generated: true,
  quality_score: 85,
  word_count: 1200,
  language: 'en',
  created_at: new Date(),
  updated_at: new Date(),
  version: 1
});

// Insert sample user preferences
db.user_preferences.insertOne({
  tenant_id: '00000000-0000-0000-0000-000000000001',
  user_id: '00000000-0000-0000-0000-000000000001',
  preferences: {
    theme: 'dark',
    language: 'en',
    timezone: 'UTC',
    notifications_enabled: true
  },
  notification_settings: {
    email_notifications: true,
    push_notifications: false,
    sms_notifications: false
  },
  ui_settings: {
    sidebar_collapsed: false,
    items_per_page: 25,
    default_view: 'grid'
  },
  content_preferences: {
    preferred_niches: ['technology', 'business'],
    content_difficulty: 'intermediate',
    auto_save_interval: 30
  },
  privacy_settings: {
    profile_visibility: 'public',
    activity_tracking: true,
    analytics_opt_in: true
  },
  created_at: new Date(),
  updated_at: new Date()
});

// Insert sample application log
db.application_logs.insertOne({
  level: 'info',
  message: 'MongoDB collections setup completed successfully',
  timestamp: new Date(),
  service: 'database-setup',
  tenant_id: '00000000-0000-0000-0000-000000000001',
  metadata: {
    collections_created: 10,
    indexes_created: 30,
    setup_duration_ms: 1500
  },
  tags: ['setup', 'mongodb', 'initialization']
});

// Insert sample media processing log
db.media_processing_logs.insertOne({
  media_id: '00000000-0000-0000-0000-000000000001',
  processing_type: 'thumbnail',
  status: 'completed',
  progress: 100,
  input_params: {
    width: 300,
    height: 300,
    quality: 85
  },
  output_data: {
    url: 'https://cdn.example.com/thumbnails/sample-thumb.jpg',
    file_size: 15420,
    dimensions: { width: 300, height: 300 }
  },
  processing_time_ms: 1250,
  file_size_before: 2048000,
  file_size_after: 15420,
  quality_metrics: {
    compression_ratio: 0.75,
    visual_quality_score: 92
  },
  timestamp: new Date(),
  worker_id: 'media-worker-01',
  tenant_id: '00000000-0000-0000-0000-000000000001'
});

// Insert sample media analytics
db.media_analytics.insertOne({
  media_id: '00000000-0000-0000-0000-000000000001',
  event_type: 'view',
  article_id: '00000000-0000-0000-0000-000000000001',
  user_id: '00000000-0000-0000-0000-000000000001',
  session_id: 'sess_' + new Date().getTime(),
  device_info: {
    type: 'desktop',
    os: 'Windows',
    browser: 'Chrome',
    screen_resolution: '1920x1080'
  },
  viewport_size: {
    width: 1200,
    height: 800
  },
  load_time_ms: 450,
  interaction_data: {
    scroll_depth: 75,
    time_visible: 5200
  },
  timestamp: new Date(),
  tenant_id: '00000000-0000-0000-0000-000000000001'
});

print('✅ Sample data inserted successfully');

// ============================================================================
// COLLECTION STATISTICS
// ============================================================================

print('\n📊 Collection Statistics:');

const collections = [
  'content_drafts',
  'user_preferences',
  'application_logs',
  'workflow_executions',
  'content_metadata',
  'user_sessions',
  'search_queries',
  'media_processing_logs',
  'media_analytics',
  'cache'
];

collections.forEach(collectionName => {
  const stats = db.getCollection(collectionName).stats();
  const indexes = db.getCollection(collectionName).getIndexes();

  print(`\n📁 ${collectionName}:`);
  print(`   Documents: ${stats.count}`);
  print(`   Indexes: ${indexes.length}`);
  print(`   Size: ${(stats.size / 1024).toFixed(2)} KB`);
});

// ============================================================================
// VALIDATION AND HEALTH CHECK
// ============================================================================

print('\n🔍 Running validation checks...');

// Check if all collections exist
const expectedCollections = collections;
const actualCollections = db.listCollectionNames();

expectedCollections.forEach(collectionName => {
  if (actualCollections.includes(collectionName)) {
    print(`✅ ${collectionName} - Created successfully`);
  } else {
    print(`❌ ${collectionName} - Missing!`);
  }
});

// Check indexes
print('\n📊 Index Summary:');
let totalIndexes = 0;
collections.forEach(collectionName => {
  const indexCount = db.getCollection(collectionName).getIndexes().length;
  totalIndexes += indexCount;
  print(`   ${collectionName}: ${indexCount} indexes`);
});

print(`\n🎉 Setup Complete!`);
print(`   Collections: ${collections.length}`);
print(`   Total Indexes: ${totalIndexes}`);
print(`   Sample Documents: 3`);
print(`   TTL Indexes: 4 (auto-cleanup enabled)`);

print('\n💡 Next Steps:');
print('   1. Configure your application to connect to MongoDB');
print('   2. Set up proper authentication and access controls');
print('   3. Configure backup and monitoring');
print('   4. Test the collections with your application');

print('\n🚀 MongoDB setup for Allixios platform completed successfully!');