/**
 * Tenants Routes
 * Multi-tenant management endpoints
 */

import { Router } from 'express';
import { body, param, query, validationResult } from 'express-validator';
import { authMiddleware, requirePermission, requireRole } from '../middleware/auth';
import { TenantService } from '../services/TenantService';
import { logger, logAudit } from '../utils/logger';

const router = Router();
const tenantService = new TenantService();

// Apply authentication to all tenant routes
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
 * /api/tenants:
 *   get:
 *     summary: Get tenants list (admin only)
 *     tags: [Tenants]
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
 *           enum: [active, inactive, suspended]
 *     responses:
 *       200:
 *         description: Tenants list retrieved successfully
 *       403:
 *         description: Insufficient permissions
 */
router.get('/', requireRole('admin'), [
  query('page').optional().isInt({ min: 1 }).toInt(),
  query('limit').optional().isInt({ min: 1, max: 100 }).toInt(),
  query('search').optional().isString().trim(),
  query('status').optional().isIn(['active', 'inactive', 'suspended']),
  validateRequest,
], async (req, res, next) => {
  try {
    const result = await tenantService.getTenants(req.query);

    res.json({
      success: true,
      data: result.tenants,
      pagination: result.pagination,
    });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /api/tenants:
 *   post:
 *     summary: Create new tenant (admin only)
 *     tags: [Tenants]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - name
 *               - owner_id
 *             properties:
 *               name:
 *                 type: string
 *               slug:
 *                 type: string
 *               domain:
 *                 type: string
 *               owner_id:
 *                 type: string
 *                 format: uuid
 *               settings:
 *                 type: object
 *     responses:
 *       201:
 *         description: Tenant created successfully
 *       400:
 *         description: Validation error
 *       409:
 *         description: Tenant already exists
 */
router.post('/', requireRole('admin'), [
  body('name')
    .isString()
    .isLength({ min: 1, max: 100 })
    .withMessage('Name must be between 1 and 100 characters'),
  body('slug')
    .optional()
    .isString()
    .isLength({ min: 3, max: 50 })
    .matches(/^[a-z0-9-]+$/)
    .withMessage('Slug must be 3-50 characters and contain only lowercase letters, numbers, and hyphens'),
  body('domain')
    .optional()
    .isFQDN()
    .withMessage('Valid domain is required'),
  body('owner_id')
    .isUUID()
    .withMessage('Valid owner ID is required'),
  body('settings')
    .optional()
    .isObject()
    .withMessage('Settings must be an object'),
  validateRequest,
], async (req, res, next) => {
  try {
    const tenant = await tenantService.createTenant(req.body, req.user!.id);

    logAudit('tenant_created', req.user!.id, {
      tenantId: tenant.id,
      tenantName: tenant.name,
      ownerId: tenant.owner_id,
    });

    res.status(201).json({
      success: true,
      data: tenant,
      message: 'Tenant created successfully.',
    });
  } catch (error) {
    if (error.message.includes('already exists')) {
      return res.status(409).json({
        success: false,
        error: 'Tenant already exists',
        message: 'A tenant with this name or slug already exists.',
        code: 'TENANT_EXISTS',
      });
    }
    next(error);
  }
});

/**
 * @swagger
 * /api/tenants/{id}:
 *   get:
 *     summary: Get tenant by ID
 *     tags: [Tenants]
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
 *         description: Tenant retrieved successfully
 *       404:
 *         description: Tenant not found
 *       403:
 *         description: Access denied
 */
router.get('/:id', [
  param('id').isUUID().withMessage('Invalid tenant ID'),
  validateRequest,
], async (req, res, next) => {
  try {
    const { id } = req.params;
    const tenant = await tenantService.getTenantById(id);

    if (!tenant) {
      return res.status(404).json({
        success: false,
        error: 'Tenant not found',
        code: 'TENANT_NOT_FOUND',
      });
    }

    // Check access - admin or tenant member
    if (!req.user!.roles.includes('admin') && req.user!.tenantId !== id) {
      return res.status(403).json({
        success: false,
        error: 'Access denied',
        message: 'You can only access your own tenant.',
        code: 'TENANT_ACCESS_DENIED',
      });
    }

    res.json({
      success: true,
      data: tenant,
    });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /api/tenants/{id}:
 *   put:
 *     summary: Update tenant
 *     tags: [Tenants]
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
 *             properties:
 *               name:
 *                 type: string
 *               domain:
 *                 type: string
 *               logo_url:
 *                 type: string
 *                 format: uri
 *               settings:
 *                 type: object
 *     responses:
 *       200:
 *         description: Tenant updated successfully
 *       404:
 *         description: Tenant not found
 *       403:
 *         description: Access denied
 */
router.put('/:id', [
  param('id').isUUID().withMessage('Invalid tenant ID'),
  body('name')
    .optional()
    .isString()
    .isLength({ min: 1, max: 100 })
    .withMessage('Name must be between 1 and 100 characters'),
  body('domain')
    .optional()
    .isFQDN()
    .withMessage('Valid domain is required'),
  body('logo_url')
    .optional()
    .isURL()
    .withMessage('Valid logo URL is required'),
  body('settings')
    .optional()
    .isObject()
    .withMessage('Settings must be an object'),
  validateRequest,
], async (req, res, next) => {
  try {
    const { id } = req.params;

    // Check access - admin or tenant owner
    const tenant = await tenantService.getTenantById(id);
    if (!tenant) {
      return res.status(404).json({
        success: false,
        error: 'Tenant not found',
        code: 'TENANT_NOT_FOUND',
      });
    }

    if (!req.user!.roles.includes('admin') && tenant.owner_id !== req.user!.id) {
      return res.status(403).json({
        success: false,
        error: 'Access denied',
        message: 'Only tenant owners and admins can update tenant settings.',
        code: 'TENANT_UPDATE_DENIED',
      });
    }

    const updatedTenant = await tenantService.updateTenant(id, req.body, req.user!.id);

    res.json({
      success: true,
      data: updatedTenant,
      message: 'Tenant updated successfully.',
    });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /api/tenants/{id}/status:
 *   patch:
 *     summary: Update tenant status (admin only)
 *     tags: [Tenants]
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
 *                 enum: [active, inactive, suspended]
 *               reason:
 *                 type: string
 *     responses:
 *       200:
 *         description: Tenant status updated successfully
 */
router.patch('/:id/status', requireRole('admin'), [
  param('id').isUUID().withMessage('Invalid tenant ID'),
  body('status')
    .isIn(['active', 'inactive', 'suspended'])
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

    const updatedTenant = await tenantService.updateTenantStatus(id, status, req.user!.id, reason);

    res.json({
      success: true,
      data: updatedTenant,
      message: `Tenant status updated to ${status}.`,
    });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /api/tenants/{id}/users:
 *   get:
 *     summary: Get tenant users
 *     tags: [Tenants]
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
 *         description: Tenant users retrieved successfully
 */
router.get('/:id/users', [
  param('id').isUUID().withMessage('Invalid tenant ID'),
  validateRequest,
], async (req, res, next) => {
  try {
    const { id } = req.params;

    // Check access
    if (!req.user!.roles.includes('admin') && req.user!.tenantId !== id) {
      return res.status(403).json({
        success: false,
        error: 'Access denied',
        code: 'TENANT_ACCESS_DENIED',
      });
    }

    const users = await tenantService.getTenantUsers(id);

    res.json({
      success: true,
      data: users,
    });
  } catch (error) {
    next(error);
  }
});

export { router as tenantsRouter };