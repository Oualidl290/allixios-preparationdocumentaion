/**
 * JWT Manager
 * Shared JWT token management utilities
 */

import jwt from 'jsonwebtoken';
import { logger } from '../logging/Logger';

export interface JWTPayload {
  id: string;
  tenantId: string;
  role: string;
  permissions: string[];
  email?: string;
  iat?: number;
  exp?: number;
}

export class JWTManager {
  private static secret: string;
  private static expiresIn: string = '24h';

  public static initialize(secret: string, expiresIn: string = '24h'): void {
    this.secret = secret;
    this.expiresIn = expiresIn;
  }

  public static generateToken(payload: Omit<JWTPayload, 'iat' | 'exp'>): string {
    if (!this.secret) {
      throw new Error('JWT secret not initialized');
    }

    return jwt.sign(payload, this.secret, {
      expiresIn: this.expiresIn,
      issuer: 'allixios',
      audience: 'allixios-services',
    });
  }

  public static verifyToken(token: string): JWTPayload {
    if (!this.secret) {
      throw new Error('JWT secret not initialized');
    }

    try {
      return jwt.verify(token, this.secret, {
        issuer: 'allixios',
        audience: 'allixios-services',
      }) as JWTPayload;
    } catch (error) {
      logger.warn('JWT verification failed', { error: error.message });
      throw error;
    }
  }

  public static decodeToken(token: string): JWTPayload | null {
    try {
      return jwt.decode(token) as JWTPayload;
    } catch (error) {
      logger.warn('JWT decode failed', { error: error.message });
      return null;
    }
  }

  public static refreshToken(token: string): string {
    const decoded = this.verifyToken(token);
    
    // Remove JWT specific fields
    const { iat, exp, ...payload } = decoded;
    
    return this.generateToken(payload);
  }
}