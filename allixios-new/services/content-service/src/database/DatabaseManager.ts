/**
 * Database Manager
 * Manages PostgreSQL and MongoDB connections
 */

import { Pool, PoolClient } from 'pg';
import { MongoClient, Db } from 'mongodb';
import { config, getDatabaseUrl, getMongoUrl } from '../config';
import { logger, logDatabase, logError } from '../utils/logger';

export class DatabaseManager {
  private static pgPool: Pool;
  private static mongoClient: MongoClient;
  private static mongoDB: Db;
  private static isInitialized = false;

  /**
   * Initialize database connections
   */
  public static async initialize(): Promise<void> {
    if (this.isInitialized) {
      return;
    }

    try {
      // Initialize PostgreSQL
      await this.initializePostgreSQL();
      
      // Initialize MongoDB
      await this.initializeMongoDB();

      this.isInitialized = true;
      logger.info('Database connections initialized successfully');
    } catch (error) {
      logError(error as Error, { context: 'DatabaseManager.initialize' });
      throw error;
    }
  }

  /**
   * Initialize PostgreSQL connection pool
   */
  private static async initializePostgreSQL(): Promise<void> {
    const { postgresql } = config.database;
    
    this.pgPool = new Pool({
      connectionString: getDatabaseUrl(),
      max: postgresql.maxConnections,
      idleTimeoutMillis: postgresql.idleTimeoutMillis,
      connectionTimeoutMillis: postgresql.connectionTimeoutMillis,
      ssl: postgresql.ssl ? { rejectUnauthorized: false } : false,
    });

    // Test connection
    const client = await this.pgPool.connect();
    const result = await client.query('SELECT NOW() as current_time, version() as version');
    client.release();

    logger.info('PostgreSQL connected successfully', {
      host: postgresql.host,
      port: postgresql.port,
      database: postgresql.database,
      currentTime: result.rows[0].current_time,
      version: result.rows[0].version.split(' ')[0] + ' ' + result.rows[0].version.split(' ')[1],
    });

    // Handle pool errors
    this.pgPool.on('error', (error) => {
      logError(error, { context: 'PostgreSQL Pool Error' });
    });

    // Handle pool connection events
    this.pgPool.on('connect', (client) => {
      logger.debug('New PostgreSQL client connected');
    });

    this.pgPool.on('remove', (client) => {
      logger.debug('PostgreSQL client removed from pool');
    });
  }

  /**
   * Initialize MongoDB connection
   */
  private static async initializeMongoDB(): Promise<void> {
    const { mongodb } = config.database;

    this.mongoClient = new MongoClient(getMongoUrl(), {
      maxPoolSize: mongodb.maxPoolSize,
      serverSelectionTimeoutMS: mongodb.serverSelectionTimeoutMS,
      retryWrites: true,
      retryReads: true,
    });

    await this.mongoClient.connect();
    this.mongoDB = this.mongoClient.db(mongodb.database);

    // Test connection
    const adminDb = this.mongoClient.db('admin');
    const result = await adminDb.command({ ping: 1 });

    logger.info('MongoDB connected successfully', {
      database: mongodb.database,
      ping: result.ok === 1 ? 'success' : 'failed',
    });

    // Handle MongoDB events
    this.mongoClient.on('error', (error) => {
      logError(error, { context: 'MongoDB Client Error' });
    });

    this.mongoClient.on('close', () => {
      logger.warn('MongoDB connection closed');
    });

    this.mongoClient.on('reconnect', () => {
      logger.info('MongoDB reconnected');
    });
  }

  /**
   * Get PostgreSQL pool
   */
  public static getPostgreSQLPool(): Pool {
    if (!this.pgPool) {
      throw new Error('PostgreSQL pool not initialized. Call initialize() first.');
    }
    return this.pgPool;
  }

  /**
   * Get MongoDB database instance
   */
  public static getMongoDB(): Db {
    if (!this.mongoDB) {
      throw new Error('MongoDB not initialized. Call initialize() first.');
    }
    return this.mongoDB;
  }

