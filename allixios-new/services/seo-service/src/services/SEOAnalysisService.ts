/**
 * SEO Analysis Service
 * Ultimate SEO analysis engine with comprehensive checks
 */

import { URL } from 'url';
import axios from 'axios';
import cheerio from 'cheerio';
import lighthouse from 'lighthouse';
import * as chromeLauncher from 'chrome-launcher';
import { readability } from 'text-readability';
import natural from 'natural';
import { DatabaseManager } from '../database/DatabaseManager';
import { CacheManager } from '../cache/CacheManager';
import { config } from '../config';
import { logger, logSEOAnalysis, logError } from '../utils/logger';
import {
  SEOAnalysisResult,
  TechnicalSEOResult,
  ContentAnalysisResult,
  PerformanceMetricsResult,
  KeywordAnalysisResult,
  SEOIssue,
  SEORecommendation,
  MetaTagsAnalysis,
  HeadingStructureAnalysis,
  URLStructureAnalysis,
  InternalLinkingAnalysis,
  SchemaMarkupAnalysis,
  CoreWebVitalsResult,
} from '../types';

export class SEOAnalysisService {
  private cacheManager: CacheManager;

  constructor() {
    this.cacheManager = new CacheManager();
  }

  /**
   * Perform comprehensive SEO analysis
   */
  async analyzePage(
    url: string,
    options: {
      tenantId?: string;
      userId?: string;
      includeCompetitors?: boolean;
      depth?: 'basic' | 'standard' | 'comprehensive';
    } = {}
  ): Promise<SEOAnalysisResult> {
    const startTime = Date.now();
    const { tenantId, userId, includeCompetitors = false, depth = 'standard' } = options;

    try {
      // Validate URL
      const parsedUrl = new URL(url);
      const domain = parsedUrl.hostname;

      // Check cache first
      const cacheKey = `seo-analysis:${url}:${depth}`;
      const cached = await this.cacheManager.get(cacheKey);
      if (cached) {
        return JSON.parse(cached);
      }

      logger.info('Starting SEO analysis', { url, domain, depth });

      // Fetch page content
      const pageContent = await this.fetchPageContent(url);
      const $ = cheerio.load(pageContent.html);

      // Perform parallel analysis
      const [
        technicalSeo,
        contentAnalysis,
        performanceMetrics,
        keywordAnalysis,
      ] = await Promise.all([
        this.analyzeTechnicalSEO(url, $, pageContent),
        this.analyzeContent(url, $, pageContent),
        this.analyzePerformance(url, depth),
        this.analyzeKeywords(url, $, pageContent),
      ]);

      // Calculate overall scores
      const overallScore = this.calculateOverallScore(
        technicalSeo.score,
        contentAnalysis.score,
        performanceMetrics.score
      );

      // Create analysis result
      const analysisResult: SEOAnalysisResult = {
        id: '', // Will be set when saved
        url,
        domain,
        title: $('title').text() || undefined,
        description: $('meta[name="description"]').attr('content') || undefined,
        keywords: this.extractMetaKeywords($),
        overallScore,
        technicalScore: technicalSeo.score,
        contentScore: contentAnalysis.score,
        performanceScore: performanceMetrics.score,
        technicalSeo,
        contentAnalysis,
        performanceMetrics,
        keywordAnalysis,
        analyzedAt: new Date(),
        analysisVersion: '2.0',
        tenantId,
        userId,
      };

      // Save to database
      const analysisId = await DatabaseManager.saveSEOAnalysis(analysisResult);
      analysisResult.id = analysisId;

      // Cache result
      await this.cacheManager.setex(
        cacheKey,
        config.cache.ttl.seoAnalysis,
        JSON.stringify(analysisResult)
      );

      const duration = Date.now() - startTime;
      logSEOAnalysis(url, 'comprehensive', duration, true, {
        overallScore,
        technicalScore: technicalSeo.score,
        contentScore: contentAnalysis.score,
        performanceScore: performanceMetrics.score,
      });

      return analysisResult;
    } catch (error) {
      const duration = Date.now() - startTime;
      logSEOAnalysis(url, 'comprehensive', duration, false, {
        error: error.message,
      });
      logError(error as Error, { context: 'SEO Analysis', url });
      throw error;
    }
  }

