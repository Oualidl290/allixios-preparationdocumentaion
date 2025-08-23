 /**
 * Database Manager for SEO Service
 * PostgreSQL connection and SEO-specific query management
 */

import { Pool, PoolClient } from 'pg';
import { config, getDatabaseUrl } from '../config';
import { logger, logError, logDatabase } from '../utils/logger';

export class DatabaseManager {
  private static pool: Pool;
  private static isInitialized = false;

  public static async initialize(): Promise<void> {
    if (this.isInitialized) {
      return;
    }

    try {
      this.pool = new Pool({
        connectionString: getDatabaseUrl(),
        max: config.database.postgresql.maxConnections,
        idleTimeoutMillis: 30000,
        connectionTimeoutMillis: 2000,
        ssl: config.database.postgresql.ssl ? { rejectUnauthorized: false } : false,
      });

      // Test connection
      const client = await this.pool.connect();
      const result = await client.query('SELECT NOW() as current_time, version() as version');
      client.release();

      logger.info('PostgreSQL connected successfully', {
        host: config.database.postgresql.host,
        port: config.database.postgresql.port,
        database: config.database.postgresql.database,
        currentTime: result.rows[0].current_time,
        version: result.rows[0].version.split(' ')[0] + ' ' + result.rows[0].version.split(' ')[1],
      });

      // Handle pool events
      this.pool.on('error', (error) => {
        logError(error, { context: 'PostgreSQL Pool Error' });
      });

      this.pool.on('connect', () => {
        logger.debug('New PostgreSQL client connected');
      });

      // Create SEO-specific database schema if not exists
      await this.createSEOSchema();

      this.isInitialized = true;
    } catch (error) {
      logError(error as Error, { context: 'DatabaseManager.initialize' });
      throw error;
    }
  }

