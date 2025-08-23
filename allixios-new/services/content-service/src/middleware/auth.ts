/**
 * Authentication Middleware
 * JWT token validation and user context
 */

import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import { config } from '../config';
import { logger } from '../utils/logger';

interface JWTPayload {
  id: string;
  tenantId: string;
  authorId?: string;
  role: string;
  permissions: string[];
  iat: number;
  exp: number;
}

export const authMiddleware = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  try {
    // Skip auth for public routes
    if (req.path.startsWith('/api/public/')) {
      return next();
    }

    // Get token from header
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({
        success: false,
        error: 'Access denied',
        message: 'No token provided or invalid token format.',
        code: 'NO_TOKEN',
      });
    }

    const token = authHeader.substring(7); // Remove 'Bearer ' prefix

    // Verify token
    const decoded = jwt.verify(token, config.auth.jwtSecret) as JWTPayload;

    // Add user to request
    req.user = {
      id: decoded.id,
      tenantId: decoded.tenantId,
      authorId: decoded.authorId,
      role: decoded.role,
      permissions: decoded.permissions,
    };

    logger.debug('User authenticated', {
      userId: decoded.id,
      tenantId: decoded.tenantId,
      role: decoded.role,
      requestId: req.id,
    });

    next();
  } catch (error) {
    if (error instanceof jwt.JsonWebTokenError) {
      return res.status(401).json({
        success: false,
        error: 'Invalid token',
        message: 'The provided token is invalid.',
        code: 'INVALID_TOKEN',
      });
    }

    if (error instanceof jwt.TokenExpiredError) {
      return res.status(401).json({
        success: false,
        error: 'Token expired',
        message: 'The provided token has expired.',
        code: 'TOKEN_EXPIRED',
      });
    }

    logger.error('Authentication error:', error);
    return res.status(500).json({
      success: false,
      error: 'Authentication failed',
      message: 'An error occurred during authentication.',
      code: 'AUTH_ERROR',
    });
  }
};

export const requirePermission = (permission: string) => {
  return (req: Request, res: Response, next: NextFunction) => {
    if (!req.user) {
      return res.status(401).json({
        success: false,
        error: 'Authentication required',
        code: 'AUTH_REQUIRED',
      });
    }

    if (!req.user.permissions.includes(permission) && req.user.role !== 'admin') {
      return res.status(403).json({
        success: false,
        error: 'Insufficient permissions',
        message: `This action requires the '${permission}' permission.`,
        code: 'INSUFFICIENT_PERMISSIONS',
      });
    }

    next();
  };
};