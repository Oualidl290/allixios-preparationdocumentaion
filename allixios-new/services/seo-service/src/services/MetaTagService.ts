/**
 * Meta Tag Service
 * AI-powered meta tag generation and optimization
 */

import axios from 'axios';
import cheerio from 'cheerio';
import { DatabaseManager } from '../database/DatabaseManager';
import { CacheManager } from '../cache/CacheManager';
import { AIService } from './AIService';
import { config } from '../config';
import { logger, logAIOperation, logError } from '../utils/logger';
import {
  MetaTagSuggestions,
  MetaTitleSuggestion,
  MetaDescriptionSuggestion,
  OpenGraphSuggestions,
  TwitterCardSuggestions,
  JsonLdSuggestions,
} from '../types';

export class MetaTagService {
  private cacheManager: CacheManager;
  private aiService: AIService;

  constructor() {
    this.cacheManager = new CacheManager();
    this.aiService = new AIService();
  }

  /**
   * Generate comprehensive meta tag suggestions
   */
  async generateMetaTags(
    url: string,
    options: {
      targetKeywords?: string[];
      contentType?: string;
      customData?: Record<string, any>;
      tenantId?: string;
    } = {}
  ): Promise<MetaTagSuggestions> {
    const { targetKeywords = [], contentType = 'article', customData = {}, tenantId } = options;

    try {
      logger.info('Generating meta tags', { url, contentType, keywordCount: targetKeywords.length });

      // Check cache first
      const cacheKey = `meta-tags:${url}:${contentType}:${targetKeywords.join(',')}`;
      const cached = await this.cacheManager.get(cacheKey);
      if (cached) {
        return JSON.parse(cached);
      }

      // Fetch and analyze page content
      const pageData = await this.fetchPageContent(url);
      const contentAnalysis = await this.analyzePageContent(pageData, targetKeywords);

      // Generate title suggestions
      const titleSuggestions = await this.generateTitleSuggestions(
        contentAnalysis,
        targetKeywords,
        contentType
      );

      // Generate description suggestions
      const descriptionSuggestions = await this.generateDescriptionSuggestions(
        contentAnalysis,
        targetKeywords,
        contentType
      );

      // Generate keyword suggestions
      const keywordSuggestions = await this.generateKeywordSuggestions(
        contentAnalysis,
        targetKeywords
      );

      // Generate Open Graph suggestions
      const openGraphSuggestions = await this.generateOpenGraphSuggestions(
        contentAnalysis,
        titleSuggestions[0],
        descriptionSuggestions[0]
      );

      // Generate Twitter Card suggestions
      const twitterCardSuggestions = await this.generateTwitterCardSuggestions(
        contentAnalysis,
        titleSuggestions[0],
        descriptionSuggestions[0]
      );

      // Generate JSON-LD suggestions
      const jsonLdSuggestions = await this.generateJsonLdSuggestions(
        contentAnalysis,
        contentType,
        customData
      );

      const suggestions: MetaTagSuggestions = {
        title: titleSuggestions,
        description: descriptionSuggestions,
        keywords: keywordSuggestions,
        openGraph: openGraphSuggestions,
        twitterCards: twitterCardSuggestions,
        jsonLd: jsonLdSuggestions,
      };

      // Save suggestions to database
      await this.saveMetaTagSuggestions(url, suggestions, tenantId);

      // Cache results
      await this.cacheManager.setex(cacheKey, 3600, JSON.stringify(suggestions)); // 1 hour

      return suggestions;
    } catch (error) {
      logError(error as Error, { context: 'Meta tag generation', url });
      throw error;
    }
  }

  /**
   * Fetch page content for analysis
   */
  private async fetchPageContent(url: string): Promise<{
    html: string;
    title: string;
    description: string;
    headings: string[];
    content: string;
    images: string[];
  }> {
    try {
      const response = await axios.get(url, {
        timeout: 15000,
        headers: {
          'User-Agent': 'Mozilla/5.0 (compatible; AllixiosSEOBot/2.0; +https://allixios.com/seobot)',
        },
      });

      const $ = cheerio.load(response.data);

      // Extract existing meta data
      const title = $('title').text().trim();
      const description = $('meta[name="description"]').attr('content') || '';

      // Extract headings
      const headings: string[] = [];
      $('h1, h2, h3').each((_, el) => {
        const text = $(el).text().trim();
        if (text) headings.push(text);
      });

      // Extract main content
      const content = $('body').text().replace(/\s+/g, ' ').trim();

      // Extract images
      const images: string[] = [];
      $('img[src]').each((_, el) => {
        const src = $(el).attr('src');
        if (src) {
          try {
            const imageUrl = new URL(src, url).href;
            images.push(imageUrl);
          } catch {
            // Invalid URL, skip
          }
        }
      });

      return {
        html: response.data,
        title,
        description,
        headings,
        content,
        images,
      };
    } catch (error) {
      logError(error as Error, { context: 'Fetching page content', url });
      throw new Error(`Failed to fetch page content: ${error.message}`);
    }
  }

