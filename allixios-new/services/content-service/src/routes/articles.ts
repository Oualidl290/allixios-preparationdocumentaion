/**
 * Articles Routes
 * RESTful API endpoints for article management
 */

import { Router } from 'express';
import { body, param, query, validationResult } from 'express-validator';
import { ArticleService } from '../services/ArticleService';
import { MediaService } from '../services/MediaService';
import { logger, logError } from '../utils/logger';
import { asyncHandler } from '../utils/asyncHandler';
import { validateRequest } from '../middleware/validation';

const router = Router();
const articleService = new ArticleService();
const mediaService = new MediaService();

/**
 * @swagger
 * /api/articles:
 *   get:
 *     summary: Get articles with filtering and pagination
 *     tags: [Articles]
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
 *         name: status
 *         schema:
 *           type: string
 *           enum: [draft, review, published, archived]
 *       - in: query
 *         name: niche_id
 *         schema:
 *           type: string
 *           format: uuid
 *       - in: query
 *         name: category_id
 *         schema:
 *           type: string
 *           format: uuid
 *       - in: query
 *         name: author_id
 *         schema:
 *           type: string
 *           format: uuid
 *       - in: query
 *         name: search
 *         schema:
 *           type: string
 *       - in: query
 *         name: sort
 *         schema:
 *           type: string
 *           enum: [created_at, updated_at, published_at, view_count, engagement_score]
 *           default: created_at
 *       - in: query
 *         name: order
 *         schema:
 *           type: string
 *           enum: [asc, desc]
 *           default: desc
 *     responses:
 *       200:
 *         description: List of articles
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 data:
 *                   type: array
 *                   items:
 *                     $ref: '#/components/schemas/Article'
 *                 pagination:
 *                   $ref: '#/components/schemas/Pagination'
 */
router.get('/', [
  query('page').optional().isInt({ min: 1 }).toInt(),
  query('limit').optional().isInt({ min: 1, max: 100 }).toInt(),
  query('status').optional().isIn(['draft', 'review', 'published', 'archived']),
  query('niche_id').optional().isUUID(),
  query('category_id').optional().isUUID(),
  query('author_id').optional().isUUID(),
  query('search').optional().isString().trim(),
  query('sort').optional().isIn(['created_at', 'updated_at', 'published_at', 'view_count', 'engagement_score']),
  query('order').optional().isIn(['asc', 'desc']),
  validateRequest,
], asyncHandler(async (req, res) => {
  const {
    page = 1,
    limit = 20,
    status,
    niche_id,
    category_id,
    author_id,
    search,
    sort = 'created_at',
    order = 'desc'
  } = req.query;

  const filters = {
    status,
    niche_id,
    category_id,
    author_id,
    search: search as string,
  };

  const result = await articleService.getArticles({
    page: page as number,
    limit: limit as number,
    filters,
    sort: sort as string,
    order: order as string,
    tenantId: req.user?.tenantId,
    includeMedia: true,
  });

  res.json({
    success: true,
    data: result.articles,
    pagination: {
      page: page as number,
      limit: limit as number,
      total: result.total,
      pages: Math.ceil(result.total / (limit as number)),
      hasNext: (page as number) * (limit as number) < result.total,
      hasPrev: (page as number) > 1,
    },
    meta: {
      requestId: req.id,
      timestamp: new Date().toISOString(),
      processingTime: Date.now() - req.startTime,
    }
  });
}));

/**
 * @swagger
 * /api/articles/{id}:
 *   get:
 *     summary: Get article by ID
 *     tags: [Articles]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *       - in: query
 *         name: include_media
 *         schema:
 *           type: boolean
 *           default: true
 *       - in: query
 *         name: include_analytics
 *         schema:
 *           type: boolean
 *           default: false
 *     responses:
 *       200:
 *         description: Article details
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 data:
 *                   $ref: '#/components/schemas/ArticleDetailed'
 *       404:
 *         description: Article not found
 */
