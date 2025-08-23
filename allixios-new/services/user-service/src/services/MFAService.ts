/**
 * Multi-Factor Authentication Service
 * TOTP-based MFA implementation
 */

import speakeasy from 'speakeasy';
import QRCode from 'qrcode';
import { DatabaseManager } from '../database/DatabaseManager';
import { config } from '../config';
import { logger, logAudit, logSecurity } from '../utils/logger';
import { EnableMFAResponse } from '../types';

export class MFAService {
  
  /**
   * Generate MFA secret and QR code for user
   */
  async setupMFA(userId: string, userEmail: string): Promise<EnableMFAResponse> {
    // Generate secret
    const secret = speakeasy.generateSecret({
      name: userEmail,
      issuer: config.mfa.issuer,
      length: 32,
    });

    // Generate QR code
    const qrCodeUrl = speakeasy.otpauthURL({
      secret: secret.ascii,
      label: userEmail,
      issuer: config.mfa.issuer,
      encoding: 'ascii',
    });

    const qrCode = await QRCode.toDataURL(qrCodeUrl, {
      width: config.mfa.qrCodeSize,
      margin: 2,
    });

    // Generate backup codes
    const backupCodes = this.generateBackupCodes();

    // Store secret temporarily (not enabled until verified)
    await DatabaseManager.query(
      `UPDATE users 
       SET mfa_secret = $1, updated_at = NOW()
       WHERE id = $2`,
      [secret.base32, userId]
    );

    // Store backup codes
    await this.storeBackupCodes(userId, backupCodes);

    logAudit('mfa_setup_initiated', userId, {
      email: userEmail,
    });

    return {
      secret: secret.base32,
      qr_code: qrCode,
      backup_codes: backupCodes,
    };
  }

  /**
   * Verify MFA setup and enable MFA for user
   */
  async verifyAndEnableMFA(userId: string, code: string): Promise<boolean> {
    // Get user's MFA secret
    const userQuery = await DatabaseManager.query(
      `SELECT mfa_secret, email FROM users WHERE id = $1`,
      [userId]
    );

    const user = userQuery.rows[0];
    if (!user || !user.mfa_secret) {
      throw new Error('MFA setup not found');
    }

    // Verify the code
    const isValid = speakeasy.totp.verify({
      secret: user.mfa_secret,
      encoding: 'base32',
      token: code,
      window: config.mfa.window,
    });

    if (!isValid) {
      logSecurity('Invalid MFA verification code during setup', {
        userId,
        email: user.email,
      });
      return false;
    }

    // Enable MFA for user
    await DatabaseManager.query(
      `UPDATE users 
       SET mfa_enabled = true, updated_at = NOW()
       WHERE id = $1`,
      [userId]
    );

    logAudit('mfa_enabled', userId, {
      email: user.email,
    });

    logger.info('MFA enabled for user', {
      userId,
      email: user.email,
    });

    return true;
  }

  /**
   * Verify MFA code for login
   */
  async verifyMFACode(userId: string, code: string): Promise<boolean> {
    // Get user's MFA secret
    const userQuery = await DatabaseManager.query(
      `SELECT mfa_secret, mfa_enabled, email FROM users WHERE id = $1`,
      [userId]
    );

    const user = userQuery.rows[0];
    if (!user || !user.mfa_enabled || !user.mfa_secret) {
      return false;
    }

    // Check if it's a backup code first
    const isBackupCode = await this.verifyBackupCode(userId, code);
    if (isBackupCode) {
      return true;
    }

    // Verify TOTP code
    const isValid = speakeasy.totp.verify({
      secret: user.mfa_secret,
      encoding: 'base32',
      token: code,
      window: config.mfa.window,
    });

    if (isValid) {
      logAudit('mfa_code_verified', userId, {
        email: user.email,
      });
    } else {
      logSecurity('Invalid MFA code during login', {
        userId,
        email: user.email,
      });
    }

    return isValid;
  }

  /**
   * Disable MFA for user
   */
  async disableMFA(userId: string): Promise<void> {
    await DatabaseManager.transaction(async (client) => {
      // Disable MFA and clear secret
      await DatabaseManager.query(
        `UPDATE users 
         SET mfa_enabled = false, mfa_secret = NULL, updated_at = NOW()
         WHERE id = $1`,
        [userId],
        client
      );

      // Remove backup codes
      await DatabaseManager.query(
        `DELETE FROM mfa_backup_codes WHERE user_id = $1`,
        [userId],
        client
      );
    });

    logAudit('mfa_disabled', userId);
    logger.info('MFA disabled for user', { userId });
  }

  /**
   * Generate new backup codes
   */
  async regenerateBackupCodes(userId: string): Promise<string[]> {
    const backupCodes = this.generateBackupCodes();

    await DatabaseManager.transaction(async (client) => {
      // Remove old backup codes
      await DatabaseManager.query(
        `DELETE FROM mfa_backup_codes WHERE user_id = $1`,
        [userId],
        client
      );

      // Store new backup codes
      await this.storeBackupCodes(userId, backupCodes, client);
    });

    logAudit('mfa_backup_codes_regenerated', userId);

    return backupCodes;
  }

  /**
   * Get MFA status for user
   */
  async getMFAStatus(userId: string): Promise<{
    enabled: boolean;
    hasBackupCodes: boolean;
    backupCodesCount: number;
  }> {
    const userQuery = await DatabaseManager.query(
      `SELECT mfa_enabled FROM users WHERE id = $1`,
      [userId]
    );

    const backupCodesQuery = await DatabaseManager.query(
      `SELECT COUNT(*) as count FROM mfa_backup_codes WHERE user_id = $1 AND used_at IS NULL`,
      [userId]
    );

    const user = userQuery.rows[0];
    const backupCodesCount = parseInt(backupCodesQuery.rows[0]?.count || '0');

    return {
      enabled: user?.mfa_enabled || false,
      hasBackupCodes: backupCodesCount > 0,
      backupCodesCount,
    };
  }

  /**
   * Generate backup codes
   */
  private generateBackupCodes(count = 10): string[] {
    const codes: string[] = [];
    
    for (let i = 0; i < count; i++) {
      // Generate 8-character alphanumeric code
      const code = Math.random().toString(36).substring(2, 10).toUpperCase();
      codes.push(code);
    }

    return codes;
  }

  /**
   * Store backup codes in database
   */
  private async storeBackupCodes(userId: string, codes: string[], client?: any): Promise<void> {
    const bcrypt = require('bcrypt');
    
    for (const code of codes) {
      const hashedCode = await bcrypt.hash(code, 10);
      
      await DatabaseManager.query(
        `INSERT INTO mfa_backup_codes (user_id, code_hash)
         VALUES ($1, $2)`,
        [userId, hashedCode],
        client
      );
    }
  }

  /**
   * Verify backup code
   */
  private async verifyBackupCode(userId: string, code: string): Promise<boolean> {
    const bcrypt = require('bcrypt');
    
    // Get unused backup codes
    const codesQuery = await DatabaseManager.query(
      `SELECT id, code_hash FROM mfa_backup_codes 
       WHERE user_id = $1 AND used_at IS NULL`,
      [userId]
    );

    for (const row of codesQuery.rows) {
      const isMatch = await bcrypt.compare(code, row.code_hash);
      
      if (isMatch) {
        // Mark backup code as used
        await DatabaseManager.query(
          `UPDATE mfa_backup_codes 
           SET used_at = NOW()
           WHERE id = $1`,
          [row.id]
        );

        logAudit('mfa_backup_code_used', userId, {
          backupCodeId: row.id,
        });

        return true;
      }
    }

    return false;
  }
}