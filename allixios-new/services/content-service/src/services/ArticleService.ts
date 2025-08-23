/**
 * Article Service
 * Business logic for article management
 */

import { DatabaseManager } from '../database/DatabaseManager';
import { RedisManager } from '../cache/RedisManager';
import { ElasticsearchManager } from '../search/ElasticsearchManager';
import { logger } from '../utils/logger';
import slugify from 'slugify';

export interface Article {
  id: string;
  title: string;
  content: string;
  excerpt?: string;
  slug: string;
  status: 'draft' | 'review' | 'published' | 'archived';
  author_id: string;
  tenant_id: string;
  niche_id?: string;
  category_id?: string;
  featured_image_id?: string;
  meta_title?: string;
  meta_description?: string;
  language: string;
  reading_time?: number;
  word_count?: number;
  view_count: number;
  engagement_score: number;
  published_at?: Date;
  created_at: Date;
  updated_at: Date;
}

export class ArticleService {
  async getArticles(options: {
    page: number;
    limit: number;
    filters: any;
    sort: string;
    order: string;
    tenantId?: string;
    includeMedia?: boolean;
  }) {
    const { page, limit, filters, sort, order, tenantId, includeMedia } = options;
    const offset = (page - 1) * limit;

    // Build WHERE clause
    const conditions: string[] = [];
    const params: any[] = [];
    let paramIndex = 1;

    if (tenantId) {
      conditions.push(`a.tenant_id = $${paramIndex++}`);
      params.push(tenantId);
    }

    if (filters.status) {
      conditions.push(`a.status = $${paramIndex++}`);
      params.push(filters.status);
    }

    if (filters.niche_id) {
      conditions.push(`a.niche_id = $${paramIndex++}`);
      params.push(filters.niche_id);
    }

    if (filters.category_id) {
      conditions.push(`a.category_id = $${paramIndex++}`);
      params.push(filters.category_id);
    }

    if (filters.author_id) {
      conditions.push(`a.author_id = $${paramIndex++}`);
      params.push(filters.author_id);
    }

    if (filters.search) {
      conditions.push(`(a.title ILIKE $${paramIndex} OR a.content ILIKE $${paramIndex})`);
      params.push(`%${filters.search}%`);
      paramIndex++;
    }

    const whereClause = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';

    // Build ORDER BY clause
    const validSortFields = ['created_at', 'updated_at', 'published_at', 'view_count', 'engagement_score'];
    const sortField = validSortFields.includes(sort) ? sort : 'created_at';
    const sortOrder = order.toUpperCase() === 'ASC' ? 'ASC' : 'DESC';

    // Get total count
    const countQuery = `
      SELECT COUNT(*) as total
      FROM articles a
      ${whereClause}
    `;
    const countResult = await DatabaseManager.query(countQuery, params);
    const total = parseInt(countResult.rows[0].total);

    // Get articles
    const articlesQuery = `
      SELECT 
        a.*,
        au.name as author_name,
        au.email as author_email,
        c.name as category_name,
        n.name as niche_name
      FROM articles a
      LEFT JOIN authors au ON a.author_id = au.id
      LEFT JOIN categories c ON a.category_id = c.id
      LEFT JOIN niches n ON a.niche_id = n.id
      ${whereClause}
      ORDER BY a.${sortField} ${sortOrder}
      LIMIT $${paramIndex} OFFSET $${paramIndex + 1}
    `;
    params.push(limit, offset);

    const articlesResult = await DatabaseManager.query(articlesQuery, params);

    return {
      articles: articlesResult.rows,
      total,
    };
  }

