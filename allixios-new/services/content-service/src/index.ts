/**
 * Content Service - Main Entry Point
 * Allixios Platform Content Management Microservice
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
import { authMiddleware } from './middleware/auth';
import { metricsMiddleware } from './middleware/metrics';
import { DatabaseManager } from './database/DatabaseManager';
import { RedisManager } from './cache/RedisManager';
import { ElasticsearchManager } from './search/ElasticsearchManager';
import { QueueManager } from './queue/QueueManager';

// Import routes
import { articlesRouter } from './routes/articles';
import { authorsRouter } from './routes/authors';
import { categoriesRouter } from './routes/categories';
import { tagsRouter } from './routes/tags';
import { mediaRouter } from './routes/media';
import { searchRouter } from './routes/search';
import { analyticsRouter } from './routes/analytics';
import { workflowRouter } from './routes/workflow';
import { healthRouter } from './routes/health';

// Import Swagger documentation
import { setupSwagger } from './docs/swagger';

class ContentService {
  private app: express.Application;
  private server: any;

  constructor() {
    this.app = express();
    this.setupMiddleware();
    this.setupRoutes();
    this.setupErrorHandling();
  }

  private setupMiddleware(): void {
    // Security middleware
    this.app.use(helmet({
      contentSecurityPolicy: {
        directives: {
          defaultSrc: ["'self'"],
          styleSrc: ["'self'", "'unsafe-inline'"],
          scriptSrc: ["'self'"],
          imgSrc: ["'self'", "data:", "https:"],
        },
      },
    }));

    // CORS configuration
    this.app.use(cors({
      origin: config.cors.origin,
      credentials: true,
      methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],
      allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With'],
    }));

    // Compression
    this.app.use(compression());

    // Request logging
    this.app.use(morgan('combined', {
      stream: {
        write: (message: string) => logger.info(message.trim())
      }
    }));

    // Rate limiting
    const limiter = rateLimit({
      windowMs: config.rateLimit.windowMs,
      max: config.rateLimit.max,
      message: {
        error: 'Too many requests from this IP, please try again later.',
        retryAfter: Math.ceil(config.rateLimit.windowMs / 1000)
      },
      standardHeaders: true,
      legacyHeaders: false,
    });
    this.app.use('/api/', limiter);

    // Body parsing
    this.app.use(express.json({ limit: '10mb' }));
    this.app.use(express.urlencoded({ extended: true, limit: '10mb' }));

    // Metrics middleware
    this.app.use(metricsMiddleware);

    // Request ID middleware
    this.app.use((req, res, next) => {
      req.id = require('uuid').v4();
      res.setHeader('X-Request-ID', req.id);
      next();
    });

    // Request context middleware
    this.app.use((req, res, next) => {
      req.startTime = Date.now();
      req.context = {
        requestId: req.id,
        userAgent: req.get('User-Agent'),
        ip: req.ip,
        method: req.method,
        url: req.url,
      };
      next();
    });
  }

  private setupRoutes(): void {
    // Health check (no auth required)
    this.app.use('/health', healthRouter);
    this.app.use('/ready', healthRouter);

    // API documentation
    setupSwagger(this.app);

    // API routes with authentication
    this.app.use('/api/articles', authMiddleware, articlesRouter);
    this.app.use('/api/authors', authMiddleware, authorsRouter);
    this.app.use('/api/categories', authMiddleware, categoriesRouter);
    this.app.use('/api/tags', authMiddleware, tagsRouter);
    this.app.use('/api/media', authMiddleware, mediaRouter);
    this.app.use('/api/search', authMiddleware, searchRouter);
    this.app.use('/api/analytics', authMiddleware, analyticsRouter);
    this.app.use('/api/workflow', authMiddleware, workflowRouter);

    // Public routes (no auth required)
    this.app.use('/api/public/articles', articlesRouter);
    this.app.use('/api/public/search', searchRouter);

    // Root endpoint
    this.app.get('/', (req, res) => {
      res.json({
        service: 'Allixios Content Service',
        version: '1.0.0',
        status: 'running',
        timestamp: new Date().toISOString(),
        endpoints: {
          health: '/health',
          docs: '/api-docs',
          api: '/api',
          public: '/api/public'
        }
      });
    });

    // 404 handler
    this.app.use('*', (req, res) => {
      res.status(404).json({
        error: 'Endpoint not found',
        message: `The requested endpoint ${req.method} ${req.originalUrl} was not found.`,
        availableEndpoints: [
          'GET /health',
          'GET /api-docs',
          'GET /api/articles',
          'POST /api/articles',
          'GET /api/search',
        ]
      });
    });
  }

  private setupErrorHandling(): void {
    this.app.use(errorHandler);
  }

  public async start(): Promise<void> {
    try {
      // Initialize database connections
      logger.info('Initializing database connections...');
      await DatabaseManager.initialize();
      
      // Initialize Redis
      logger.info('Initializing Redis connection...');
      await RedisManager.initialize();
      
      // Initialize Elasticsearch
      logger.info('Initializing Elasticsearch connection...');
      await ElasticsearchManager.initialize();
      
      // Initialize Queue Manager
      logger.info('Initializing Queue Manager...');
      await QueueManager.initialize();

      // Start HTTP server
      this.server = this.app.listen(config.port, () => {
        logger.info(`🚀 Content Service started successfully!`);
        logger.info(`📍 Server running on port ${config.port}`);
        logger.info(`🌍 Environment: ${config.nodeEnv}`);
        logger.info(`📚 API Documentation: http://localhost:${config.port}/api-docs`);
        logger.info(`❤️  Health Check: http://localhost:${config.port}/health`);
      });

      // Graceful shutdown handling
      this.setupGracefulShutdown();

    } catch (error) {
      logger.error('Failed to start Content Service:', error);
      process.exit(1);
    }
  }

  private setupGracefulShutdown(): void {
    const gracefulShutdown = async (signal: string) => {
      logger.info(`Received ${signal}. Starting graceful shutdown...`);

      // Stop accepting new requests
      if (this.server) {
        this.server.close(async () => {
          logger.info('HTTP server closed');

          try {
            // Close database connections
            await DatabaseManager.close();
            logger.info('Database connections closed');

            // Close Redis connection
            await RedisManager.close();
            logger.info('Redis connection closed');

            // Close Elasticsearch connection
            await ElasticsearchManager.close();
            logger.info('Elasticsearch connection closed');

            // Close queue connections
            await QueueManager.close();
            logger.info('Queue connections closed');

            logger.info('Graceful shutdown completed');
            process.exit(0);
          } catch (error) {
            logger.error('Error during graceful shutdown:', error);
            process.exit(1);
          }
        });
      }

      // Force shutdown after 30 seconds
      setTimeout(() => {
        logger.error('Forced shutdown after timeout');
        process.exit(1);
      }, 30000);
    };

    // Handle shutdown signals
    process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
    process.on('SIGINT', () => gracefulShutdown('SIGINT'));

    // Handle uncaught exceptions
    process.on('uncaughtException', (error) => {
      logger.error('Uncaught Exception:', error);
      gracefulShutdown('uncaughtException');
    });

    // Handle unhandled promise rejections
    process.on('unhandledRejection', (reason, promise) => {
      logger.error('Unhandled Rejection at:', promise, 'reason:', reason);
      gracefulShutdown('unhandledRejection');
    });
  }
}

// Start the service
const contentService = new ContentService();
contentService.start().catch((error) => {
  logger.error('Failed to start Content Service:', error);
  process.exit(1);
});

// Export for testing
export { ContentService };