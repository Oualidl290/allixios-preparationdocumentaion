/**
 * User Service
 * Core business logic for user management
 */

import bcrypt from 'bcrypt';
import jwt from 'jsonwebtoken';
import { v4 as uuidv4 } from 'uuid';
import { DatabaseManager } from '../database/DatabaseManager';
import { config } from '../config';
import { logger, logAuth, logAudit, logSecurity } from '../utils/logger';
import { 
  User, 
  RegisterRequest, 
  LoginRequest, 
  LoginResponse, 
  UpdateProfileRequest,
  ChangePasswordRequest 
} from '../types';

export class UserService {
  
  /**
   * Register a new user
   */
  async registerUser(data: RegisterRequest): Promise<Omit<User, 'password_hash' | 'mfa_secret'>> {
    // Check if user already exists
    const existingUser = await this.getUserByEmail(data.email);
    if (existingUser) {
      throw new Error('User already exists with this email');
    }

    // Validate password strength
    this.validatePassword(data.password);

    // Hash password
    const passwordHash = await bcrypt.hash(data.password, config.auth.bcryptRounds);

    // Generate user ID
    const userId = uuidv4();

    // Insert user
    const query = `
      INSERT INTO users (
        id, email, username, password_hash, first_name, last_name,
        status, email_verified, phone_verified, mfa_enabled,
        login_attempts, password_changed_at, tenant_id, metadata
      ) VALUES (
        $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, NOW(), $12, $13
      ) RETURNING 
        id, email, username, first_name, last_name, avatar_url, phone,
        date_of_birth, timezone, locale, status, email_verified, 
        email_verified_at, phone_verified, phone_verified_at, mfa_enabled,
        last_login_at, last_login_ip, login_attempts, locked_until,
        password_changed_at, tenant_id, metadata, created_at, updated_at
    `;

    const result = await DatabaseManager.query(query, [
      userId,
      data.email.toLowerCase(),
      data.username,
      passwordHash,
      data.first_name,
      data.last_name,
      'pending_verification',
      false,
      false,
      false,
      0,
      data.tenant_id,
      data.metadata || {}
    ]);

    const user = result.rows[0];

    logAudit('user_registered', userId, {
      email: data.email,
      tenantId: data.tenant_id,
    });

    // Send verification email if required
    if (config.account.emailVerificationRequired) {
      await this.sendEmailVerification(userId);
    }

    return user;
  }

  /**
   * Authenticate user login
   */
  async loginUser(data: LoginRequest, ipAddress: string, userAgent?: string): Promise<LoginResponse> {
    const email = data.email.toLowerCase();

    // Record login attempt
    await this.recordLoginAttempt(email, ipAddress, userAgent, false);

    // Get user by email
    const user = await this.getUserByEmail(email, true);
    if (!user) {
      logSecurity('Login attempt with non-existent email', {
        email,
        ipAddress,
        userAgent,
      });
      throw new Error('Invalid credentials');
    }

    // Check if account is locked
    if (user.locked_until && new Date() < user.locked_until) {
      logSecurity('Login attempt on locked account', {
        userId: user.id,
        email,
        ipAddress,
        lockedUntil: user.locked_until,
      });
      throw new Error('Account is temporarily locked due to too many failed login attempts');
    }

    // Check if account is active
    if (user.status !== 'active' && user.status !== 'pending_verification') {
      logSecurity('Login attempt on inactive account', {
        userId: user.id,
        email,
        status: user.status,
        ipAddress,
      });
      throw new Error('Account is not active');
    }

    // Verify password
    const isPasswordValid = await bcrypt.compare(data.password, user.password_hash);
    if (!isPasswordValid) {
      await this.handleFailedLogin(user.id, email, ipAddress, userAgent);
      throw new Error('Invalid credentials');
    }

    // Check if MFA is required
    if (user.mfa_enabled && !data.mfa_code) {
      return {
        user: this.sanitizeUser(user),
        token: '',
        expires_in: 0,
        mfa_required: true,
      };
    }

    // Verify MFA if provided
    if (user.mfa_enabled && data.mfa_code) {
      const isMFAValid = await this.verifyMFACode(user.id, data.mfa_code);
      if (!isMFAValid) {
        await this.handleFailedLogin(user.id, email, ipAddress, userAgent);
        throw new Error('Invalid MFA code');
      }
    }

    // Reset login attempts on successful login
    await this.resetLoginAttempts(user.id);

    // Update last login
    await this.updateLastLogin(user.id, ipAddress);

    // Record successful login attempt
    await this.recordLoginAttempt(email, ipAddress, userAgent, true);

    // Generate tokens
    const { token, refreshToken } = await this.generateTokens(user);

    // Create session
    await this.createSession(user.id, token, refreshToken, ipAddress, userAgent);

    logAuth('user_logged_in', user.id, {
      email: user.email,
      ipAddress,
      mfaUsed: user.mfa_enabled,
    });

    logAudit('user_login', user.id, {
      ipAddress,
      userAgent,
    });

    return {
      user: this.sanitizeUser(user),
      token,
      refresh_token: refreshToken,
      expires_in: this.getTokenExpirySeconds(),
    };
  }