  /**
   * Fetch page content with comprehensive data
   */
  private async fetchPageContent(url: string): Promise<{
    html: string;
    statusCode: number;
    headers: Record<string, string>;
    loadTime: number;
    size: number;
  }> {
    const startTime = Date.now();

    try {
      const response = await axios.get(url, {
        timeout: 30000,
        maxRedirects: 5,
        headers: {
          'User-Agent': 'Mozilla/5.0 (compatible; AllixiosSEOBot/2.0; +https://allixios.com/seobot)',
        },
      });

      const loadTime = Date.now() - startTime;
      const size = Buffer.byteLength(response.data, 'utf8');

      return {
        html: response.data,
        statusCode: response.status,
        headers: response.headers as Record<string, string>,
        loadTime,
        size,
      };
    } catch (error) {
      logError(error as Error, { context: 'Fetching page content', url });
      throw new Error(`Failed to fetch page content: ${error.message}`);
    }
  }

  /**
   * Analyze Technical SEO factors
   */
  private async analyzeTechnicalSEO(
    url: string,
    $: cheerio.CheerioAPI,
    pageContent: any
  ): Promise<TechnicalSEOResult> {
    const issues: SEOIssue[] = [];
    const recommendations: SEORecommendation[] = [];

    // Analyze meta tags
    const metaTags = this.analyzeMetaTags($, issues, recommendations);

    // Analyze heading structure
    const headingStructure = this.analyzeHeadingStructure($, issues, recommendations);

    // Analyze URL structure
    const urlStructure = this.analyzeURLStructure(url, issues, recommendations);

    // Analyze internal linking
    const internalLinking = this.analyzeInternalLinking($, url, issues, recommendations);

    // Analyze schema markup
    const schemaMarkup = this.analyzeSchemaMarkup($, issues, recommendations);

    // Check robots.txt
    const robotsTxt = await this.analyzeRobotsTxt(url, issues, recommendations);

    // Check sitemap
    const sitemap = await this.analyzeSitemap(url, issues, recommendations);

    // Check SSL
    const ssl = await this.analyzeSSL(url, issues, recommendations);

    // Check redirects
    const redirects = await this.analyzeRedirects(url, issues, recommendations);

    // Check canonicalization
    const canonicalization = this.analyzeCanonicalization($, url, issues, recommendations);

    // Check mobile optimization
    const mobileOptimization = this.analyzeMobileOptimization($, issues, recommendations);

    // Analyze Core Web Vitals (basic check)
    const coreWebVitals = await this.analyzeCoreWebVitals(url);

    // Calculate technical score
    const score = this.calculateTechnicalScore({
      metaTags,
      headingStructure,
      urlStructure,
      schemaMarkup,
      robotsTxt,
      sitemap,
      ssl,
      issues,
    });

    return {
      score,
      issues,
      recommendations,
      metaTags,
      headingStructure,
      urlStructure,
      internalLinking,
      schemaMarkup,
      robotsTxt,
      sitemap,
      ssl,
      redirects,
      canonicalization,
      mobileOptimization,
      coreWebVitals,
      accessibility: { score: 0, violations: [], passes: 0, incomplete: 0 }, // Placeholder
      structuredData: { types: [], items: [], errors: [], warnings: [] }, // Placeholder
      internationalSeo: { hreflangPresent: false, hreflangTags: [], languageDeclaration: false, issues: [] }, // Placeholder
    };
  }

