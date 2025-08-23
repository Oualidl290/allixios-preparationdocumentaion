/**
 * Authors Routes
 * RESTful API endpoints for author management
 */

import { Router } from 'express';
import { body, param, query, validationResult } from 'express-validator';
import { DatabaseManager } from '../database/DatabaseManager';
import { logger } from '../utils/logger';
import { asyncHandler } from '../utils/asyncHandler';
import { validateRequest } from '../middleware/validation';

const router = Router();

/**
 * Get authors with pagination
 */
router.get('/', [
  query('page').optional().isInt({ min: 1 }).toInt(),
  query('limit').optional().isInt({ min: 1, max: 100 }).toInt(),
  query('search').optional().isString().trim(),
  validateRequest,
], asyncHandler(async (req, res) => {
  const { page = 1, limit = 20, search } = req.query;
  const offset = (page as number - 1) * (limit as number);

  let whereClause = 'WHERE tenant_id = $1';
  const params = [req.user?.tenantId];

  if (search) {
    whereClause += ' AND (name ILIKE $2 OR email ILIKE $2)';
    params.push(`%${search}%`);
  }

  const countQuery = `SELECT COUNT(*) as total FROM authors ${whereClause}`;
  const countResult = await DatabaseManager.query(countQuery, params);
  const total = parseInt(countResult.rows[0].total);

  const authorsQuery = `
    SELECT id, name, email, bio, avatar_url, social_links, created_at, updated_at
    FROM authors 
    ${whereClause}
    ORDER BY created_at DESC
    LIMIT $${params.length + 1} OFFSET $${params.length + 2}
  `;
  params.push(limit as number, offset);

  const authorsResult = await DatabaseManager.query(authorsQuery, params);

  res.json({
    success: true,
    data: authorsResult.rows,
    pagination: {
      page: page as number,
      limit: limit as number,
      total,
      pages: Math.ceil(total / (limit as number)),
    },
  });
}));

/**
 * Get author by ID
 */
router.get('/:id', [
  param('id').isUUID().withMessage('Invalid author ID'),
  validateRequest,
], asyncHandler(async (req, res) => {
  const { id } = req.params;

  const query = `
    SELECT id, name, email, bio, avatar_url, social_links, created_at, updated_at
    FROM authors 
    WHERE id = $1 AND tenant_id = $2
  `;

  const result = await DatabaseManager.query(query, [id, req.user?.tenantId]);
  const author = result.rows[0];

  if (!author) {
    return res.status(404).json({
      success: false,
      error: 'Author not found',
    });
  }

  res.json({
    success: true,
    data: author,
  });
}));

/**
 * Create new author
 */
router.post('/', [
  body('name').isString().isLength({ min: 1, max: 255 }).withMessage('Name is required'),
  body('email').isEmail().withMessage('Valid email is required'),
  body('bio').optional().isString().isLength({ max: 1000 }),
  body('avatar_url').optional().isURL(),
  body('social_links').optional().isObject(),
  validateRequest,
], asyncHandler(async (req, res) => {
  const { name, email, bio, avatar_url, social_links } = req.body;

  const query = `
    INSERT INTO authors (name, email, bio, avatar_url, social_links, tenant_id)
    VALUES ($1, $2, $3, $4, $5, $6)
    RETURNING id, name, email, bio, avatar_url, social_links, created_at, updated_at
  `;

  const result = await DatabaseManager.query(query, [
    name, email, bio, avatar_url, social_links, req.user?.tenantId
  ]);

  res.status(201).json({
    success: true,
    data: result.rows[0],
    message: 'Author created successfully',
  });
}));

export { router as authorsRouter };