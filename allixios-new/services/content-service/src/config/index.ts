/**
 * Configuration Management
 * Centralized configuration for the Content Service
 */

import dotenv from 'dotenv';
import { z } from 'zod';

// Load environment variables
dotenv.config();

// Configuration schema for validation
const configSchema = z.object({
  // Server Configuration
  nodeEnv: z.enum(['development', 'staging', 'production']).default('development'),
  port: z.coerce.number().default(3001),
  host: z.string().default('0.0.0.0'),

  // Database Configuration
  database: z.object({
    postgresql: z.object({
      host: z.string().default('localhost'),
      port: z.coerce.number().default(5432),
      database: z.string().default('allixios'),
      username: z.string().default('allixios_user'),
      password: z.string().min(1),
      ssl: z.boolean().default(false),
      maxConnections: z.coerce.number().default(20),
      idleTimeoutMillis: z.coerce.number().default(30000),
      connectionTimeoutMillis: z.coerce.number().default(2000),
    }),
    mongodb: z.object({
      url: z.string().url(),
      database: z.string().default('allixios'),
      maxPoolSize: z.coerce.number().default(10),
      serverSelectionTimeoutMS: z.coerce.number().default(5000),
    }),
  }),

  // Redis Configuration
  redis: z.object({
    url: z.string().url(),
    maxRetriesPerRequest: z.coerce.number().default(3),
    retryDelayOnFailover: z.coerce.number().default(100),
    enableReadyCheck: z.boolean().default(true),
  }),

  // Elasticsearch Configuration
  elasticsearch: z.object({
    url: z.string().url(),
    maxRetries: z.coerce.number().default(3),
    requestTimeout: z.coerce.number().default(30000),
    pingTimeout: z.coerce.number().default(3000),
  }),

  // Authentication & Security
  auth: z.object({
    jwtSecret: z.string().min(32),
    jwtExpiresIn: z.string().default('24h'),
    bcryptRounds: z.coerce.number().default(12),
  }),

  // CORS Configuration
  cors: z.object({
    origin: z.union([
      z.string(),
      z.array(z.string()),
      z.boolean()
    ]).default('*'),
  }),

  // Rate Limiting
  rateLimit: z.object({
    windowMs: z.coerce.number().default(15 * 60 * 1000), // 15 minutes
    max: z.coerce.number().default(1000), // requests per window
  }),

  // File Upload Configuration
  upload: z.object({
    maxFileSize: z.coerce.number().default(10 * 1024 * 1024), // 10MB
    allowedMimeTypes: z.array(z.string()).default([
      'image/jpeg',
      'image/png',
      'image/webp',
      'image/gif',
      'video/mp4',
      'video/webm',
      'application/pdf',
      'text/plain',
    ]),
    destination: z.string().default('./uploads'),
  }),

  // AI Configuration
  ai: z.object({
    openai: z.object({
      apiKey: z.string().optional(),
      model: z.string().default('gpt-4'),
      maxTokens: z.coerce.number().default(2000),
    }),
    gemini: z.object({
      apiKey: z.string().optional(),
      model: z.string().default('gemini-pro'),
    }),
    anthropic: z.object({
      apiKey: z.string().optional(),
      model: z.string().default('claude-3-sonnet-20240229'),
    }),
  }),

  // External Services
  services: z.object({
    seoService: z.string().url().optional(),
    analyticsService: z.string().url().optional(),
    userService: z.string().url().optional(),
    translationService: z.string().url().optional(),
    notificationService: z.string().url().optional(),
  }),

  // Logging Configuration
  logging: z.object({
    level: z.enum(['error', 'warn', 'info', 'debug']).default('info'),
    format: z.enum(['json', 'simple']).default('json'),
    enableConsole: z.boolean().default(true),
    enableFile: z.boolean().default(true),
    maxFiles: z.coerce.number().default(5),
    maxSize: z.string().default('20m'),
  }),

  // Monitoring Configuration
  monitoring: z.object({
    enableMetrics: z.boolean().default(true),
    metricsPath: z.string().default('/metrics'),
    enableHealthCheck: z.boolean().default(true),
    healthCheckPath: z.string().default('/health'),
  }),

  // Feature Flags
  features: z.object({
    enableAI: z.boolean().default(true),
    enableSearch: z.boolean().default(true),
    enableAnalytics: z.boolean().default(true),
    enableWorkflow: z.boolean().default(true),
    enableCache: z.boolean().default(true),
    enableQueue: z.boolean().default(true),
  }),

  // Performance Configuration
  performance: z.object({
    enableCompression: z.boolean().default(true),
    enableEtag: z.boolean().default(true),
    cacheMaxAge: z.coerce.number().default(3600), // 1 hour
  }),
});

