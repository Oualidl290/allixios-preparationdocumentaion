/**
 * SEO Service Configuration
 * Ultimate SEO optimization and analysis platform configuration
 */

import dotenv from 'dotenv';
import { z } from 'zod';

// Load environment variables
dotenv.config();

// Configuration schema with comprehensive SEO settings
const configSchema = z.object({
  // Server Configuration
  nodeEnv: z.enum(['development', 'staging', 'production']).default('development'),
  port: z.coerce.number().default(3004),
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
    }),
  }),

  // Redis Configuration
  redis: z.object({
    url: z.string().url().default('redis://localhost:6379'),
    maxRetriesPerRequest: z.coerce.number().default(3),
    retryDelayOnFailover: z.coerce.number().default(100),
  }),

  // CORS Configuration
  cors: z.object({
    origin: z.union([z.string(), z.array(z.string()), z.boolean()]).default('*'),
  }),

  // Rate Limiting
  rateLimit: z.object({
    windowMs: z.coerce.number().default(15 * 60 * 1000),
    max: z.coerce.number().default(1000),
    auditWindowMs: z.coerce.number().default(60 * 60 * 1000), // 1 hour for audits
    auditMax: z.coerce.number().default(10),
  }),

  // SEO Analysis Configuration
  seoAnalysis: z.object({
    // Lighthouse Configuration
    lighthouse: z.object({
      enabled: z.boolean().default(true),
      timeout: z.coerce.number().default(60000), // 60 seconds
      maxConcurrent: z.coerce.number().default(3),
      chromeFlags: z.array(z.string()).default([
        '--headless',
        '--disable-gpu',
        '--no-sandbox',
        '--disable-dev-shm-usage'
      ]),
    }),

    // Page Speed Configuration
    pageSpeed: z.object({
      enabled: z.boolean().default(true),
      apiKey: z.string().optional(),
      timeout: z.coerce.number().default(30000),
      strategies: z.array(z.enum(['mobile', 'desktop'])).default(['mobile', 'desktop']),
    }),

    // Content Analysis
    contentAnalysis: z.object({
      enabled: z.boolean().default(true),
      minWordCount: z.coerce.number().default(300),
      maxWordCount: z.coerce.number().default(3000),
      keywordDensityMin: z.coerce.number().default(0.5),
      keywordDensityMax: z.coerce.number().default(3.0),
      readabilityTarget: z.coerce.number().default(60), // Flesch Reading Ease
    }),

    // Technical SEO
    technicalSeo: z.object({
      enabled: z.boolean().default(true),
      checkRobotsTxt: z.boolean().default(true),
      checkSitemap: z.boolean().default(true),
      checkSSL: z.boolean().default(true),
      checkRedirects: z.boolean().default(true),
      maxRedirects: z.coerce.number().default(5),
    }),

    // Schema Markup
    schemaMarkup: z.object({
      enabled: z.boolean().default(true),
      validateStructuredData: z.boolean().default(true),
      autoGenerate: z.boolean().default(true),
      supportedTypes: z.array(z.string()).default([
        'Article',
        'BlogPosting',
        'NewsArticle',
        'WebPage',
        'Organization',
        'Person',
        'Product',
        'Review',
        'FAQ',
        'BreadcrumbList'
      ]),
    }),
  }),

  // Keyword Research Configuration
  keywordResearch: z.object({
    // Google Keyword Planner
    googleKeywords: z.object({
      enabled: z.boolean().default(false),
      apiKey: z.string().optional(),
      customerId: z.string().optional(),
    }),

    // SEMrush Integration
    semrush: z.object({
      enabled: z.boolean().default(false),
      apiKey: z.string().optional(),
    }),

    // Ahrefs Integration
    ahrefs: z.object({
      enabled: z.boolean().default(false),
      apiKey: z.string().optional(),
    }),

    // Internal Keyword Analysis
    internal: z.object({
      enabled: z.boolean().default(true),
      minSearchVolume: z.coerce.number().default(100),
      maxDifficulty: z.coerce.number().default(70),
      languageSupport: z.array(z.string()).default(['en', 'es', 'fr', 'de', 'it']),
    }),
  }),

  // Competitor Analysis
  competitorAnalysis: z.object({
    enabled: z.boolean().default(true),
    maxCompetitors: z.coerce.number().default(10),
    analysisDepth: z.enum(['basic', 'standard', 'comprehensive']).default('standard'),
    trackingInterval: z.coerce.number().default(24 * 60 * 60 * 1000), // 24 hours
    metrics: z.array(z.string()).default([
      'domain_authority',
      'page_authority',
      'backlinks',
      'organic_keywords',
      'traffic_estimate',
      'content_gaps'
    ]),
  }),

  // Sitemap Configuration
  sitemap: z.object({
    enabled: z.boolean().default(true),
    maxUrls: z.coerce.number().default(50000),
    autoGenerate: z.boolean().default(true),
    includeImages: z.boolean().default(true),
    includeVideos: z.boolean().default(true),
    includeNews: z.boolean().default(true),
    compressionEnabled: z.boolean().default(true),
    updateFrequency: z.enum(['always', 'hourly', 'daily', 'weekly', 'monthly', 'yearly', 'never']).default('daily'),
  }),

  // Meta Tag Generation
  metaTags: z.object({
    enabled: z.boolean().default(true),
    autoGenerate: z.boolean().default(true),
    titleMaxLength: z.coerce.number().default(60),
    descriptionMaxLength: z.coerce.number().default(160),
    keywordsMaxCount: z.coerce.number().default(10),
    includeOpenGraph: z.boolean().default(true),
    includeTwitterCards: z.boolean().default(true),
    includeJsonLd: z.boolean().default(true),
  }),

  // Performance Monitoring
  performance: z.object({
    enabled: z.boolean().default(true),
    monitoringInterval: z.coerce.number().default(60 * 60 * 1000), // 1 hour
    alertThresholds: z.object({
      pageLoadTime: z.coerce.number().default(3000), // 3 seconds
      firstContentfulPaint: z.coerce.number().default(2000), // 2 seconds
      largestContentfulPaint: z.coerce.number().default(2500), // 2.5 seconds
      cumulativeLayoutShift: z.coerce.number().default(0.1),
      firstInputDelay: z.coerce.number().default(100), // 100ms
    }),
  }),

  // AI-Powered Features
  ai: z.object({
    enabled: z.boolean().default(true),
    
    // OpenAI Configuration
    openai: z.object({
      apiKey: z.string().optional(),
      model: z.string().default('gpt-4'),
      maxTokens: z.coerce.number().default(2000),
      temperature: z.coerce.number().default(0.7),
    }),

    // Content Optimization
    contentOptimization: z.object({
      enabled: z.boolean().default(true),
      autoSuggestTitles: z.boolean().default(true),
      autoSuggestDescriptions: z.boolean().default(true),
      autoSuggestKeywords: z.boolean().default(true),
      contentScoring: z.boolean().default(true),
    }),

    // Semantic Analysis
    semanticAnalysis: z.object({
      enabled: z.boolean().default(true),
      entityExtraction: z.boolean().default(true),
      topicModeling: z.boolean().default(true),
      sentimentAnalysis: z.boolean().default(true),
    }),
  }),

  // External APIs
  externalApis: z.object({
    // Google Search Console
    googleSearchConsole: z.object({
      enabled: z.boolean().default(false),
      clientId: z.string().optional(),
      clientSecret: z.string().optional(),
      refreshToken: z.string().optional(),
    }),

    // Google Analytics
    googleAnalytics: z.object({
      enabled: z.boolean().default(false),
      trackingId: z.string().optional(),
      viewId: z.string().optional(),
      serviceAccountKey: z.string().optional(),
    }),

    // Bing Webmaster Tools
    bingWebmaster: z.object({
      enabled: z.boolean().default(false),
      apiKey: z.string().optional(),
    }),

    // Moz API
    moz: z.object({
      enabled: z.boolean().default(false),
      accessId: z.string().optional(),
      secretKey: z.string().optional(),
    }),
  }),

  // Caching Configuration
  cache: z.object({
    enabled: z.boolean().default(true),
    ttl: z.object({
      seoAnalysis: z.coerce.number().default(24 * 60 * 60), // 24 hours
      keywordData: z.coerce.number().default(7 * 24 * 60 * 60), // 7 days
      competitorData: z.coerce.number().default(24 * 60 * 60), // 24 hours
      performanceData: z.coerce.number().default(60 * 60), // 1 hour
      sitemapData: z.coerce.number().default(60 * 60), // 1 hour
    }),
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

  // Feature Flags
  features: z.object({
    enableLighthouse: z.boolean().default(true),
    enableKeywordResearch: z.boolean().default(true),
    enableCompetitorAnalysis: z.boolean().default(true),
    enableContentOptimization: z.boolean().default(true),
    enablePerformanceMonitoring: z.boolean().default(true),
    enableSchemaGeneration: z.boolean().default(true),
    enableSitemapGeneration: z.boolean().default(true),
    enableAIFeatures: z.boolean().default(true),
  }),

  // Notification Configuration
  notifications: z.object({
    enabled: z.boolean().default(true),
    channels: z.array(z.enum(['email', 'slack', 'webhook'])).default(['email']),
    alertOnIssues: z.boolean().default(true),
    alertOnImprovements: z.boolean().default(true),
    reportFrequency: z.enum(['daily', 'weekly', 'monthly']).default('weekly'),
  }),
});

