   /**
 * Cache Manager for SEO Service
 * Redis-based caching with SEO-specific optimizations
 */

import Redis from 'ioredis';
import { config } from '../config';
import { logger, logCacheOperation, logError } from '../utils/logger';

export class CacheManager {
  private redis: Redis;
  private isInitialized = false;

  constructor() {
    this.redis = new Redis(config.redis.url, {
      maxRetriesPerRequest: config.redis.maxRetriesPerRequest,
      retryDelayOnFailover: config.redis.retryDelayOnFailover,
      lazyConnect: true,
    });

    this.setupEventHandlers();
  }

  private setupEventHandlers(): void {
    this.redis.on('connect', () => {
      logger.info('Redis cache connected successfully');
      this.isInitialized = true;
    });

    this.redis.on('error', (error) => {
      logError(error, { context: 'Redis Cache Error' });
    });

    this.redis.on('close', () => {
      logger.warn('Redis cache connection closed');
      this.isInitialized = false;
    });
  }

  /**
   * Get cached value
   */
  async get(key: string): Promise<string | null> {
    try {
      const value = await this.redis.get(this.prefixKey(key));
      logCacheOperation(value ? 'hit' : 'miss', key);
      return value;
    } catch (error) {
      logError(error as Error, { context: 'Cache get operation', key });
      return null;
    }
  }

  /**
   * Set cached value with TTL
   */
  async setex(key: string, ttl: number, value: string): Promise<void> {
    try {
      await this.redis.setex(this.prefixKey(key), ttl, value);
      logCacheOperation('set', key, ttl);
    } catch (error) {
      logError(error as Error, { context: 'Cache setex operation', key, ttl });
    }
  }

  /**
   * Set cached value without TTL
   */
  async set(key: string, value: string): Promise<void> {
    try {
      await this.redis.set(this.prefixKey(key), value);
      logCacheOperation('set', key);
    } catch (error) {
      logError(error as Error, { context: 'Cache set operation', key });
    }
  }

  /**
   * Delete cached value
   */
  async del(key: string): Promise<void> {
    try {
      await this.redis.del(this.prefixKey(key));
      logCacheOperation('delete', key);
    } catch (error) {
      logError(error as Error, { context: 'Cache delete operation', key });
    }
  }

  /**
   * Check if key exists
   */
  async exists(key: string): Promise<boolean> {
    try {
      const result = await this.redis.exists(this.prefixKey(key));
      return result === 1;
    } catch (error) {
      logError(error as Error, { context: 'Cache exists operation', key });
      return false;
    }
  }

  /**
   * Get multiple keys
   */
  async mget(keys: string[]): Promise<(string | null)[]> {
    try {
      const prefixedKeys = keys.map(key => this.prefixKey(key));
      const values = await this.redis.mget(...prefixedKeys);
      
      keys.forEach((key, index) => {
        logCacheOperation(values[index] ? 'hit' : 'miss', key);
      });
      
      return values;
    } catch (error) {
      logError(error as Error, { context: 'Cache mget operation', keys });
      return keys.map(() => null);
    }
  }

  /**
   * Set multiple keys with TTL
   */
  async msetex(keyValuePairs: Array<{ key: string; value: string; ttl: number }>): Promise<void> {
    try {
      const pipeline = this.redis.pipeline();
      
      keyValuePairs.forEach(({ key, value, ttl }) => {
        pipeline.setex(this.prefixKey(key), ttl, value);
        logCacheOperation('set', key, ttl);
      });
      
      await pipeline.exec();
    } catch (error) {
      logError(error as Error, { context: 'Cache msetex operation' });
    }
  }

  /**
   * Increment counter
   */
  async incr(key: string): Promise<number> {
    try {
      const result = await this.redis.incr(this.prefixKey(key));
      logCacheOperation('set', key);
      return result;
    } catch (error) {
      logError(error as Error, { context: 'Cache incr operation', key });
      return 0;
    }
  }

  /**
   * Set expiration for existing key
   */
  async expire(key: string, ttl: number): Promise<void> {
    try {
      await this.redis.expire(this.prefixKey(key), ttl);
      logCacheOperation('set', key, ttl);
    } catch (error) {
      logError(error as Error, { context: 'Cache expire operation', key, ttl });
    }
  }

