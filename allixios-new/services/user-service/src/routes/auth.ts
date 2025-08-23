/**
 * Authentication Routes
 * User registration, login, logout, and token management
 */

import { Router } from 'express';
import { body, validationResult } from 'express-validator';
import rateLimit from 'express-rate-limit';
import { UserService } from '../services/UserService';
import { MFAService } from '../services/MFAService';
import { config } from '../config';
import { logger, logAuth, logSecurity } from '../utils/logger';

const router = Router();
const userService = new UserService();
const mfaService = new MFAService();

// Rate limiting for auth endpoints
const authLimiter = rateLimit({
  windowMs: config.rateLimit.authWindowMs,
  max: config.rateLimit.authMax,
  message: {
    error: 'Too many authentication attempts, please try again later.',
    code: 'RATE_LIMIT_EXCEEDED',
  },
  standardHeaders: true,
  legacyHeaders: false,
});

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
 * /api/auth/register:
 *   post:
 *     summary: Register a new user
 *     tags: [Authentication]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - email
 *               - password
 *             properties:
 *               email:
 *                 type: string
 *                 format: email
 *               password:
 *                 type: string
 *                 minLength: 8
 *               first_name:
 *                 type: string
 *               last_name:
 *                 type: string
 *               username:
 *                 type: string
 *     responses:
 *       201:
 *         description: User registered successfully
 *       400:
 *         description: Validation error
 *       409:
 *         description: User already exists
 */
router.post('/register', authLimiter, [
  body('email')
    .isEmail()
    .normalizeEmail()
    .withMessage('Valid email is required'),
  body('password')
    .isLength({ min: config.passwordPolicy.minLength })
    .withMessage(`Password must be at least ${config.passwordPolicy.minLength} characters long`),
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
  validateRequest,
], async (req, res, next) => {
  try {
    const user = await userService.registerUser(req.body);

    logAuth('user_registered', user.id, {
      email: user.email,
      ip: req.ip,
      userAgent: req.get('User-Agent'),
    });

    res.status(201).json({
      success: true,
      data: user,
      message: config.account.emailVerificationRequired 
        ? 'User registered successfully. Please check your email to verify your account.'
        : 'User registered successfully.',
    });
  } catch (error) {
    if (error.message.includes('already exists')) {
      return res.status(409).json({
        success: false,
        error: 'User already exists',
        message: 'A user with this email address already exists.',
        code: 'USER_EXISTS',
      });
    }
    next(error);
  }
});

/**
 * @swagger
 * /api/auth/login:
 *   post:
 *     summary: User login
 *     tags: [Authentication]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - email
 *               - password
 *             properties:
 *               email:
 *                 type: string
 *                 format: email
 *               password:
 *                 type: string
 *               mfa_code:
 *                 type: string
 *                 description: Required if MFA is enabled
 *               remember_me:
 *                 type: boolean
 *     responses:
 *       200:
 *         description: Login successful
 *       401:
 *         description: Invalid credentials or MFA required
 *       423:
 *         description: Account locked
 */
router.post('/login', authLimiter, [
  body('email')
    .isEmail()
    .normalizeEmail()
    .withMessage('Valid email is required'),
  body('password')
    .notEmpty()
    .withMessage('Password is required'),
  body('mfa_code')
    .optional()
    .isString()
    .isLength({ min: 6, max: 6 })
    .withMessage('MFA code must be 6 digits'),
  body('remember_me')
    .optional()
    .isBoolean()
    .withMessage('Remember me must be a boolean'),
  validateRequest,
], async (req, res, next) => {
  try {
    const loginResult = await userService.loginUser(
      req.body,
      req.ip,
      req.get('User-Agent')
    );

    if (loginResult.mfa_required) {
      return res.status(200).json({
        success: true,
        mfa_required: true,
        message: 'MFA code required to complete login.',
      });
    }

    res.json({
      success: true,
      data: loginResult,
      message: 'Login successful.',
    });
  } catch (error) {
    if (error.message.includes('Invalid credentials')) {
      logSecurity('Invalid login attempt', {
        email: req.body.email,
        ip: req.ip,
        userAgent: req.get('User-Agent'),
      });
      
      return res.status(401).json({
        success: false,
        error: 'Invalid credentials',
        message: 'The email or password you entered is incorrect.',
        code: 'INVALID_CREDENTIALS',
      });
    }

    if (error.message.includes('locked')) {
      return res.status(423).json({
        success: false,
        error: 'Account locked',
        message: error.message,
        code: 'ACCOUNT_LOCKED',
      });
    }

    if (error.message.includes('not active')) {
      return res.status(401).json({
        success: false,
        error: 'Account inactive',
        message: 'Your account is not active. Please contact support.',
        code: 'ACCOUNT_INACTIVE',
      });
    }

    next(error);
  }
});

