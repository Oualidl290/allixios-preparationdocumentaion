/**
 * Sitemap Service
 * Advanced XML sitemap generation and management
 */

import { URL } from 'url';
import axios from 'axios';
import cheerio from 'cheerio';
import { create } from 'xmlbuilder2';
import { gzip } from 'zlib';
import { promisify } from 'util';
import { DatabaseManager } from '../database/DatabaseManager';
import { CacheManager } from '../cache/CacheManager';
import { config } from '../config';
import { logger, logSitemapGeneration, logError } from '../utils/logger';
import {
  SitemapEntry,
  SitemapImage,
  SitemapVideo,
  SitemapNews,
} from '../types';

const gzipAsync = promisify(gzip);

export class SitemapService {
  private cacheManager: CacheManager;

  constructor() {
    this.cacheManager = new CacheManager();
  }

  /**
   * Generate comprehensive XML sitemap
   */
  async generateSitemap(
    domain: string,
    options: {
      includeImages?: boolean;
      includeVideos?: boolean;
      includeNews?: boolean;
      maxUrls?: number;
      crawlDepth?: number;
      excludePatterns?: string[];
      includePatterns?: string[];
      tenantId?: string;
    } = {}
  ): Promise<{
    sitemap: string;
    sitemapIndex?: string;
    entries: SitemapEntry[];
    stats: {
      totalUrls: number;
      imageCount: number;
      videoCount: number;
      newsCount: number;
      size: number;
      compressed: boolean;
    };
  }> {
    const startTime = Date.now();
    const {
      includeImages = config.sitemap.includeImages,
      includeVideos = config.sitemap.includeVideos,
      includeNews = config.sitemap.includeNews,
      maxUrls = config.sitemap.maxUrls,
      crawlDepth = 3,
      excludePatterns = [],
      includePatterns = [],
      tenantId,
    } = options;

    try {
      logger.info('Starting sitemap generation', {
        domain,
        includeImages,
        includeVideos,
        includeNews,
        maxUrls,
        crawlDepth,
      });

      // Check cache first
      const cached = await this.cacheManager.getCachedSitemapData(domain);
      if (cached && !this.shouldRegenerateSitemap(cached.lastGenerated)) {
        return cached;
      }

      // Discover URLs through crawling
      const discoveredUrls = await this.discoverUrls(domain, {
        maxUrls,
        crawlDepth,
        excludePatterns,
        includePatterns,
      });

      // Process each URL to create sitemap entries
      const entries: SitemapEntry[] = [];
      let imageCount = 0;
      let videoCount = 0;
      let newsCount = 0;

      for (const url of discoveredUrls.slice(0, maxUrls)) {
        try {
          const entry = await this.createSitemapEntry(url, {
            includeImages,
            includeVideos,
            includeNews,
          });

          entries.push(entry);

          // Count media
          if (entry.images) imageCount += entry.images.length;
          if (entry.videos) videoCount += entry.videos.length;
          if (entry.news) newsCount += 1;

          // Save to database
          await this.saveSitemapEntry(entry, tenantId);
        } catch (error) {
          logger.warn('Failed to process URL for sitemap', {
            url,
            error: error.message,
          });
        }
      }

      // Generate XML sitemap
      const { sitemap, sitemapIndex } = await this.generateXMLSitemap(entries, domain);

      // Calculate stats
      const stats = {
        totalUrls: entries.length,
        imageCount,
        videoCount,
        newsCount,
        size: Buffer.byteLength(sitemap, 'utf8'),
        compressed: config.sitemap.compressionEnabled,
      };

      // Compress if enabled and large
      let finalSitemap = sitemap;
      if (config.sitemap.compressionEnabled && stats.size > 50000) {
        const compressed = await gzipAsync(sitemap);
        finalSitemap = compressed.toString('base64');
        stats.compressed = true;
      }

      const result = {
        sitemap: finalSitemap,
        sitemapIndex,
        entries,
        stats,
        lastGenerated: new Date(),
      };

      // Cache result
      await this.cacheManager.cacheSitemapData(domain, result);

      const duration = Date.now() - startTime;
      logSitemapGeneration(domain, entries.length, duration, {
        imageCount,
        videoCount,
        newsCount,
        compressed: stats.compressed,
      });

      return result;
    } catch (error) {
      const duration = Date.now() - startTime;
      logSitemapGeneration(domain, 0, duration, { error: error.message });
      logError(error as Error, { context: 'Sitemap generation', domain });
      throw error;
    }
  }