  /**
   * Get user by ID
   */
  async getUserById(id: string, includePassword = false): Promise<User | null> {
    const fields = includePassword 
      ? '*'
      : `id, email, username, first_name, last_name, avatar_url, phone,
         date_of_birth, timezone, locale, status, email_verified, 
         email_verified_at, phone_verified, phone_verified_at, mfa_enabled,
         last_login_at, last_login_ip, login_attempts, locked_until,
         password_changed_at, tenant_id, metadata, created_at, updated_at`;

    const query = `SELECT ${fields} FROM users WHERE id = $1`;
    const result = await DatabaseManager.query(query, [id]);
    
    return result.rows[0] || null;
  }

  /**
   * Get user by email
   */
  async getUserByEmail(email: string, includePassword = false): Promise<User | null> {
    const fields = includePassword 
      ? '*'
      : `id, email, username, first_name, last_name, avatar_url, phone,
         date_of_birth, timezone, locale, status, email_verified, 
         email_verified_at, phone_verified, phone_verified_at, mfa_enabled,
         last_login_at, last_login_ip, login_attempts, locked_until,
         password_changed_at, tenant_id, metadata, created_at, updated_at`;

    const query = `SELECT ${fields} FROM users WHERE email = $1`;
    const result = await DatabaseManager.query(query, [email.toLowerCase()]);
    
    return result.rows[0] || null;
  }

  /**
   * Update user profile
   */
  async updateProfile(userId: string, data: UpdateProfileRequest): Promise<User> {
    const updateFields: string[] = [];
    const params: any[] = [];
    let paramIndex = 1;

    if (data.first_name !== undefined) {
      updateFields.push(`first_name = $${paramIndex++}`);
      params.push(data.first_name);
    }

    if (data.last_name !== undefined) {
      updateFields.push(`last_name = $${paramIndex++}`);
      params.push(data.last_name);
    }

    if (data.username !== undefined) {
      updateFields.push(`username = $${paramIndex++}`);
      params.push(data.username);
    }

    if (data.phone !== undefined) {
      updateFields.push(`phone = $${paramIndex++}`);
      params.push(data.phone);
    }

    if (data.date_of_birth !== undefined) {
      updateFields.push(`date_of_birth = $${paramIndex++}`);
      params.push(data.date_of_birth);
    }

    if (data.timezone !== undefined) {
      updateFields.push(`timezone = $${paramIndex++}`);
      params.push(data.timezone);
    }

    if (data.locale !== undefined) {
      updateFields.push(`locale = $${paramIndex++}`);
      params.push(data.locale);
    }

    if (data.avatar_url !== undefined) {
      updateFields.push(`avatar_url = $${paramIndex++}`);
      params.push(data.avatar_url);
    }

    if (data.metadata !== undefined) {
      updateFields.push(`metadata = $${paramIndex++}`);
      params.push(JSON.stringify(data.metadata));
    }

    updateFields.push(`updated_at = NOW()`);
    params.push(userId);

    const query = `
      UPDATE users 
      SET ${updateFields.join(', ')}
      WHERE id = $${paramIndex}
      RETURNING 
        id, email, username, first_name, last_name, avatar_url, phone,
        date_of_birth, timezone, locale, status, email_verified, 
        email_verified_at, phone_verified, phone_verified_at, mfa_enabled,
        last_login_at, last_login_ip, login_attempts, locked_until,
        password_changed_at, tenant_id, metadata, created_at, updated_at
    `;

    const result = await DatabaseManager.query(query, params);
    const user = result.rows[0];

    if (!user) {
      throw new Error('User not found');
    }

    logAudit('profile_updated', userId, {
      updatedFields: Object.keys(data),
    });

    return user;
  }

