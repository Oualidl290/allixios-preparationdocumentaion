/**
 * Tags Routes
 * RESTful API endpoints for tag management
 */

import { Router } from 'express';
import { body, query } from 'express-validator';
import { DatabaseManager } from '../database/DatabaseManager';
import { asyncHandler } from '../utils/asyncHandler';
import { validateRequest } from '../middleware/validation';

const router = Router();

/**
 * Get tags
 */
router.get('/', [
  query('search').optional().isString().trim(),
  query('limit').optional().isInt({ min: 1, max: 100 }).toInt(),
  validateRequest,
], asyncHandler(async (req, res) => {
  const { search, limit = 50 } = req.query;

  let whereClause = 'WHERE tenant_id = $1';
  const params = [req.user?.tenantId];

  if (search) {
    whereClause += ' AND name ILIKE $2';
    params.push(`%${search}%`);
  }

  const query = `
    SELECT id, name, slug, color, usage_count
    FROM tags 
    ${whereClause}
    ORDER BY usage_count DESC, name ASC
    LIMIT $${params.length + 1}
  `;
  params.push(limit as number);

  const result = await DatabaseManager.query(query, params);

  res.json({
    success: true,
    data: result.rows,
  });
}));

/**
 * Create tag
 */
router.post('/', [
  body('name').isString().isLength({ min: 1, max: 100 }),
  body('color').optional().isString().matches(/^#[0-9A-F]{6}$/i),
  validateRequest,
], asyncHandler(async (req, res) => {
  const { name, color } = req.body;
  const slug = name.toLowerCase().replace(/[^a-z0-9]+/g, '-');

  const query = `
    INSERT INTO tags (name, slug, color, tenant_id)
    VALUES ($1, $2, $3, $4)
    RETURNING *
  `;

  const result = await DatabaseManager.query(query, [
    name, slug, color, req.user?.tenantId
  ]);

  res.status(201).json({
    success: true,
    data: result.rows[0],
  });
}));

export { router as tagsRouter };