  /**
   * Discover URLs through intelligent crawling
   */
  private async discoverUrls(
    domain: string,
    options: {
      maxUrls: number;
      crawlDepth: number;
      excludePatterns: string[];
      includePatterns: string[];
    }
  ): Promise<string[]> {
    const { maxUrls, crawlDepth, excludePatterns, includePatterns } = options;
    const baseUrl = `https://${domain}`;
    const discoveredUrls = new Set<string>();
    const urlsToProcess = [baseUrl];
    const processedUrls = new Set<string>();

    // Add URLs from robots.txt sitemap references
    const robotsSitemaps = await this.extractSitemapsFromRobots(domain);
    for (const sitemapUrl of robotsSitemaps) {
      const sitemapUrls = await this.extractUrlsFromSitemap(sitemapUrl);
      sitemapUrls.forEach(url => discoveredUrls.add(url));
    }

    // Crawl website
    let currentDepth = 0;
    while (urlsToProcess.length > 0 && currentDepth < crawlDepth && discoveredUrls.size < maxUrls) {
      const currentLevelUrls = [...urlsToProcess];
      urlsToProcess.length = 0;

      for (const url of currentLevelUrls) {
        if (processedUrls.has(url) || discoveredUrls.size >= maxUrls) {
          continue;
        }

        try {
          processedUrls.add(url);
          
          // Fetch page content
          const response = await axios.get(url, {
            timeout: 10000,
            headers: {
              'User-Agent': 'Mozilla/5.0 (compatible; AllixiosSEOBot/2.0; +https://allixios.com/seobot)',
            },
          });

          const $ = cheerio.load(response.data);
          
          // Extract links
          $('a[href]').each((_, element) => {
            const href = $(element).attr('href');
            if (!href) return;

            try {
              const absoluteUrl = new URL(href, url).href;
              const urlObj = new URL(absoluteUrl);

              // Only include URLs from the same domain
              if (urlObj.hostname !== domain) return;

              // Apply filters
              if (!this.shouldIncludeUrl(absoluteUrl, excludePatterns, includePatterns)) {
                return;
              }

              discoveredUrls.add(absoluteUrl);
              
              // Add to next level processing if not too deep
              if (currentDepth < crawlDepth - 1) {
                urlsToProcess.push(absoluteUrl);
              }
            } catch (error) {
              // Invalid URL, skip
            }
          });
        } catch (error) {
          logger.warn('Failed to crawl URL', { url, error: error.message });
        }
      }

      currentDepth++;
    }

    return Array.from(discoveredUrls).slice(0, maxUrls);
  }

  /**
   * Extract sitemap URLs from robots.txt
   */
  private async extractSitemapsFromRobots(domain: string): Promise<string[]> {
    try {
      const robotsUrl = `https://${domain}/robots.txt`;
      const response = await axios.get(robotsUrl, { timeout: 10000 });
      
      const sitemaps: string[] = [];
      const lines = response.data.split('\n');
      
      for (const line of lines) {
        const trimmed = line.trim();
        if (trimmed.toLowerCase().startsWith('sitemap:')) {
          const sitemapUrl = trimmed.substring(8).trim();
          sitemaps.push(sitemapUrl);
        }
      }

      return sitemaps;
    } catch (error) {
      logger.warn('Failed to extract sitemaps from robots.txt', {
        domain,
        error: error.message,
      });
      return [];
    }
  }