  /**
   * Change user password
   */
  async changePassword(userId: string, data: ChangePasswordRequest): Promise<void> {
    // Get current user
    const user = await this.getUserById(userId, true);
    if (!user) {
      throw new Error('User not found');
    }

    // Verify current password
    const isCurrentPasswordValid = await bcrypt.compare(data.current_password, user.password_hash);
    if (!isCurrentPasswordValid) {
      logSecurity('Invalid current password in change password attempt', {
        userId,
      });
      throw new Error('Current password is incorrect');
    }

    // Validate new password
    this.validatePassword(data.new_password);

    // Check password history if enabled
    if (config.features.enablePasswordHistory) {
      const isPasswordReused = await this.checkPasswordHistory(userId, data.new_password);
      if (isPasswordReused) {
        throw new Error('Cannot reuse a recent password');
      }
    }

    // Hash new password
    const newPasswordHash = await bcrypt.hash(data.new_password, config.auth.bcryptRounds);

    // Update password
    await DatabaseManager.transaction(async (client) => {
      // Update user password
      await DatabaseManager.query(
        `UPDATE users 
         SET password_hash = $1, password_changed_at = NOW(), updated_at = NOW()
         WHERE id = $2`,
        [newPasswordHash, userId],
        client
      );

      // Add to password history if enabled
      if (config.features.enablePasswordHistory) {
        await DatabaseManager.query(
          `INSERT INTO password_history (user_id, password_hash)
           VALUES ($1, $2)`,
          [userId, user.password_hash],
          client
        );
      }

      // Invalidate all existing sessions except current one
      await DatabaseManager.query(
        `UPDATE sessions 
         SET expires_at = NOW()
         WHERE user_id = $1`,
        [userId],
        client
      );
    });

    logAudit('password_changed', userId);
    logSecurity('Password changed', { userId });
  }