// Parse configuration
const parseConfig = () => {
  const rawConfig = {
    nodeEnv: process.env.NODE_ENV,
    port: process.env.SEO_SERVICE_PORT || process.env.PORT,
    host: process.env.HOST,

    database: {
      postgresql: {
        host: process.env.POSTGRES_HOST,
        port: process.env.POSTGRES_PORT,
        database: process.env.POSTGRES_DB,
        username: process.env.POSTGRES_USER,
        password: process.env.POSTGRES_PASSWORD,
        ssl: process.env.POSTGRES_SSL === 'true',
        maxConnections: process.env.POSTGRES_MAX_CONNECTIONS,
      },
    },

    redis: {
      url: process.env.REDIS_URL,
      maxRetriesPerRequest: process.env.REDIS_MAX_RETRIES,
      retryDelayOnFailover: process.env.REDIS_RETRY_DELAY,
    },

    cors: {
      origin: process.env.CORS_ORIGIN?.split(',') || process.env.CORS_ORIGIN,
    },

    rateLimit: {
      windowMs: process.env.RATE_LIMIT_WINDOW_MS,
      max: process.env.RATE_LIMIT_MAX,
      auditWindowMs: process.env.AUDIT_RATE_LIMIT_WINDOW_MS,
      auditMax: process.env.AUDIT_RATE_LIMIT_MAX,
    },

    seoAnalysis: {
      lighthouse: {
        enabled: process.env.LIGHTHOUSE_ENABLED !== 'false',
        timeout: process.env.LIGHTHOUSE_TIMEOUT,
        maxConcurrent: process.env.LIGHTHOUSE_MAX_CONCURRENT,
        chromeFlags: process.env.LIGHTHOUSE_CHROME_FLAGS?.split(','),
      },
      pageSpeed: {
        enabled: process.env.PAGESPEED_ENABLED !== 'false',
        apiKey: process.env.GOOGLE_PAGESPEED_API_KEY,
        timeout: process.env.PAGESPEED_TIMEOUT,
        strategies: process.env.PAGESPEED_STRATEGIES?.split(','),
      },
      contentAnalysis: {
        enabled: process.env.CONTENT_ANALYSIS_ENABLED !== 'false',
        minWordCount: process.env.CONTENT_MIN_WORD_COUNT,
        maxWordCount: process.env.CONTENT_MAX_WORD_COUNT,
        keywordDensityMin: process.env.KEYWORD_DENSITY_MIN,
        keywordDensityMax: process.env.KEYWORD_DENSITY_MAX,
        readabilityTarget: process.env.READABILITY_TARGET,
      },
      technicalSeo: {
        enabled: process.env.TECHNICAL_SEO_ENABLED !== 'false',
        checkRobotsTxt: process.env.CHECK_ROBOTS_TXT !== 'false',
        checkSitemap: process.env.CHECK_SITEMAP !== 'false',
        checkSSL: process.env.CHECK_SSL !== 'false',
        checkRedirects: process.env.CHECK_REDIRECTS !== 'false',
        maxRedirects: process.env.MAX_REDIRECTS,
      },
      schemaMarkup: {
        enabled: process.env.SCHEMA_MARKUP_ENABLED !== 'false',
        validateStructuredData: process.env.VALIDATE_STRUCTURED_DATA !== 'false',
        autoGenerate: process.env.AUTO_GENERATE_SCHEMA !== 'false',
        supportedTypes: process.env.SCHEMA_SUPPORTED_TYPES?.split(','),
      },
    },

    keywordResearch: {
      googleKeywords: {
        enabled: process.env.GOOGLE_KEYWORDS_ENABLED === 'true',
        apiKey: process.env.GOOGLE_ADS_API_KEY,
        customerId: process.env.GOOGLE_ADS_CUSTOMER_ID,
      },
      semrush: {
        enabled: process.env.SEMRUSH_ENABLED === 'true',
        apiKey: process.env.SEMRUSH_API_KEY,
      },
      ahrefs: {
        enabled: process.env.AHREFS_ENABLED === 'true',
        apiKey: process.env.AHREFS_API_KEY,
      },
      internal: {
        enabled: process.env.INTERNAL_KEYWORDS_ENABLED !== 'false',
        minSearchVolume: process.env.MIN_SEARCH_VOLUME,
        maxDifficulty: process.env.MAX_KEYWORD_DIFFICULTY,
        languageSupport: process.env.KEYWORD_LANGUAGES?.split(','),
      },
    },

    competitorAnalysis: {
      enabled: process.env.COMPETITOR_ANALYSIS_ENABLED !== 'false',
      maxCompetitors: process.env.MAX_COMPETITORS,
      analysisDepth: process.env.COMPETITOR_ANALYSIS_DEPTH,
      trackingInterval: process.env.COMPETITOR_TRACKING_INTERVAL,
      metrics: process.env.COMPETITOR_METRICS?.split(','),
    },

    sitemap: {
      enabled: process.env.SITEMAP_ENABLED !== 'false',
      maxUrls: process.env.SITEMAP_MAX_URLS,
      autoGenerate: process.env.SITEMAP_AUTO_GENERATE !== 'false',
      includeImages: process.env.SITEMAP_INCLUDE_IMAGES !== 'false',
      includeVideos: process.env.SITEMAP_INCLUDE_VIDEOS !== 'false',
      includeNews: process.env.SITEMAP_INCLUDE_NEWS !== 'false',
      compressionEnabled: process.env.SITEMAP_COMPRESSION !== 'false',
      updateFrequency: process.env.SITEMAP_UPDATE_FREQUENCY,
    },

    metaTags: {
      enabled: process.env.META_TAGS_ENABLED !== 'false',
      autoGenerate: process.env.META_AUTO_GENERATE !== 'false',
      titleMaxLength: process.env.META_TITLE_MAX_LENGTH,
      descriptionMaxLength: process.env.META_DESCRIPTION_MAX_LENGTH,
      keywordsMaxCount: process.env.META_KEYWORDS_MAX_COUNT,
      includeOpenGraph: process.env.META_INCLUDE_OPENGRAPH !== 'false',
      includeTwitterCards: process.env.META_INCLUDE_TWITTER !== 'false',
      includeJsonLd: process.env.META_INCLUDE_JSONLD !== 'false',
    },

    performance: {
      enabled: process.env.PERFORMANCE_MONITORING_ENABLED !== 'false',
      monitoringInterval: process.env.PERFORMANCE_MONITORING_INTERVAL,
      alertThresholds: {
        pageLoadTime: process.env.ALERT_PAGE_LOAD_TIME,
        firstContentfulPaint: process.env.ALERT_FCP,
        largestContentfulPaint: process.env.ALERT_LCP,
        cumulativeLayoutShift: process.env.ALERT_CLS,
        firstInputDelay: process.env.ALERT_FID,
      },
    },

    ai: {
      enabled: process.env.AI_FEATURES_ENABLED !== 'false',
      openai: {
        apiKey: process.env.OPENAI_API_KEY,
        model: process.env.OPENAI_MODEL,
        maxTokens: process.env.OPENAI_MAX_TOKENS,
        temperature: process.env.OPENAI_TEMPERATURE,
      },
      contentOptimization: {
        enabled: process.env.AI_CONTENT_OPTIMIZATION_ENABLED !== 'false',
        autoSuggestTitles: process.env.AI_AUTO_SUGGEST_TITLES !== 'false',
        autoSuggestDescriptions: process.env.AI_AUTO_SUGGEST_DESCRIPTIONS !== 'false',
        autoSuggestKeywords: process.env.AI_AUTO_SUGGEST_KEYWORDS !== 'false',
        contentScoring: process.env.AI_CONTENT_SCORING !== 'false',
      },
      semanticAnalysis: {
        enabled: process.env.AI_SEMANTIC_ANALYSIS_ENABLED !== 'false',
        entityExtraction: process.env.AI_ENTITY_EXTRACTION !== 'false',
        topicModeling: process.env.AI_TOPIC_MODELING !== 'false',
        sentimentAnalysis: process.env.AI_SENTIMENT_ANALYSIS !== 'false',
      },
    },

    externalApis: {
      googleSearchConsole: {
        enabled: process.env.GOOGLE_SEARCH_CONSOLE_ENABLED === 'true',
        clientId: process.env.GOOGLE_SEARCH_CONSOLE_CLIENT_ID,
        clientSecret: process.env.GOOGLE_SEARCH_CONSOLE_CLIENT_SECRET,
        refreshToken: process.env.GOOGLE_SEARCH_CONSOLE_REFRESH_TOKEN,
      },
      googleAnalytics: {
        enabled: process.env.GOOGLE_ANALYTICS_ENABLED === 'true',
        trackingId: process.env.GOOGLE_ANALYTICS_TRACKING_ID,
        viewId: process.env.GOOGLE_ANALYTICS_VIEW_ID,
        serviceAccountKey: process.env.GOOGLE_ANALYTICS_SERVICE_ACCOUNT_KEY,
      },
      bingWebmaster: {
        enabled: process.env.BING_WEBMASTER_ENABLED === 'true',
        apiKey: process.env.BING_WEBMASTER_API_KEY,
      },
      moz: {
        enabled: process.env.MOZ_ENABLED === 'true',
        accessId: process.env.MOZ_ACCESS_ID,
        secretKey: process.env.MOZ_SECRET_KEY,
      },
    },

    cache: {
      enabled: process.env.CACHE_ENABLED !== 'false',
      ttl: {
        seoAnalysis: process.env.CACHE_SEO_ANALYSIS_TTL,
        keywordData: process.env.CACHE_KEYWORD_DATA_TTL,
        competitorData: process.env.CACHE_COMPETITOR_DATA_TTL,
        performanceData: process.env.CACHE_PERFORMANCE_DATA_TTL,
        sitemapData: process.env.CACHE_SITEMAP_DATA_TTL,
      },
    },

    logging: {
      level: process.env.LOG_LEVEL,
      format: process.env.LOG_FORMAT,
      enableConsole: process.env.LOG_ENABLE_CONSOLE !== 'false',
      enableFile: process.env.LOG_ENABLE_FILE !== 'false',
      maxFiles: process.env.LOG_MAX_FILES,
      maxSize: process.env.LOG_MAX_SIZE,
    },

    features: {
      enableLighthouse: process.env.ENABLE_LIGHTHOUSE !== 'false',
      enableKeywordResearch: process.env.ENABLE_KEYWORD_RESEARCH !== 'false',
      enableCompetitorAnalysis: process.env.ENABLE_COMPETITOR_ANALYSIS !== 'false',
      enableContentOptimization: process.env.ENABLE_CONTENT_OPTIMIZATION !== 'false',
      enablePerformanceMonitoring: process.env.ENABLE_PERFORMANCE_MONITORING !== 'false',
      enableSchemaGeneration: process.env.ENABLE_SCHEMA_GENERATION !== 'false',
      enableSitemapGeneration: process.env.ENABLE_SITEMAP_GENERATION !== 'false',
      enableAIFeatures: process.env.ENABLE_AI_FEATURES !== 'false',
    },

    notifications: {
      enabled: process.env.NOTIFICATIONS_ENABLED !== 'false',
      channels: process.env.NOTIFICATION_CHANNELS?.split(','),
      alertOnIssues: process.env.ALERT_ON_ISSUES !== 'false',
      alertOnImprovements: process.env.ALERT_ON_IMPROVEMENTS !== 'false',
      reportFrequency: process.env.REPORT_FREQUENCY,
    },
  };

  try {
    return configSchema.parse(rawConfig);
  } catch (error) {
    console.error('SEO Service configuration validation failed:', error);
    process.exit(1);
  }
};

export const config = parseConfig();

// Export types
export type Config = z.infer<typeof configSchema>;

// Utility functions
export const isDevelopment = () => config.nodeEnv === 'development';
export const isProduction = () => config.nodeEnv === 'production';

// Database connection string
export const getDatabaseUrl = () => {
  const { postgresql } = config.database;
  return `postgresql://${postgresql.username}:${postgresql.password}@${postgresql.host}:${postgresql.port}/${postgresql.database}${postgresql.ssl ? '?ssl=true' : ''}`;
};