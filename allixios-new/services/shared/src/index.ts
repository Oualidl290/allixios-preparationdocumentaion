/**
 * Shared Utilities Index
 * Common utilities for all Allixios microservices
 */

// Database utilities
export * from './database/BaseRepository';
export * from './database/DatabaseConnection';
export * from './database/QueryBuilder';

// Authentication utilities
export * from './auth/JWTManager';
export * from './auth/PasswordManager';
export * from './auth/AuthMiddleware';

// Logging utilities
export * from './logging/Logger';
export * from './logging/RequestLogger';

// Validation utilities
export * from './validation/CommonSchemas';
export * from './validation/ValidationMiddleware';

// Error handling
export * from './errors/AppError';
export * from './errors/ErrorHandler';

// Metrics utilities
export * from './metrics/MetricsCollector';
export * from './metrics/HealthCheck';

// Configuration utilities
export * from './config/ConfigManager';
export * from './config/Environment';

// Cache utilities
export * from './cache/CacheManager';
export * from './cache/RedisClient';

// Queue utilities
export * from './queue/QueueManager';
export * from './queue/JobProcessor';

// HTTP utilities
export * from './http/HttpClient';
export * from './http/ResponseFormatter';

// Utility functions
export * from './utils/DateUtils';
export * from './utils/StringUtils';
export * from './utils/ValidationUtils';
export * from './utils/CryptoUtils';