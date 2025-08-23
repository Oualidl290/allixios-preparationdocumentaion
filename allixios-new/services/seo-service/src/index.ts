/**
 * SEO Service - Main Entry Point
 * SEO optimization and analysis for Allixios Platform
 */

import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import compression from 'compression';
import morgan from 'morgan';
import rateLimit from 'express-rate-limit';
import { config } from './config';
import { logger } from './utils/logger';
import { errorHandler } from './middleware/errorHandler';
import { DatabaseManager } from './database/DatabaseManager';

// Import routes
import { seoRouter } from './routes/seo';
import { sitemapRouter } from './routes/sitemap';
import { keywordsRouter } from './routes/keywords';
import { auditRouter } from './routes/audit';
import { healthRouter } from './routes/health';

class SEOService {
  private app: express.Application;
  private server: any;

  constructor() {
    this.app = express();
    this.setupMiddleware();
    this.setupRoutes();
    this.setupErrorHandling();
  }

  private setupMiddleware(): void {
    this.app.use(helmet());
    this.app.use(cors({ origin: config.cors.origin, credentials: true }));
    this.app.use(compression());
    this.app.use(morgan('combined'));
    
    const limiter = rateLimit({
      windowMs: 15 * 60 * 1000,
      max: 1000,
    });
    this.app.use('/api/', limiter);

    this.app.use(express.json({ limit: '10mb' }));
    this.app.use(express.urlencoded({ extended: true }));

    this.app.use((req, res, next) => {
      req.id = require('uuid').v4();
      res.setHeader('X-Request-ID', req.id);
      req.startTime = Date.now();
      next();
    });
  }

  private setupRoutes(): void {
    this.app.use('/health', healthRouter);
    this.app.use('/api/seo', seoRouter);
    this.app.use('/api/sitemap', sitemapRouter);
    this.app.use('/api/keywords', keywordsRouter);
    this.app.use('/api/audit', auditRouter);

    this.app.get('/', (req, res) => {
      res.json({
        service: 'Allixios SEO Service',
        version: '1.0.0',
        status: 'running',
        timestamp: new Date().toISOString(),
        features: [
          'Meta tag generation',
          'Sitemap generation',
          'SEO score analysis',
          'Keyword optimization',
          'Schema markup',
          'Performance monitoring',
          'Competitor analysis'
        ]
      });
    });
  }

  private setupErrorHandling(): void {
    this.app.use(errorHandler);
  }

  public async start(): Promise<void> {
    try {
      await DatabaseManager.initialize();
      
      this.server = this.app.listen(config.port, () => {
        logger.info(`🚀 SEO Service started on port ${config.port}`);
        logger.info(`🔍 SEO optimization ready`);
        logger.info(`📊 SEO analytics available at http://localhost:${config.port}/api/seo`);
      });

      this.setupGracefulShutdown();
    } catch (error) {
      logger.error('Failed to start SEO Service:', error);
      process.exit(1);
    }
  }

  private setupGracefulShutdown(): void {
    const gracefulShutdown = async (signal: string) => {
      logger.info(`Received ${signal}. Starting graceful shutdown...`);
      
      if (this.server) {
        this.server.close(async () => {
          await DatabaseManager.close();
          logger.info('Graceful shutdown completed');
          process.exit(0);
        });
      }
    };

    process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
    process.on('SIGINT', () => gracefulShutdown('SIGINT'));
  }
}

const seoService = new SEOService();
seoService.start();