  /**
   * Extract URLs from existing sitemap
   */
  private async extractUrlsFromSitemap(sitemapUrl: string): Promise<string[]> {
    try {
      const response = await axios.get(sitemapUrl, { timeout: 15000 });
      const $ = cheerio.load(response.data, { xmlMode: true });
      
      const urls: string[] = [];
      
      // Handle sitemap index
      $('sitemap loc').each((_, element) => {
        const url = $(element).text().trim();
        if (url) urls.push(url);
      });

      // Handle regular sitemap
      $('url loc').each((_, element) => {
        const url = $(element).text().trim();
        if (url) urls.push(url);
      });

      // If this was a sitemap index, recursively fetch child sitemaps
      if ($('sitemap').length > 0) {
        const childUrls: string[] = [];
        for (const childSitemapUrl of urls) {
          const childSitemapUrls = await this.extractUrlsFromSitemap(childSitemapUrl);
          childUrls.push(...childSitemapUrls);
        }
        return childUrls;
      }

      return urls;
    } catch (error) {
      logger.warn('Failed to extract URLs from sitemap', {
        sitemapUrl,
        error: error.message,
      });
      return [];
    }
  }

  /**
   * Check if URL should be included based on patterns
   */
  private shouldIncludeUrl(
    url: string,
    excludePatterns: string[],
    includePatterns: string[]
  ): boolean {
    // Check exclude patterns
    for (const pattern of excludePatterns) {
      if (url.includes(pattern)) {
        return false;
      }
    }

    // If include patterns are specified, URL must match at least one
    if (includePatterns.length > 0) {
      return includePatterns.some(pattern => url.includes(pattern));
    }

    // Default exclusions
    const defaultExclusions = [
      '/admin',
      '/wp-admin',
      '/login',
      '/logout',
      '/search',
      '?',
      '#',
      '.pdf',
      '.doc',
      '.zip',
    ];

    return !defaultExclusions.some(exclusion => url.includes(exclusion));
  }

  /**
   * Create sitemap entry for a URL
   */
  private async createSitemapEntry(
    url: string,
    options: {
      includeImages: boolean;
      includeVideos: boolean;
      includeNews: boolean;
    }
  ): Promise<SitemapEntry> {
    const { includeImages, includeVideos, includeNews } = options;

    try {
      // Fetch page content
      const response = await axios.get(url, {
        timeout: 10000,
        headers: {
          'User-Agent': 'Mozilla/5.0 (compatible; AllixiosSEOBot/2.0; +https://allixios.com/seobot)',
        },
      });

      const $ = cheerio.load(response.data);
      const lastModified = response.headers['last-modified'] 
        ? new Date(response.headers['last-modified'])
        : new Date();

      // Determine change frequency based on content type
      const changeFrequency = this.determineChangeFrequency(url, $);
      
      // Calculate priority based on URL structure and content
      const priority = this.calculatePriority(url, $);

      const entry: SitemapEntry = {
        url,
        lastModified,
        changeFrequency,
        priority,
      };

      // Extract images if enabled
      if (includeImages) {
        entry.images = this.extractImages($, url);
      }

      // Extract videos if enabled
      if (includeVideos) {
        entry.videos = this.extractVideos($, url);
      }

      // Extract news data if enabled
      if (includeNews) {
        entry.news = this.extractNewsData($, url);
      }

      return entry;
    } catch (error) {
      // Return basic entry if page fetch fails
      return {
        url,
        lastModified: new Date(),
        changeFrequency: 'monthly',
        priority: 0.5,
      };
    }
  }