router.get('/:id', [
  param('id').isUUID().withMessage('Invalid article ID'),
  query('include_media').optional().isBoolean().toBoolean(),
  query('include_analytics').optional().isBoolean().toBoolean(),
  validateRequest,
], asyncHandler(async (req, res) => {
  const { id } = req.params;
  const { include_media = true, include_analytics = false } = req.query;

  const article = await articleService.getArticleById(id, {
    tenantId: req.user?.tenantId,
    includeMedia: include_media as boolean,
    includeAnalytics: include_analytics as boolean,
  });

  if (!article) {
    return res.status(404).json({
      success: false,
      error: 'Article not found',
      message: `Article with ID ${id} was not found.`,
    });
  }

  // Track article view if it's a public request
  if (req.path.includes('/public/') && article.status === 'published') {
    await articleService.trackView(id, {
      userId: req.user?.id,
      sessionId: req.sessionID,
      userAgent: req.get('User-Agent'),
      referrer: req.get('Referer'),
      ip: req.ip,
    });
  }

  res.json({
    success: true,
    data: article,
    meta: {
      requestId: req.id,
      timestamp: new Date().toISOString(),
      processingTime: Date.now() - req.startTime,
    }
  });
}));

/**
 * @swagger
 * /api/articles:
 *   post:
 *     summary: Create new article
 *     tags: [Articles]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             $ref: '#/components/schemas/CreateArticleRequest'
 *     responses:
 *       201:
 *         description: Article created successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 data:
 *                   $ref: '#/components/schemas/Article'
 *       400:
 *         description: Validation error
 */
router.post('/', [
  body('title')
    .isString()
    .isLength({ min: 1, max: 1000 })
    .withMessage('Title must be between 1 and 1000 characters'),
  body('content')
    .isString()
    .isLength({ min: 100 })
    .withMessage('Content must be at least 100 characters'),
  body('excerpt')
    .optional()
    .isString()
    .isLength({ max: 500 })
    .withMessage('Excerpt must be less than 500 characters'),
  body('meta_title')
    .optional()
    .isString()
    .isLength({ max: 255 })
    .withMessage('Meta title must be less than 255 characters'),
  body('meta_description')
    .optional()
    .isString()
    .isLength({ max: 500 })
    .withMessage('Meta description must be less than 500 characters'),
  body('niche_id')
    .optional()
    .isUUID()
    .withMessage('Invalid niche ID'),
  body('category_id')
    .optional()
    .isUUID()
    .withMessage('Invalid category ID'),
  body('author_id')
    .optional()
    .isUUID()
    .withMessage('Invalid author ID'),
  body('language')
    .optional()
    .isString()
    .isLength({ min: 2, max: 5 })
    .withMessage('Invalid language code'),
  body('status')
    .optional()
    .isIn(['draft', 'review', 'published', 'archived'])
    .withMessage('Invalid status'),
  body('tag_ids')
    .optional()
    .isArray()
    .withMessage('Tag IDs must be an array'),
  body('tag_ids.*')
    .optional()
    .isUUID()
    .withMessage('Invalid tag ID'),
  body('media_data')
    .optional()
    .isArray()
    .withMessage('Media data must be an array'),
  body('featured_image_id')
    .optional()
    .isUUID()
    .withMessage('Invalid featured image ID'),
  validateRequest,
], asyncHandler(async (req, res) => {
  const articleData = {
    ...req.body,
    tenant_id: req.user?.tenantId,
    author_id: req.body.author_id || req.user?.authorId,
  };

  const article = await articleService.createArticle(articleData);

  logger.info('Article created', {
    articleId: article.id,
    title: article.title,
    authorId: article.author_id,
    userId: req.user?.id,
  });

  res.status(201).json({
    success: true,
    data: article,
    message: 'Article created successfully',
    meta: {
      requestId: req.id,
      timestamp: new Date().toISOString(),
      processingTime: Date.now() - req.startTime,
    }
  });
}));

/**
 * @swagger
 * /api/articles/{id}:
 *   put:
 *     summary: Update article
 *     tags: [Articles]
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
 *             $ref: '#/components/schemas/UpdateArticleRequest'
 *     responses:
 *       200:
 *         description: Article updated successfully
 *       404:
 *         description: Article not found
 */