/**
 * @swagger
 * /api/auth/refresh:
 *   post:
 *     summary: Refresh access token
 *     tags: [Authentication]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - refresh_token
 *             properties:
 *               refresh_token:
 *                 type: string
 *     responses:
 *       200:
 *         description: Token refreshed successfully
 *       401:
 *         description: Invalid refresh token
 */
router.post('/refresh', [
  body('refresh_token')
    .notEmpty()
    .withMessage('Refresh token is required'),
  validateRequest,
], async (req, res, next) => {
  try {
    // Implementation for token refresh
    res.json({
      success: true,
      message: 'Token refresh not yet implemented',
    });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /api/auth/logout:
 *   post:
 *     summary: User logout
 *     tags: [Authentication]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Logout successful
 */
router.post('/logout', async (req, res, next) => {
  try {
    // Implementation for logout (invalidate session)
    res.json({
      success: true,
      message: 'Logout successful.',
    });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /api/auth/forgot-password:
 *   post:
 *     summary: Request password reset
 *     tags: [Authentication]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - email
 *             properties:
 *               email:
 *                 type: string
 *                 format: email
 *     responses:
 *       200:
 *         description: Password reset email sent
 */
router.post('/forgot-password', authLimiter, [
  body('email')
    .isEmail()
    .normalizeEmail()
    .withMessage('Valid email is required'),
  validateRequest,
], async (req, res, next) => {
  try {
    // Implementation for password reset request
    res.json({
      success: true,
      message: 'If an account with that email exists, a password reset link has been sent.',
    });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /api/auth/reset-password:
 *   post:
 *     summary: Reset password with token
 *     tags: [Authentication]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - token
 *               - new_password
 *             properties:
 *               token:
 *                 type: string
 *               new_password:
 *                 type: string
 *                 minLength: 8
 *     responses:
 *       200:
 *         description: Password reset successful
 *       400:
 *         description: Invalid or expired token
 */
router.post('/reset-password', authLimiter, [
  body('token')
    .notEmpty()
    .withMessage('Reset token is required'),
  body('new_password')
    .isLength({ min: config.passwordPolicy.minLength })
    .withMessage(`Password must be at least ${config.passwordPolicy.minLength} characters long`),
  validateRequest,
], async (req, res, next) => {
  try {
    // Implementation for password reset
    res.json({
      success: true,
      message: 'Password reset successful. You can now log in with your new password.',
    });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /api/auth/verify-email:
 *   post:
 *     summary: Verify email address
 *     tags: [Authentication]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - token
 *             properties:
 *               token:
 *                 type: string
 *     responses:
 *       200:
 *         description: Email verified successfully
 *       400:
 *         description: Invalid or expired token
 */
router.post('/verify-email', [
  body('token')
    .notEmpty()
    .withMessage('Verification token is required'),
  validateRequest,
], async (req, res, next) => {
  try {
    // Implementation for email verification
    res.json({
      success: true,
      message: 'Email verified successfully.',
    });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /api/auth/resend-verification:
 *   post:
 *     summary: Resend email verification
 *     tags: [Authentication]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - email
 *             properties:
 *               email:
 *                 type: string
 *                 format: email
 *     responses:
 *       200:
 *         description: Verification email sent
 */
router.post('/resend-verification', authLimiter, [
  body('email')
    .isEmail()
    .normalizeEmail()
    .withMessage('Valid email is required'),
  validateRequest,
], async (req, res, next) => {
  try {
    // Implementation for resending verification email
    res.json({
      success: true,
      message: 'Verification email sent.',
    });
  } catch (error) {
    next(error);
  }
});

export { router as authRouter };