  /**
   * Determine change frequency based on content analysis
   */
  private determineChangeFrequency(
    url: string,
    $: cheerio.CheerioAPI
  ): 'always' | 'hourly' | 'daily' | 'weekly' | 'monthly' | 'yearly' | 'never' {
    // Check for news/blog indicators
    if (url.includes('/news/') || url.includes('/blog/') || url.includes('/article/')) {
      return 'weekly';
    }

    // Check for product pages
    if (url.includes('/product/') || url.includes('/shop/')) {
      return 'weekly';
    }

    // Check for dynamic content indicators
    const dynamicIndicators = [
      'comment', 'review', 'rating', 'price', 'stock', 'availability'
    ];
    
    const pageText = $('body').text().toLowerCase();
    const hasDynamicContent = dynamicIndicators.some(indicator => 
      pageText.includes(indicator)
    );

    if (hasDynamicContent) {
      return 'weekly';
    }

    // Check for static pages
    if (url.includes('/about') || url.includes('/contact') || url.includes('/privacy')) {
      return 'yearly';
    }

    // Default
    return 'monthly';
  }

  /**
   * Calculate priority based on URL structure and content importance
   */
  private calculatePriority(url: string, $: cheerio.CheerioAPI): number {
    let priority = 0.5; // Default priority

    // Homepage gets highest priority
    const urlObj = new URL(url);
    if (urlObj.pathname === '/' || urlObj.pathname === '') {
      return 1.0;
    }

    // Depth-based priority (shallower = higher priority)
    const pathSegments = urlObj.pathname.split('/').filter(segment => segment.length > 0);
    const depth = pathSegments.length;
    
    if (depth === 1) priority = 0.8;
    else if (depth === 2) priority = 0.6;
    else if (depth === 3) priority = 0.4;
    else priority = 0.3;

    // Content-based adjustments
    const title = $('title').text();
    const h1 = $('h1').text();
    const wordCount = $('body').text().split(/\s+/).length;

    // Boost for substantial content
    if (wordCount > 1000) priority += 0.1;
    if (wordCount > 2000) priority += 0.1;

    // Boost for important pages
    const importantKeywords = ['home', 'about', 'service', 'product', 'contact'];
    const hasImportantKeywords = importantKeywords.some(keyword =>
      title.toLowerCase().includes(keyword) || h1.toLowerCase().includes(keyword)
    );
    
    if (hasImportantKeywords) priority += 0.1;

    // Ensure priority is within valid range
    return Math.max(0.0, Math.min(1.0, priority));
  }

  /**
   * Extract images for sitemap
   */
  private extractImages($: cheerio.CheerioAPI, baseUrl: string): SitemapImage[] {
    const images: SitemapImage[] = [];
    
    $('img[src]').each((_, element) => {
      const src = $(element).attr('src');
      const alt = $(element).attr('alt');
      const title = $(element).attr('title');
      
      if (!src) return;

      try {
        const imageUrl = new URL(src, baseUrl).href;
        
        images.push({
          url: imageUrl,
          caption: alt || title,
          title: title,
        });
      } catch (error) {
        // Invalid image URL, skip
      }
    });

    return images.slice(0, 1000); // Limit per Google guidelines
  }

  /**
   * Extract videos for sitemap
   */
  private extractVideos($: cheerio.CheerioAPI, baseUrl: string): SitemapVideo[] {
    const videos: SitemapVideo[] = [];

    // Extract HTML5 videos
    $('video').each((_, element) => {
      const poster = $(element).attr('poster');
      const title = $(element).attr('title') || $('title').text();
      
      if (poster) {
        try {
          const thumbnailUrl = new URL(poster, baseUrl).href;
          
          videos.push({
            thumbnailUrl,
            title,
            description: title,
          });
        } catch (error) {
          // Invalid URL, skip
        }
      }
    });

    // Extract YouTube embeds
    $('iframe[src*="youtube.com"], iframe[src*="youtu.be"]').each((_, element) => {
      const src = $(element).attr('src');
      const title = $(element).attr('title') || $('title').text();
      
      if (src) {
        try {
          // Extract video ID from YouTube URL
          const videoId = this.extractYouTubeVideoId(src);
          if (videoId) {
            videos.push({
              thumbnailUrl: `https://img.youtube.com/vi/${videoId}/maxresdefault.jpg`,
              title,
              description: title,
              playerUrl: src,
            });
          }
        } catch (error) {
          // Invalid URL, skip
        }
      }
    });

    return videos;
  }

