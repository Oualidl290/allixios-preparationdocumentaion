/**
 * Shared Logger
 * Centralized logging configuration for all services
 */

import winston from 'winston';

// Define log levels
const levels = {
  error: 0,
  warn: 1,
  info: 2,
  debug: 3,
};

// Define colors for console output
const colors = {
  error: 'red',
  warn: 'yellow',
  info: 'green',
  debug: 'blue',
};

winston.addColors(colors);

// Create logger instance
export const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  levels,
  format: winston.format.combine(
    winston.format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss' }),
    winston.format.errors({ stack: true }),
    winston.format.json()
  ),
  defaultMeta: {
    service: process.env.SERVICE_NAME || 'allixios-service',
    environment: process.env.NODE_ENV || 'development',
  },
  transports: [
    // Console transport
    new winston.transports.Console({
      format: winston.format.combine(
        winston.format.colorize({ all: true }),
        winston.format.simple()
      ),
    }),
    
    // File transport for errors
    new winston.transports.File({
      filename: 'logs/error.log',
      level: 'error',
      maxsize: 5242880, // 5MB
      maxFiles: 5,
    }),
    
    // File transport for all logs
    new winston.transports.File({
      filename: 'logs/combined.log',
      maxsize: 5242880, // 5MB
      maxFiles: 5,
    }),
  ],
});

// Helper functions for structured logging
export const logError = (error: Error, context?: Record<string, any>) => {
  logger.error('Error occurred', {
    message: error.message,
    stack: error.stack,
    ...context,
  });
};

export const logDatabase = (query: string, duration: number, error?: Error) => {
  if (error) {
    logger.error('Database query failed', {
      query: query.substring(0, 200),
      duration: `${duration}ms`,
      error: error.message,
    });
  } else {
    logger.debug('Database query executed', {
      query: query.substring(0, 200),
      duration: `${duration}ms`,
    });
  }
};

export const logRequest = (method: string, url: string, statusCode: number, duration: number, userId?: string) => {
  logger.info('HTTP Request', {
    method,
    url,
    statusCode,
    duration: `${duration}ms`,
    userId,
  });
};

export const logService = (serviceName: string, operation: string, duration: number, success: boolean) => {
  logger.info('Service operation', {
    service: serviceName,
    operation,
    duration: `${duration}ms`,
    success,
  });
};