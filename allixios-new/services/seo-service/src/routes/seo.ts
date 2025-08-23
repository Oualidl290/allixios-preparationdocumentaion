/**
 * SEO Analysis Routes
 * Comprehensive SEO analysis and optimization endpoints
 */

import { Router } from 'express';
import { body, query, validationResult } from 'express-validator';
import rateLimit from 'express-rate-limit';
import { SEOAnalysisService } from '../services/SEOAnalysisService';
import { MetaTagService } from '../services/MetaTagService';
import { SchemaMarkupService } from '../services/SchemaMarkupService';
import { config } from '../config';
import { logger, logAudit } from '../utils/logger';

const router = Router();
const seoAnalysisService = new SEOAnalysisService();
const metaTagService = new MetaTagService();
const schemaMarkupService = new SchemaMarkupService();

// Rate limiting for SEO analysis (more restrictive)
const analysisLimiter = rateLimit({
  windowMs: config.rateLimit.auditWindowMs,
  max: config.rateLimit.auditMax,
  message: {
    error: 'Too many SEO analysis requests, please try again later.',
    code: 'ANALYSIS_RATE_LIMIT_EXCEEDED',
  },
});

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
 * /api/seo/analyze:
 *   post:
 *     summary: Perform comprehensive SEO analysis
 *     tags: [SEO Analysis]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - url
 *             properties:
 *               url:
 *                 type: string
 *                 format: uri
 *                 description: URL to analyze
 *               depth:
 *                 type: string
 *                 enum: [basic, standard, comprehensive]
 *                 default: standard
 *               includeCompetitors:
 *                 type: boolean
 *                 default: false
 *               competitors:
 *                 type: array
 *                 items:
 *                   type: string
 *                   format: uri
 *     responses:
 *       200:
 *         description: SEO analysis completed successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 data:
 *                   $ref: '#/components/schemas/SEOAnalysisResult'
 *       400:
 *         description: Invalid URL or parameters
 *       429:
 *         description: Rate limit exceeded
 */
