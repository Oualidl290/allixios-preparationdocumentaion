/**
 * Analytics Routes
 * Analytics and reporting endpoints
 */

import { Router } from 'express';
import { query } from 'express-validator';
import { DatabaseManager } from '../database/DatabaseManager';
import { asyncHandler } from '../utils/asyncHandler';
import { validateRequest } from '../middleware/validation';

const router = Router();

/**
 * Get content analytics overview
 */
router.get('/overview', [
  query('period').optional().isIn(['1d', '7d', '30d', '90d']),
  validateRequest,
], asyncHandler(async (req, res) => {
  const { period = '30d' } = req.query;
  
  const interval = period === '1d' ? '1 day' : 
                  period === '7d' ? '7 days' : 
                  period === '90d' ? '90 days' : '30 days';

  const query = `
    SELECT 
      COUNT(*) as total_articles,
      COUNT(CASE WHEN status = 'published' THEN 1 END) as published_articles,
      COUNT(CASE WHEN status = 'draft' THEN 1 END) as draft_articles,
      SUM(view_count) as total_views,
      AVG(engagement_score) as avg_engagement
    FROM articles 
    WHERE tenant_id = $1 
    AND created_at >= NOW() - INTERVAL '${interval}'
  `;

  const result = await DatabaseManager.query(query, [req.user?.tenantId]);

  res.json({
    success: true,
    data: result.rows[0],
  });
}));

export { router as analyticsRouter };