/**
 * Users Routes
 * User management endpoints (admin functions)
 */

import { Router } from 'express';
import { body, param, query, validationResult } from 'express-validator';
import { authMiddleware, requirePermission, requireRole } from '../middleware/auth';
import { UserService } from '../services/UserService';
import { DatabaseManager } from '../database/DatabaseManager';
import { logger, logAudit } from '../utils/logger';

const router = Router();
const userService = new UserService();

// Apply authentication to all user routes
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
 * /api/users:
 *   get:
 *     summary: Get users list (admin only)
 *     tags: [Users]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: page
 *         schema:
 *           type: integer
 *           minimum: 1
 *           default: 1
 *       - in: query
 *         name: limit
 *         schema:
 *           type: integer
 *           minimum: 1
 *           maximum: 100
 *           default: 20
 *       - in: query
 *         name: search
 *         schema:
 *           type: string
 *       - in: query
 *         name: status
 *         schema:
 *           type: string
 *           enum: [active, inactive, suspended, pending_verification]
 *       - in: query
 *         name: sort
 *         schema:
 *           type: string
 *           enum: [created_at, updated_at, last_login_at, email]
 *           default: created_at
 *       - in: query
 *         name: order
 *         schema:
 *           type: string
 *           enum: [asc, desc]
 *           default: desc
 *     responses:
 *       200:
 *         description: Users list retrieved successfully
 *       403:
 *         description: Insufficient permissions
 */