  /**
   * Analyze page content for meta tag generation
   */
  private async analyzePageContent(
    pageData: any,
    targetKeywords: string[]
  ): Promise<{
    mainTopic: string;
    keyPoints: string[];
    tone: string;
    audience: string;
    contentLength: number;
    existingTitle: string;
    existingDescription: string;
    primaryHeading: string;
    keywordDensity: Record<string, number>;
  }> {
    const { title, description, headings, content } = pageData;
    const words = content.toLowerCase().split(/\s+/);
    const wordCount = words.length;

    // Calculate keyword density
    const keywordDensity: Record<string, number> = {};
    targetKeywords.forEach(keyword => {
      const keywordWords = keyword.toLowerCase().split(/\s+/);
      let count = 0;
      
      for (let i = 0; i <= words.length - keywordWords.length; i++) {
        const phrase = words.slice(i, i + keywordWords.length).join(' ');
        if (phrase === keyword.toLowerCase()) {
          count++;
        }
      }
      
      keywordDensity[keyword] = (count / wordCount) * 100;
    });

    // Use AI to analyze content if available
    let aiAnalysis = null;
    if (config.ai.enabled && config.ai.contentOptimization.enabled) {
      try {
        aiAnalysis = await this.aiService.analyzeContentForSEO(content, targetKeywords);
      } catch (error) {
        logger.warn('AI content analysis failed', { error: error.message });
      }
    }

    return {
      mainTopic: aiAnalysis?.mainTopic || this.extractMainTopic(headings, content),
      keyPoints: aiAnalysis?.keyPoints || this.extractKeyPoints(headings),
      tone: aiAnalysis?.tone || 'professional',
      audience: aiAnalysis?.audience || 'general',
      contentLength: wordCount,
      existingTitle: title,
      existingDescription: description,
      primaryHeading: headings[0] || '',
      keywordDensity,
    };
  }

  /**
   * Generate title suggestions
   */
  private async generateTitleSuggestions(
    contentAnalysis: any,
    targetKeywords: string[],
    contentType: string
  ): Promise<MetaTitleSuggestion[]> {
    const suggestions: MetaTitleSuggestion[] = [];
    const { mainTopic, tone, primaryHeading } = contentAnalysis;
    const primaryKeyword = targetKeywords[0] || mainTopic;

    // Template-based suggestions
    const templates = this.getTitleTemplates(contentType);
    
    for (const template of templates) {
      const title = this.fillTemplate(template, {
        keyword: primaryKeyword,
        topic: mainTopic,
        year: new Date().getFullYear().toString(),
      });

      if (title.length <= config.metaTags.titleMaxLength) {
        suggestions.push({
          title,
          length: title.length,
          score: this.scoreTitleSuggestion(title, targetKeywords, contentAnalysis),
          reasoning: `Template-based suggestion for ${contentType} content`,
        });
      }
    }

    // AI-generated suggestions if available
    if (config.ai.enabled && config.ai.contentOptimization.autoSuggestTitles) {
      try {
        const aiSuggestions = await this.aiService.generateTitleSuggestions(
          contentAnalysis,
          targetKeywords,
          contentType
        );

        aiSuggestions.forEach((aiTitle: string) => {
          if (aiTitle.length <= config.metaTags.titleMaxLength) {
            suggestions.push({
              title: aiTitle,
              length: aiTitle.length,
              score: this.scoreTitleSuggestion(aiTitle, targetKeywords, contentAnalysis),
              reasoning: 'AI-generated suggestion based on content analysis',
            });
          }
        });
      } catch (error) {
        logger.warn('AI title generation failed', { error: error.message });
      }
    }

    // Optimization-based suggestions
    if (contentAnalysis.existingTitle) {
      const optimizedTitle = this.optimizeExistingTitle(
        contentAnalysis.existingTitle,
        targetKeywords
      );

      if (optimizedTitle !== contentAnalysis.existingTitle) {
        suggestions.push({
          title: optimizedTitle,
          length: optimizedTitle.length,
          score: this.scoreTitleSuggestion(optimizedTitle, targetKeywords, contentAnalysis),
          reasoning: 'Optimized version of existing title',
        });
      }
    }

    // Sort by score and return top suggestions
    return suggestions
      .sort((a, b) => b.score - a.score)
      .slice(0, 5);
  }