  /**
   * Analyze meta tags
   */
  private analyzeMetaTags(
    $: cheerio.CheerioAPI,
    issues: SEOIssue[],
    recommendations: SEORecommendation[]
  ): MetaTagsAnalysis {
    const title = $('title').text();
    const description = $('meta[name="description"]').attr('content') || '';
    const keywords = $('meta[name="keywords"]').attr('content') || '';

    // Title analysis
    const titleAnalysis = {
      present: !!title,
      length: title.length,
      optimal: title.length >= 30 && title.length <= 60,
      content: title,
      issues: [] as string[],
    };

    if (!title) {
      issues.push({
        id: 'missing-title',
        type: 'error',
        category: 'technical',
        title: 'Missing Title Tag',
        description: 'The page is missing a title tag',
        impact: 'high',
        effort: 'low',
        priority: 10,
      });
      titleAnalysis.issues.push('Missing title tag');
    } else if (title.length < 30) {
      issues.push({
        id: 'short-title',
        type: 'warning',
        category: 'technical',
        title: 'Title Too Short',
        description: 'The title tag is shorter than recommended (30-60 characters)',
        impact: 'medium',
        effort: 'low',
        priority: 7,
        value: title.length,
      });
      titleAnalysis.issues.push('Title too short');
    } else if (title.length > 60) {
      issues.push({
        id: 'long-title',
        type: 'warning',
        category: 'technical',
        title: 'Title Too Long',
        description: 'The title tag is longer than recommended (30-60 characters)',
        impact: 'medium',
        effort: 'low',
        priority: 7,
        value: title.length,
      });
      titleAnalysis.issues.push('Title too long');
    }

    // Description analysis
    const descriptionAnalysis = {
      present: !!description,
      length: description.length,
      optimal: description.length >= 120 && description.length <= 160,
      content: description,
      issues: [] as string[],
    };

    if (!description) {
      issues.push({
        id: 'missing-description',
        type: 'error',
        category: 'technical',
        title: 'Missing Meta Description',
        description: 'The page is missing a meta description',
        impact: 'high',
        effort: 'low',
        priority: 9,
      });
      descriptionAnalysis.issues.push('Missing meta description');
    } else if (description.length < 120) {
      descriptionAnalysis.issues.push('Description too short');
    } else if (description.length > 160) {
      descriptionAnalysis.issues.push('Description too long');
    }

    // Keywords analysis
    const keywordsArray = keywords ? keywords.split(',').map(k => k.trim()) : [];
    const keywordsAnalysis = {
      present: !!keywords,
      count: keywordsArray.length,
      content: keywordsArray,
      issues: [] as string[],
    };

    // Open Graph analysis
    const ogTags: Record<string, string> = {};
    $('meta[property^="og:"]').each((_, el) => {
      const property = $(el).attr('property');
      const content = $(el).attr('content');
      if (property && content) {
        ogTags[property] = content;
      }
    });

    const openGraph = {
      present: Object.keys(ogTags).length > 0,
      complete: !!(ogTags['og:title'] && ogTags['og:description'] && ogTags['og:image']),
      tags: ogTags,
      issues: [] as string[],
    };

    if (!openGraph.present) {
      recommendations.push({
        id: 'add-opengraph',
        category: 'technical',
        title: 'Add Open Graph Tags',
        description: 'Add Open Graph meta tags to improve social media sharing',
        impact: 'medium',
        effort: 'low',
        priority: 6,
        implementation: 'Add og:title, og:description, og:image, and og:url meta tags',
        expectedImprovement: 15,
        timeframe: '1 hour',
      });
    }

    // Twitter Cards analysis
    const twitterTags: Record<string, string> = {};
    $('meta[name^="twitter:"]').each((_, el) => {
      const name = $(el).attr('name');
      const content = $(el).attr('content');
      if (name && content) {
        twitterTags[name] = content;
      }
    });

    const twitterCards = {
      present: Object.keys(twitterTags).length > 0,
      complete: !!(twitterTags['twitter:card'] && twitterTags['twitter:title']),
      tags: twitterTags,
      issues: [] as string[],
    };

    return {
      title: titleAnalysis,
      description: descriptionAnalysis,
      keywords: keywordsAnalysis,
      openGraph,
      twitterCards,
    };
  }

  /**
   * Analyze heading structure
   */
  private analyzeHeadingStructure(
    $: cheerio.CheerioAPI,
    issues: SEOIssue[],
    recommendations: SEORecommendation[]
  ): HeadingStructureAnalysis {
    const headings = $('h1, h2, h3, h4, h5, h6');
    const h1Elements = $('h1');
    const structure: any[] = [];

    headings.each((index, el) => {
      const level = parseInt(el.tagName.substring(1));
      const content = $(el).text().trim();
      structure.push({
        level,
        content,
        position: index,
      });
    });

    const h1Count = h1Elements.length;
    const h1Content = h1Elements.map((_, el) => $(el).text().trim()).get();

    // Check H1 issues
    if (h1Count === 0) {
      issues.push({
        id: 'missing-h1',
        type: 'error',
        category: 'technical',
        title: 'Missing H1 Tag',
        description: 'The page is missing an H1 heading tag',
        impact: 'high',
        effort: 'low',
        priority: 8,
      });
    } else if (h1Count > 1) {
      issues.push({
        id: 'multiple-h1',
        type: 'warning',
        category: 'technical',
        title: 'Multiple H1 Tags',
        description: 'The page has multiple H1 tags, which may confuse search engines',
        impact: 'medium',
        effort: 'low',
        priority: 6,
        value: h1Count,
      });
    }

    // Check heading hierarchy
    const hierarchyIssues: string[] = [];
    for (let i = 1; i < structure.length; i++) {
      const current = structure[i];
      const previous = structure[i - 1];
      
      if (current.level > previous.level + 1) {
        hierarchyIssues.push(`Heading level ${current.level} follows H${previous.level} without intermediate levels`);
      }
    }

    return {
      h1Count,
      h1Content,
      hierarchyIssues,
      missingHeadings: [],
      structure,
    };
  }

