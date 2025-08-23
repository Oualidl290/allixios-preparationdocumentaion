/**
 * Workflow Routes
 * Content workflow and approval endpoints
 */

import { Router } from 'express';
import { body, param } from 'express-validator';
import { DatabaseManager } from '../database/DatabaseManager';
import { asyncHandler } from '../utils/asyncHandler';
import { validateRequest } from '../middleware/validation';

const router = Router();

/**
 * Submit article for review
 */
router.post('/articles/:id/submit', [
  param('id').isUUID().withMessage('Invalid article ID'),
  validateRequest,
], asyncHandler(async (req, res) => {
  const { id } = req.params;

  const query = `
    UPDATE articles 
    SET status = 'review', updated_at = NOW()
    WHERE id = $1 AND tenant_id = $2 AND status = 'draft'
    RETURNING *
  `;

  const result = await DatabaseManager.query(query, [id, req.user?.tenantId]);

  if (result.rows.length === 0) {
    return res.status(404).json({
      success: false,
      error: 'Article not found or cannot be submitted',
    });
  }

  res.json({
    success: true,
    data: result.rows[0],
    message: 'Article submitted for review',
  });
}));

/**
 * Approve article
 */
router.post('/articles/:id/approve', [
  param('id').isUUID().withMessage('Invalid article ID'),
  validateRequest,
], asyncHandler(async (req, res) => {
  const { id } = req.params;

  const query = `
    UPDATE articles 
    SET status = 'published', published_at = NOW(), updated_at = NOW()
    WHERE id = $1 AND tenant_id = $2 AND status = 'review'
    RETURNING *
  `;

  const result = await DatabaseManager.query(query, [id, req.user?.tenantId]);

  if (result.rows.length === 0) {
    return res.status(404).json({
      success: false,
      error: 'Article not found or cannot be approved',
    });
  }

  res.json({
    success: true,
    data: result.rows[0],
    message: 'Article approved and published',
  });
}));

export { router as workflowRouter };