  /**
   * Extract YouTube video ID from URL
   */
  private extractYouTubeVideoId(url: string): string | null {
    const patterns = [
      /(?:youtube\.com\/watch\?v=|youtu\.be\/|youtube\.com\/embed\/)([^&\n?#]+)/,
    ];

    for (const pattern of patterns) {
      const match = url.match(pattern);
      if (match) {
        return match[1];
      }
    }

    return null;
  }

  /**
   * Extract news data for sitemap
   */
  private extractNewsData($: cheerio.CheerioAPI, url: string): SitemapNews | undefined {
    // Check if this looks like a news article
    const isNews = url.includes('/news/') || 
                   url.includes('/article/') || 
                   $('article').length > 0 ||
                   $('[itemtype*="NewsArticle"]').length > 0;

    if (!isNews) return undefined;

    const title = $('h1').text() || $('title').text();
    const publicationDate = this.extractPublicationDate($);
    
    if (!title || !publicationDate) return undefined;

    return {
      publicationName: this.extractPublicationName($),
      publicationLanguage: 'en', // Could be detected from lang attribute
      title,
      publicationDate,
      keywords: this.extractNewsKeywords($),
    };
  }

  /**
   * Extract publication date from page
   */
  private extractPublicationDate($: cheerio.CheerioAPI): Date | null {
    // Try various selectors for publication date
    const dateSelectors = [
      'time[datetime]',
      '[property="article:published_time"]',
      '[name="publish_date"]',
      '.published-date',
      '.post-date',
      '.article-date',
    ];

    for (const selector of dateSelectors) {
      const element = $(selector).first();
      if (element.length > 0) {
        const dateStr = element.attr('datetime') || element.attr('content') || element.text();
        const date = new Date(dateStr);
        if (!isNaN(date.getTime())) {
          return date;
        }
      }
    }

    return null;
  }

  /**
   * Extract publication name
   */
  private extractPublicationName($: cheerio.CheerioAPI): string {
    // Try to find publication name
    const nameSelectors = [
      '[property="og:site_name"]',
      '[name="application-name"]',
      '.site-name',
      '.publication-name',
    ];

    for (const selector of nameSelectors) {
      const element = $(selector).first();
      if (element.length > 0) {
        const name = element.attr('content') || element.text();
        if (name && name.trim()) {
          return name.trim();
        }
      }
    }

    return 'Unknown Publication';
  }

  /**
   * Extract news keywords
   */
  private extractNewsKeywords($: cheerio.CheerioAPI): string[] {
    const keywords: string[] = [];

    // Extract from meta keywords
    const metaKeywords = $('meta[name="keywords"]').attr('content');
    if (metaKeywords) {
      keywords.push(...metaKeywords.split(',').map(k => k.trim()));
    }

    // Extract from article tags
    $('.tag, .category, .keyword').each((_, element) => {
      const text = $(element).text().trim();
      if (text) keywords.push(text);
    });

    return keywords.slice(0, 10); // Limit keywords
  }

  /**
   * Generate XML sitemap from entries
   */
  private async generateXMLSitemap(
    entries: SitemapEntry[],
    domain: string
  ): Promise<{ sitemap: string; sitemapIndex?: string }> {
    const maxUrlsPerSitemap = 50000;
    const sitemaps: string[] = [];

    // Split entries into multiple sitemaps if needed
    for (let i = 0; i < entries.length; i += maxUrlsPerSitemap) {
      const chunk = entries.slice(i, i + maxUrlsPerSitemap);
      const sitemap = this.generateSingleSitemap(chunk);
      sitemaps.push(sitemap);
    }

    if (sitemaps.length === 1) {
      return { sitemap: sitemaps[0] };
    }

    // Generate sitemap index if multiple sitemaps
    const sitemapIndex = this.generateSitemapIndex(sitemaps.length, domain);
    
    return {
      sitemap: sitemaps[0], // Return first sitemap
      sitemapIndex,
    };
  }

  /**
   * Generate single XML sitemap
   */
  private generateSingleSitemap(entries: SitemapEntry[]): string {
    const root = create({ version: '1.0', encoding: 'UTF-8' })
      .ele('urlset', {
        xmlns: 'http://www.sitemaps.org/schemas/sitemap/0.9',
        'xmlns:image': 'http://www.google.com/schemas/sitemap-image/1.1',
        'xmlns:video': 'http://www.google.com/schemas/sitemap-video/1.1',
        'xmlns:news': 'http://www.google.com/schemas/sitemap-news/0.9',
      });

    for (const entry of entries) {
      const urlElement = root.ele('url');
      
      urlElement.ele('loc').txt(entry.url);
      
      if (entry.lastModified) {
        urlElement.ele('lastmod').txt(entry.lastModified.toISOString().split('T')[0]);
      }
      
      if (entry.changeFrequency) {
        urlElement.ele('changefreq').txt(entry.changeFrequency);
      }
      
      if (entry.priority !== undefined) {
        urlElement.ele('priority').txt(entry.priority.toFixed(1));
      }

      // Add images
      if (entry.images && entry.images.length > 0) {
        for (const image of entry.images) {
          const imageElement = urlElement.ele('image:image');
          imageElement.ele('image:loc').txt(image.url);
          
          if (image.caption) {
            imageElement.ele('image:caption').txt(image.caption);
          }
          
          if (image.title) {
            imageElement.ele('image:title').txt(image.title);
          }
        }
      }

      // Add videos
      if (entry.videos && entry.videos.length > 0) {
        for (const video of entry.videos) {
          const videoElement = urlElement.ele('video:video');
          videoElement.ele('video:thumbnail_loc').txt(video.thumbnailUrl);
          videoElement.ele('video:title').txt(video.title);
          videoElement.ele('video:description').txt(video.description);
          
          if (video.contentUrl) {
            videoElement.ele('video:content_loc').txt(video.contentUrl);
          }
          
          if (video.playerUrl) {
            videoElement.ele('video:player_loc').txt(video.playerUrl);
          }
        }
      }

      // Add news
      if (entry.news) {
        const newsElement = urlElement.ele('news:news');
        const publicationElement = newsElement.ele('news:publication');
        
        publicationElement.ele('news:name').txt(entry.news.publicationName);
        publicationElement.ele('news:language').txt(entry.news.publicationLanguage);
        
        newsElement.ele('news:publication_date')
          .txt(entry.news.publicationDate.toISOString());
        newsElement.ele('news:title').txt(entry.news.title);
        
        if (entry.news.keywords && entry.news.keywords.length > 0) {
          newsElement.ele('news:keywords').txt(entry.news.keywords.join(', '));
        }
      }
    }

    return root.end({ prettyPrint: true });
  }

  /**
   * Generate sitemap index
   */
  private generateSitemapIndex(sitemapCount: number, domain: string): string {
    const root = create({ version: '1.0', encoding: 'UTF-8' })
      .ele('sitemapindex', {
        xmlns: 'http://www.sitemaps.org/schemas/sitemap/0.9',
      });

    for (let i = 0; i < sitemapCount; i++) {
      const sitemapElement = root.ele('sitemap');
      sitemapElement.ele('loc').txt(`https://${domain}/sitemap-${i + 1}.xml`);
      sitemapElement.ele('lastmod').txt(new Date().toISOString().split('T')[0]);
    }

    return root.end({ prettyPrint: true });
  }

  /**
   * Save sitemap entry to database
   */
  private async saveSitemapEntry(entry: SitemapEntry, tenantId?: string): Promise<void> {
    try {
      const url = new URL(entry.url);
      const domain = url.hostname;

      await DatabaseManager.query(
        `INSERT INTO sitemap_entries (
          domain, url, last_modified, change_frequency, priority,
          images, videos, news, tenant_id
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
        ON CONFLICT (domain, url) DO UPDATE SET
          last_modified = EXCLUDED.last_modified,
          change_frequency = EXCLUDED.change_frequency,
          priority = EXCLUDED.priority,
          images = EXCLUDED.images,
          videos = EXCLUDED.videos,
          news = EXCLUDED.news,
          updated_at = NOW()`,
        [
          domain,
          entry.url,
          entry.lastModified,
          entry.changeFrequency,
          entry.priority,
          JSON.stringify(entry.images || []),
          JSON.stringify(entry.videos || []),
          entry.news ? JSON.stringify(entry.news) : null,
          tenantId,
        ]
      );
    } catch (error) {
      logError(error as Error, { context: 'Saving sitemap entry', url: entry.url });
    }
  }

  /**
   * Check if sitemap should be regenerated
   */
  private shouldRegenerateSitemap(lastGenerated: Date): boolean {
    const now = new Date();
    const hoursSinceGeneration = (now.getTime() - lastGenerated.getTime()) / (1000 * 60 * 60);
    
    // Regenerate if older than 24 hours
    return hoursSinceGeneration > 24;
  }

  /**
   * Validate sitemap XML
   */
  async validateSitemap(sitemapXml: string): Promise<{
    valid: boolean;
    errors: string[];
    warnings: string[];
    stats: {
      urlCount: number;
      imageCount: number;
      videoCount: number;
    };
  }> {
    const errors: string[] = [];
    const warnings: string[] = [];
    let urlCount = 0;
    let imageCount = 0;
    let videoCount = 0;

    try {
      const $ = cheerio.load(sitemapXml, { xmlMode: true });

      // Count elements
      urlCount = $('url').length;
      imageCount = $('image\\:image').length;
      videoCount = $('video\\:video').length;

      // Validate URL count
      if (urlCount > 50000) {
        errors.push('Sitemap contains more than 50,000 URLs');
      }

      // Validate each URL
      $('url').each((_, element) => {
        const loc = $(element).find('loc').text();
        
        if (!loc) {
          errors.push('URL element missing loc tag');
          return;
        }

        try {
          new URL(loc);
        } catch {
          errors.push(`Invalid URL: ${loc}`);
        }

        // Validate lastmod format
        const lastmod = $(element).find('lastmod').text();
        if (lastmod && isNaN(Date.parse(lastmod))) {
          warnings.push(`Invalid lastmod format: ${lastmod}`);
        }

        // Validate priority
        const priority = $(element).find('priority').text();
        if (priority) {
          const priorityNum = parseFloat(priority);
          if (isNaN(priorityNum) || priorityNum < 0 || priorityNum > 1) {
            warnings.push(`Invalid priority value: ${priority}`);
          }
        }
      });

      return {
        valid: errors.length === 0,
        errors,
        warnings,
        stats: { urlCount, imageCount, videoCount },
      };
    } catch (error) {
      return {
        valid: false,
        errors: [`XML parsing error: ${error.message}`],
        warnings,
        stats: { urlCount, imageCount, videoCount },
      };
    }
  }

  /**
   * Submit sitemap to search engines
   */
  async submitSitemap(
    sitemapUrl: string,
    searchEngines: string[] = ['google', 'bing']
  ): Promise<{
    submissions: Array<{
      searchEngine: string;
      success: boolean;
      message: string;
    }>;
  }> {
    const submissions = [];

    for (const searchEngine of searchEngines) {
      try {
        let success = false;
        let message = '';

        switch (searchEngine) {
          case 'google':
            // Submit to Google Search Console (requires authentication)
            message = 'Google Search Console submission requires authentication';
            break;

          case 'bing':
            // Submit to Bing Webmaster Tools (requires API key)
            message = 'Bing Webmaster Tools submission requires API key';
            break;

          default:
            message = `Unknown search engine: ${searchEngine}`;
        }

        submissions.push({
          searchEngine,
          success,
          message,
        });
      } catch (error) {
        submissions.push({
          searchEngine,
          success: false,
          message: error.message,
        });
      }
    }

    return { submissions };
  }
}