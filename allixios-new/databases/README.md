# Allixios Database Layer

This directory contains all database-related components for the Allixios platform, supporting multiple database technologies for optimal performance and scalability.

## 🗄️ Database Architecture

### Multi-Database Strategy

```
┌─────────────────────────────────────────────────────────────┐
│                    DATABASE LAYER                           │
├─────────────────────────────────────────────────────────────┤
│  PostgreSQL (Primary)     │  MongoDB (Documents)            │
│  - Structured data        │  - Flexible schemas             │
│  - ACID compliance        │  - Content drafts               │
│  - Complex relationships  │  - User preferences             │
│  - Analytics              │  - Logs & events               │
├─────────────────────────────────────────────────────────────┤
│  Redis (Cache)            │  Elasticsearch (Search)        │
│  - Session management     │  - Full-text search            │
│  - API caching           │  - Content indexing            │
│  - Rate limiting         │  - Analytics queries           │
│  - Real-time data        │  - Aggregations                │
├─────────────────────────────────────────────────────────────┤
│  ClickHouse (Analytics)                                     │
│  - Time-series data       │  - Real-time analytics         │
│  - User behavior tracking │  - Performance metrics         │
│  - Revenue analytics      │  - Business intelligence        │
└─────────────────────────────────────────────────────────────┘
```

## 📁 Directory Structure

```
databases/
├── postgresql/              # Primary database (ACID, relationships)
│   ├── schemas/            # Database schema definitions
│   ├── functions/          # Stored procedures and functions
│   ├── migrations/         # Database migration scripts
│   └── indexes/           # Performance optimization indexes
├── mongodb/               # Document store (flexible schemas)
│   ├── collections/       # Collection definitions
│   └── indexes/          # MongoDB indexes
├── redis/                # Caching layer (in-memory)
│   └── config/           # Redis configuration
├── elasticsearch/        # Search engine (full-text search)
│   └── mappings/         # Index mappings and settings
├── clickhouse/          # Analytics database (columnar)
│   └── schemas/         # ClickHouse table definitions
└── README.md           # This file
```

## 🚀 Quick Start

### 1. PostgreSQL Setup (Primary Database)

```bash
# Deploy core schema
cd postgresql/migrations
psql -h your-db-host -U postgres -d postgres -f 001_initial_migration.sql

# Verify deployment
psql -h your-db-host -U postgres -d postgres -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';"
```

### 2. MongoDB Setup (Document Store)

```bash
# Connect to MongoDB
mongosh "mongodb://your-mongodb-connection-string"

# Create collections and indexes
cd mongodb/collections
mongosh --file setup_collections.js
```

### 3. Redis Setup (Caching)

```bash
# Configure Redis
cp redis/config/redis.conf /etc/redis/redis.conf

# Start Redis
redis-server /etc/redis/redis.conf
```

### 4. Elasticsearch Setup (Search)

```bash
# Create indexes
cd elasticsearch/mappings
curl -X PUT "localhost:9200/articles" -H 'Content-Type: application/json' -d @articles_mapping.json
```

### 5. ClickHouse Setup (Analytics)

```bash
# Create analytics tables
cd clickhouse/schemas
clickhouse-client --queries-file analytics_tables.sql
```

## 📊 Database Usage Patterns

### PostgreSQL (Primary)
- **Articles, Users, Categories**: Core content management
- **Relationships**: Foreign keys, joins, complex queries
- **Transactions**: ACID compliance for critical operations
- **Analytics**: Aggregated metrics and reporting

### MongoDB (Documents)
- **Content Drafts**: Work-in-progress content with flexible structure
- **User Preferences**: Dynamic user settings and preferences
- **Logs**: Application logs and audit trails
- **Metadata**: Flexible metadata storage

### Redis (Cache)
- **Session Management**: User sessions and authentication tokens
- **API Caching**: Frequently accessed data caching
- **Rate Limiting**: API rate limiting counters
- **Real-time Data**: Live metrics and temporary data

### Elasticsearch (Search)
- **Full-text Search**: Article content and metadata search
- **Faceted Search**: Category, tag, and author filtering
- **Analytics Queries**: Search analytics and user behavior
- **Autocomplete**: Search suggestions and typeahead

### ClickHouse (Analytics)
- **User Events**: Page views, clicks, interactions
- **Performance Metrics**: Response times, error rates
- **Revenue Analytics**: Conversion tracking, revenue attribution
- **Business Intelligence**: Dashboards and reporting

## 🔧 Configuration

### Environment Variables

```env
# PostgreSQL
DATABASE_URL=postgresql://user:pass@localhost:5432/allixios
POSTGRES_HOST=localhost
POSTGRES_PORT=5432
POSTGRES_DB=allixios
POSTGRES_USER=allixios_user
POSTGRES_PASSWORD=secure_password

# MongoDB
MONGODB_URL=mongodb://localhost:27017/allixios
MONGODB_HOST=localhost
MONGODB_PORT=27017
MONGODB_DB=allixios

# Redis
REDIS_URL=redis://localhost:6379
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=redis_password

# Elasticsearch
ELASTICSEARCH_URL=http://localhost:9200
ELASTICSEARCH_HOST=localhost
ELASTICSEARCH_PORT=9200

# ClickHouse
CLICKHOUSE_URL=http://localhost:8123
CLICKHOUSE_HOST=localhost
CLICKHOUSE_PORT=8123
CLICKHOUSE_DB=allixios
```

### Connection Pooling

