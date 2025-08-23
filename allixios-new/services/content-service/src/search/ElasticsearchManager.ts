/**
 * Elasticsearch Manager
 * Search functionality management
 */

import { Client } from '@elastic/elasticsearch';
import { config, getElasticsearchUrl } from '../config';
import { logger } from '../utils/logger';

export class ElasticsearchManager {
  private static client: Client;
  private static isInitialized = false;

  public static async initialize(): Promise<void> {
    if (this.isInitialized) {
      return;
    }

    try {
      this.client = new Client({
        node: getElasticsearchUrl(),
        maxRetries: config.elasticsearch.maxRetries,
        requestTimeout: config.elasticsearch.requestTimeout,
        pingTimeout: config.elasticsearch.pingTimeout,
      });

      // Test connection
      await this.client.ping();
      
      this.isInitialized = true;
      logger.info('Elasticsearch Manager initialized successfully');
    } catch (error) {
      logger.error('Failed to initialize Elasticsearch Manager:', error);
      throw error;
    }
  }

  public static async index(indexName: string, id: string, document: any): Promise<void> {
    await this.client.index({
      index: indexName,
      id,
      body: document,
    });
  }

  public static async search(indexName: string, query: any): Promise<any> {
    const result = await this.client.search({
      index: indexName,
      body: query,
    });
    return result.body;
  }

  public static async delete(indexName: string, id: string): Promise<void> {
    try {
      await this.client.delete({
        index: indexName,
        id,
      });
    } catch (error) {
      // Ignore if document doesn't exist
      if (error.statusCode !== 404) {
        throw error;
      }
    }
  }

  public static async close(): Promise<void> {
    if (this.client) {
      await this.client.close();
      this.isInitialized = false;
      logger.info('Elasticsearch connection closed');
    }
  }
}