  /**
   * Generate description suggestions
   */
  private async generateDescriptionSuggestions(
    contentAnalysis: any,
    targetKeywords: string[],
    contentType: string
  ): Promise<MetaDescriptionSuggestion[]> {
    const suggestions: MetaDescriptionSuggestion[] = [];
    const { mainTopic, keyPoints } = contentAnalysis;

    // Template-based suggestions
    const templates = this.getDescriptionTemplates(contentType);
    
    for (const template of templates) {
      const description = this.fillTemplate(template, {
        keyword: targetKeywords[0] || mainTopic,
        topic: mainTopic,
        keyPoints: keyPoints.slice(0, 2).join(', '),
      });

      if (description.length <= config.metaTags.descriptionMaxLength) {
        suggestions.push({
          description,
          length: description.length,
          score: this.scoreDescriptionSuggestion(description, targetKeywords, contentAnalysis),
          reasoning: `Template-based suggestion for ${contentType} content`,
        });
      }
    }

    // AI-generated suggestions if available
    if (config.ai.enabled && config.ai.contentOptimization.autoSuggestDescriptions) {
      try {
        const aiSuggestions = await this.aiService.generateDescriptionSuggestions(
          contentAnalysis,
          targetKeywords,
          contentType
        );

        aiSuggestions.forEach((aiDescription: string) => {
          if (aiDescription.length <= config.metaTags.descriptionMaxLength) {
            suggestions.push({
              description: aiDescription,
              length: aiDescription.length,
              score: this.scoreDescriptionSuggestion(aiDescription, targetKeywords, contentAnalysis),
              reasoning: 'AI-generated suggestion based on content analysis',
            });
          }
        });
      } catch (error) {
        logger.warn('AI description generation failed', { error: error.message });
      }
    }

    // Content-based suggestion
    const contentBasedDescription = this.generateContentBasedDescription(
      contentAnalysis,
      targetKeywords
    );

    if (contentBasedDescription.length <= config.metaTags.descriptionMaxLength) {
      suggestions.push({
        description: contentBasedDescription,
        length: contentBasedDescription.length,
        score: this.scoreDescriptionSuggestion(contentBasedDescription, targetKeywords, contentAnalysis),
        reasoning: 'Generated from page content and key points',
      });
    }

    // Sort by score and return top suggestions
    return suggestions
      .sort((a, b) => b.score - a.score)
      .slice(0, 5);
  }

  /**
   * Generate keyword suggestions
   */
  private async generateKeywordSuggestions(
    contentAnalysis: any,
    targetKeywords: string[]
  ): Promise<string[]> {
    const keywords = new Set(targetKeywords);
    const { content, mainTopic } = contentAnalysis;

    // Extract keywords from content
    const words = content.toLowerCase().match(/\b\w{4,}\b/g) || [];
    const wordFreq: Record<string, number> = {};

    words.forEach(word => {
      if (word.length > 3 && !this.isStopWord(word)) {
        wordFreq[word] = (wordFreq[word] || 0) + 1;
      }
    });

    // Add high-frequency words as keywords
    Object.entries(wordFreq)
      .sort(([, a], [, b]) => b - a)
      .slice(0, 5)
      .forEach(([word]) => keywords.add(word));

    // Add main topic variations
    if (mainTopic) {
      keywords.add(mainTopic.toLowerCase());
      
      // Add plurals and variations
      const variations = this.generateKeywordVariations(mainTopic);
      variations.forEach(variation => keywords.add(variation));
    }

    return Array.from(keywords).slice(0, config.metaTags.keywordsMaxCount);
  }

  /**
   * Generate Open Graph suggestions
   */
  private async generateOpenGraphSuggestions(
    contentAnalysis: any,
    titleSuggestion: MetaTitleSuggestion,
    descriptionSuggestion: MetaDescriptionSuggestion
  ): Promise<OpenGraphSuggestions> {
    return {
      title: titleSuggestion.title,
      description: descriptionSuggestion.description,
      image: '', // Would be populated with best image from page
      type: this.getOpenGraphType(contentAnalysis),
      url: '', // Would be the canonical URL
    };
  }

  /**
   * Generate Twitter Card suggestions
   */
  private async generateTwitterCardSuggestions(
    contentAnalysis: any,
    titleSuggestion: MetaTitleSuggestion,
    descriptionSuggestion: MetaDescriptionSuggestion
  ): Promise<TwitterCardSuggestions> {
    return {
      card: 'summary_large_image',
      title: titleSuggestion.title,
      description: descriptionSuggestion.description,
      image: '', // Would be populated with best image from page
    };
  }