  async getArticleById(id: string, options: {
    tenantId?: string;
    includeMedia?: boolean;
    includeAnalytics?: boolean;
  }) {
    const { tenantId, includeMedia, includeAnalytics } = options;

    // Try cache first
    const cacheKey = `article:${id}:${tenantId || 'public'}`;
    const cached = await RedisManager.get(cacheKey);
    if (cached) {
      return JSON.parse(cached);
    }

    const conditions = ['a.id = $1'];
    const params = [id];

    if (tenantId) {
      conditions.push('a.tenant_id = $2');
      params.push(tenantId);
    }

    const query = `
      SELECT 
        a.*,
        au.name as author_name,
        au.email as author_email,
        au.bio as author_bio,
        c.name as category_name,
        c.slug as category_slug,
        n.name as niche_name,
        n.slug as niche_slug
      FROM articles a
      LEFT JOIN authors au ON a.author_id = au.id
      LEFT JOIN categories c ON a.category_id = c.id
      LEFT JOIN niches n ON a.niche_id = n.id
      WHERE ${conditions.join(' AND ')}
    `;

    const result = await DatabaseManager.query(query, params);
    const article = result.rows[0];

    if (!article) {
      return null;
    }

    // Cache the result
    await RedisManager.setex(cacheKey, 300, JSON.stringify(article)); // 5 minutes

    return article;
  }

  async createArticle(data: Partial<Article>) {
    const slug = this.generateSlug(data.title!);
    
    const query = `
      INSERT INTO articles (
        title, content, excerpt, slug, status, author_id, tenant_id,
        niche_id, category_id, featured_image_id, meta_title, meta_description,
        language, reading_time, word_count
      ) VALUES (
        $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15
      ) RETURNING *
    `;

    const params = [
      data.title,
      data.content,
      data.excerpt,
      slug,
      data.status || 'draft',
      data.author_id,
      data.tenant_id,
      data.niche_id,
      data.category_id,
      data.featured_image_id,
      data.meta_title,
      data.meta_description,
      data.language || 'en',
      this.calculateReadingTime(data.content!),
      this.calculateWordCount(data.content!),
    ];

    const result = await DatabaseManager.query(query, params);
    const article = result.rows[0];

    // Index in Elasticsearch
    if (article.status === 'published') {
      await this.indexArticle(article);
    }

    return article;
  }

  async updateArticle(id: string, data: Partial<Article>, options: {
    tenantId?: string;
    userId?: string;
  }) {
    const { tenantId, userId } = options;

    // Build update query
    const updateFields: string[] = [];
    const params: any[] = [];
    let paramIndex = 1;

    if (data.title) {
      updateFields.push(`title = $${paramIndex++}`);
      params.push(data.title);
      
      updateFields.push(`slug = $${paramIndex++}`);
      params.push(this.generateSlug(data.title));
    }

    if (data.content) {
      updateFields.push(`content = $${paramIndex++}`);
      params.push(data.content);
      
      updateFields.push(`reading_time = $${paramIndex++}`);
      params.push(this.calculateReadingTime(data.content));
      
      updateFields.push(`word_count = $${paramIndex++}`);
      params.push(this.calculateWordCount(data.content));
    }

    if (data.excerpt !== undefined) {
      updateFields.push(`excerpt = $${paramIndex++}`);
      params.push(data.excerpt);
    }

    if (data.status) {
      updateFields.push(`status = $${paramIndex++}`);
      params.push(data.status);
    }

    if (data.meta_title !== undefined) {
      updateFields.push(`meta_title = $${paramIndex++}`);
      params.push(data.meta_title);
    }

    if (data.meta_description !== undefined) {
      updateFields.push(`meta_description = $${paramIndex++}`);
      params.push(data.meta_description);
    }

    updateFields.push(`updated_at = NOW()`);

    const conditions = [`id = $${paramIndex++}`];
    params.push(id);

    if (tenantId) {
      conditions.push(`tenant_id = $${paramIndex++}`);
      params.push(tenantId);
    }

    const query = `
      UPDATE articles 
      SET ${updateFields.join(', ')}
      WHERE ${conditions.join(' AND ')}
      RETURNING *
    `;

    const result = await DatabaseManager.query(query, params);
    const article = result.rows[0];

    if (article) {
      // Clear cache
      await RedisManager.del(`article:${id}:${tenantId || 'public'}`);
      
      // Update search index
      if (article.status === 'published') {
        await this.indexArticle(article);
      } else {
        await this.removeFromIndex(id);
      }
    }

    return article;
  }

