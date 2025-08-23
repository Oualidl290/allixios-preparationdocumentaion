/**
 * User Service - Main Entry Point
 * Allixios Platform User Management Microservice
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
import { authRouter } from './routes/auth';
import { usersRouter } from './routes/users';
import { profileRouter } from './routes/profile';
import { tenantsRouter } from './routes/tenants';
import { healthRouter } from './routes/health';

class UserService {
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
      windowMs: 15 * 60 * 1000, // 15 minutes
      max: 1000,
    });
    this.app.use('/api/', limiter);

    this.app.use(express.json({ limit: '10mb' }));
    this.app.use(express.urlencoded({ extended: true }));

    // Request ID middleware
    this.app.use((req, res, next) => {
      req.id = require('uuid').v4();
      res.setHeader('X-Request-ID', req.id);
      req.startTime = Date.now();
      next();
    });
  }

  private setupRoutes(): void {
    this.app.use('/health', healthRouter);
    this.app.use('/api/auth', authRouter);
    this.app.use('/api/users', usersRouter);
    this.app.use('/api/profile', profileRouter);
    this.app.use('/api/tenants', tenantsRouter);

    this.app.get('/', (req, res) => {
      res.json({
        service: 'Allixios User Service',
        version: '1.0.0',
        status: 'running',
        timestamp: new Date().toISOString(),
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
        logger.info(`🚀 User Service started on port ${config.port}`);
      });

      this.setupGracefulShutdown();
    } catch (error) {
      logger.error('Failed to start User Service:', error);
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

const userService = new UserService();
userService.start();