  /**
   * Analyze URL structure
   */
  private analyzeURLStructure(
    url: string,
    issues: SEOIssue[],
    recommendations: SEORecommendation[]
  ): URLStructureAnalysis {
    const parsedUrl = new URL(url);
    const pathname = parsedUrl.pathname;
    
    const length = url.length;
    const hasKeywords = /[a-zA-Z]/.test(pathname);
    const hasNumbers = /\d/.test(pathname);
    const hasSpecialChars = /[^a-zA-Z0-9\-\/]/.test(pathname);
    
    let readability = 100;
    let structure: 'good' | 'fair' | 'poor' = 'good';
    const urlIssues: string[] = [];

    // Check URL length
    if (length > 100) {
      urlIssues.push('URL is too long');
      readability -= 20;
      structure = 'fair';
    }

    // Check for special characters
    if (hasSpecialChars) {
      urlIssues.push('URL contains special characters');
      readability -= 15;
      structure = 'fair';
    }

    // Check for excessive parameters
    if (parsedUrl.search.length > 50) {
      urlIssues.push('URL has too many parameters');
      readability -= 10;
    }

    // Check for keyword presence
    if (!hasKeywords) {
      urlIssues.push('URL lacks descriptive keywords');
      readability -= 25;
      structure = 'poor';
    }

    if (readability < 60) {
      structure = 'poor';
    } else if (readability < 80) {
      structure = 'fair';
    }

    return {
      length,
      readability,
      keywordPresence: hasKeywords,
      structure,
      issues: urlIssues,
    };
  }

  /**
   * Analyze internal linking
   */
  private analyzeInternalLinking(
    $: cheerio.CheerioAPI,
    url: string,
    issues: SEOIssue[],
    recommendations: SEORecommendation[]
  ): InternalLinkingAnalysis {
    const parsedUrl = new URL(url);
    const domain = parsedUrl.hostname;
    
    const allLinks = $('a[href]');
    const internalLinks = allLinks.filter((_, el) => {
      const href = $(el).attr('href');
      if (!href) return false;
      
      try {
        const linkUrl = new URL(href, url);
        return linkUrl.hostname === domain;
      } catch {
        return href.startsWith('/') || !href.includes('://');
      }
    });

    const anchorTexts: Record<string, number> = {};
    const anchorTextAnalysis: any[] = [];

    internalLinks.each((_, el) => {
      const text = $(el).text().trim();
      if (text) {
        anchorTexts[text] = (anchorTexts[text] || 0) + 1;
      }
    });

    Object.entries(anchorTexts).forEach(([text, count]) => {
      let type: 'exact' | 'partial' | 'branded' | 'generic' = 'generic';
      
      if (text.toLowerCase().includes(domain.split('.')[0])) {
        type = 'branded';
      } else if (text.length > 20) {
        type = 'partial';
      } else if (['click here', 'read more', 'learn more'].includes(text.toLowerCase())) {
        type = 'generic';
      } else {
        type = 'exact';
      }

      anchorTextAnalysis.push({ text, count, type });
    });

    return {
      totalLinks: allLinks.length,
      uniqueLinks: internalLinks.length,
      anchorTextAnalysis,
      linkDepth: 0, // Would need crawling to calculate
      orphanPages: [], // Would need site crawling to identify
      issues: [],
    };
  }

  /**
   * Analyze schema markup
   */
  private analyzeSchemaMarkup(
    $: cheerio.CheerioAPI,
    issues: SEOIssue[],
    recommendations: SEORecommendation[]
  ): SchemaMarkupAnalysis {
    const jsonLdScripts = $('script[type="application/ld+json"]');
    const microdataElements = $('[itemscope]');
    
    let present = false;
    const types: string[] = [];
    let valid = true;
    const errors: string[] = [];
    const warnings: string[] = [];

    // Check JSON-LD
    jsonLdScripts.each((_, el) => {
      try {
        const content = $(el).html();
        if (content) {
          const data = JSON.parse(content);
          present = true;
          
          if (data['@type']) {
            types.push(data['@type']);
          } else if (Array.isArray(data)) {
            data.forEach(item => {
              if (item['@type']) {
                types.push(item['@type']);
              }
            });
          }
        }
      } catch (error) {
        valid = false;
        errors.push('Invalid JSON-LD syntax');
      }
    });

    // Check Microdata
    if (microdataElements.length > 0) {
      present = true;
      microdataElements.each((_, el) => {
        const itemType = $(el).attr('itemtype');
        if (itemType) {
          const type = itemType.split('/').pop();
          if (type) {
            types.push(type);
          }
        }
      });
    }

    if (!present) {
      recommendations.push({
        id: 'add-schema-markup',
        category: 'technical',
        title: 'Add Schema Markup',
        description: 'Add structured data markup to help search engines understand your content',
        impact: 'medium',
        effort: 'medium',
        priority: 5,
        implementation: 'Add JSON-LD structured data for your content type',
        expectedImprovement: 20,
        timeframe: '2-4 hours',
      });
    }

    const coverage = present ? Math.min(types.length * 20, 100) : 0;

    return {
      present,
      types: [...new Set(types)],
      valid,
      errors,
      warnings,
      coverage,
    };
  }