router.get('/', requirePermission('users:read'), [
  query('page').optional().isInt({ min: 1 }).toInt(),
  query('limit').optional().isInt({ min: 1, max: 100 }).toInt(),
  query('search').optional().isString().trim(),
  query('status').optional().isIn(['active', 'inactive', 'suspended', 'pending_verification']),
  query('sort').optional().isIn(['created_at', 'updated_at', 'last_login_at', 'email']),
  query('order').optional().isIn(['asc', 'desc']),
  validateRequest,
], async (req, res, next) => {
  try {
    const {
      page = 1,
      limit = 20,
      search,
      status,
      sort = 'created_at',
      order = 'desc'
    } = req.query;

    // Build WHERE clause
    const conditions: string[] = [];
    const params: any[] = [];
    let paramIndex = 1;

    // Add tenant filter if user is not admin
    if (!req.user!.roles.includes('admin') && req.user!.tenantId) {
      conditions.push(`tenant_id = $${paramIndex++}`);
      params.push(req.user!.tenantId);
    }

    if (status) {
      conditions.push(`status = $${paramIndex++}`);
      params.push(status);
    }

    if (search) {
      conditions.push(`(email ILIKE $${paramIndex} OR first_name ILIKE $${paramIndex} OR last_name ILIKE $${paramIndex})`);
      params.push(`%${search}%`);
      paramIndex++;
    }

    const whereClause = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';
    const offset = (page as number - 1) * (limit as number);

    // Get total count
    const countQuery = `SELECT COUNT(*) as total FROM users ${whereClause}`;
    const countResult = await DatabaseManager.query(countQuery, params);
    const total = parseInt(countResult.rows[0].total);

    // Get users
    const usersQuery = `
      SELECT 
        id, email, username, first_name, last_name, avatar_url, phone,
        status, email_verified, phone_verified, mfa_enabled,
        last_login_at, last_login_ip, tenant_id, created_at, updated_at
      FROM users 
      ${whereClause}
      ORDER BY ${sort} ${order.toUpperCase()}
      LIMIT $${paramIndex} OFFSET $${paramIndex + 1}
    `;
    params.push(limit, offset);

    const usersResult = await DatabaseManager.query(usersQuery, params);

    res.json({
      success: true,
      data: usersResult.rows,
      pagination: {
        page: page as number,
        limit: limit as number,
        total,
        pages: Math.ceil(total / (limit as number)),
        hasNext: (page as number) * (limit as number) < total,
        hasPrev: (page as number) > 1,
      },
    });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /api/users/{id}:
 *   get:
 *     summary: Get user by ID (admin only)
 *     tags: [Users]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *     responses:
 *       200:
 *         description: User retrieved successfully
 *       404:
 *         description: User not found
 *       403:
 *         description: Insufficient permissions
 */
router.get('/:id', requirePermission('users:read'), [
  param('id').isUUID().withMessage('Invalid user ID'),
  validateRequest,
], async (req, res, next) => {
  try {
    const { id } = req.params;
    const user = await userService.getUserById(id);

    if (!user) {
      return res.status(404).json({
        success: false,
        error: 'User not found',
        code: 'USER_NOT_FOUND',
      });
    }

    // Check tenant access if user is not admin
    if (!req.user!.roles.includes('admin') && user.tenant_id !== req.user!.tenantId) {
      return res.status(403).json({
        success: false,
        error: 'Access denied',
        message: 'You can only access users in your tenant.',
        code: 'TENANT_ACCESS_DENIED',
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
 * /api/users/{id}/status:
 *   patch:
 *     summary: Update user status (admin only)
 *     tags: [Users]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - status
 *             properties:
 *               status:
 *                 type: string
 *                 enum: [active, inactive, suspended, pending_verification]
 *               reason:
 *                 type: string
 *     responses:
 *       200:
 *         description: User status updated successfully
 *       404:
 *         description: User not found
 *       403:
 *         description: Insufficient permissions
 */
router.patch('/:id/status', requirePermission('users:update'), [
  param('id').isUUID().withMessage('Invalid user ID'),
  body('status')
    .isIn(['active', 'inactive', 'suspended', 'pending_verification'])
    .withMessage('Invalid status'),
  body('reason')
    .optional()
    .isString()
    .isLength({ min: 1, max: 500 })
    .withMessage('Reason must be between 1 and 500 characters'),
  validateRequest,
], async (req, res, next) => {
  try {
    const { id } = req.params;
    const { status, reason } = req.body;

    // Get current user
    const user = await userService.getUserById(id);
    if (!user) {
      return res.status(404).json({
        success: false,
        error: 'User not found',
        code: 'USER_NOT_FOUND',
      });
    }

    // Check tenant access if user is not admin
    if (!req.user!.roles.includes('admin') && user.tenant_id !== req.user!.tenantId) {
      return res.status(403).json({
        success: false,
        error: 'Access denied',
        message: 'You can only modify users in your tenant.',
        code: 'TENANT_ACCESS_DENIED',
      });
    }

    // Prevent self-suspension
    if (id === req.user!.id && (status === 'suspended' || status === 'inactive')) {
      return res.status(400).json({
        success: false,
        error: 'Cannot modify own status',
        message: 'You cannot suspend or deactivate your own account.',
        code: 'SELF_MODIFICATION_NOT_ALLOWED',
      });
    }

    // Update user status
    const query = `
      UPDATE users 
      SET status = $1, updated_at = NOW()
      WHERE id = $2
      RETURNING 
        id, email, username, first_name, last_name, avatar_url, phone,
        status, email_verified, phone_verified, mfa_enabled,
        last_login_at, last_login_ip, tenant_id, created_at, updated_at
    `;

    const result = await DatabaseManager.query(query, [status, id]);
    const updatedUser = result.rows[0];

    // Log the status change
    logAudit('user_status_changed', req.user!.id, {
      targetUserId: id,
      targetUserEmail: user.email,
      oldStatus: user.status,
      newStatus: status,
      reason,
    });

    res.json({
      success: true,
      data: updatedUser,
      message: `User status updated to ${status}.`,
    });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /api/users/{id}/roles:
 *   get:
 *     summary: Get user roles (admin only)
 *     tags: [Users]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *     responses:
 *       200:
 *         description: User roles retrieved successfully
 */
router.get('/:id/roles', requirePermission('users:read'), [
  param('id').isUUID().withMessage('Invalid user ID'),
  validateRequest,
], async (req, res, next) => {
  try {
    const { id } = req.params;

    const query = `
      SELECT 
        ur.id as user_role_id,
        r.id as role_id,
        r.name as role_name,
        r.description as role_description,
        r.permissions,
        ur.granted_by,
        ur.granted_at,
        ur.expires_at,
        u_granter.email as granted_by_email
      FROM user_roles ur
      JOIN roles r ON ur.role_id = r.id
      LEFT JOIN users u_granter ON ur.granted_by = u_granter.id
      WHERE ur.user_id = $1
      AND (ur.expires_at IS NULL OR ur.expires_at > NOW())
      ORDER BY ur.granted_at DESC
    `;

    const result = await DatabaseManager.query(query, [id]);

    res.json({
      success: true,
      data: result.rows,
    });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /api/users/{id}/roles:
 *   post:
 *     summary: Assign role to user (admin only)
 *     tags: [Users]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - role_id
 *             properties:
 *               role_id:
 *                 type: string
 *                 format: uuid
 *               expires_at:
 *                 type: string
 *                 format: date-time
 *     responses:
 *       200:
 *         description: Role assigned successfully
 */
router.post('/:id/roles', requirePermission('users:update'), [
  param('id').isUUID().withMessage('Invalid user ID'),
  body('role_id').isUUID().withMessage('Invalid role ID'),
  body('expires_at').optional().isISO8601().withMessage('Invalid expiration date'),
  validateRequest,
], async (req, res, next) => {
  try {
    const { id } = req.params;
    const { role_id, expires_at } = req.body;

    // Check if role assignment already exists
    const existingQuery = `
      SELECT id FROM user_roles 
      WHERE user_id = $1 AND role_id = $2 
      AND (expires_at IS NULL OR expires_at > NOW())
    `;
    const existingResult = await DatabaseManager.query(existingQuery, [id, role_id]);

    if (existingResult.rows.length > 0) {
      return res.status(409).json({
        success: false,
        error: 'Role already assigned',
        message: 'This role is already assigned to the user.',
        code: 'ROLE_ALREADY_ASSIGNED',
      });
    }

    // Assign role
    const assignQuery = `
      INSERT INTO user_roles (user_id, role_id, granted_by, expires_at)
      VALUES ($1, $2, $3, $4)
      RETURNING id
    `;

    await DatabaseManager.query(assignQuery, [id, role_id, req.user!.id, expires_at]);

    logAudit('role_assigned', req.user!.id, {
      targetUserId: id,
      roleId: role_id,
      expiresAt: expires_at,
    });

    res.json({
      success: true,
      message: 'Role assigned successfully.',
    });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /api/users/{id}/roles/{roleId}:
 *   delete:
 *     summary: Remove role from user (admin only)
 *     tags: [Users]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *       - in: path
 *         name: roleId
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *     responses:
 *       200:
 *         description: Role removed successfully
 */
router.delete('/:id/roles/:roleId', requirePermission('users:update'), [
  param('id').isUUID().withMessage('Invalid user ID'),
  param('roleId').isUUID().withMessage('Invalid role ID'),
  validateRequest,
], async (req, res, next) => {
  try {
    const { id, roleId } = req.params;

    const deleteQuery = `
      DELETE FROM user_roles 
      WHERE user_id = $1 AND role_id = $2
      RETURNING id
    `;

    const result = await DatabaseManager.query(deleteQuery, [id, roleId]);

    if (result.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'Role assignment not found',
        code: 'ROLE_ASSIGNMENT_NOT_FOUND',
      });
    }

    logAudit('role_removed', req.user!.id, {
      targetUserId: id,
      roleId: roleId,
    });

    res.json({
      success: true,
      message: 'Role removed successfully.',
    });
  } catch (error) {
    next(error);
  }
});

export { router as usersRouter };