/**
 * Notification Service - Main Entry Point
 * Multi-channel notification system for Allixios Platform
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
import { QueueManager } from './queue/QueueManager';

// Import routes
import { emailRouter } from './routes/email';
import { smsRouter } from './routes/sms';
import { pushRouter } from './routes/push';
import { templatesRouter } from './routes/templates';
import { campaignsRouter } from './routes/campaigns';
import { healthRouter } from './routes/health';

class NotificationService {
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
    this.app.use('/api/email', emailRouter);
    this.app.use('/api/sms', smsRouter);
    this.app.use('/api/push', pushRouter);
    this.app.use('/api/templates', templatesRouter);
    this.app.use('/api/campaigns', campaignsRouter);

    this.app.get('/', (req, res) => {
      res.json({
        service: 'Allixios Notification Service',
        version: '1.0.0',
        status: 'running',
        timestamp: new Date().toISOString(),
        channels: [
          'Email (SMTP, SES)',
          'SMS (Twilio)',
          'Push Notifications (Web Push)',
          'In-app Notifications'
        ],
        features: [
          'Template management',
          'Campaign automation',
          'Delivery tracking',
          'A/B testing',
          'Personalization',
          'Scheduling'
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
      await QueueManager.initialize();
      
      this.server = this.app.listen(config.port, () => {
        logger.info(`🚀 Notification Service started on port ${config.port}`);
        logger.info(`📧 Email notifications ready`);
        logger.info(`📱 SMS notifications ready`);
        logger.info(`🔔 Push notifications ready`);
      });

      this.setupGracefulShutdown();
    } catch (error) {
      logger.error('Failed to start Notification Service:', error);
      process.exit(1);
    }
  }

  private setupGracefulShutdown(): void {
    const gracefulShutdown = async (signal: string) => {
      logger.info(`Received ${signal}. Starting graceful shutdown...`);
      
      if (this.server) {
        this.server.close(async () => {
          await DatabaseManager.close();
          await QueueManager.close();
          logger.info('Graceful shutdown completed');
          process.exit(0);
        });
      }
    };

    process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
    process.on('SIGINT', () => gracefulShutdown('SIGINT'));
  }
}

const notificationService = new NotificationService();
notificationService.start();