  /**
   * Validate password strength
   */
  private validatePassword(password: string): void {
    const policy = config.passwordPolicy;

    if (password.length < policy.minLength) {
      throw new Error(`Password must be at least ${policy.minLength} characters long`);
    }

    if (policy.requireUppercase && !/[A-Z]/.test(password)) {
      throw new Error('Password must contain at least one uppercase letter');
    }

    if (policy.requireLowercase && !/[a-z]/.test(password)) {
      throw new Error('Password must contain at least one lowercase letter');
    }

    if (policy.requireNumbers && !/\d/.test(password)) {
      throw new Error('Password must contain at least one number');
    }

    if (policy.requireSpecialChars && !/[!@#$%^&*(),.?":{}|<>]/.test(password)) {
      throw new Error('Password must contain at least one special character');
    }
  }

  /**
   * Generate JWT tokens
   */
  private async generateTokens(user: User): Promise<{ token: string; refreshToken: string }> {
    // Get user roles and permissions
    const { roles, permissions } = await this.getUserRolesAndPermissions(user.id);

    const payload = {
      id: user.id,
      email: user.email,
      tenantId: user.tenant_id,
      roles,
      permissions,
    };

    const token = jwt.sign(payload, config.auth.jwtSecret, {
      expiresIn: config.auth.jwtExpiresIn,
      issuer: 'allixios-user-service',
      audience: 'allixios-services',
    });

    const refreshToken = jwt.sign(
      { id: user.id, type: 'refresh' },
      config.auth.jwtSecret,
      {
        expiresIn: config.auth.refreshTokenExpiresIn,
        issuer: 'allixios-user-service',
        audience: 'allixios-services',
      }
    );

    return { token, refreshToken };
  }

  /**
   * Get user roles and permissions
   */
  private async getUserRolesAndPermissions(userId: string): Promise<{
    roles: string[];
    permissions: string[];
  }> {
    const query = `
      SELECT DISTINCT r.name as role_name, r.permissions
      FROM user_roles ur
      JOIN roles r ON ur.role_id = r.id
      WHERE ur.user_id = $1 
      AND (ur.expires_at IS NULL OR ur.expires_at > NOW())
    `;

    const result = await DatabaseManager.query(query, [userId]);
    
    const roles = result.rows.map(row => row.role_name);
    const permissions = [...new Set(
      result.rows.flatMap(row => row.permissions || [])
    )];

    return { roles, permissions };
  }

  /**
   * Handle failed login attempt
   */
  private async handleFailedLogin(userId: string, email: string, ipAddress: string, userAgent?: string): Promise<void> {
    // Increment login attempts
    const query = `
      UPDATE users 
      SET login_attempts = login_attempts + 1,
          locked_until = CASE 
            WHEN login_attempts + 1 >= $1 THEN NOW() + INTERVAL '${config.auth.lockoutDuration} milliseconds'
            ELSE locked_until
          END,
          updated_at = NOW()
      WHERE id = $2
      RETURNING login_attempts, locked_until
    `;

    const result = await DatabaseManager.query(query, [config.auth.maxLoginAttempts, userId]);
    const user = result.rows[0];

    // Record failed login attempt
    await this.recordLoginAttempt(email, ipAddress, userAgent, false, 'Invalid credentials');

    logSecurity('Failed login attempt', {
      userId,
      email,
      ipAddress,
      attempts: user.login_attempts,
      locked: !!user.locked_until,
    });

    if (user.locked_until) {
      logSecurity('Account locked due to too many failed attempts', {
        userId,
        email,
        lockedUntil: user.locked_until,
      });
    }
  }

  /**
   * Reset login attempts
   */
  private async resetLoginAttempts(userId: string): Promise<void> {
    await DatabaseManager.query(
      `UPDATE users 
       SET login_attempts = 0, locked_until = NULL, updated_at = NOW()
       WHERE id = $1`,
      [userId]
    );
  }

  /**
   * Update last login information
   */
  private async updateLastLogin(userId: string, ipAddress: string): Promise<void> {
    await DatabaseManager.query(
      `UPDATE users 
       SET last_login_at = NOW(), last_login_ip = $1, updated_at = NOW()
       WHERE id = $2`,
      [ipAddress, userId]
    );
  }

  /**
   * Record login attempt
   */
  private async recordLoginAttempt(
    email: string, 
    ipAddress: string, 
    userAgent?: string, 
    success = false, 
    failureReason?: string
  ): Promise<void> {
    await DatabaseManager.query(
      `INSERT INTO login_attempts (email, ip_address, user_agent, success, failure_reason)
       VALUES ($1, $2, $3, $4, $5)`,
      [email, ipAddress, userAgent, success, failureReason]
    );
  }

  /**
   * Create user session
   */
  private async createSession(
    userId: string, 
    token: string, 
    refreshToken: string, 
    ipAddress: string, 
    userAgent?: string
  ): Promise<void> {
    const sessionId = uuidv4();
    const tokenHash = await bcrypt.hash(token, 10);
    const refreshTokenHash = await bcrypt.hash(refreshToken, 10);
    
    const expiresAt = new Date();
    expiresAt.setTime(expiresAt.getTime() + this.getTokenExpirySeconds() * 1000);

    await DatabaseManager.query(
      `INSERT INTO sessions (id, user_id, token_hash, refresh_token_hash, device_info, ip_address, user_agent, last_activity, expires_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7, NOW(), $8)`,
      [sessionId, userId, tokenHash, refreshTokenHash, userAgent, ipAddress, userAgent, expiresAt]
    );

    // Clean up old sessions if user has too many
    await this.cleanupOldSessions(userId);
  }

  /**
   * Clean up old sessions
   */
  private async cleanupOldSessions(userId: string): Promise<void> {
    const maxSessions = config.account.maxSessions;
    
    await DatabaseManager.query(
      `DELETE FROM sessions 
       WHERE user_id = $1 
       AND id NOT IN (
         SELECT id FROM sessions 
         WHERE user_id = $1 
         ORDER BY last_activity DESC 
         LIMIT $2
       )`,
      [userId, maxSessions]
    );
  }

  /**
   * Send email verification
   */
  private async sendEmailVerification(userId: string): Promise<void> {
    // Implementation would integrate with notification service
    logger.info('Email verification sent', { userId });
  }

  /**
   * Verify MFA code
   */
  private async verifyMFACode(userId: string, code: string): Promise<boolean> {
    // Implementation would use speakeasy or similar library
    // This is a placeholder
    return true;
  }

  /**
   * Check password history
   */
  private async checkPasswordHistory(userId: string, newPassword: string): Promise<boolean> {
    const query = `
      SELECT password_hash 
      FROM password_history 
      WHERE user_id = $1 
      ORDER BY created_at DESC 
      LIMIT 5
    `;

    const result = await DatabaseManager.query(query, [userId]);
    
    for (const row of result.rows) {
      const isMatch = await bcrypt.compare(newPassword, row.password_hash);
      if (isMatch) {
        return true;
      }
    }

    return false;
  }

  /**
   * Get token expiry in seconds
   */
  private getTokenExpirySeconds(): number {
    const expiresIn = config.auth.jwtExpiresIn;
    
    if (expiresIn.endsWith('h')) {
      return parseInt(expiresIn) * 3600;
    } else if (expiresIn.endsWith('d')) {
      return parseInt(expiresIn) * 86400;
    } else if (expiresIn.endsWith('m')) {
      return parseInt(expiresIn) * 60;
    }
    
    return parseInt(expiresIn);
  }

  /**
   * Sanitize user object (remove sensitive fields)
   */
  private sanitizeUser(user: User): Omit<User, 'password_hash' | 'mfa_secret'> {
    const { password_hash, mfa_secret, ...sanitized } = user;
    return sanitized;
  }
}