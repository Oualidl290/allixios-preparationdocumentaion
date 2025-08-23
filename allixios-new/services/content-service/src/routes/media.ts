/**
 * Media Routes
 * RESTful API endpoints for media management
 */

import { Router } from 'express';
import { query } from 'express-validator';
import { DatabaseManager } from '../database/DatabaseManager';
import { asyncHandler } from '../utils/asyncHandler';
import { validateRequest } from '../middleware/validation';

const router = Router();

/**
 * Get media files
 */
router.get('/', [
  query('page').optional().isInt({ min: 1 }).toInt(),
  query('limit').optional().isInt({ min: 1, max: 100 }).toInt(),
  query('type').optional().isIn(['image', 'video', 'document', 'audio']),
  validateRequest,
], asyncHandler(async (req, res) => {
  const { page = 1, limit = 20, type } = req.query;
  const offset = (page as number - 1) * (limit as number);

  let whereClause = 'WHERE tenant_id = $1';
  const params = [req.user?.tenantId];

  if (type) {
    whereClause += ' AND media_type = $2';
    params.push(type);
  }

  const query = `
    SELECT id, filename, original_filename, media_type, file_size, 
           mime_type, url, thumbnail_url, alt_text, caption, created_at
    FROM media 
    ${whereClause}
    ORDER BY created_at DESC
    LIMIT $${params.length + 1} OFFSET $${params.length + 2}
  `;
  params.push(limit as number, offset);

  const result = await DatabaseManager.query(query, params);

  res.json({
    success: true,
    data: result.rows,
  });
}));

export { router as mediaRouter };