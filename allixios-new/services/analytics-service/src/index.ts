/**
 * Analytics Service - Main Entry Point
 * Real-time analytics and reporting for Allixios Platform
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
import { analyticsRouter } from './routes/analytics';
import { dashboardRouter } from './routes/dashboard';
import { reportsRouter } from './routes/reports';
import { metricsRouter } from './routes/metrics';
import { healthRouter } from './routes/health';

class AnalyticsService {
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
    this.app.use('/api/analytics', analyticsRouter);
    this.app.use('/api/dashboard', dashboardRouter);
    this.app.use('/api/reports', reportsRouter);
    this.app.use('/api/metrics', metricsRouter);

    this.app.get('/', (req, res) => {
      res.json({
        service: 'Allixios Analytics Service',
        version: '1.0.0',
        status: 'running',
        timestamp: new Date().toISOString(),
        features: [
          'Real-time analytics',
          'Custom dashboards',
          'Performance metrics',
          'User behavior tracking',
          'Revenue analytics',
          'A/B testing',
          'Data export'
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
        logger.info(`🚀 Analytics Service started on port ${config.port}`);
        logger.info(`📊 Real-time analytics ready`);
        logger.info(`📈 Dashboard available at http://localhost:${config.port}/api/dashboard`);
      });

      this.setupGracefulShutdown();
    } catch (error) {
      logger.error('Failed to start Analytics Service:', error);
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

const analyticsService = new AnalyticsService();
analyticsService.start();