router.post('/analyze', analysisLimiter, [
  body('url')
    .isURL({ protocols: ['http', 'https'] })
    .withMessage('Valid URL is required'),
  body('depth')
    .optional()
    .isIn(['basic', 'standard', 'comprehensive'])
    .withMessage('Depth must be basic, standard, or comprehensive'),
  body('includeCompetitors')
    .optional()
    .isBoolean()
    .withMessage('includeCompetitors must be a boolean'),
  body('competitors')
    .optional()
    .isArray({ max: 5 })
    .withMessage('Maximum 5 competitors allowed'),
  body('competitors.*')
    .optional()
    .isURL()
    .withMessage('Each competitor must be a valid URL'),
  validateRequest,
], async (req, res, next) => {
  try {
    const { url, depth = 'standard', includeCompetitors = false, competitors = [] } = req.body;

    logger.info('SEO analysis requested', {
      url,
      depth,
      includeCompetitors,
      competitorCount: competitors.length,
      userId: req.user?.id,
      tenantId: req.user?.tenantId,
    });

    const analysisResult = await seoAnalysisService.analyzePage(url, {
      tenantId: req.user?.tenantId,
      userId: req.user?.id,
      includeCompetitors,
      depth,
    });

    logAudit('seo_analysis_performed', req.user?.id, {
      url,
      overallScore: analysisResult.overallScore,
      technicalScore: analysisResult.technicalScore,
      contentScore: analysisResult.contentScore,
      performanceScore: analysisResult.performanceScore,
    });

    res.json({
      success: true,
      data: analysisResult,
      message: 'SEO analysis completed successfully',
      meta: {
        requestId: req.id,
        timestamp: new Date().toISOString(),
        processingTime: Date.now() - req.startTime,
      },
    });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /api/seo/analysis/{id}:
 *   get:
 *     summary: Get SEO analysis by ID
 *     tags: [SEO Analysis]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *     responses:
 *       200:
 *         description: SEO analysis retrieved successfully
 *       404:
 *         description: Analysis not found
 */
router.get('/analysis/:id', async (req, res, next) => {
  try {
    // Implementation would retrieve analysis from database
    res.json({
      success: true,
      message: 'Analysis retrieval not yet implemented',
    });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /api/seo/meta-tags/generate:
 *   post:
 *     summary: Generate optimized meta tags
 *     tags: [SEO Analysis]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - url
 *             properties:
 *               url:
 *                 type: string
 *                 format: uri
 *               targetKeywords:
 *                 type: array
 *                 items:
 *                   type: string
 *               contentType:
 *                 type: string
 *                 enum: [article, product, homepage, category]
 *     responses:
 *       200:
 *         description: Meta tags generated successfully
 */
router.post('/meta-tags/generate', [
  body('url')
    .isURL({ protocols: ['http', 'https'] })
    .withMessage('Valid URL is required'),
  body('targetKeywords')
    .optional()
    .isArray({ max: 10 })
    .withMessage('Maximum 10 target keywords allowed'),
  body('contentType')
    .optional()
    .isIn(['article', 'product', 'homepage', 'category'])
    .withMessage('Invalid content type'),
  validateRequest,
], async (req, res, next) => {
  try {
    const { url, targetKeywords = [], contentType = 'article' } = req.body;

    const metaTagSuggestions = await metaTagService.generateMetaTags(url, {
      targetKeywords,
      contentType,
      tenantId: req.user?.tenantId,
    });

    logAudit('meta_tags_generated', req.user?.id, {
      url,
      contentType,
      keywordCount: targetKeywords.length,
    });

    res.json({
      success: true,
      data: metaTagSuggestions,
      message: 'Meta tags generated successfully',
    });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /api/seo/schema/generate:
 *   post:
 *     summary: Generate schema markup
 *     tags: [SEO Analysis]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - url
 *               - schemaType
 *             properties:
 *               url:
 *                 type: string
 *                 format: uri
 *               schemaType:
 *                 type: string
 *                 enum: [Article, Product, Organization, Person, FAQ, Review]
 *               customData:
 *                 type: object
 *     responses:
 *       200:
 *         description: Schema markup generated successfully
 */
router.post('/schema/generate', [
  body('url')
    .isURL({ protocols: ['http', 'https'] })
    .withMessage('Valid URL is required'),
  body('schemaType')
    .isIn(['Article', 'Product', 'Organization', 'Person', 'FAQ', 'Review', 'BlogPosting', 'NewsArticle'])
    .withMessage('Invalid schema type'),
  body('customData')
    .optional()
    .isObject()
    .withMessage('Custom data must be an object'),
  validateRequest,
], async (req, res, next) => {
  try {
    const { url, schemaType, customData = {} } = req.body;

    const schemaMarkup = await schemaMarkupService.generateSchema(url, schemaType, {
      customData,
      tenantId: req.user?.tenantId,
    });

    logAudit('schema_markup_generated', req.user?.id, {
      url,
      schemaType,
    });

    res.json({
      success: true,
      data: schemaMarkup,
      message: 'Schema markup generated successfully',
    });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /api/seo/schema/validate:
 *   post:
 *     summary: Validate schema markup
 *     tags: [SEO Analysis]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - schema
 *             properties:
 *               schema:
 *                 type: object
 *                 description: JSON-LD schema to validate
 *     responses:
 *       200:
 *         description: Schema validation completed
 */
router.post('/schema/validate', [
  body('schema')
    .isObject()
    .withMessage('Schema must be a valid JSON object'),
  validateRequest,
], async (req, res, next) => {
  try {
    const { schema } = req.body;

    const validationResult = await schemaMarkupService.validateSchema(schema);

    res.json({
      success: true,
      data: validationResult,
      message: 'Schema validation completed',
    });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /api/seo/issues:
 *   get:
 *     summary: Get SEO issues for a domain
 *     tags: [SEO Analysis]
 *     parameters:
 *       - in: query
 *         name: domain
 *         required: true
 *         schema:
 *           type: string
 *       - in: query
 *         name: severity
 *         schema:
 *           type: string
 *           enum: [high, medium, low]
 *       - in: query
 *         name: category
 *         schema:
 *           type: string
 *           enum: [technical, content, performance, keywords]
 *       - in: query
 *         name: resolved
 *         schema:
 *           type: boolean
 *     responses:
 *       200:
 *         description: SEO issues retrieved successfully
 */
router.get('/issues', [
  query('domain')
    .notEmpty()
    .withMessage('Domain is required'),
  query('severity')
    .optional()
    .isIn(['high', 'medium', 'low'])
    .withMessage('Invalid severity level'),
  query('category')
    .optional()
    .isIn(['technical', 'content', 'performance', 'keywords', 'competitors'])
    .withMessage('Invalid category'),
  query('resolved')
    .optional()
    .isBoolean()
    .withMessage('Resolved must be a boolean'),
  validateRequest,
], async (req, res, next) => {
  try {
    // Implementation would query database for SEO issues
    res.json({
      success: true,
      data: [],
      message: 'SEO issues retrieval not yet implemented',
    });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /api/seo/recommendations:
 *   get:
 *     summary: Get SEO recommendations for a domain
 *     tags: [SEO Analysis]
 *     parameters:
 *       - in: query
 *         name: domain
 *         required: true
 *         schema:
 *           type: string
 *       - in: query
 *         name: priority
 *         schema:
 *           type: string
 *           enum: [high, medium, low]
 *       - in: query
 *         name: implemented
 *         schema:
 *           type: boolean
 *     responses:
 *       200:
 *         description: SEO recommendations retrieved successfully
 */
router.get('/recommendations', [
  query('domain')
    .notEmpty()
    .withMessage('Domain is required'),
  query('priority')
    .optional()
    .isIn(['high', 'medium', 'low'])
    .withMessage('Invalid priority level'),
  query('implemented')
    .optional()
    .isBoolean()
    .withMessage('Implemented must be a boolean'),
  validateRequest,
], async (req, res, next) => {
  try {
    // Implementation would query database for SEO recommendations
    res.json({
      success: true,
      data: [],
      message: 'SEO recommendations retrieval not yet implemented',
    });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /api/seo/score-history:
 *   get:
 *     summary: Get SEO score history for a domain
 *     tags: [SEO Analysis]
 *     parameters:
 *       - in: query
 *         name: domain
 *         required: true
 *         schema:
 *           type: string
 *       - in: query
 *         name: period
 *         schema:
 *           type: string
 *           enum: [7d, 30d, 90d, 1y]
 *           default: 30d
 *     responses:
 *       200:
 *         description: SEO score history retrieved successfully
 */
router.get('/score-history', [
  query('domain')
    .notEmpty()
    .withMessage('Domain is required'),
  query('period')
    .optional()
    .isIn(['7d', '30d', '90d', '1y'])
    .withMessage('Invalid period'),
  validateRequest,
], async (req, res, next) => {
  try {
    // Implementation would query database for historical SEO scores
    res.json({
      success: true,
      data: {
        scores: [],
        trend: 'improving',
        averageScore: 0,
      },
      message: 'SEO score history retrieval not yet implemented',
    });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /api/seo/bulk-analyze:
 *   post:
 *     summary: Perform bulk SEO analysis
 *     tags: [SEO Analysis]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - urls
 *             properties:
 *               urls:
 *                 type: array
 *                 items:
 *                   type: string
 *                   format: uri
 *                 maxItems: 10
 *               depth:
 *                 type: string
 *                 enum: [basic, standard]
 *                 default: basic
 *     responses:
 *       200:
 *         description: Bulk analysis initiated successfully
 *       400:
 *         description: Invalid URLs or too many URLs
 */
router.post('/bulk-analyze', analysisLimiter, [
  body('urls')
    .isArray({ min: 1, max: 10 })
    .withMessage('URLs array must contain 1-10 URLs'),
  body('urls.*')
    .isURL({ protocols: ['http', 'https'] })
    .withMessage('Each URL must be valid'),
  body('depth')
    .optional()
    .isIn(['basic', 'standard'])
    .withMessage('Bulk analysis only supports basic or standard depth'),
  validateRequest,
], async (req, res, next) => {
  try {
    const { urls, depth = 'basic' } = req.body;

    // Start bulk analysis (would typically be queued)
    const analysisPromises = urls.map((url: string) =>
      seoAnalysisService.analyzePage(url, {
        tenantId: req.user?.tenantId,
        userId: req.user?.id,
        depth,
      })
    );

    const results = await Promise.allSettled(analysisPromises);

    const successful = results
      .filter(result => result.status === 'fulfilled')
      .map(result => (result as PromiseFulfilledResult<any>).value);

    const failed = results
      .filter(result => result.status === 'rejected')
      .map((result, index) => ({
        url: urls[index],
        error: (result as PromiseRejectedResult).reason.message,
      }));

    logAudit('bulk_seo_analysis_performed', req.user?.id, {
      urlCount: urls.length,
      successCount: successful.length,
      failureCount: failed.length,
    });

    res.json({
      success: true,
      data: {
        successful,
        failed,
        summary: {
          total: urls.length,
          successful: successful.length,
          failed: failed.length,
        },
      },
      message: 'Bulk SEO analysis completed',
    });
  } catch (error) {
    next(error);
  }
});

export { router as seoRouter };