  /**
   * Generate JSON-LD suggestions
   */
  private async generateJsonLdSuggestions(
    contentAnalysis: any,
    contentType: string,
    customData: Record<string, any>
  ): Promise<JsonLdSuggestions> {
    const schemaType = this.getSchemaType(contentType);
    
    const baseData = {
      '@context': 'https://schema.org',
      '@type': schemaType,
      name: contentAnalysis.primaryHeading || contentAnalysis.mainTopic,
      description: contentAnalysis.existingDescription || contentAnalysis.keyPoints.join('. '),
      ...customData,
    };

    return {
      type: schemaType,
      data: baseData,
    };
  }

  /**
   * Helper methods
   */

  private getTitleTemplates(contentType: string): string[] {
    const templates: Record<string, string[]> = {
      article: [
        '{keyword}: Complete Guide for {year}',
        'How to {keyword} - Step by Step Guide',
        '{keyword} Explained: Everything You Need to Know',
        'The Ultimate {keyword} Guide',
        '{keyword} Tips and Best Practices',
      ],
      product: [
        '{keyword} - Best {topic} for {year}',
        'Buy {keyword} - Top Quality {topic}',
        '{keyword} Review: Features, Price & More',
        'Premium {keyword} - {topic} Collection',
      ],
      homepage: [
        '{keyword} - {topic} Services',
        'Professional {keyword} Solutions',
        '{topic} Expert - {keyword} Services',
      ],
      category: [
        '{keyword} - Browse {topic} Collection',
        'Best {keyword} - {topic} Category',
        '{topic} {keyword} - Complete Selection',
      ],
    };

    return templates[contentType] || templates.article;
  }

  private getDescriptionTemplates(contentType: string): string[] {
    const templates: Record<string, string[]> = {
      article: [
        'Learn everything about {keyword}. Our comprehensive guide covers {keyPoints} and more. Get expert insights and practical tips.',
        'Discover the best {keyword} strategies. This detailed guide explains {keyPoints} with real examples and actionable advice.',
        'Master {keyword} with our complete guide. Learn about {keyPoints} and become an expert in {topic}.',
      ],
      product: [
        'Shop the best {keyword} for {topic}. High quality, competitive prices, and fast shipping. {keyPoints} available.',
        'Premium {keyword} collection. Find the perfect {topic} with features like {keyPoints}. Order now!',
      ],
      homepage: [
        'Professional {keyword} services for {topic}. We specialize in {keyPoints} and deliver exceptional results.',
        'Expert {keyword} solutions. Our team provides {keyPoints} services to help you succeed in {topic}.',
      ],
    };

    return templates[contentType] || templates.article;
  }

  private fillTemplate(template: string, variables: Record<string, string>): string {
    let result = template;
    
    Object.entries(variables).forEach(([key, value]) => {
      const regex = new RegExp(`\\{${key}\\}`, 'g');
      result = result.replace(regex, value);
    });

    return result;
  }

