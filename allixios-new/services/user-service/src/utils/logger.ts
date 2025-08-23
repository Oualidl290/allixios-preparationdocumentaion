/**
 * Logger Utility
 * Structured logging for User Service
 */

import winston from 'winston';
import { config } from '../config';

// Create logger instance
export const logger = winston.createLogger({
  level: config.logging.level,
  format: winston.format.combine(
    winston.format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss' }),
    winston.format.errors({ stack: true }),
    config.logging.format === 'json' 
      ? winston.format.json()
      : winston.format.simple()
  ),
  defaultMeta: {
    service: 'user-service',
    environment: config.nodeEnv,
  },
  transports: [
    new winston.transports.Console({
      format: winston.format.combine(
        winston.format.colorize({ all: true }),
        winston.format.simple()
      ),
    }),
    new winston.transports.File({
      filename: 'logs/error.log',
      level: 'error',
      maxsize: 5242880, // 5MB
      maxFiles: 5,
    }),
    new winston.transports.File({
      filename: 'logs/combined.log',
      maxsize: 5242880, // 5MB
      maxFiles: 5,
    }),
  ],
});

// Helper functions
export const logError = (error: Error, context?: Record<string, any>) => {
  logger.error('Error occurred', {
    message: error.message,
    stack: error.stack,
    ...context,
  });
};

export const logAuth = (event: string, userId?: string, context?: Record<string, any>) => {
  logger.info('Authentication event', {
    event,
    userId,
    ...context,
  });
};

export const logSecurity = (event: string, context?: Record<string, any>) => {
  logger.warn('Security event', {
    event,
    ...context,
  });
};

export const logAudit = (action: string, userId: string, context?: Record<string, any>) => {
  logger.info('Audit log', {
    action,
    userId,
    timestamp: new Date().toISOString(),
    ...context,
  });
};