  /**
   * Create SEO-specific database schema
   */
  private static async createSEOSchema(): Promise<void> {
    const schemas = [
      // SEO Analysis Results table
      `CREATE TABLE IF NOT EXISTS seo_analysis_results (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        url TEXT NOT NULL,
        domain TEXT NOT NULL,
        title TEXT,
        description TEXT,
        keywords JSONB DEFAULT '[]',
        overall_score INTEGER NOT NULL,
        technical_score INTEGER NOT NULL,
        content_score INTEGER NOT NULL,
        performance_score INTEGER NOT NULL,
        analysis_data JSONB NOT NULL,
        analyzed_at TIMESTAMP DEFAULT NOW(),
        analysis_version TEXT DEFAULT '1.0',
        tenant_id UUID,
        user_id UUID,
        created_at TIMESTAMP DEFAULT NOW(),
        updated_at TIMESTAMP DEFAULT NOW()
      )`,

      // SEO Issues table
      `CREATE TABLE IF NOT EXISTS seo_issues (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        analysis_id UUID NOT NULL REFERENCES seo_analysis_results(id) ON DELETE CASCADE,
        type TEXT NOT NULL CHECK (type IN ('error', 'warning', 'info')),
        category TEXT NOT NULL CHECK (category IN ('technical', 'content', 'performance', 'keywords', 'competitors')),
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        impact TEXT NOT NULL CHECK (impact IN ('high', 'medium', 'low')),
        effort TEXT NOT NULL CHECK (effort IN ('high', 'medium', 'low')),
        priority INTEGER NOT NULL,
        element TEXT,
        location TEXT,
        value JSONB,
        resolved BOOLEAN DEFAULT FALSE,
        resolved_at TIMESTAMP,
        created_at TIMESTAMP DEFAULT NOW()
      )`,

      // SEO Recommendations table
      `CREATE TABLE IF NOT EXISTS seo_recommendations (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        analysis_id UUID NOT NULL REFERENCES seo_analysis_results(id) ON DELETE CASCADE,
        category TEXT NOT NULL CHECK (category IN ('technical', 'content', 'performance', 'keywords', 'competitors')),
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        impact TEXT NOT NULL CHECK (impact IN ('high', 'medium', 'low')),
        effort TEXT NOT NULL CHECK (effort IN ('high', 'medium', 'low')),
        priority INTEGER NOT NULL,
        implementation TEXT NOT NULL,
        expected_improvement INTEGER,
        timeframe TEXT,
        implemented BOOLEAN DEFAULT FALSE,
        implemented_at TIMESTAMP,
        created_at TIMESTAMP DEFAULT NOW()
      )`,

      // Keyword Research Results table
      `CREATE TABLE IF NOT EXISTS keyword_research_results (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        keyword TEXT NOT NULL,
        search_volume INTEGER,
        difficulty INTEGER,
        cpc DECIMAL(10,2),
        competition TEXT CHECK (competition IN ('low', 'medium', 'high')),
        trend_data JSONB DEFAULT '[]',
        related_keywords JSONB DEFAULT '[]',
        questions JSONB DEFAULT '[]',
        seasonality_data JSONB DEFAULT '[]',
        source TEXT NOT NULL,
        language TEXT DEFAULT 'en',
        location TEXT DEFAULT 'global',
        tenant_id UUID,
        created_at TIMESTAMP DEFAULT NOW(),
        updated_at TIMESTAMP DEFAULT NOW()
      )`,

      // Keyword Positions table
      `CREATE TABLE IF NOT EXISTS keyword_positions (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        keyword TEXT NOT NULL,
        url TEXT NOT NULL,
        domain TEXT NOT NULL,
        position INTEGER NOT NULL,
        search_engine TEXT NOT NULL DEFAULT 'google',
        location TEXT DEFAULT 'global',
        device TEXT CHECK (device IN ('desktop', 'mobile')) DEFAULT 'desktop',
        tenant_id UUID,
        tracked_at TIMESTAMP DEFAULT NOW(),
        created_at TIMESTAMP DEFAULT NOW()
      )`,

      // Competitor Analysis Results table
      `CREATE TABLE IF NOT EXISTS competitor_analysis_results (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        domain TEXT NOT NULL,
        competitor_domain TEXT NOT NULL,
        overall_score INTEGER,
        technical_score INTEGER,
        content_score INTEGER,
        performance_score INTEGER,
        backlinks INTEGER,
        organic_keywords INTEGER,
        estimated_traffic INTEGER,
        domain_authority INTEGER,
        page_authority INTEGER,
        analysis_data JSONB NOT NULL,
        tenant_id UUID,
        analyzed_at TIMESTAMP DEFAULT NOW(),
        created_at TIMESTAMP DEFAULT NOW()
      )`,

      // Sitemap Entries table
      `CREATE TABLE IF NOT EXISTS sitemap_entries (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        domain TEXT NOT NULL,
        url TEXT NOT NULL,
        last_modified TIMESTAMP,
        change_frequency TEXT CHECK (change_frequency IN ('always', 'hourly', 'daily', 'weekly', 'monthly', 'yearly', 'never')),
        priority DECIMAL(2,1) CHECK (priority >= 0.0 AND priority <= 1.0),
        images JSONB DEFAULT '[]',
        videos JSONB DEFAULT '[]',
        news JSONB,
        tenant_id UUID,
        created_at TIMESTAMP DEFAULT NOW(),
        updated_at TIMESTAMP DEFAULT NOW()
      )`,

      // Performance Metrics table
      `CREATE TABLE IF NOT EXISTS performance_metrics (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        url TEXT NOT NULL,
        largest_contentful_paint INTEGER,
        first_input_delay INTEGER,
        cumulative_layout_shift DECIMAL(5,3),
        first_contentful_paint INTEGER,
        time_to_interactive INTEGER,
        page_load_time INTEGER,
        dom_content_loaded INTEGER,
        lighthouse_performance INTEGER,
        lighthouse_seo INTEGER,
        lighthouse_accessibility INTEGER,
        lighthouse_best_practices INTEGER,
        lighthouse_pwa INTEGER,
        metrics_data JSONB,
        tenant_id UUID,
        measured_at TIMESTAMP DEFAULT NOW(),
        created_at TIMESTAMP DEFAULT NOW()
      )`,

      // SEO Monitoring Alerts table
      `CREATE TABLE IF NOT EXISTS seo_monitoring_alerts (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        type TEXT NOT NULL CHECK (type IN ('performance', 'ranking', 'technical', 'content')),
        severity TEXT NOT NULL CHECK (severity IN ('low', 'medium', 'high', 'critical')),
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        url TEXT,
        metric TEXT,
        current_value DECIMAL(10,2),
        previous_value DECIMAL(10,2),
        threshold DECIMAL(10,2),
        resolved BOOLEAN DEFAULT FALSE,
        resolved_at TIMESTAMP,
        tenant_id UUID,
        created_at TIMESTAMP DEFAULT NOW()
      )`,

      // Meta Tag Suggestions table
      `CREATE TABLE IF NOT EXISTS meta_tag_suggestions (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        url TEXT NOT NULL,
        type TEXT NOT NULL CHECK (type IN ('title', 'description', 'keywords', 'opengraph', 'twitter', 'jsonld')),
        suggestion TEXT NOT NULL,
        score INTEGER NOT NULL,
        reasoning TEXT,
        applied BOOLEAN DEFAULT FALSE,
        applied_at TIMESTAMP,
        tenant_id UUID,
        created_at TIMESTAMP DEFAULT NOW()
      )`,

      // Schema Markup Data table
      `CREATE TABLE IF NOT EXISTS schema_markup_data (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        url TEXT NOT NULL,
        schema_type TEXT NOT NULL,
        schema_data JSONB NOT NULL,
        valid BOOLEAN DEFAULT TRUE,
        errors JSONB DEFAULT '[]',
        warnings JSONB DEFAULT '[]',
        tenant_id UUID,
        created_at TIMESTAMP DEFAULT NOW(),
        updated_at TIMESTAMP DEFAULT NOW()
      )`,
    ];

    // Create indexes for better performance
    const indexes = [
      'CREATE INDEX IF NOT EXISTS idx_seo_analysis_url ON seo_analysis_results(url)',
      'CREATE INDEX IF NOT EXISTS idx_seo_analysis_domain ON seo_analysis_results(domain)',
      'CREATE INDEX IF NOT EXISTS idx_seo_analysis_tenant ON seo_analysis_results(tenant_id)',
      'CREATE INDEX IF NOT EXISTS idx_seo_analysis_date ON seo_analysis_results(analyzed_at)',
      'CREATE INDEX IF NOT EXISTS idx_seo_issues_analysis ON seo_issues(analysis_id)',
      'CREATE INDEX IF NOT EXISTS idx_seo_issues_category ON seo_issues(category)',
      'CREATE INDEX IF NOT EXISTS idx_seo_issues_priority ON seo_issues(priority)',
      'CREATE INDEX IF NOT EXISTS idx_keyword_research_keyword ON keyword_research_results(keyword)',
      'CREATE INDEX IF NOT EXISTS idx_keyword_research_tenant ON keyword_research_results(tenant_id)',
      'CREATE INDEX IF NOT EXISTS idx_keyword_positions_keyword ON keyword_positions(keyword)',
      'CREATE INDEX IF NOT EXISTS idx_keyword_positions_domain ON keyword_positions(domain)',
      'CREATE INDEX IF NOT EXISTS idx_keyword_positions_date ON keyword_positions(tracked_at)',
      'CREATE INDEX IF NOT EXISTS idx_competitor_analysis_domain ON competitor_analysis_results(domain)',
      'CREATE INDEX IF NOT EXISTS idx_competitor_analysis_competitor ON competitor_analysis_results(competitor_domain)',
      'CREATE INDEX IF NOT EXISTS idx_sitemap_entries_domain ON sitemap_entries(domain)',
      'CREATE INDEX IF NOT EXISTS idx_sitemap_entries_url ON sitemap_entries(url)',
      'CREATE INDEX IF NOT EXISTS idx_performance_metrics_url ON performance_metrics(url)',
      'CREATE INDEX IF NOT EXISTS idx_performance_metrics_date ON performance_metrics(measured_at)',
      'CREATE INDEX IF NOT EXISTS idx_seo_alerts_type ON seo_monitoring_alerts(type)',
      'CREATE INDEX IF NOT EXISTS idx_seo_alerts_severity ON seo_monitoring_alerts(severity)',
      'CREATE INDEX IF NOT EXISTS idx_seo_alerts_resolved ON seo_monitoring_alerts(resolved)',
      'CREATE INDEX IF NOT EXISTS idx_meta_suggestions_url ON meta_tag_suggestions(url)',
      'CREATE INDEX IF NOT EXISTS idx_meta_suggestions_type ON meta_tag_suggestions(type)',
      'CREATE INDEX IF NOT EXISTS idx_schema_markup_url ON schema_markup_data(url)',
      'CREATE INDEX IF NOT EXISTS idx_schema_markup_type ON schema_markup_data(schema_type)',
    ];

    try {
      // Create tables
      for (const schema of schemas) {
        await this.query(schema);
      }

      // Create indexes
      for (const index of indexes) {
        await this.query(index);
      }

      logger.info('SEO database schema created successfully');
    } catch (error) {
      logError(error as Error, { context: 'Creating SEO database schema' });
      throw error;
    }
  }