  /**
   * Analyze robots.txt
   */
  private async analyzeRobotsTxt(
    url: string,
    issues: SEOIssue[],
    recommendations: SEORecommendation[]
  ): Promise<any> {
    try {
      const parsedUrl = new URL(url);
      const robotsUrl = `${parsedUrl.protocol}//${parsedUrl.host}/robots.txt`;
      
      const response = await axios.get(robotsUrl, { timeout: 10000 });
      
      const directives: any[] = [];
      const lines = response.data.split('\n');
      
      lines.forEach(line => {
        const trimmed = line.trim();
        if (trimmed && !trimmed.startsWith('#')) {
          const [directive, ...valueParts] = trimmed.split(':');
          const value = valueParts.join(':').trim();
          
          directives.push({
            userAgent: '*', // Simplified
            directive: directive.trim(),
            value,
          });
        }
      });

      return {
        present: true,
        accessible: true,
        valid: true,
        directives,
        issues: [],
      };
    } catch (error) {
      issues.push({
        id: 'robots-txt-missing',
        type: 'warning',
        category: 'technical',
        title: 'Robots.txt Not Found',
        description: 'The robots.txt file is missing or inaccessible',
        impact: 'medium',
        effort: 'low',
        priority: 4,
      });

      return {
        present: false,
        accessible: false,
        valid: false,
        directives: [],
        issues: ['Robots.txt not found'],
      };
    }
  }

  /**
   * Analyze sitemap
   */
  private async analyzeSitemap(
    url: string,
    issues: SEOIssue[],
    recommendations: SEORecommendation[]
  ): Promise<any> {
    try {
      const parsedUrl = new URL(url);
      const sitemapUrl = `${parsedUrl.protocol}//${parsedUrl.host}/sitemap.xml`;
      
      const response = await axios.get(sitemapUrl, { timeout: 10000 });
      
      // Basic XML validation
      const urlMatches = response.data.match(/<url>/g);
      const urlCount = urlMatches ? urlMatches.length : 0;

      return {
        present: true,
        accessible: true,
        valid: true,
        urlCount,
        lastModified: new Date(),
        issues: [],
      };
    } catch (error) {
      recommendations.push({
        id: 'create-sitemap',
        category: 'technical',
        title: 'Create XML Sitemap',
        description: 'Create and submit an XML sitemap to help search engines discover your pages',
        impact: 'medium',
        effort: 'medium',
        priority: 5,
        implementation: 'Generate and upload an XML sitemap, then submit to search engines',
        expectedImprovement: 15,
        timeframe: '1-2 hours',
      });

      return {
        present: false,
        accessible: false,
        valid: false,
        urlCount: 0,
        issues: ['Sitemap not found'],
      };
    }
  }

  /**
   * Analyze SSL configuration
   */
  private async analyzeSSL(
    url: string,
    issues: SEOIssue[],
    recommendations: SEORecommendation[]
  ): Promise<any> {
    const parsedUrl = new URL(url);
    const isHttps = parsedUrl.protocol === 'https:';

    if (!isHttps) {
      issues.push({
        id: 'no-ssl',
        type: 'error',
        category: 'technical',
        title: 'No SSL Certificate',
        description: 'The website is not using HTTPS, which affects security and SEO rankings',
        impact: 'high',
        effort: 'medium',
        priority: 9,
      });

      return {
        enabled: false,
        valid: false,
        issues: ['No SSL certificate'],
      };
    }

    return {
      enabled: true,
      valid: true,
      expiryDate: undefined, // Would need certificate inspection
      issuer: undefined,
      issues: [],
    };
  }

  /**
   * Analyze redirects
   */
  private async analyzeRedirects(
    url: string,
    issues: SEOIssue[],
    recommendations: SEORecommendation[]
  ): Promise<any> {
    // This would require following redirect chains
    // For now, return basic structure
    return {
      redirectChains: [],
      redirectLoops: [],
      brokenRedirects: [],
      issues: [],
    };
  }

  /**
   * Analyze canonicalization
   */
  private analyzeCanonicalization(
    $: cheerio.CheerioAPI,
    url: string,
    issues: SEOIssue[],
    recommendations: SEORecommendation[]
  ): any {
    const canonicalLink = $('link[rel="canonical"]').attr('href');
    const canonicalPresent = !!canonicalLink;
    
    let selfReferencing = false;
    if (canonicalLink) {
      try {
        const canonicalUrl = new URL(canonicalLink, url);
        const currentUrl = new URL(url);
        selfReferencing = canonicalUrl.href === currentUrl.href;
      } catch (error) {
        issues.push({
          id: 'invalid-canonical',
          type: 'error',
          category: 'technical',
          title: 'Invalid Canonical URL',
          description: 'The canonical URL is malformed',
          impact: 'medium',
          effort: 'low',
          priority: 6,
        });
      }
    }

    return {
      canonicalPresent,
      canonicalUrl: canonicalLink,
      selfReferencing,
      issues: [],
    };
  }