  /**
   * Execute PostgreSQL query with logging and error handling
   */
  public static async query<T = any>(
    text: string,
    params?: any[],
    client?: PoolClient
  ): Promise<{ rows: T[]; rowCount: number }> {
    const startTime = Date.now();
    const useClient = client || this.pgPool;

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

  /**
   * Execute PostgreSQL transaction
   */
  public static async transaction<T>(
    callback: (client: PoolClient) => Promise<T>
  ): Promise<T> {
    const client = await this.pgPool.connect();
    
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

  /**
   * Execute MongoDB operation with error handling
   */
  public static async mongoOperation<T>(
    operation: (db: Db) => Promise<T>
  ): Promise<T> {
    const startTime = Date.now();
    
    try {
      const result = await operation(this.mongoDB);
      const duration = Date.now() - startTime;
      
      logger.debug('MongoDB Operation', {
        duration: `${duration}ms`,
      });
      
      return result;
    } catch (error) {
      const duration = Date.now() - startTime;
      logError(error as Error, {
        context: 'MongoDB Operation',
        duration: `${duration}ms`,
      });
      throw error;
    }
  }

  /**
   * Health check for databases
   */
  public static async healthCheck(): Promise<{
    postgresql: { status: string; latency?: number; error?: string };
    mongodb: { status: string; latency?: number; error?: string };
  }> {
    const result = {
      postgresql: { status: 'unknown' as string, latency: undefined as number | undefined, error: undefined as string | undefined },
      mongodb: { status: 'unknown' as string, latency: undefined as number | undefined, error: undefined as string | undefined },
    };

    // Check PostgreSQL
    try {
      const startTime = Date.now();
      await this.query('SELECT 1');
      result.postgresql.latency = Date.now() - startTime;
      result.postgresql.status = 'healthy';
    } catch (error) {
      result.postgresql.status = 'unhealthy';
      result.postgresql.error = (error as Error).message;
    }

    // Check MongoDB
    try {
      const startTime = Date.now();
      await this.mongoDB.admin().ping();
      result.mongodb.latency = Date.now() - startTime;
      result.mongodb.status = 'healthy';
    } catch (error) {
      result.mongodb.status = 'unhealthy';
      result.mongodb.error = (error as Error).message;
    }

    return result;
  }

  /**
   * Get connection statistics
   */
  public static getConnectionStats(): {
    postgresql: {
      totalCount: number;
      idleCount: number;
      waitingCount: number;
    };
    mongodb: {
      isConnected: boolean;
      serverDescription?: any;
    };
  } {
    return {
      postgresql: {
        totalCount: this.pgPool?.totalCount || 0,
        idleCount: this.pgPool?.idleCount || 0,
        waitingCount: this.pgPool?.waitingCount || 0,
      },
      mongodb: {
        isConnected: this.mongoClient?.topology?.isConnected() || false,
        serverDescription: this.mongoClient?.topology?.description,
      },
    };
  }

  /**
   * Close all database connections
   */
  public static async close(): Promise<void> {
    const promises: Promise<void>[] = [];

    if (this.pgPool) {
      promises.push(this.pgPool.end());
    }

    if (this.mongoClient) {
      promises.push(this.mongoClient.close());
    }

    await Promise.all(promises);
    this.isInitialized = false;
    
    logger.info('All database connections closed');
  }

  /**
   * Execute database function (stored procedure)
   */
  public static async callFunction<T = any>(
    functionName: string,
    params: any[] = []
  ): Promise<T[]> {
    const placeholders = params.map((_, index) => `$${index + 1}`).join(', ');
    const query = `SELECT * FROM ${functionName}(${placeholders})`;
    
    const result = await this.query<T>(query, params);
    return result.rows;
  }

  /**
   * Batch insert with conflict resolution
   */
  public static async batchInsert(
    tableName: string,
    columns: string[],
    values: any[][],
    conflictResolution: 'ignore' | 'update' | 'error' = 'error'
  ): Promise<number> {
    if (values.length === 0) {
      return 0;
    }

    const columnList = columns.join(', ');
    const valueRows = values.map((row, rowIndex) => {
      const rowPlaceholders = row.map((_, colIndex) => 
        `$${rowIndex * columns.length + colIndex + 1}`
      ).join(', ');
      return `(${rowPlaceholders})`;
    }).join(', ');

    const flatValues = values.flat();
    
    let query = `INSERT INTO ${tableName} (${columnList}) VALUES ${valueRows}`;
    
    if (conflictResolution === 'ignore') {
      query += ' ON CONFLICT DO NOTHING';
    } else if (conflictResolution === 'update') {
      const updateSet = columns.map(col => `${col} = EXCLUDED.${col}`).join(', ');
      query += ` ON CONFLICT DO UPDATE SET ${updateSet}`;
    }

    const result = await this.query(query, flatValues);
    return result.rowCount;
  }
}