// Parse and validate configuration
const parseConfig = () => {
  const rawConfig = {
    nodeEnv: process.env.NODE_ENV,
    port: process.env.PORT,
    host: process.env.HOST,

    database: {
      postgresql: {
        host: process.env.POSTGRES_HOST || process.env.DATABASE_URL?.split('@')[1]?.split(':')[0],
        port: process.env.POSTGRES_PORT || process.env.DATABASE_URL?.split(':')[3]?.split('/')[0],
        database: process.env.POSTGRES_DB || process.env.DATABASE_URL?.split('/').pop(),
        username: process.env.POSTGRES_USER || process.env.DATABASE_URL?.split('://')[1]?.split(':')[0],
        password: process.env.POSTGRES_PASSWORD || process.env.DATABASE_URL?.split(':')[2]?.split('@')[0],
        ssl: process.env.POSTGRES_SSL === 'true',
        maxConnections: process.env.POSTGRES_MAX_CONNECTIONS,
        idleTimeoutMillis: process.env.POSTGRES_IDLE_TIMEOUT,
        connectionTimeoutMillis: process.env.POSTGRES_CONNECTION_TIMEOUT,
      },
      mongodb: {
        url: process.env.MONGODB_URL || 'mongodb://localhost:27017',
        database: process.env.MONGODB_DB,
        maxPoolSize: process.env.MONGODB_MAX_POOL_SIZE,
        serverSelectionTimeoutMS: process.env.MONGODB_SERVER_SELECTION_TIMEOUT,
      },
    },

    redis: {
      url: process.env.REDIS_URL || 'redis://localhost:6379',
      maxRetriesPerRequest: process.env.REDIS_MAX_RETRIES,
      retryDelayOnFailover: process.env.REDIS_RETRY_DELAY,
      enableReadyCheck: process.env.REDIS_ENABLE_READY_CHECK !== 'false',
    },

    elasticsearch: {
      url: process.env.ELASTICSEARCH_URL || 'http://localhost:9200',
      maxRetries: process.env.ELASTICSEARCH_MAX_RETRIES,
      requestTimeout: process.env.ELASTICSEARCH_REQUEST_TIMEOUT,
      pingTimeout: process.env.ELASTICSEARCH_PING_TIMEOUT,
    },

    auth: {
      jwtSecret: process.env.JWT_SECRET,
      jwtExpiresIn: process.env.JWT_EXPIRES_IN,
      bcryptRounds: process.env.BCRYPT_ROUNDS,
    },

    cors: {
      origin: process.env.CORS_ORIGIN?.split(',') || process.env.CORS_ORIGIN,
    },

    rateLimit: {
      windowMs: process.env.RATE_LIMIT_WINDOW_MS,
      max: process.env.RATE_LIMIT_MAX,
    },

    upload: {
      maxFileSize: process.env.UPLOAD_MAX_FILE_SIZE,
      allowedMimeTypes: process.env.UPLOAD_ALLOWED_MIME_TYPES?.split(','),
      destination: process.env.UPLOAD_DESTINATION,
    },

    ai: {
      openai: {
        apiKey: process.env.OPENAI_API_KEY,
        model: process.env.OPENAI_MODEL,
        maxTokens: process.env.OPENAI_MAX_TOKENS,
      },
      gemini: {
        apiKey: process.env.GOOGLE_AI_API_KEY,
        model: process.env.GEMINI_MODEL,
      },
      anthropic: {
        apiKey: process.env.ANTHROPIC_API_KEY,
        model: process.env.ANTHROPIC_MODEL,
      },
    },

    services: {
      seoService: process.env.SEO_SERVICE_URL,
      analyticsService: process.env.ANALYTICS_SERVICE_URL,
      userService: process.env.USER_SERVICE_URL,
      translationService: process.env.TRANSLATION_SERVICE_URL,
      notificationService: process.env.NOTIFICATION_SERVICE_URL,
    },

    logging: {
      level: process.env.LOG_LEVEL,
      format: process.env.LOG_FORMAT,
      enableConsole: process.env.LOG_ENABLE_CONSOLE !== 'false',
      enableFile: process.env.LOG_ENABLE_FILE !== 'false',
      maxFiles: process.env.LOG_MAX_FILES,
      maxSize: process.env.LOG_MAX_SIZE,
    },

    monitoring: {
      enableMetrics: process.env.ENABLE_METRICS !== 'false',
      metricsPath: process.env.METRICS_PATH,
      enableHealthCheck: process.env.ENABLE_HEALTH_CHECK !== 'false',
      healthCheckPath: process.env.HEALTH_CHECK_PATH,
    },

    features: {
      enableAI: process.env.ENABLE_AI !== 'false',
      enableSearch: process.env.ENABLE_SEARCH !== 'false',
      enableAnalytics: process.env.ENABLE_ANALYTICS !== 'false',
      enableWorkflow: process.env.ENABLE_WORKFLOW !== 'false',
      enableCache: process.env.ENABLE_CACHE !== 'false',
      enableQueue: process.env.ENABLE_QUEUE !== 'false',
    },

    performance: {
      enableCompression: process.env.ENABLE_COMPRESSION !== 'false',
      enableEtag: process.env.ENABLE_ETAG !== 'false',
      cacheMaxAge: process.env.CACHE_MAX_AGE,
    },
  };

  try {
    return configSchema.parse(rawConfig);
  } catch (error) {
    console.error('Configuration validation failed:', error);
    process.exit(1);
  }
};

export const config = parseConfig();

// Export types
export type Config = z.infer<typeof configSchema>;

// Configuration utilities
export const isDevelopment = () => config.nodeEnv === 'development';
export const isProduction = () => config.nodeEnv === 'production';
export const isStaging = () => config.nodeEnv === 'staging';

// Database connection strings
export const getDatabaseUrl = () => {
  const { postgresql } = config.database;
  return `postgresql://${postgresql.username}:${postgresql.password}@${postgresql.host}:${postgresql.port}/${postgresql.database}${postgresql.ssl ? '?ssl=true' : ''}`;
};

export const getMongoUrl = () => {
  return config.database.mongodb.url;
};

export const getRedisUrl = () => {
  return config.redis.url;
};

export const getElasticsearchUrl = () => {
  return config.elasticsearch.url;
};