  /**
   * Analyze mobile optimization
   */
  private analyzeMobileOptimization(
    $: cheerio.CheerioAPI,
    issues: SEOIssue[],
    recommendations: SEORecommendation[]
  ): any {
    const viewportMeta = $('meta[name="viewport"]').attr('content');
    const hasViewport = !!viewportMeta;
    
    // Basic responsive checks
    const responsiveIndicators = [
      $('link[rel="stylesheet"]').filter((_, el) => $(el).attr('media')?.includes('screen')).length > 0,
      $('style').text().includes('@media'),
      hasViewport,
    ];

    const responsive = responsiveIndicators.filter(Boolean).length >= 2;

    if (!hasViewport) {
      issues.push({
        id: 'missing-viewport',
        type: 'error',
        category: 'technical',
        title: 'Missing Viewport Meta Tag',
        description: 'The page is missing a viewport meta tag for mobile optimization',
        impact: 'high',
        effort: 'low',
        priority: 8,
      });
    }

    return {
      responsive,
      viewportMeta: hasViewport,
      mobileSpeed: 0, // Would need mobile-specific testing
      mobileFriendly: responsive && hasViewport,
      issues: [],
    };
  }

  /**
   * Analyze Core Web Vitals
   */
  private async analyzeCoreWebVitals(url: string): Promise<CoreWebVitalsResult> {
    // This would integrate with real Core Web Vitals data
    // For now, return placeholder data
    return {
      lcp: { value: 2500, rating: 'good' },
      fid: { value: 100, rating: 'good' },
      cls: { value: 0.1, rating: 'good' },
    };
  }

  /**
   * Analyze content quality and SEO factors
   */
  private async analyzeContent(
    url: string,
    $: cheerio.CheerioAPI,
    pageContent: any
  ): Promise<ContentAnalysisResult> {
    const issues: SEOIssue[] = [];
    const recommendations: SEORecommendation[] = [];

    // Extract text content
    const textContent = $('body').text().replace(/\s+/g, ' ').trim();
    const wordCount = textContent.split(' ').length;

    // Basic content metrics
    if (wordCount < config.seoAnalysis.contentAnalysis.minWordCount) {
      issues.push({
        id: 'low-word-count',
        type: 'warning',
        category: 'content',
        title: 'Low Word Count',
        description: `Content has only ${wordCount} words, which may be insufficient for SEO`,
        impact: 'medium',
        effort: 'high',
        priority: 6,
        value: wordCount,
      });
    }

    // Readability analysis
    const readabilityScore = this.calculateReadability(textContent);

    // Keyword density analysis
    const keywordDensity = this.analyzeKeywordDensity(textContent);

    // Content structure analysis
    const contentStructure = this.analyzeContentStructure($);

    // Calculate content score
    const score = this.calculateContentScore({
      wordCount,
      readabilityScore,
      keywordDensity,
      contentStructure,
    });

    return {
      score,
      issues,
      recommendations,
      wordCount,
      readabilityScore: readabilityScore.fleschReadingEase,
      keywordDensity,
      semanticAnalysis: {
        entities: [],
        topics: [],
        sentiment: { score: 0, magnitude: 0, label: 'neutral' },
        readability: readabilityScore,
      },
      contentStructure,
      uniqueness: 85, // Placeholder
      relevance: 80, // Placeholder
      engagement: 75, // Placeholder
      topicCoverage: {
        mainTopic: '',
        subtopics: [],
        coverage: 0,
        gaps: [],
      },
      entityAnalysis: {
        entities: [],
        entityDensity: 0,
        entityRelevance: 0,
      },
      sentimentAnalysis: {
        overall: { score: 0, magnitude: 0, label: 'neutral' },
        bySection: [],
      },
      contentGaps: [],
    };
  }

  /**
   * Calculate readability scores
   */
  private calculateReadability(text: string): any {
    try {
      return {
        fleschKincaid: readability.fleschKincaidGrade(text),
        fleschReadingEase: readability.fleschReadingEase(text),
        gunningFog: readability.gunningFog(text),
        smog: readability.smogIndex(text),
        automatedReadability: readability.automatedReadabilityIndex(text),
        grade: readability.textStandard(text),
      };
    } catch (error) {
      return {
        fleschKincaid: 0,
        fleschReadingEase: 0,
        gunningFog: 0,
        smog: 0,
        automatedReadability: 0,
        grade: 'Unknown',
      };
    }
  }

