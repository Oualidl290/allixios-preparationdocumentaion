/**
 * Media Service
 * Business logic for media management
 */

import { DatabaseManager } from '../database/DatabaseManager';
import { logger } from '../utils/logger';

export class MediaService {
  async getArticleMedia(articleId: string, usageType?: string) {
    const conditions = ['am.article_id = $1'];
    const params = [articleId];

    if (usageType) {
      conditions.push('am.usage_type = $2');
      params.push(usageType);
    }

    const query = `
      SELECT 
        m.*,
        am.usage_type,
        am.position,
        am.section,
        am.alignment,
        am.size,
        am.caption_override,
        am.alt_text_override
      FROM article_media am
      JOIN media m ON am.media_id = m.id
      WHERE ${conditions.join(' AND ')}
      ORDER BY am.position ASC, am.created_at ASC
    `;

    const result = await DatabaseManager.query(query, params);
    return result.rows;
  }

  async attachMediaToArticle(articleId: string, mediaData: {
    media_id: string;
    usage_type?: string;
    position?: number;
    section?: string;
    alignment?: string;
    size?: string;
    caption_override?: string;
    alt_text_override?: string;
  }) {
    const query = `
      INSERT INTO article_media (
        article_id, media_id, usage_type, position, section,
        alignment, size, caption_override, alt_text_override
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
      RETURNING *
    `;

    const params = [
      articleId,
      mediaData.media_id,
      mediaData.usage_type || 'content',
      mediaData.position,
      mediaData.section,
      mediaData.alignment || 'center',
      mediaData.size || 'medium',
      mediaData.caption_override,
      mediaData.alt_text_override,
    ];

    const result = await DatabaseManager.query(query, params);
    return result.rows[0];
  }
}