  public static async query<T = any>(
    text: string,
    params?: any[],
    client?: PoolClient
  ): Promise<{ rows: T[]; rowCount: number }> {
    const startTime = Date.now();
    const useClient = client || this.pool;

    try {
      const result = await useClient.query(text, params);
      const duration = Date.now() - startTime;
      
      logDatabase(text, duration);
      
      return {
        rows: result.rows,
        rowCount: result.rowCount || 0,
      };
    } catch (error) {
      const duration = Date.now() - startTime;
      logDatabase(text, duration, error as Error);
      throw error;
    }
  }

  public static async transaction<T>(
    callback: (client: PoolClient) => Promise<T>
  ): Promise<T> {
    const client = await this.pool.connect();
    
    try {
      await client.query('BEGIN');
      const result = await callback(client);
      await client.query('COMMIT');
      return result;
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  }

  public static async healthCheck(): Promise<{
    status: string;
    latency?: number;
    error?: string;
  }> {
    try {
      const startTime = Date.now();
      await this.query('SELECT 1');
      const latency = Date.now() - startTime;
      
      return {
        status: 'healthy',
        latency,
      };
    } catch (error) {
      return {
        status: 'unhealthy',
        error: (error as Error).message,
      };
    }
  }

  public static getConnectionStats(): {
    totalCount: number;
    idleCount: number;
    waitingCount: number;
  } {
    return {
      totalCount: this.pool?.totalCount || 0,
      idleCount: this.pool?.idleCount || 0,
      waitingCount: this.pool?.waitingCount || 0,
    };
  }

  public static async close(): Promise<void> {
    if (this.pool) {
      await this.pool.end();
      this.isInitialized = false;
      logger.info('Database connection closed');
    }
  }

  /**
   * SEO-specific query helpers
   */

  // Save SEO analysis result
  public static async saveSEOAnalysis(analysisData: any): Promise<string> {
    const query = `
      INSERT INTO seo_analysis_results (
        url, domain, title, description, keywords,
        overall_score, technical_score, content_score, performance_score,
        analysis_data, tenant_id, user_id
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
      RETURNING id
    `;

    const result = await this.query(query, [
      analysisData.url,
      analysisData.domain,
      analysisData.title,
      analysisData.description,
      JSON.stringify(analysisData.keywords || []),
      analysisData.overallScore,
      analysisData.technicalScore,
      analysisData.contentScore,
      analysisData.performanceScore,
      JSON.stringify(analysisData),
      analysisData.tenantId,
      analysisData.userId,
    ]);

    return result.rows[0].id;
  }

  // Get recent SEO analysis for URL
  public static async getRecentSEOAnalysis(url: string, tenantId?: string): Promise<any> {
    let query = `
      SELECT * FROM seo_analysis_results 
      WHERE url = $1
    `;
    const params = [url];

    if (tenantId) {
      query += ` AND tenant_id = $2`;
      params.push(tenantId);
    }

    query += ` ORDER BY analyzed_at DESC LIMIT 1`;

    const result = await this.query(query, params);
    return result.rows[0] || null;
  }

  // Save keyword research results
  public static async saveKeywordResearch(keywordData: any): Promise<void> {
    const query = `
      INSERT INTO keyword_research_results (
        keyword, search_volume, difficulty, cpc, competition,
        trend_data, related_keywords, questions, seasonality_data,
        source, language, location, tenant_id
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)
      ON CONFLICT (keyword, source, language, location) 
      DO UPDATE SET
        search_volume = EXCLUDED.search_volume,
        difficulty = EXCLUDED.difficulty,
        cpc = EXCLUDED.cpc,
        competition = EXCLUDED.competition,
        trend_data = EXCLUDED.trend_data,
        related_keywords = EXCLUDED.related_keywords,
        questions = EXCLUDED.questions,
        seasonality_data = EXCLUDED.seasonality_data,
        updated_at = NOW()
    `;

    await this.query(query, [
      keywordData.keyword,
      keywordData.searchVolume,
      keywordData.difficulty,
      keywordData.cpc,
      keywordData.competition,
      JSON.stringify(keywordData.trend || []),
      JSON.stringify(keywordData.relatedKeywords || []),
      JSON.stringify(keywordData.questions || []),
      JSON.stringify(keywordData.seasonality || []),
      keywordData.source,
      keywordData.language || 'en',
      keywordData.location || 'global',
      keywordData.tenantId,
    ]);
  }

  // Save performance metrics
  public static async savePerformanceMetrics(metricsData: any): Promise<void> {
    const query = `
      INSERT INTO performance_metrics (
        url, largest_contentful_paint, first_input_delay, cumulative_layout_shift,
        first_contentful_paint, time_to_interactive, page_load_time, dom_content_loaded,
        lighthouse_performance, lighthouse_seo, lighthouse_accessibility,
        lighthouse_best_practices, lighthouse_pwa, metrics_data, tenant_id
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15)
    `;

    await this.query(query, [
      metricsData.url,
      metricsData.largestContentfulPaint,
      metricsData.firstInputDelay,
      metricsData.cumulativeLayoutShift,
      metricsData.firstContentfulPaint,
      metricsData.timeToInteractive,
      metricsData.pageLoadTime,
      metricsData.domContentLoaded,
      metricsData.lighthousePerformance,
      metricsData.lighthouseSeo,
      metricsData.lighthouseAccessibility,
      metricsData.lighthouseBestPractices,
      metricsData.lighthousePwa,
      JSON.stringify(metricsData),
      metricsData.tenantId,
    ]);
  }

  // Create SEO monitoring alert
  public static async createSEOAlert(alertData: any): Promise<string> {
    const query = `
      INSERT INTO seo_monitoring_alerts (
        type, severity, title, description, url, metric,
        current_value, previous_value, threshold, tenant_id
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
      RETURNING id
    `;

    const result = await this.query(query, [
      alertData.type,
      alertData.severity,
      alertData.title,
      alertData.description,
      alertData.url,
      alertData.metric,
      alertData.currentValue,
      alertData.previousValue,
      alertData.threshold,
      alertData.tenantId,
    ]);

    return result.rows[0].id;
  }
}