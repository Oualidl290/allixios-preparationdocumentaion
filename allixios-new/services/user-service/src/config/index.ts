/**
 * User Service Configuration
 * Centralized configuration management
 */

import dotenv from 'dotenv';
import { z } from 'zod';

// Load environment variables
dotenv.config();

// Configuration schema
const configSchema = z.object({
  // Server Configuration
  nodeEnv: z.enum(['development', 'staging', 'production']).default('development'),
  port: z.coerce.number().default(3002),
  host: z.string().default('0.0.0.0'),

  // Database Configuration
  database: z.object({
    postgresql: z.object({
      host: z.string().default('localhost'),
      port: z.coerce.number().default(5432),
      database: z.string().default('allixios'),
      username: z.string().default('allixios_user'),
      password: z.string().min(1),
      ssl: z.boolean().default(false),
      maxConnections: z.coerce.number().default(20),
    }),
  }),

  // Redis Configuration
  redis: z.object({
    url: z.string().url().default('redis://localhost:6379'),
    maxRetriesPerRequest: z.coerce.number().default(3),
    retryDelayOnFailover: z.coerce.number().default(100),
  }),

  // Authentication Configuration
  auth: z.object({
    jwtSecret: z.string().min(32),
    jwtExpiresIn: z.string().default('24h'),
    refreshTokenExpiresIn: z.string().default('7d'),
    bcryptRounds: z.coerce.number().default(12),
    maxLoginAttempts: z.coerce.number().default(5),
    lockoutDuration: z.coerce.number().default(15 * 60 * 1000), // 15 minutes
  }),

  // MFA Configuration
  mfa: z.object({
    issuer: z.string().default('Allixios'),
    window: z.coerce.number().default(2),
    qrCodeSize: z.coerce.number().default(200),
  }),

  // Email Configuration
  email: z.object({
    smtp: z.object({
      host: z.string().default('localhost'),
      port: z.coerce.number().default(587),
      secure: z.boolean().default(false),
      user: z.string().optional(),
      pass: z.string().optional(),
    }),
    from: z.string().email().default('noreply@allixios.com'),
    templates: z.object({
      welcome: z.string().default('welcome'),
      passwordReset: z.string().default('password-reset'),
      emailVerification: z.string().default('email-verification'),
      mfaSetup: z.string().default('mfa-setup'),
    }),
  }),

  // CORS Configuration
  cors: z.object({
    origin: z.union([z.string(), z.array(z.string()), z.boolean()]).default('*'),
  }),

  // Rate Limiting
  rateLimit: z.object({
    windowMs: z.coerce.number().default(15 * 60 * 1000),
    max: z.coerce.number().default(1000),
    authWindowMs: z.coerce.number().default(15 * 60 * 1000),
    authMax: z.coerce.number().default(10),
  }),

  // Session Configuration
  session: z.object({
    secret: z.string().min(32),
    maxAge: z.coerce.number().default(24 * 60 * 60 * 1000), // 24 hours
    secure: z.boolean().default(false),
    httpOnly: z.boolean().default(true),
  }),

  // Password Policy
  passwordPolicy: z.object({
    minLength: z.coerce.number().default(8),
    requireUppercase: z.boolean().default(true),
    requireLowercase: z.boolean().default(true),
    requireNumbers: z.boolean().default(true),
    requireSpecialChars: z.boolean().default(true),
    maxAge: z.coerce.number().default(90 * 24 * 60 * 60 * 1000), // 90 days
  }),

  // Account Settings
  account: z.object({
    emailVerificationRequired: z.boolean().default(true),
    emailVerificationExpiry: z.coerce.number().default(24 * 60 * 60 * 1000), // 24 hours
    passwordResetExpiry: z.coerce.number().default(60 * 60 * 1000), // 1 hour
    maxSessions: z.coerce.number().default(5),
  }),

  // Logging Configuration
  logging: z.object({
    level: z.enum(['error', 'warn', 'info', 'debug']).default('info'),
    format: z.enum(['json', 'simple']).default('json'),
  }),

  // Feature Flags
  features: z.object({
    enableMFA: z.boolean().default(true),
    enableSocialLogin: z.boolean().default(true),
    enablePasswordHistory: z.boolean().default(true),
    enableAccountLocking: z.boolean().default(true),
    enableAuditLog: z.boolean().default(true),
  }),
});

