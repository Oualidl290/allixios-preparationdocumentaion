/**
 * Logger Utility for SEO Service
 * Advanced logging with SEO-specific context
 */

import winston from 'winston';
import { config } from '../config';

// Create logger instance with SEO-specific formatting
export const logger = winston.createLogger({
  level: config.logging.level,
  format: winston.format.combine(
    winston.format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss' }),
    winston.format.errors({ stack: true }),
    winston.format.json(),
    winston.format.printf(({ timestamp, level, message, service, ...meta }) => {
      return JSON.stringify({
        timestamp,
        level,
        service: 'seo-service',
        message,
        ...meta
      });
    })
  ),
  defaultMeta: {
    service: 'seo-service',
    environment: config.nodeEnv,
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

    // SEO-specific log file
    new winston.transports.File({
      filename: 'logs/seo-analysis.log',
      level: 'info',
      maxsize: 10485760, // 10MB
      maxFiles: 10,
      format: winston.format.combine(
        winston.format.timestamp(),
        winston.format.json()
      )
    }),
  ],
});

// Helper functions for structured logging
export const logError = (error: Error, context?: Record<string, any>) => {
  logger.error('Error occurred', {
    message: error.message,
    stack: error.stack,
    name: error.name,
    ...context,
  });
};

export const logSEOAnalysis = (
  url: string, 
  analysisType: string, 
  duration: number, 
  success: boolean,
  context?: Record<string, any>
) => {
  logger.info('SEO Analysis completed', {
    url,
    analysisType,
    duration: `${duration}ms`,
    success,
    category: 'seo-analysis',
    ...context,
  });
};

export const logKeywordResearch = (
  keyword: string,
  source: string,
  resultsCount: number,
  duration: number,
  context?: Record<string, any>
) => {
  logger.info('Keyword research completed', {
    keyword,
    source,
    resultsCount,
    duration: `${duration}ms`,
    category: 'keyword-research',
    ...context,
  });
};

export const logCompetitorAnalysis = (
  domain: string,
  competitors: string[],
  duration: number,
  context?: Record<string, any>
) => {
  logger.info('Competitor analysis completed', {
    domain,
    competitorCount: competitors.length,
    competitors: competitors.slice(0, 5), // Log first 5 competitors
    duration: `${duration}ms`,
    category: 'competitor-analysis',
    ...context,
  });
};

export const logPerformanceMetrics = (
  url: string,
  metrics: Record<string, number>,
  context?: Record<string, any>
) => {
  logger.info('Performance metrics collected', {
    url,
    metrics,
    category: 'performance-monitoring',
    ...context,
  });
};

export const logSitemapGeneration = (
  domain: string,
  urlCount: number,
  duration: number,
  context?: Record<string, any>
) => {
  logger.info('Sitemap generated', {
    domain,
    urlCount,
    duration: `${duration}ms`,
    category: 'sitemap-generation',
    ...context,
  });
};

export const logAIOperation = (
  operation: string,
  input: string,
  outputLength: number,
  duration: number,
  context?: Record<string, any>
) => {
  logger.info('AI operation completed', {
    operation,
    inputLength: input.length,
    outputLength,
    duration: `${duration}ms`,
    category: 'ai-operations',
    ...context,
  });
};

export const logExternalAPI = (
  service: string,
  endpoint: string,
  statusCode: number,
  duration: number,
  context?: Record<string, any>
) => {
  logger.info('External API call', {
    service,
    endpoint,
    statusCode,
    duration: `${duration}ms`,
    category: 'external-api',
    success: statusCode >= 200 && statusCode < 300,
    ...context,
  });
};

export const logCacheOperation = (
  operation: 'hit' | 'miss' | 'set' | 'delete',
  key: string,
  ttl?: number,
  context?: Record<string, any>
) => {
  logger.debug('Cache operation', {
    operation,
    key: key.substring(0, 50), // Truncate long keys
    ttl,
    category: 'cache',
    ...context,
  });
};

export const logSecurityEvent = (
  event: string,
  severity: 'low' | 'medium' | 'high' | 'critical',
  context?: Record<string, any>
) => {
  logger.warn('Security event', {
    event,
    severity,
    category: 'security',
    ...context,
  });
};

export const logAudit = (
  action: string,
  userId?: string,
  context?: Record<string, any>
) => {
  logger.info('Audit log', {
    action,
    userId,
    timestamp: new Date().toISOString(),
    category: 'audit',
    ...context,
  });
};

export const logAlert = (
  alertType: string,
  severity: 'low' | 'medium' | 'high' | 'critical',
  message: string,
  context?: Record<string, any>
) => {
  const logLevel = severity === 'critical' || severity === 'high' ? 'error' : 
                   severity === 'medium' ? 'warn' : 'info';
  
  logger.log(logLevel, 'SEO Alert triggered', {
    alertType,
    severity,
    message,
    category: 'alerts',
    ...context,
  });
};

export const logDatabase = (query: string, duration: number, error?: Error) => {
  if (error) {
    logger.error('Database query failed', {
      query: query.substring(0, 200),
      duration: `${duration}ms`,
      error: error.message,
      category: 'database',
    });
  } else {
    logger.debug('Database query executed', {
      query: query.substring(0, 200),
      duration: `${duration}ms`,
      category: 'database',
    });
  }
};

export const logRequest = (
  method: string, 
  url: string, 
  statusCode: number, 
  duration: number, 
  userId?: string,
  context?: Record<string, any>
) => {
  logger.info('HTTP Request', {
    method,
    url,
    statusCode,
    duration: `${duration}ms`,
    userId,
    category: 'http-request',
    ...context,
  });
};