/**
 * Logger Utility
 * Centralized logging configuration using Winston
 */

import winston from 'winston';
import DailyRotateFile from 'winston-daily-rotate-file';
import { config } from '../config';

// Custom log format
const logFormat = winston.format.combine(
  winston.format.timestamp({
    format: 'YYYY-MM-DD HH:mm:ss.SSS'
  }),
  winston.format.errors({ stack: true }),
  winston.format.json(),
  winston.format.printf(({ timestamp, level, message, stack, ...meta }) => {
    const logEntry = {
      timestamp,
      level,
      message,
      service: 'content-service',
      ...meta
    };

    if (stack) {
      logEntry.stack = stack;
    }

    return JSON.stringify(logEntry);
  })
);

// Console format for development
const consoleFormat = winston.format.combine(
  winston.format.colorize(),
  winston.format.timestamp({
    format: 'HH:mm:ss'
  }),
  winston.format.printf(({ timestamp, level, message, ...meta }) => {
    const metaStr = Object.keys(meta).length ? JSON.stringify(meta, null, 2) : '';
    return `${timestamp} [${level}]: ${message} ${metaStr}`;
  })
);

// Create transports array
const transports: winston.transport[] = [];

// Console transport
if (config.logging.enableConsole) {
  transports.push(
    new winston.transports.Console({
      format: config.nodeEnv === 'development' ? consoleFormat : logFormat,
      level: config.logging.level,
    })
  );
}

// File transports
if (config.logging.enableFile) {
  // Error logs
  transports.push(
    new DailyRotateFile({
      filename: 'logs/error-%DATE%.log',
      datePattern: 'YYYY-MM-DD',
      level: 'error',
      format: logFormat,
      maxFiles: config.logging.maxFiles,
      maxSize: config.logging.maxSize,
      zippedArchive: true,
    })
  );

  // Combined logs
  transports.push(
    new DailyRotateFile({
      filename: 'logs/combined-%DATE%.log',
      datePattern: 'YYYY-MM-DD',
      format: logFormat,
      maxFiles: config.logging.maxFiles,
      maxSize: config.logging.maxSize,
      zippedArchive: true,
    })
  );

  // Access logs (for HTTP requests)
  transports.push(
    new DailyRotateFile({
      filename: 'logs/access-%DATE%.log',
      datePattern: 'YYYY-MM-DD',
      format: logFormat,
      maxFiles: config.logging.maxFiles,
      maxSize: config.logging.maxSize,
      zippedArchive: true,
      level: 'info',
    })
  );
}

// Create logger instance
export const logger = winston.createLogger({
  level: config.logging.level,
  format: logFormat,
  transports,
  exitOnError: false,
  silent: process.env.NODE_ENV === 'test',
});

// Add request logging helper
export const logRequest = (req: any, res: any, responseTime?: number) => {
  const logData = {
    method: req.method,
    url: req.originalUrl,
    statusCode: res.statusCode,
    responseTime: responseTime ? `${responseTime}ms` : undefined,
    userAgent: req.get('User-Agent'),
    ip: req.ip,
    requestId: req.id,
    userId: req.user?.id,
    contentLength: res.get('Content-Length'),
  };

  if (res.statusCode >= 400) {
    logger.warn('HTTP Request', logData);
  } else {
    logger.info('HTTP Request', logData);
  }
};

// Add error logging helper
export const logError = (error: Error, context?: any) => {
  logger.error('Application Error', {
    message: error.message,
    stack: error.stack,
    name: error.name,
    context,
  });
};

// Add performance logging helper
export const logPerformance = (operation: string, duration: number, metadata?: any) => {
  logger.info('Performance Metric', {
    operation,
    duration: `${duration}ms`,
    ...metadata,
  });
};

// Add database logging helper
export const logDatabase = (query: string, duration: number, error?: Error) => {
  const logData = {
    query: query.substring(0, 200), // Truncate long queries
    duration: `${duration}ms`,
  };

  if (error) {
    logger.error('Database Error', {
      ...logData,
      error: error.message,
      stack: error.stack,
    });
  } else {
    logger.debug('Database Query', logData);
  }
};

// Add cache logging helper
export const logCache = (operation: string, key: string, hit: boolean, duration?: number) => {
  logger.debug('Cache Operation', {
    operation,
    key,
    hit,
    duration: duration ? `${duration}ms` : undefined,
  });
};

// Add AI logging helper
export const logAI = (provider: string, model: string, tokens: number, duration: number, cost?: number) => {
  logger.info('AI Operation', {
    provider,
    model,
    tokens,
    duration: `${duration}ms`,
    cost: cost ? `$${cost.toFixed(4)}` : undefined,
  });
};

// Add security logging helper
export const logSecurity = (event: string, userId?: string, ip?: string, details?: any) => {
  logger.warn('Security Event', {
    event,
    userId,
    ip,
    timestamp: new Date().toISOString(),
    ...details,
  });
};

// Add business metrics logging helper
export const logBusinessMetric = (metric: string, value: number, unit?: string, metadata?: any) => {
  logger.info('Business Metric', {
    metric,
    value,
    unit,
    timestamp: new Date().toISOString(),
    ...metadata,
  });
};

// Stream for Morgan HTTP logging
export const morganStream = {
  write: (message: string) => {
    logger.info(message.trim());
  },
};

// Export logger as default
export default logger;