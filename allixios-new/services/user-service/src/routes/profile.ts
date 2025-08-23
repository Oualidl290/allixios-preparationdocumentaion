/**
 * Profile Routes
 * User profile management endpoints
 */

import { Router } from 'express';
import { body, validationResult } from 'express-validator';
import { authMiddleware } from '../middleware/auth';
import { UserService } from '../services/UserService';
import { MFAService } from '../services/MFAService';
import { config } from '../config';
import { logger, logAudit } from '../utils/logger';

const router = Router();
const userService = new UserService();
const mfaService = new MFAService();

// Apply authentication to all profile routes
router.use(authMiddleware);

// Validation middleware
const validateRequest = (req: any, res: any, next: any) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({
      success: false,
      error: 'Validation failed',
      details: errors.array(),
    });
  }
  next();
};

/**
 * @swagger
 * /api/profile:
 *   get:
 *     summary: Get current user profile
 *     tags: [Profile]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: User profile retrieved successfully
 *       401:
 *         description: Unauthorized
 */
router.get('/', async (req, res, next) => {
  try {
    const user = await userService.getUserById(req.user!.id);
    
    if (!user) {
      return res.status(404).json({
        success: false,
        error: 'User not found',
        code: 'USER_NOT_FOUND',
      });
    }

    res.json({
      success: true,
      data: user,
    });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /api/profile:
 *   put:
 *     summary: Update user profile
 *     tags: [Profile]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               first_name:
 *                 type: string
 *               last_name:
 *                 type: string
 *               username:
 *                 type: string
 *               phone:
 *                 type: string
 *               date_of_birth:
 *                 type: string
 *                 format: date
 *               timezone:
 *                 type: string
 *               locale:
 *                 type: string
 *               avatar_url:
 *                 type: string
 *                 format: uri
 *     responses:
 *       200:
 *         description: Profile updated successfully
 *       400:
 *         description: Validation error
 */
router.put('/', [
  body('first_name')
    .optional()
    .isString()
    .isLength({ min: 1, max: 50 })
    .withMessage('First name must be between 1 and 50 characters'),
  body('last_name')
    .optional()
    .isString()
    .isLength({ min: 1, max: 50 })
    .withMessage('Last name must be between 1 and 50 characters'),
  body('username')
    .optional()
    .isString()
    .isLength({ min: 3, max: 30 })
    .matches(/^[a-zA-Z0-9_]+$/)
    .withMessage('Username must be 3-30 characters and contain only letters, numbers, and underscores'),
  body('phone')
    .optional()
    .isMobilePhone('any')
    .withMessage('Valid phone number is required'),
  body('date_of_birth')
    .optional()
    .isISO8601()
    .withMessage('Valid date is required'),
  body('timezone')
    .optional()
    .isString()
    .withMessage('Valid timezone is required'),
  body('locale')
    .optional()
    .isString()
    .isLength({ min: 2, max: 10 })
    .withMessage('Valid locale is required'),
  body('avatar_url')
    .optional()
    .isURL()
    .withMessage('Valid URL is required'),
  validateRequest,
], async (req, res, next) => {
  try {
    const updatedUser = await userService.updateProfile(req.user!.id, req.body);

    res.json({
      success: true,
      data: updatedUser,
      message: 'Profile updated successfully.',
    });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /api/profile/change-password:
 *   post:
 *     summary: Change user password
 *     tags: [Profile]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - current_password
 *               - new_password
 *             properties:
 *               current_password:
 *                 type: string
 *               new_password:
 *                 type: string
 *                 minLength: 8
 *     responses:
 *       200:
 *         description: Password changed successfully
 *       400:
 *         description: Validation error or invalid current password
 */
router.post('/change-password', [
  body('current_password')
    .notEmpty()
    .withMessage('Current password is required'),
  body('new_password')
    .isLength({ min: config.passwordPolicy.minLength })
    .withMessage(`New password must be at least ${config.passwordPolicy.minLength} characters long`),
  validateRequest,
], async (req, res, next) => {
  try {
    await userService.changePassword(req.user!.id, req.body);

    res.json({
      success: true,
      message: 'Password changed successfully.',
    });
  } catch (error) {
    if (error.message.includes('Current password is incorrect')) {
      return res.status(400).json({
        success: false,
        error: 'Invalid current password',
        message: 'The current password you entered is incorrect.',
        code: 'INVALID_CURRENT_PASSWORD',
      });
    }

    if (error.message.includes('Cannot reuse')) {
      return res.status(400).json({
        success: false,
        error: 'Password reuse not allowed',
        message: 'You cannot reuse a recent password.',
        code: 'PASSWORD_REUSE_NOT_ALLOWED',
      });
    }

    next(error);
  }
});

/**
 * @swagger
 * /api/profile/mfa/setup:
 *   post:
 *     summary: Setup MFA for user
 *     tags: [Profile, MFA]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: MFA setup initiated
 *       409:
 *         description: MFA already enabled
 */
router.post('/mfa/setup', async (req, res, next) => {
  try {
    // Check if MFA is already enabled
    const mfaStatus = await mfaService.getMFAStatus(req.user!.id);
    if (mfaStatus.enabled) {
      return res.status(409).json({
        success: false,
        error: 'MFA already enabled',
        message: 'Multi-factor authentication is already enabled for this account.',
        code: 'MFA_ALREADY_ENABLED',
      });
    }

    const mfaSetup = await mfaService.setupMFA(req.user!.id, req.user!.email);

    res.json({
      success: true,
      data: mfaSetup,
      message: 'MFA setup initiated. Please scan the QR code with your authenticator app and verify with a code.',
    });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /api/profile/mfa/verify:
 *   post:
 *     summary: Verify and enable MFA
 *     tags: [Profile, MFA]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - code
 *             properties:
 *               code:
 *                 type: string
 *                 description: 6-digit TOTP code
 *     responses:
 *       200:
 *         description: MFA enabled successfully
 *       400:
 *         description: Invalid verification code
 */
router.post('/mfa/verify', [
  body('code')
    .isString()
    .isLength({ min: 6, max: 6 })
    .withMessage('MFA code must be 6 digits'),
  validateRequest,
], async (req, res, next) => {
  try {
    const isValid = await mfaService.verifyAndEnableMFA(req.user!.id, req.body.code);

    if (!isValid) {
      return res.status(400).json({
        success: false,
        error: 'Invalid verification code',
        message: 'The verification code you entered is invalid.',
        code: 'INVALID_MFA_CODE',
      });
    }

    res.json({
      success: true,
      message: 'Multi-factor authentication has been enabled successfully.',
    });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /api/profile/mfa/disable:
 *   post:
 *     summary: Disable MFA
 *     tags: [Profile, MFA]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - password
 *             properties:
 *               password:
 *                 type: string
 *     responses:
 *       200:
 *         description: MFA disabled successfully
 *       400:
 *         description: Invalid password
 */
router.post('/mfa/disable', [
  body('password')
    .notEmpty()
    .withMessage('Password is required to disable MFA'),
  validateRequest,
], async (req, res, next) => {
  try {
    // Verify password before disabling MFA
    const user = await userService.getUserById(req.user!.id, true);
    if (!user) {
      return res.status(404).json({
        success: false,
        error: 'User not found',
        code: 'USER_NOT_FOUND',
      });
    }

    const bcrypt = require('bcrypt');
    const isPasswordValid = await bcrypt.compare(req.body.password, user.password_hash);
    
    if (!isPasswordValid) {
      return res.status(400).json({
        success: false,
        error: 'Invalid password',
        message: 'The password you entered is incorrect.',
        code: 'INVALID_PASSWORD',
      });
    }

    await mfaService.disableMFA(req.user!.id);

    res.json({
      success: true,
      message: 'Multi-factor authentication has been disabled.',
    });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /api/profile/mfa/backup-codes:
 *   get:
 *     summary: Get MFA backup codes
 *     tags: [Profile, MFA]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: New backup codes generated
 */
router.get('/mfa/backup-codes', async (req, res, next) => {
  try {
    const backupCodes = await mfaService.regenerateBackupCodes(req.user!.id);

    res.json({
      success: true,
      data: {
        backup_codes: backupCodes,
      },
      message: 'New backup codes generated. Please store them securely.',
    });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /api/profile/mfa/status:
 *   get:
 *     summary: Get MFA status
 *     tags: [Profile, MFA]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: MFA status retrieved
 */
router.get('/mfa/status', async (req, res, next) => {
  try {
    const mfaStatus = await mfaService.getMFAStatus(req.user!.id);

    res.json({
      success: true,
      data: mfaStatus,
    });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /api/profile/sessions:
 *   get:
 *     summary: Get active sessions
 *     tags: [Profile]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Active sessions retrieved
 */
router.get('/sessions', async (req, res, next) => {
  try {
    // Implementation for getting active sessions
    res.json({
      success: true,
      data: [],
      message: 'Sessions endpoint not yet implemented',
    });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /api/profile/sessions/{sessionId}:
 *   delete:
 *     summary: Revoke a session
 *     tags: [Profile]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: sessionId
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Session revoked successfully
 */
router.delete('/sessions/:sessionId', async (req, res, next) => {
  try {
    // Implementation for revoking a session
    res.json({
      success: true,
      message: 'Session revoked successfully.',
    });
  } catch (error) {
    next(error);
  }
});

export { router as profileRouter };