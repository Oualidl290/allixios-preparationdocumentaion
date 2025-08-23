/**
 * Search Routes
 * Search functionality endpoints
 */

import { Router } from 'express';
import { query } from 'express-validator';
import { ElasticsearchManager } from '../search/ElasticsearchManager';
import { asyncHandler } from '../utils/asyncHandler';
import { validateRequest } from '../middleware/validation';

const router = Router();

/**
 * Search articles
 */
router.get('/articles', [
  query('q').isString().isLength({ min: 1 }).withMessage('Search query is required'),
  query('page').optional().isInt({ min: 1 }).toInt(),
  query('limit').optional().isInt({ min: 1, max: 100 }).toInt(),
  validateRequest,
], asyncHandler(async (req, res) => {
  const { q, page = 1, limit = 20 } = req.query;
  const from = (page as number - 1) * (limit as number);

  const searchQuery = {
    query: {
      multi_match: {
        query: q,
        fields: ['title^3', 'content', 'excerpt^2', 'author_name', 'category_name'],
        type: 'best_fields',
        fuzziness: 'AUTO',
      },
    },
    highlight: {
      fields: {
        title: {},
        content: { fragment_size: 150, number_of_fragments: 3 },
        excerpt: {},
      },
    },
    from,
    size: limit,
  };

  const result = await ElasticsearchManager.search('articles', searchQuery);

  res.json({
    success: true,
    data: {
      hits: result.hits.hits.map((hit: any) => ({
        ...hit._source,
        id: hit._id,
        score: hit._score,
        highlights: hit.highlight,
      })),
      total: result.hits.total.value,
      maxScore: result.hits.max_score,
    },
    pagination: {
      page: page as number,
      limit: limit as number,
      total: result.hits.total.value,
    },
  });
}));

export { router as searchRouter };