router.put('/:id', [
  param('id').isUUID().withMessage('Invalid article ID'),
  body('title')
    .optional()
    .isString()
    .isLength({ min: 1, max: 1000 })
    .withMessage('Title must be between 1 and 1000 characters'),
  body('content')
    .optional()
    .isString()
    .isLength({ min: 100 })
    .withMessage('Content must be at least 100 characters'),
  body('status')
    .optional()
    .isIn(['draft', 'review', 'published', 'archived'])
    .withMessage('Invalid status'),
  validateRequest,
], asyncHandler(async (req, res) => {
  const { id } = req.params;
  const updateData = req.body;

  const article = await articleService.updateArticle(id, updateData, {
    tenantId: req.user?.tenantId,
    userId: req.user?.id,
  });

  if (!article) {
    return res.status(404).json({
      success: false,
      error: 'Article not found',
      message: `Article with ID ${id} was not found.`,
    });
  }

  logger.info('Article updated', {
    articleId: id,
    userId: req.user?.id,
    changes: Object.keys(updateData),
  });

  res.json({
    success: true,
    data: article,
    message: 'Article updated successfully',
    meta: {
      requestId: req.id,
      timestamp: new Date().toISOString(),
      processingTime: Date.now() - req.startTime,
    }
  });
}));

/**
 * @swagger
 * /api/articles/{id}:
 *   delete:
 *     summary: Delete article
 *     tags: [Articles]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *     responses:
 *       200:
 *         description: Article deleted successfully
 *       404:
 *         description: Article not found
 */
router.delete('/:id', [
  param('id').isUUID().withMessage('Invalid article ID'),
  validateRequest,
], asyncHandler(async (req, res) => {
  const { id } = req.params;

  const deleted = await articleService.deleteArticle(id, {
    tenantId: req.user?.tenantId,
    userId: req.user?.id,
  });

  if (!deleted) {
    return res.status(404).json({
      success: false,
      error: 'Article not found',
      message: `Article with ID ${id} was not found.`,
    });
  }

  logger.info('Article deleted', {
    articleId: id,
    userId: req.user?.id,
  });

  res.json({
    success: true,
    message: 'Article deleted successfully',
    meta: {
      requestId: req.id,
      timestamp: new Date().toISOString(),
      processingTime: Date.now() - req.startTime,
    }
  });
}));

/**
 * @swagger
 * /api/articles/{id}/media:
 *   get:
 *     summary: Get article media
 *     tags: [Articles, Media]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *       - in: query
 *         name: usage_type
 *         schema:
 *           type: string
 *           enum: [featured, content, gallery, thumbnail, hero, inline, background]
 *     responses:
 *       200:
 *         description: Article media
 */
router.get('/:id/media', [
  param('id').isUUID().withMessage('Invalid article ID'),
  query('usage_type').optional().isIn(['featured', 'content', 'gallery', 'thumbnail', 'hero', 'inline', 'background']),
  validateRequest,
], asyncHandler(async (req, res) => {
  const { id } = req.params;
  const { usage_type } = req.query;

  const media = await mediaService.getArticleMedia(id, usage_type as string);

  res.json({
    success: true,
    data: media,
    meta: {
      requestId: req.id,
      timestamp: new Date().toISOString(),
      processingTime: Date.now() - req.startTime,
    }
  });
}));

/**
 * @swagger
 * /api/articles/{id}/media:
 *   post:
 *     summary: Attach media to article
 *     tags: [Articles, Media]
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
 *               - media_id
 *             properties:
 *               media_id:
 *                 type: string
 *                 format: uuid
 *               usage_type:
 *                 type: string
 *                 enum: [featured, content, gallery, thumbnail, hero, inline, background]
 *                 default: content
 *               position:
 *                 type: integer
 *                 minimum: 1
 *               section:
 *                 type: string
 *               alignment:
 *                 type: string
 *                 enum: [left, center, right, full-width]
 *                 default: center
 *               size:
 *                 type: string
 *                 enum: [small, medium, large, full]
 *                 default: medium
 *               caption_override:
 *                 type: string
 *               alt_text_override:
 *                 type: string
 *     responses:
 *       200:
 *         description: Media attached successfully
 */