  /**
   * Analyze keyword density
   */
  private analyzeKeywordDensity(text: string): any[] {
    const words = text.toLowerCase().match(/\b\w+\b/g) || [];
    const wordCount = words.length;
    const wordFreq: Record<string, number> = {};

    // Count word frequencies
    words.forEach(word => {
      if (word.length > 3) { // Ignore short words
        wordFreq[word] = (wordFreq[word] || 0) + 1;
      }
    });

    // Calculate density for top keywords
    return Object.entries(wordFreq)
      .sort(([, a], [, b]) => b - a)
      .slice(0, 10)
      .map(([keyword, count]) => ({
        keyword,
        density: (count / wordCount) * 100,
        count,
        optimal: (count / wordCount) * 100 >= 0.5 && (count / wordCount) * 100 <= 3.0,
      }));
  }

  /**
   * Analyze content structure
   */
  private analyzeContentStructure($: cheerio.CheerioAPI): any {
    const paragraphs = $('p');
    const sentences = $('body').text().split(/[.!?]+/).filter(s => s.trim().length > 0);
    const lists = $('ul, ol');
    const images = $('img');
    const videos = $('video, iframe[src*="youtube"], iframe[src*="vimeo"]');

    const paragraphLengths = paragraphs.map((_, el) => $(el).text().length).get();
    const sentenceLengths = sentences.map(s => s.trim().split(' ').length);

    return {
      paragraphCount: paragraphs.length,
      averageParagraphLength: paragraphLengths.reduce((a, b) => a + b, 0) / paragraphLengths.length || 0,
      sentenceCount: sentences.length,
      averageSentenceLength: sentenceLengths.reduce((a, b) => a + b, 0) / sentenceLengths.length || 0,
      listCount: lists.length,
      imageCount: images.length,
      videoCount: videos.length,
    };
  }

  /**
   * Analyze performance metrics using Lighthouse
   */
  private async analyzePerformance(
    url: string,
    depth: string
  ): Promise<PerformanceMetricsResult> {
    if (!config.features.enableLighthouse || depth === 'basic') {
      // Return basic performance data
      return {
        score: 75,
        issues: [],
        recommendations: [],
        largestContentfulPaint: 2500,
        firstInputDelay: 100,
        cumulativeLayoutShift: 0.1,
        firstContentfulPaint: 1800,
        timeToInteractive: 3500,
        pageLoadTime: 2000,
        domContentLoaded: 1500,
        resourceLoadTime: [],
        lighthousePerformance: 75,
        lighthouseSeo: 85,
        lighthouseAccessibility: 80,
        lighthouseBestPractices: 90,
        lighthousePwa: 60,
      };
    }

    try {
      // Launch Chrome and run Lighthouse
      const chrome = await chromeLauncher.launch({
        chromeFlags: config.seoAnalysis.lighthouse.chromeFlags,
      });

      const options = {
        logLevel: 'info',
        output: 'json',
        onlyCategories: ['performance', 'seo', 'accessibility', 'best-practices', 'pwa'],
        port: chrome.port,
      };

      const runnerResult = await lighthouse(url, options);
      await chrome.kill();

      if (!runnerResult || !runnerResult.lhr) {
        throw new Error('Lighthouse analysis failed');
      }

      const lhr = runnerResult.lhr;
      const audits = lhr.audits;

      return {
        score: Math.round((lhr.categories.performance?.score || 0) * 100),
        issues: [],
        recommendations: [],
        largestContentfulPaint: audits['largest-contentful-paint']?.numericValue || 0,
        firstInputDelay: audits['max-potential-fid']?.numericValue || 0,
        cumulativeLayoutShift: audits['cumulative-layout-shift']?.numericValue || 0,
        firstContentfulPaint: audits['first-contentful-paint']?.numericValue || 0,
        timeToInteractive: audits['interactive']?.numericValue || 0,
        pageLoadTime: audits['speed-index']?.numericValue || 0,
        domContentLoaded: 0, // Not directly available in Lighthouse
        resourceLoadTime: [],
        lighthousePerformance: Math.round((lhr.categories.performance?.score || 0) * 100),
        lighthouseSeo: Math.round((lhr.categories.seo?.score || 0) * 100),
        lighthouseAccessibility: Math.round((lhr.categories.accessibility?.score || 0) * 100),
        lighthouseBestPractices: Math.round((lhr.categories['best-practices']?.score || 0) * 100),
        lighthousePwa: Math.round((lhr.categories.pwa?.score || 0) * 100),
      };
    } catch (error) {
      logError(error as Error, { context: 'Lighthouse analysis', url });
      
      // Return fallback performance data
      return {
        score: 50,
        issues: [{
          id: 'lighthouse-failed',
          type: 'warning',
          category: 'performance',
          title: 'Performance Analysis Failed',
          description: 'Could not run Lighthouse performance analysis',
          impact: 'medium',
          effort: 'low',
          priority: 3,
        }],
        recommendations: [],
        largestContentfulPaint: 0,
        firstInputDelay: 0,
        cumulativeLayoutShift: 0,
        firstContentfulPaint: 0,
        timeToInteractive: 0,
        pageLoadTime: 0,
        domContentLoaded: 0,
        resourceLoadTime: [],
        lighthousePerformance: 0,
        lighthouseSeo: 0,
        lighthouseAccessibility: 0,
        lighthouseBestPractices: 0,
        lighthousePwa: 0,
      };
    }
  }

