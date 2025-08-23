/**
 * Authentication Middleware
 * JWT token validation and user context
 */

import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import { config } from '../config';
import { UserService } from '../services/UserService';
import { logger, logAuth, logSecurity } from '../utils/logger';

interface JWTPayload {
  id: string;
  email: string;
  tenantId?: string;
  roles: string[];
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
    // Get token from header
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      logSecurity('Missing or invalid authorization header', {
        ip: req.ip,
        userAgent: req.get('User-Agent'),
        url: req.url,
      });
      
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

    // Check if user still exists and is active
    const userService = new UserService();
    const user = await userService.getUserById(decoded.id);
    
    if (!user || user.status !== 'active') {
      logSecurity('Token valid but user inactive or not found', {
        userId: decoded.id,
        ip: req.ip,
        userAgent: req.get('User-Agent'),
      });
      
      return res.status(401).json({
        success: false,
        error: 'Access denied',
        message: 'User account is inactive or not found.',
        code: 'USER_INACTIVE',
      });
    }

    // Add user to request
    req.user = {
      id: decoded.id,
      email: decoded.email,
      tenantId: decoded.tenantId,
      roles: decoded.roles,
      permissions: decoded.permissions,
    };

    logAuth('User authenticated', decoded.id, {
      email: decoded.email,
      tenantId: decoded.tenantId,
      requestId: req.id,
    });

    next();
  } catch (error) {
    if (error instanceof jwt.JsonWebTokenError) {
      logSecurity('Invalid JWT token', {
        error: error.message,
        ip: req.ip,
        userAgent: req.get('User-Agent'),
      });
      
      return res.status(401).json({
        success: false,
        error: 'Invalid token',
        message: 'The provided token is invalid.',
        code: 'INVALID_TOKEN',
      });
    }

    if (error instanceof jwt.TokenExpiredError) {
      logSecurity('Expired JWT token', {
        ip: req.ip,
        userAgent: req.get('User-Agent'),
      });
      
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

export const optionalAuth = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  const authHeader = req.headers.authorization;
  
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return next();
  }

  try {
    await authMiddleware(req, res, next);
  } catch (error) {
    // Continue without authentication for optional auth
    next();
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

    if (!req.user.permissions.includes(permission) && !req.user.roles.includes('admin')) {
      logSecurity('Insufficient permissions', {
        userId: req.user.id,
        requiredPermission: permission,
        userPermissions: req.user.permissions,
        userRoles: req.user.roles,
      });
      
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

export const requireRole = (role: string) => {
  return (req: Request, res: Response, next: NextFunction) => {
    if (!req.user) {
      return res.status(401).json({
        success: false,
        error: 'Authentication required',
        code: 'AUTH_REQUIRED',
      });
    }

    if (!req.user.roles.includes(role) && !req.user.roles.includes('admin')) {
      logSecurity('Insufficient role', {
        userId: req.user.id,
        requiredRole: role,
        userRoles: req.user.roles,
      });
      
      return res.status(403).json({
        success: false,
        error: 'Insufficient role',
        message: `This action requires the '${role}' role.`,
        code: 'INSUFFICIENT_ROLE',
      });
    }

    next();
  };
};

export const requireTenant = (req: Request, res: Response, next: NextFunction) => {
  if (!req.user?.tenantId) {
    return res.status(403).json({
      success: false,
      error: 'Tenant required',
      message: 'This action requires a tenant context.',
      code: 'TENANT_REQUIRED',
    });
  }

  next();
};