```javascript
// PostgreSQL connection pool
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  max: 20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
});

// MongoDB connection
const mongodb = await MongoClient.connect(process.env.MONGODB_URL, {
  maxPoolSize: 10,
  serverSelectionTimeoutMS: 5000,
});

// Redis connection
const redis = new Redis(process.env.REDIS_URL, {
  maxRetriesPerRequest: 3,
  retryDelayOnFailover: 100,
});
```

## 📈 Performance Optimization

### Indexing Strategy

#### PostgreSQL Indexes
- **B-tree**: Standard indexes for equality and range queries
- **GIN**: Full-text search and array operations
- **Partial**: Filtered indexes for specific conditions
- **Composite**: Multi-column indexes for complex queries

#### MongoDB Indexes
- **Single Field**: Basic field indexes
- **Compound**: Multi-field indexes
- **Text**: Full-text search indexes
- **Geospatial**: Location-based queries

#### Elasticsearch Mappings
- **Text**: Full-text search with analyzers
- **Keyword**: Exact match and aggregations
- **Nested**: Complex object structures
- **Date**: Time-based queries and ranges

### Query Optimization

```sql
-- PostgreSQL: Use EXPLAIN ANALYZE for query optimization
EXPLAIN ANALYZE SELECT * FROM articles WHERE status = 'published';

-- MongoDB: Use explain() for query analysis
db.articles.find({status: 'published'}).explain('executionStats');

-- Elasticsearch: Use _profile API for query analysis
GET /articles/_search
{
  "profile": true,
  "query": {"match": {"title": "search term"}}
}
```

## 🔒 Security

### Access Control

#### PostgreSQL RLS (Row Level Security)
```sql
-- Enable RLS on sensitive tables
ALTER TABLE articles ENABLE ROW LEVEL SECURITY;

-- Create policies for data access
CREATE POLICY "Users can view published articles" ON articles
  FOR SELECT USING (status = 'published');
```

#### MongoDB Access Control
```javascript
// Use MongoDB roles and authentication
db.createUser({
  user: "allixios_app",
  pwd: "secure_password",
  roles: [
    { role: "readWrite", db: "allixios" }
  ]
});
```

#### Redis Security
```conf
# Redis configuration
requirepass secure_redis_password
bind 127.0.0.1
protected-mode yes
```

### Data Encryption

- **At Rest**: Database-level encryption for sensitive data
- **In Transit**: TLS/SSL for all database connections
- **Application Level**: Encrypt PII before storage

## 🔄 Backup & Recovery

### Automated Backups

```bash
# PostgreSQL backup
pg_dump -h $POSTGRES_HOST -U $POSTGRES_USER -d $POSTGRES_DB > backup_$(date +%Y%m%d_%H%M%S).sql

# MongoDB backup
mongodump --host $MONGODB_HOST --db $MONGODB_DB --out backup_$(date +%Y%m%d_%H%M%S)

# Redis backup
redis-cli --rdb backup_$(date +%Y%m%d_%H%M%S).rdb
```

### Recovery Procedures

```bash
# PostgreSQL restore
psql -h $POSTGRES_HOST -U $POSTGRES_USER -d $POSTGRES_DB < backup_file.sql

# MongoDB restore
mongorestore --host $MONGODB_HOST --db $MONGODB_DB backup_directory/

# Redis restore
redis-cli --pipe < backup_file.rdb
```

## 📊 Monitoring

### Health Checks

```sql
-- PostgreSQL health check
SELECT 
  datname,
  numbackends,
  xact_commit,
  xact_rollback,
  blks_read,
  blks_hit
FROM pg_stat_database 
WHERE datname = 'allixios';
```

```javascript
// MongoDB health check
db.runCommand({serverStatus: 1});

// Redis health check
redis.ping();

// Elasticsearch health check
GET /_cluster/health
```

### Performance Metrics

- **Connection Pool Usage**: Monitor active/idle connections
- **Query Performance**: Track slow queries and optimization opportunities
- **Cache Hit Rates**: Monitor Redis cache effectiveness
- **Index Usage**: Ensure indexes are being utilized effectively

## 🚀 Scaling Strategies

### Horizontal Scaling

#### PostgreSQL
- **Read Replicas**: Scale read operations
- **Partitioning**: Distribute large tables
- **Connection Pooling**: Optimize connection usage

#### MongoDB
- **Sharding**: Distribute data across multiple servers
- **Replica Sets**: High availability and read scaling
- **Indexes**: Optimize for sharded queries

#### Redis
- **Clustering**: Distribute cache across multiple nodes
- **Sentinel**: High availability and failover
- **Partitioning**: Distribute keys across instances

### Vertical Scaling

- **CPU**: Increase processing power for complex queries
- **Memory**: More RAM for caching and query performance
- **Storage**: Faster SSDs for improved I/O performance
- **Network**: Higher bandwidth for data transfer

## 📚 Documentation

- [PostgreSQL Schema Documentation](postgresql/schemas/README.md)
- [MongoDB Collections Guide](mongodb/collections/README.md)
- [Redis Configuration Guide](redis/config/README.md)
- [Elasticsearch Mappings](elasticsearch/mappings/README.md)
- [ClickHouse Analytics Setup](clickhouse/schemas/README.md)

## 🤝 Contributing

When adding new database components:

1. **Follow naming conventions** for consistency
2. **Add proper indexes** for performance
3. **Include migration scripts** for schema changes
4. **Document relationships** and dependencies
5. **Add monitoring** for new components

---

*This multi-database architecture provides the foundation for enterprise-scale content management with optimal performance, scalability, and reliability.*