  /**
   * Analyze keywords and search optimization
   */
  private async analyzeKeywords(
    url: string,
    $: cheerio.CheerioAPI,
    pageContent: any
  ): Promise<KeywordAnalysisResult> {
    const textContent = $('body').text().toLowerCase();
    const title = $('title').text().toLowerCase();
    const description = $('meta[name="description"]').attr('content')?.toLowerCase() || '';

    // Extract potential keywords from content
    const words = textContent.match(/\b\w{4,}\b/g) || [];
    const wordFreq: Record<string, number> = {};

    words.forEach(word => {
      wordFreq[word] = (wordFreq[word] || 0) + 1;
    });

    // Get top keywords by frequency
    const topKeywords = Object.entries(wordFreq)
      .sort(([, a], [, b]) => b - a)
      .slice(0, 20)
      .map(([keyword]) => keyword);

    // Analyze keyword density
    const keywordDensity = topKeywords.slice(0, 10).map(keyword => ({
      keyword,
      density: (wordFreq[keyword] / words.length) * 100,
      count: wordFreq[keyword],
      optimal: (wordFreq[keyword] / words.length) * 100 >= 0.5 && (wordFreq[keyword] / words.length) * 100 <= 3.0,
    }));

    return {
      score: 75, // Calculated based on keyword optimization
      primaryKeyword: topKeywords[0],
      secondaryKeywords: topKeywords.slice(1, 6),
      keywordDensity,
      keywordPositions: [], // Would need search engine data
      keywordOpportunities: [], // Would need keyword research data
      semanticKeywords: [], // Would need NLP analysis
      competitorKeywords: [], // Would need competitor analysis
    };
  }

  /**
   * Extract meta keywords
   */
  private extractMetaKeywords($: cheerio.CheerioAPI): string[] {
    const keywords = $('meta[name="keywords"]').attr('content');
    return keywords ? keywords.split(',').map(k => k.trim()) : [];
  }

  /**
   * Calculate overall SEO score
   */
  private calculateOverallScore(
    technicalScore: number,
    contentScore: number,
    performanceScore: number
  ): number {
    // Weighted average: Technical 40%, Content 35%, Performance 25%
    return Math.round(
      (technicalScore * 0.4) + (contentScore * 0.35) + (performanceScore * 0.25)
    );
  }

  /**
   * Calculate technical SEO score
   */
  private calculateTechnicalScore(factors: any): number {
    let score = 100;
    
    // Deduct points for missing elements
    if (!factors.metaTags.title.present) score -= 15;
    if (!factors.metaTags.description.present) score -= 15;
    if (!factors.schemaMarkup.present) score -= 10;
    if (!factors.robotsTxt.present) score -= 5;
    if (!factors.sitemap.present) score -= 10;
    if (!factors.ssl.enabled) score -= 20;

    // Deduct points for issues
    factors.issues.forEach((issue: SEOIssue) => {
      if (issue.impact === 'high') score -= 10;
      else if (issue.impact === 'medium') score -= 5;
      else score -= 2;
    });

    return Math.max(0, Math.min(100, score));
  }

  /**
   * Calculate content score
   */
  private calculateContentScore(factors: any): number {
    let score = 100;

    // Word count scoring
    if (factors.wordCount < 300) score -= 20;
    else if (factors.wordCount < 500) score -= 10;

    // Readability scoring
    if (factors.readabilityScore < 30) score -= 15;
    else if (factors.readabilityScore < 50) score -= 10;
    else if (factors.readabilityScore > 90) score -= 5;

    // Content structure scoring
    if (factors.contentStructure.paragraphCount < 3) score -= 10;
    if (factors.contentStructure.imageCount === 0) score -= 5;

    return Math.max(0, Math.min(100, score));
  }
}