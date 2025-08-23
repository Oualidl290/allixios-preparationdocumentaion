/**
 * Database Manager for User Service
 * PostgreSQL connection and query management
 */

import { Pool, PoolClient } from 'pg';
import { config, getDatabaseUrl } from '../config';
import { logger, logError } from '../utils/logger';

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

      this.isInitialized = true;
    } catch (error) {
      logError(error as Error, { context: 'DatabaseManager.initialize' });
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
      
      logger.debug('Database query executed', {
        query: text.substring(0, 100),
        duration: `${duration}ms`,
        rowCount: result.rowCount,
      });
      
      return {
        rows: result.rows,
        rowCount: result.rowCount || 0,
      };
    } catch (error) {
      const duration = Date.now() - startTime;
      logError(error as Error, {
        context: 'Database query failed',
        query: text.substring(0, 100),
        duration: `${duration}ms`,
      });
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
}