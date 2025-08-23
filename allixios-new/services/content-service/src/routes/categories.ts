/**
 * Categories Routes
 * RESTful API endpoints for category management
 */

import { Router } from 'express';
import { body, param, query } from 'express-validator';
import { DatabaseManager } from '../database/DatabaseManager';
import { asyncHandler } from '../utils/asyncHandler';
import { validateRequest } from '../middleware/validation';

const router = Router();

/**
 * Get categories
 */
router.get('/', [
  query('page').optional().isInt({ min: 1 }).toInt(),
  query('limit').optional().isInt({ min: 1, max: 100 }).toInt(),
  validateRequest,
], asyncHandler(async (req, res) => {
  const { page = 1, limit = 50 } = req.query;
  const offset = (page as number - 1) * (limit as number);

  const query = `
    SELECT id, name, slug, description, parent_id, created_at, updated_at
    FROM categories 
    WHERE tenant_id = $1
    ORDER BY name ASC
    LIMIT $2 OFFSET $3
  `;

  const result = await DatabaseManager.query(query, [req.user?.tenantId, limit, offset]);

  res.json({
    success: true,
    data: result.rows,
  });
}));

/**
 * Create category
 */
router.post('/', [
  body('name').isString().isLength({ min: 1, max: 255 }),
  body('description').optional().isString(),
  body('parent_id').optional().isUUID(),
  validateRequest,
], asyncHandler(async (req, res) => {
  const { name, description, parent_id } = req.body;
  const slug = name.toLowerCase().replace(/[^a-z0-9]+/g, '-');

  const query = `
    INSERT INTO categories (name, slug, description, parent_id, tenant_id)
    VALUES ($1, $2, $3, $4, $5)
    RETURNING *
  `;

  const result = await DatabaseManager.query(query, [
    name, slug, description, parent_id, req.user?.tenantId
  ]);

  res.status(201).json({
    success: true,
    data: result.rows[0],
  });
}));

export { router as categoriesRouter };