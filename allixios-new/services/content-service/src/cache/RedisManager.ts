/**
 * Redis Manager
 * Redis connection and operations management
 */

import Redis from 'ioredis';
import { config, getRedisUrl } from '../config';
import { logger } from '../utils/logger';

export class RedisManager {
  private static client: Redis;
  private static isInitialized = false;

  public static async initialize(): Promise<void> {
    if (this.isInitialized) {
      return;
    }

    try {
      this.client = new Redis(getRedisUrl(), {
        maxRetriesPerRequest: config.redis.maxRetriesPerRequest,
        retryDelayOnFailover: config.redis.retryDelayOnFailover,
        enableReadyCheck: config.redis.enableReadyCheck,
        lazyConnect: true,
      });

      // Event handlers
      this.client.on('connect', () => {
        logger.info('Redis connected successfully');
      });

      this.client.on('error', (error) => {
        logger.error('Redis connection error:', error);
      });

      this.client.on('close', () => {
        logger.warn('Redis connection closed');
      });

      // Connect
      await this.client.connect();
      
      // Test connection
      await this.client.ping();
      
      this.isInitialized = true;
      logger.info('Redis Manager initialized successfully');
    } catch (error) {
      logger.error('Failed to initialize Redis Manager:', error);
      throw error;
    }
  }

  public static async get(key: string): Promise<string | null> {
    return await this.client.get(key);
  }

  public static async set(key: string, value: string): Promise<void> {
    await this.client.set(key, value);
  }

  public static async setex(key: string, seconds: number, value: string): Promise<void> {
    await this.client.setex(key, seconds, value);
  }

  public static async del(key: string): Promise<void> {
    await this.client.del(key);
  }

  public static async close(): Promise<void> {
    if (this.client) {
      await this.client.quit();
      this.isInitialized = false;
      logger.info('Redis connection closed');
    }
  }
}