  /**
   * Get keys matching pattern
   */
  async keys(pattern: string): Promise<string[]> {
    try {
      const keys = await this.redis.keys(this.prefixKey(pattern));
      return keys.map(key => this.unprefixKey(key));
    } catch (error) {
      logError(error as Error, { context: 'Cache keys operation', pattern });
      return [];
    }
  }

  /**
   * Delete keys matching pattern
   */
  async deletePattern(pattern: string): Promise<number> {
    try {
      const keys = await this.redis.keys(this.prefixKey(pattern));
      if (keys.length === 0) return 0;
      
      const result = await this.redis.del(...keys);
      logCacheOperation('delete', pattern);
      return result;
    } catch (error) {
      logError(error as Error, { context: 'Cache delete pattern operation', pattern });
      return 0;
    }
  }

  /**
   * SEO-specific cache methods
   */

  /**
   * Cache SEO analysis result
   */
  async cacheSEOAnalysis(url: string, depth: string, result: any): Promise<void> {
    const key = `seo-analysis:${url}:${depth}`;
    const ttl = config.cache.ttl.seoAnalysis;
    await this.setex(key, ttl, JSON.stringify(result));
  }

  /**
   * Get cached SEO analysis
   */
  async getCachedSEOAnalysis(url: string, depth: string): Promise<any | null> {
    const key = `seo-analysis:${url}:${depth}`;
    const cached = await this.get(key);
    return cached ? JSON.parse(cached) : null;
  }

  /**
   * Cache keyword research data
   */
  async cacheKeywordData(keyword: string, source: string, data: any): Promise<void> {
    const key = `keyword-data:${source}:${keyword}`;
    const ttl = config.cache.ttl.keywordData;
    await this.setex(key, ttl, JSON.stringify(data));
  }

  /**
   * Get cached keyword data
   */
  async getCachedKeywordData(keyword: string, source: string): Promise<any | null> {
    const key = `keyword-data:${source}:${keyword}`;
    const cached = await this.get(key);
    return cached ? JSON.parse(cached) : null;
  }

  /**
   * Cache competitor analysis
   */
  async cacheCompetitorAnalysis(domain: string, competitors: string[], data: any): Promise<void> {
    const key = `competitor-analysis:${domain}:${competitors.sort().join(',')}`;
    const ttl = config.cache.ttl.competitorData;
    await this.setex(key, ttl, JSON.stringify(data));
  }

  /**
   * Get cached competitor analysis
   */
  async getCachedCompetitorAnalysis(domain: string, competitors: string[]): Promise<any | null> {
    const key = `competitor-analysis:${domain}:${competitors.sort().join(',')}`;
    const cached = await this.get(key);
    return cached ? JSON.parse(cached) : null;
  }

  /**
   * Cache performance metrics
   */
  async cachePerformanceMetrics(url: string, metrics: any): Promise<void> {
    const key = `performance-metrics:${url}`;
    const ttl = config.cache.ttl.performanceData;
    await this.setex(key, ttl, JSON.stringify(metrics));
  }

  /**
   * Get cached performance metrics
   */
  async getCachedPerformanceMetrics(url: string): Promise<any | null> {
    const key = `performance-metrics:${url}`;
    const cached = await this.get(key);
    return cached ? JSON.parse(cached) : null;
  }

  /**
   * Cache sitemap data
   */
  async cacheSitemapData(domain: string, sitemap: any): Promise<void> {
    const key = `sitemap-data:${domain}`;
    const ttl = config.cache.ttl.sitemapData;
    await this.setex(key, ttl, JSON.stringify(sitemap));
  }

  /**
   * Get cached sitemap data
   */
  async getCachedSitemapData(domain: string): Promise<any | null> {
    const key = `sitemap-data:${domain}`;
    const cached = await this.get(key);
    return cached ? JSON.parse(cached) : null;
  }

  /**
   * Cache external API response
   */
  async cacheAPIResponse(
    service: string,
    endpoint: string,
    params: Record<string, any>,
    response: any,
    ttl: number = 3600
  ): Promise<void> {
    const paramString = Object.keys(params)
      .sort()
      .map(key => `${key}=${params[key]}`)
      .join('&');
    
    const key = `api-response:${service}:${endpoint}:${paramString}`;
    await this.setex(key, ttl, JSON.stringify(response));
  }