router.post('/:id/media', [
  param('id').isUUID().withMessage('Invalid article ID'),
  body('media_id').isUUID().withMessage('Invalid media ID'),
  body('usage_type').optional().isIn(['featured', 'content', 'gallery', 'thumbnail', 'hero', 'inline', 'background']),
  body('position').optional().isInt({ min: 1 }),
  body('section').optional().isString(),
  body('alignment').optional().isIn(['left', 'center', 'right', 'full-width']),
  body('size').optional().isIn(['small', 'medium', 'large', 'full']),
  body('caption_override').optional().isString(),
  body('alt_text_override').optional().isString(),
  validateRequest,
], asyncHandler(async (req, res) => {
  const { id } = req.params;
  const mediaData = req.body;

  const attachment = await mediaService.attachMediaToArticle(id, mediaData);

  logger.info('Media attached to article', {
    articleId: id,
    mediaId: mediaData.media_id,
    usageType: mediaData.usage_type,
    userId: req.user?.id,
  });

  res.json({
    success: true,
    data: attachment,
    message: 'Media attached successfully',
    meta: {
      requestId: req.id,
      timestamp: new Date().toISOString(),
      processingTime: Date.now() - req.startTime,
    }
  });
}));

/**
 * @swagger
 * /api/articles/{id}/publish:
 *   post:
 *     summary: Publish article
 *     tags: [Articles]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *     responses:
 *       200:
 *         description: Article published successfully
 *       404:
 *         description: Article not found
 *       400:
 *         description: Article cannot be published
 */
router.post('/:id/publish', [
  param('id').isUUID().withMessage('Invalid article ID'),
  validateRequest,
], asyncHandler(async (req, res) => {
  const { id } = req.params;

  const article = await articleService.publishArticle(id, {
    tenantId: req.user?.tenantId,
    userId: req.user?.id,
  });

  if (!article) {
    return res.status(404).json({
      success: false,
      error: 'Article not found',
      message: `Article with ID ${id} was not found.`,
    });
  }

  logger.info('Article published', {
    articleId: id,
    title: article.title,
    userId: req.user?.id,
  });

  res.json({
    success: true,
    data: article,
    message: 'Article published successfully',
    meta: {
      requestId: req.id,
      timestamp: new Date().toISOString(),
      processingTime: Date.now() - req.startTime,
    }
  });
}));

/**
 * @swagger
 * /api/articles/{id}/analytics:
 *   get:
 *     summary: Get article analytics
 *     tags: [Articles, Analytics]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *       - in: query
 *         name: period
 *         schema:
 *           type: string
 *           enum: [1d, 7d, 30d, 90d]
 *           default: 30d
 *     responses:
 *       200:
 *         description: Article analytics data
 */
router.get('/:id/analytics', [
  param('id').isUUID().withMessage('Invalid article ID'),
  query('period').optional().isIn(['1d', '7d', '30d', '90d']),
  validateRequest,
], asyncHandler(async (req, res) => {
  const { id } = req.params;
  const { period = '30d' } = req.query;

  const analytics = await articleService.getArticleAnalytics(id, period as string);

  res.json({
    success: true,
    data: analytics,
    meta: {
      requestId: req.id,
      timestamp: new Date().toISOString(),
      processingTime: Date.now() - req.startTime,
    }
  });
}));

/**
 * @swagger
 * /api/articles/batch:
 *   post:
 *     summary: Create multiple articles in batch
 *     tags: [Articles]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               articles:
 *                 type: array
 *                 items:
 *                   $ref: '#/components/schemas/CreateArticleRequest'
 *     responses:
 *       201:
 *         description: Articles created successfully
 */
router.post('/batch', [
  body('articles')
    .isArray({ min: 1, max: 50 })
    .withMessage('Articles array must contain 1-50 items'),
  body('articles.*.title')
    .isString()
    .isLength({ min: 1, max: 1000 })
    .withMessage('Each article must have a valid title'),
  body('articles.*.content')
    .isString()
    .isLength({ min: 100 })
    .withMessage('Each article must have content with at least 100 characters'),
  validateRequest,
], asyncHandler(async (req, res) => {
  const { articles } = req.body;

  const results = await articleService.createArticlesBatch(articles, {
    tenantId: req.user?.tenantId,
    userId: req.user?.id,
  });

  logger.info('Batch articles created', {
    count: results.length,
    userId: req.user?.id,
  });

  res.status(201).json({
    success: true,
    data: results,
    message: `${results.length} articles created successfully`,
    meta: {
      requestId: req.id,
      timestamp: new Date().toISOString(),
      processingTime: Date.now() - req.startTime,
    }
  });
}));

export { router as articlesRouter };