  async deleteArticle(id: string, options: {
    tenantId?: string;
    userId?: string;
  }) {
    const { tenantId, userId } = options;

    const conditions = ['id = $1'];
    const params = [id];

    if (tenantId) {
      conditions.push('tenant_id = $2');
      params.push(tenantId);
    }

    const query = `
      DELETE FROM articles 
      WHERE ${conditions.join(' AND ')}
      RETURNING id
    `;

    const result = await DatabaseManager.query(query, params);
    
    if (result.rows.length > 0) {
      // Clear cache
      await RedisManager.del(`article:${id}:${tenantId || 'public'}`);
      
      // Remove from search index
      await this.removeFromIndex(id);
      
      return true;
    }

    return false;
  }

  async publishArticle(id: string, options: {
    tenantId?: string;
    userId?: string;
  }) {
    const article = await this.updateArticle(id, {
      status: 'published',
      published_at: new Date(),
    }, options);

    if (article) {
      // Index in search
      await this.indexArticle(article);
      
      logger.info('Article published', {
        articleId: id,
        title: article.title,
        userId: options.userId,
      });
    }

    return article;
  }

  async trackView(id: string, viewData: {
    userId?: string;
    sessionId: string;
    userAgent?: string;
    referrer?: string;
    ip: string;
  }) {
    // Insert view record
    const viewQuery = `
      INSERT INTO article_views (article_id, user_id, session_id, user_agent, referrer, ip_address)
      VALUES ($1, $2, $3, $4, $5, $6)
    `;
    
    await DatabaseManager.query(viewQuery, [
      id,
      viewData.userId,
      viewData.sessionId,
      viewData.userAgent,
      viewData.referrer,
      viewData.ip,
    ]);

    // Update view count
    const updateQuery = `
      UPDATE articles 
      SET view_count = view_count + 1
      WHERE id = $1
    `;
    
    await DatabaseManager.query(updateQuery, [id]);
  }

  async getArticleAnalytics(id: string, period: string) {
    // This would integrate with analytics service
    // For now, return basic stats from database
    
    const query = `
      SELECT 
        COUNT(*) as total_views,
        COUNT(DISTINCT user_id) as unique_users,
        COUNT(DISTINCT session_id) as unique_sessions
      FROM article_views 
      WHERE article_id = $1 
      AND created_at >= NOW() - INTERVAL '${period === '1d' ? '1 day' : period === '7d' ? '7 days' : period === '90d' ? '90 days' : '30 days'}'
    `;

    const result = await DatabaseManager.query(query, [id]);
    return result.rows[0];
  }

  async createArticlesBatch(articles: Partial<Article>[], options: {
    tenantId?: string;
    userId?: string;
  }) {
    const results = [];
    
    for (const articleData of articles) {
      const article = await this.createArticle({
        ...articleData,
        tenant_id: options.tenantId,
      });
      results.push(article);
    }

    return results;
  }

  private generateSlug(title: string): string {
    return slugify(title, {
      lower: true,
      strict: true,
      remove: /[*+~.()'"!:@]/g,
    });
  }

  private calculateReadingTime(content: string): number {
    const wordsPerMinute = 200;
    const wordCount = this.calculateWordCount(content);
    return Math.ceil(wordCount / wordsPerMinute);
  }

  private calculateWordCount(content: string): number {
    return content.trim().split(/\s+/).length;
  }

  private async indexArticle(article: any) {
    try {
      await ElasticsearchManager.index('articles', article.id, {
        title: article.title,
        content: article.content,
        excerpt: article.excerpt,
        author_name: article.author_name,
        category_name: article.category_name,
        niche_name: article.niche_name,
        status: article.status,
        published_at: article.published_at,
        created_at: article.created_at,
      });
    } catch (error) {
      logger.error('Failed to index article:', error);
    }
  }

  private async removeFromIndex(id: string) {
    try {
      await ElasticsearchManager.delete('articles', id);
    } catch (error) {
      logger.error('Failed to remove article from index:', error);
    }
  }
}