  /**
   * Get cached API response
   */
  async getCachedAPIResponse(
    service: string,
    endpoint: string,
    params: Record<string, any>
  ): Promise<any | null> {
    const paramString = Object.keys(params)
      .sort()
      .map(key => `${key}=${params[key]}`)
      .join('&');
    
    const key = `api-response:${service}:${endpoint}:${paramString}`;
    const cached = await this.get(key);
    return cached ? JSON.parse(cached) : null;
  }

  /**
   * Rate limiting helpers
   */

  /**
   * Check rate limit
   */
  async checkRateLimit(
    identifier: string,
    limit: number,
    windowSeconds: number
  ): Promise<{ allowed: boolean; remaining: number; resetTime: number }> {
    const key = `rate-limit:${identifier}`;
    const now = Math.floor(Date.now() / 1000);
    const windowStart = now - windowSeconds;

    try {
      // Use Redis sorted set for sliding window rate limiting
      const pipeline = this.redis.pipeline();
      
      // Remove expired entries
      pipeline.zremrangebyscore(this.prefixKey(key), 0, windowStart);
      
      // Count current requests
      pipeline.zcard(this.prefixKey(key));
      
      // Add current request
      pipeline.zadd(this.prefixKey(key), now, `${now}-${Math.random()}`);
      
      // Set expiration
      pipeline.expire(this.prefixKey(key), windowSeconds);
      
      const results = await pipeline.exec();
      const currentCount = (results?.[1]?.[1] as number) || 0;
      
      const allowed = currentCount < limit;
      const remaining = Math.max(0, limit - currentCount - 1);
      const resetTime = now + windowSeconds;

      return { allowed, remaining, resetTime };
    } catch (error) {
      logError(error as Error, { context: 'Rate limit check', identifier });
      // Allow request on error
      return { allowed: true, remaining: limit - 1, resetTime: now + windowSeconds };
    }
  }

  /**
   * Cache warming helpers
   */

  /**
   * Warm cache with popular URLs
   */
  async warmCache(urls: string[]): Promise<void> {
    logger.info('Starting cache warming', { urlCount: urls.length });
    
    // This would trigger background SEO analysis for popular URLs
    // Implementation would depend on your specific needs
    
    for (const url of urls.slice(0, 10)) { // Limit to prevent overload
      const key = `cache-warm:${url}`;
      await this.setex(key, 3600, 'warming'); // Mark as warming
    }
  }

  /**
   * Get cache statistics
   */
  async getCacheStats(): Promise<{
    totalKeys: number;
    memoryUsage: string;
    hitRate: number;
    keysByPattern: Record<string, number>;
  }> {
    try {
      const info = await this.redis.info('memory');
      const keyspace = await this.redis.info('keyspace');
      
      // Count keys by pattern
      const patterns = [
        'seo-analysis:*',
        'keyword-data:*',
        'competitor-analysis:*',
        'performance-metrics:*',
        'sitemap-data:*',
        'api-response:*',
        'rate-limit:*',
      ];

      const keysByPattern: Record<string, number> = {};
      
      for (const pattern of patterns) {
        const keys = await this.keys(pattern);
        keysByPattern[pattern] = keys.length;
      }

      // Parse memory usage
      const memoryMatch = info.match(/used_memory_human:(.+)/);
      const memoryUsage = memoryMatch ? memoryMatch[1].trim() : 'Unknown';

      // Calculate total keys
      const totalKeys = Object.values(keysByPattern).reduce((sum, count) => sum + count, 0);

      return {
        totalKeys,
        memoryUsage,
        hitRate: 0, // Would need to track hits/misses over time
        keysByPattern,
      };
    } catch (error) {
      logError(error as Error, { context: 'Getting cache stats' });
      return {
        totalKeys: 0,
        memoryUsage: 'Unknown',
        hitRate: 0,
        keysByPattern: {},
      };
    }
  }

  /**
   * Clear all cache
   */
  async clearAll(): Promise<void> {
    try {
      await this.redis.flushdb();
      logger.info('Cache cleared successfully');
    } catch (error) {
      logError(error as Error, { context: 'Clearing cache' });
    }
  }

  /**
   * Close Redis connection
   */
  async close(): Promise<void> {
    try {
      await this.redis.quit();
      logger.info('Cache connection closed');
    } catch (error) {
      logError(error as Error, { context: 'Closing cache connection' });
    }
  }

  /**
   * Private helper methods
   */

  private prefixKey(key: string): string {
    return `seo-service:${key}`;
  }

  private unprefixKey(key: string): string {
    return key.replace(/^seo-service:/, '');
  }
}