  private scoreTitleSuggestion(
    title: string,
    targetKeywords: string[],
    contentAnalysis: any
  ): number {
    let score = 50; // Base score

    // Length scoring
    const length = title.length;
    if (length >= 30 && length <= 60) score += 20;
    else if (length >= 20 && length <= 70) score += 10;
    else score -= 10;

    // Keyword presence
    const titleLower = title.toLowerCase();
    targetKeywords.forEach(keyword => {
      if (titleLower.includes(keyword.toLowerCase())) {
        score += 15;
      }
    });

    // Uniqueness (not same as existing)
    if (title !== contentAnalysis.existingTitle) {
      score += 10;
    }

    // Readability
    if (title.split(' ').length <= 10) score += 5;
    if (!/[!@#$%^&*()_+={}\[\]:";'<>?,./]/.test(title)) score += 5;

    return Math.max(0, Math.min(100, score));
  }

  private scoreDescriptionSuggestion(
    description: string,
    targetKeywords: string[],
    contentAnalysis: any
  ): number {
    let score = 50; // Base score

    // Length scoring
    const length = description.length;
    if (length >= 120 && length <= 160) score += 20;
    else if (length >= 100 && length <= 170) score += 10;
    else score -= 10;

    // Keyword presence
    const descriptionLower = description.toLowerCase();
    targetKeywords.forEach(keyword => {
      if (descriptionLower.includes(keyword.toLowerCase())) {
        score += 10;
      }
    });

    // Call-to-action presence
    const ctaWords = ['learn', 'discover', 'find', 'get', 'buy', 'shop', 'read'];
    if (ctaWords.some(word => descriptionLower.includes(word))) {
      score += 10;
    }

    // Uniqueness
    if (description !== contentAnalysis.existingDescription) {
      score += 10;
    }

    return Math.max(0, Math.min(100, score));
  }

  private extractMainTopic(headings: string[], content: string): string {
    if (headings.length > 0) {
      return headings[0];
    }

    // Extract from content (simplified)
    const words = content.split(/\s+/).slice(0, 50);
    return words.join(' ').substring(0, 50);
  }

  private extractKeyPoints(headings: string[]): string[] {
    return headings.slice(1, 4); // Take H2, H3 headings as key points
  }

  private optimizeExistingTitle(title: string, targetKeywords: string[]): string {
    let optimized = title;
    
    // Add primary keyword if not present
    const primaryKeyword = targetKeywords[0];
    if (primaryKeyword && !title.toLowerCase().includes(primaryKeyword.toLowerCase())) {
      optimized = `${primaryKeyword} - ${title}`;
    }

    // Truncate if too long
    if (optimized.length > config.metaTags.titleMaxLength) {
      optimized = optimized.substring(0, config.metaTags.titleMaxLength - 3) + '...';
    }

    return optimized;
  }

  private generateContentBasedDescription(
    contentAnalysis: any,
    targetKeywords: string[]
  ): string {
    const { keyPoints, mainTopic } = contentAnalysis;
    const primaryKeyword = targetKeywords[0] || mainTopic;
    
    let description = `Learn about ${primaryKeyword}.`;
    
    if (keyPoints.length > 0) {
      description += ` This guide covers ${keyPoints.slice(0, 2).join(' and ')}.`;
    }
    
    description += ' Get expert insights and practical advice.';
    
    return description.substring(0, config.metaTags.descriptionMaxLength);
  }

  private isStopWord(word: string): boolean {
    const stopWords = new Set([
      'the', 'a', 'an', 'and', 'or', 'but', 'in', 'on', 'at', 'to', 'for',
      'of', 'with', 'by', 'is', 'are', 'was', 'were', 'be', 'been', 'have',
      'has', 'had', 'do', 'does', 'did', 'will', 'would', 'could', 'should',
      'this', 'that', 'these', 'those', 'i', 'you', 'he', 'she', 'it', 'we', 'they'
    ]);
    
    return stopWords.has(word.toLowerCase());
  }

  private generateKeywordVariations(keyword: string): string[] {
    const variations = [];
    
    // Add plural
    if (!keyword.endsWith('s')) {
      variations.push(keyword + 's');
    }
    
    // Add common suffixes
    variations.push(keyword + 'ing');
    variations.push(keyword + 'ed');
    
    return variations;
  }

  private getOpenGraphType(contentAnalysis: any): string {
    // Determine OG type based on content
    return 'article'; // Simplified
  }

  private getSchemaType(contentType: string): string {
    const schemaTypes: Record<string, string> = {
      article: 'Article',
      product: 'Product',
      homepage: 'WebSite',
      category: 'CollectionPage',
    };
    
    return schemaTypes[contentType] || 'WebPage';
  }

  /**
   * Save meta tag suggestions to database
   */
  private async saveMetaTagSuggestions(
    url: string,
    suggestions: MetaTagSuggestions,
    tenantId?: string
  ): Promise<void> {
    try {
      // Save title suggestions
      for (const titleSuggestion of suggestions.title) {
        await DatabaseManager.query(
          `INSERT INTO meta_tag_suggestions (
            url, type, suggestion, score, reasoning, tenant_id
          ) VALUES ($1, $2, $3, $4, $5, $6)`,
          [url, 'title', titleSuggestion.title, titleSuggestion.score, titleSuggestion.reasoning, tenantId]
        );
      }

      // Save description suggestions
      for (const descSuggestion of suggestions.description) {
        await DatabaseManager.query(
          `INSERT INTO meta_tag_suggestions (
            url, type, suggestion, score, reasoning, tenant_id
          ) VALUES ($1, $2, $3, $4, $5, $6)`,
          [url, 'description', descSuggestion.description, descSuggestion.score, descSuggestion.reasoning, tenantId]
        );
      }

      // Save other suggestions as JSON
      await DatabaseManager.query(
        `INSERT INTO meta_tag_suggestions (
          url, type, suggestion, score, reasoning, tenant_id
        ) VALUES ($1, $2, $3, $4, $5, $6)`,
        [url, 'keywords', JSON.stringify(suggestions.keywords), 80, 'Generated keyword suggestions', tenantId]
      );
    } catch (error) {
      logError(error as Error, { context: 'Saving meta tag suggestions', url });
    }
  }
}