// Parse configuration
const parseConfig = () => {
  const rawConfig = {
    nodeEnv: process.env.NODE_ENV,
    port: process.env.USER_SERVICE_PORT || process.env.PORT,
    host: process.env.HOST,

    database: {
      postgresql: {
        host: process.env.POSTGRES_HOST,
        port: process.env.POSTGRES_PORT,
        database: process.env.POSTGRES_DB,
        username: process.env.POSTGRES_USER,
        password: process.env.POSTGRES_PASSWORD,
        ssl: process.env.POSTGRES_SSL === 'true',
        maxConnections: process.env.POSTGRES_MAX_CONNECTIONS,
      },
    },

    redis: {
      url: process.env.REDIS_URL,
      maxRetriesPerRequest: process.env.REDIS_MAX_RETRIES,
      retryDelayOnFailover: process.env.REDIS_RETRY_DELAY,
    },

    auth: {
      jwtSecret: process.env.JWT_SECRET,
      jwtExpiresIn: process.env.JWT_EXPIRES_IN,
      refreshTokenExpiresIn: process.env.REFRESH_TOKEN_EXPIRES_IN,
      bcryptRounds: process.env.BCRYPT_ROUNDS,
      maxLoginAttempts: process.env.MAX_LOGIN_ATTEMPTS,
      lockoutDuration: process.env.LOCKOUT_DURATION,
    },

    mfa: {
      issuer: process.env.MFA_ISSUER,
      window: process.env.MFA_WINDOW,
      qrCodeSize: process.env.MFA_QR_CODE_SIZE,
    },

    email: {
      smtp: {
        host: process.env.SMTP_HOST,
        port: process.env.SMTP_PORT,
        secure: process.env.SMTP_SECURE === 'true',
        user: process.env.SMTP_USER,
        pass: process.env.SMTP_PASS,
      },
      from: process.env.EMAIL_FROM,
      templates: {
        welcome: process.env.EMAIL_TEMPLATE_WELCOME,
        passwordReset: process.env.EMAIL_TEMPLATE_PASSWORD_RESET,
        emailVerification: process.env.EMAIL_TEMPLATE_EMAIL_VERIFICATION,
        mfaSetup: process.env.EMAIL_TEMPLATE_MFA_SETUP,
      },
    },

    cors: {
      origin: process.env.CORS_ORIGIN?.split(',') || process.env.CORS_ORIGIN,
    },

    rateLimit: {
      windowMs: process.env.RATE_LIMIT_WINDOW_MS,
      max: process.env.RATE_LIMIT_MAX,
      authWindowMs: process.env.AUTH_RATE_LIMIT_WINDOW_MS,
      authMax: process.env.AUTH_RATE_LIMIT_MAX,
    },

    session: {
      secret: process.env.SESSION_SECRET || process.env.JWT_SECRET,
      maxAge: process.env.SESSION_MAX_AGE,
      secure: process.env.SESSION_SECURE === 'true',
      httpOnly: process.env.SESSION_HTTP_ONLY !== 'false',
    },

    passwordPolicy: {
      minLength: process.env.PASSWORD_MIN_LENGTH,
      requireUppercase: process.env.PASSWORD_REQUIRE_UPPERCASE !== 'false',
      requireLowercase: process.env.PASSWORD_REQUIRE_LOWERCASE !== 'false',
      requireNumbers: process.env.PASSWORD_REQUIRE_NUMBERS !== 'false',
      requireSpecialChars: process.env.PASSWORD_REQUIRE_SPECIAL_CHARS !== 'false',
      maxAge: process.env.PASSWORD_MAX_AGE,
    },

    account: {
      emailVerificationRequired: process.env.EMAIL_VERIFICATION_REQUIRED !== 'false',
      emailVerificationExpiry: process.env.EMAIL_VERIFICATION_EXPIRY,
      passwordResetExpiry: process.env.PASSWORD_RESET_EXPIRY,
      maxSessions: process.env.MAX_SESSIONS,
    },

    logging: {
      level: process.env.LOG_LEVEL,
      format: process.env.LOG_FORMAT,
    },

    features: {
      enableMFA: process.env.ENABLE_MFA !== 'false',
      enableSocialLogin: process.env.ENABLE_SOCIAL_LOGIN !== 'false',
      enablePasswordHistory: process.env.ENABLE_PASSWORD_HISTORY !== 'false',
      enableAccountLocking: process.env.ENABLE_ACCOUNT_LOCKING !== 'false',
      enableAuditLog: process.env.ENABLE_AUDIT_LOG !== 'false',
    },
  };

  try {
    return configSchema.parse(rawConfig);
  } catch (error) {
    console.error('User Service configuration validation failed:', error);
    process.exit(1);
  }
};

export const config = parseConfig();

// Export types
export type Config = z.infer<typeof configSchema>;

// Utility functions
export const isDevelopment = () => config.nodeEnv === 'development';
export const isProduction = () => config.nodeEnv === 'production';

// Database connection string
export const getDatabaseUrl = () => {
  const { postgresql } = config.database;
  return `postgresql://${postgresql.username}:${postgresql.password}@${postgresql.host}:${postgresql.port}/${postgresql.database}${postgresql.ssl ? '?ssl=true' : ''}`;
};