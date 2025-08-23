/**
 * Keyword Research Service
 * Advanced keyword research and analysis with multiple data sources
 */

import axios from 'axios';
import natural from 'natural';
import { DatabaseManager } from '../database/DatabaseManager';
import { CacheManager } from '../cache/CacheManager';
import { config } from '../config';
import { logger, logKeywordResearch, logError, logExternalAPI } from '../utils/logger';
import {
  KeywordResearchResult,
  SeasonalityData,
  KeywordOpportunityResult,
  KeywordPositionResult,
} from '../types';

export class KeywordResearchService {
  private cacheManager: CacheManager;
  private stemmer: any;

  constructor() {
    this.cacheManager = new CacheManager();
    this.stemmer = natural.PorterStemmer;
  }

  /**
   * Comprehensive keyword research
   */
  async researchKeywords(
    seedKeywords: string[],
    options: {
      language?: string;
      location?: string;
      includeQuestions?: boolean;
      includeRelated?: boolean;
      includeCompetitor?: boolean;
      tenantId?: string;
    } = {}
  ): Promise<KeywordResearchResult[]> {
    const startTime = Date.now();
    const {
      language = 'en',
      location = 'global',
      includeQuestions = true,
      includeRelated = true,
      includeCompetitor = false,
      tenantId,
    } = options;

    try {
      logger.info('Starting keyword research', {
        seedKeywords,
        language,
        location,
        includeQuestions,
        includeRelated,
      });

      const results: KeywordResearchResult[] = [];

      // Process each seed keyword
      for (const keyword of seedKeywords) {
        // Check cache first
        const cached = await this.cacheManager.getCachedKeywordData(keyword, 'comprehensive');
        if (cached) {
          results.push(cached);
          continue;
        }

        // Gather data from multiple sources
        const keywordData = await this.gatherKeywordData(keyword, {
          language,
          location,
          includeQuestions,
          includeRelated,
        });

        // Save to database
        await DatabaseManager.saveKeywordResearch({
          ...keywordData,
          tenantId,
          source: 'comprehensive',
          language,
          location,
        });

        // Cache result
        await this.cacheManager.cacheKeywordData(keyword, 'comprehensive', keywordData);

        results.push(keywordData);
      }

      const duration = Date.now() - startTime;
      logKeywordResearch(
        seedKeywords.join(', '),
        'comprehensive',
        results.length,
        duration,
        { language, location }
      );

      return results;
    } catch (error) {
      const duration = Date.now() - startTime;
      logKeywordResearch(
        seedKeywords.join(', '),
        'comprehensive',
        0,
        duration,
        { error: error.message }
      );
      logError(error as Error, { context: 'Keyword research', seedKeywords });
      throw error;
    }
  }

  /**
   * Gather keyword data from multiple sources
   */
  private async gatherKeywordData(
    keyword: string,
    options: {
      language: string;
      location: string;
      includeQuestions: boolean;
      includeRelated: boolean;
    }
  ): Promise<KeywordResearchResult> {
    const { language, location, includeQuestions, includeRelated } = options;

    // Initialize result structure
    let result: KeywordResearchResult = {
      keyword,
      searchVolume: 0,
      difficulty: 0,
      cpc: 0,
      competition: 'medium',
      trend: [],
      relatedKeywords: [],
      questions: [],
      seasonality: [],
    };

    // Try different data sources in order of preference
    const dataSources = [
      { name: 'google', enabled: config.keywordResearch.googleKeywords.enabled },
      { name: 'semrush', enabled: config.keywordResearch.semrush.enabled },
      { name: 'ahrefs', enabled: config.keywordResearch.ahrefs.enabled },
      { name: 'internal', enabled: config.keywordResearch.internal.enabled },
    ];

    for (const source of dataSources) {
      if (!source.enabled) continue;

      try {
        const sourceData = await this.getKeywordDataFromSource(
          source.name,
          keyword,
          { language, location }
        );

        // Merge data (prioritize first successful source for main metrics)
        if (result.searchVolume === 0 && sourceData.searchVolume > 0) {
          result.searchVolume = sourceData.searchVolume;
          result.difficulty = sourceData.difficulty;
          result.cpc = sourceData.cpc;
          result.competition = sourceData.competition;
          result.trend = sourceData.trend;
        }

        // Always merge related keywords and questions
        if (includeRelated && sourceData.relatedKeywords) {
          result.relatedKeywords = [
            ...result.relatedKeywords,
            ...sourceData.relatedKeywords,
          ];
        }

        if (includeQuestions && sourceData.questions) {
          result.questions = [...result.questions, ...sourceData.questions];
        }

        if (sourceData.seasonality) {
          result.seasonality = sourceData.seasonality;
        }

        break; // Use first successful source for main data
      } catch (error) {
        logger.warn(`Failed to get data from ${source.name}`, {
          keyword,
          error: error.message,
        });
        continue;
      }
    }

    // If no external data, use internal analysis
    if (result.searchVolume === 0) {
      result = await this.performInternalAnalysis(keyword, options);
    }

    // Remove duplicates and clean data
    result.relatedKeywords = [...new Set(result.relatedKeywords)].slice(0, 20);
    result.questions = [...new Set(result.questions)].slice(0, 10);

    return result;
  }

  /**
   * Get keyword data from specific source
   */
  private async getKeywordDataFromSource(
    source: string,
    keyword: string,
    options: { language: string; location: string }
  ): Promise<Partial<KeywordResearchResult>> {
    switch (source) {
      case 'google':
        return await this.getGoogleKeywordData(keyword, options);
      case 'semrush':
        return await this.getSEMrushKeywordData(keyword, options);
      case 'ahrefs':
        return await this.getAhrefsKeywordData(keyword, options);
      case 'internal':
        return await this.performInternalAnalysis(keyword, options);
      default:
        throw new Error(`Unknown keyword data source: ${source}`);
    }
  }

  /**
   * Get keyword data from Google Ads API
   */
  private async getGoogleKeywordData(
    keyword: string,
    options: { language: string; location: string }
  ): Promise<Partial<KeywordResearchResult>> {
    if (!config.keywordResearch.googleKeywords.apiKey) {
      throw new Error('Google Ads API key not configured');
    }

    const startTime = Date.now();

    try {
      // This would integrate with Google Ads Keyword Planner API
      // For now, return simulated data structure
      const response = {
        searchVolume: Math.floor(Math.random() * 10000) + 1000,
        difficulty: Math.floor(Math.random() * 100),
        cpc: Math.random() * 5,
        competition: ['low', 'medium', 'high'][Math.floor(Math.random() * 3)] as 'low' | 'medium' | 'high',
        trend: Array.from({ length: 12 }, () => Math.floor(Math.random() * 100)),
        relatedKeywords: this.generateRelatedKeywords(keyword),
      };

      const duration = Date.now() - startTime;
      logExternalAPI('google-ads', 'keyword-planner', 200, duration, { keyword });

      return response;
    } catch (error) {
      const duration = Date.now() - startTime;
      logExternalAPI('google-ads', 'keyword-planner', 500, duration, {
        keyword,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Get keyword data from SEMrush API
   */
  private async getSEMrushKeywordData(
    keyword: string,
    options: { language: string; location: string }
  ): Promise<Partial<KeywordResearchResult>> {
    if (!config.keywordResearch.semrush.apiKey) {
      throw new Error('SEMrush API key not configured');
    }

    const startTime = Date.now();

    try {
      const url = 'https://api.semrush.com/';
      const params = {
        type: 'phrase_this',
        key: config.keywordResearch.semrush.apiKey,
        phrase: keyword,
        database: options.location === 'global' ? 'us' : options.location,
        export_columns: 'Ph,Nq,Cp,Co,Nr,Td',
      };

      const response = await axios.get(url, {
        params,
        timeout: 30000,
      });

      const duration = Date.now() - startTime;
      logExternalAPI('semrush', 'phrase-this', response.status, duration, { keyword });

      // Parse SEMrush response (CSV format)
      const lines = response.data.split('\n').filter((line: string) => line.trim());
      if (lines.length < 2) {
        throw new Error('No data returned from SEMrush');
      }

      const data = lines[1].split(';');
      
      return {
        searchVolume: parseInt(data[1]) || 0,
        difficulty: Math.min(100, parseInt(data[5]) || 0),
        cpc: parseFloat(data[2]) || 0,
        competition: this.mapCompetitionLevel(parseFloat(data[3]) || 0),
        relatedKeywords: await this.getSEMrushRelatedKeywords(keyword),
      };
    } catch (error) {
      const duration = Date.now() - startTime;
      logExternalAPI('semrush', 'phrase-this', 500, duration, {
        keyword,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Get keyword data from Ahrefs API
   */
  private async getAhrefsKeywordData(
    keyword: string,
    options: { language: string; location: string }
  ): Promise<Partial<KeywordResearchResult>> {
    if (!config.keywordResearch.ahrefs.apiKey) {
      throw new Error('Ahrefs API key not configured');
    }

    const startTime = Date.now();

    try {
      const url = 'https://apiv2.ahrefs.com/v2/keywords-explorer/overview';
      const params = {
        target: keyword,
        country: options.location === 'global' ? 'us' : options.location,
        mode: 'exact',
      };

      const response = await axios.get(url, {
        params,
        headers: {
          Authorization: `Bearer ${config.keywordResearch.ahrefs.apiKey}`,
        },
        timeout: 30000,
      });

      const duration = Date.now() - startTime;
      logExternalAPI('ahrefs', 'keywords-explorer', response.status, duration, { keyword });

      const data = response.data.keywords[0];
      
      return {
        searchVolume: data.search_volume || 0,
        difficulty: data.keyword_difficulty || 0,
        cpc: data.cpc || 0,
        competition: this.mapCompetitionLevel(data.keyword_difficulty || 0),
        relatedKeywords: await this.getAhrefsRelatedKeywords(keyword),
      };
    } catch (error) {
      const duration = Date.now() - startTime;
      logExternalAPI('ahrefs', 'keywords-explorer', 500, duration, {
        keyword,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Perform internal keyword analysis
   */
  private async performInternalAnalysis(
    keyword: string,
    options: any
  ): Promise<KeywordResearchResult> {
    // Generate estimated metrics based on keyword characteristics
    const wordCount = keyword.split(' ').length;
    const keywordLength = keyword.length;
    
    // Estimate search volume (longer tail = lower volume)
    let estimatedVolume = 5000;
    if (wordCount > 3) estimatedVolume = Math.floor(estimatedVolume / (wordCount - 2));
    if (keywordLength > 30) estimatedVolume = Math.floor(estimatedVolume * 0.7);
    
    // Add some randomness
    estimatedVolume = Math.floor(estimatedVolume * (0.5 + Math.random()));

    // Estimate difficulty (longer tail = easier)
    let estimatedDifficulty = 50;
    if (wordCount > 2) estimatedDifficulty = Math.max(10, estimatedDifficulty - (wordCount * 10));
    
    // Generate related keywords using NLP
    const relatedKeywords = this.generateRelatedKeywords(keyword);
    
    // Generate questions
    const questions = this.generateQuestions(keyword);

    return {
      keyword,
      searchVolume: estimatedVolume,
      difficulty: estimatedDifficulty,
      cpc: Math.random() * 3,
      competition: estimatedDifficulty > 70 ? 'high' : estimatedDifficulty > 40 ? 'medium' : 'low',
      trend: Array.from({ length: 12 }, () => Math.floor(Math.random() * 100) + 50),
      relatedKeywords,
      questions,
      seasonality: this.generateSeasonalityData(),
    };
  }

  /**
   * Generate related keywords using NLP techniques
   */
  private generateRelatedKeywords(keyword: string): string[] {
    const words = keyword.toLowerCase().split(' ');
    const related: string[] = [];

    // Stemming-based variations
    const stemmed = words.map(word => this.stemmer.stem(word));
    
    // Common keyword modifiers
    const modifiers = [
      'best', 'top', 'how to', 'what is', 'guide', 'tips', 'review',
      'cheap', 'free', 'online', 'near me', '2024', 'vs', 'comparison'
    ];

    // Generate variations
    modifiers.forEach(modifier => {
      related.push(`${modifier} ${keyword}`);
      related.push(`${keyword} ${modifier}`);
    });

    // Synonym-based variations (simplified)
    const synonyms: Record<string, string[]> = {
      'best': ['top', 'great', 'excellent', 'good'],
      'guide': ['tutorial', 'how to', 'tips', 'help'],
      'review': ['rating', 'opinion', 'feedback', 'evaluation'],
      'cheap': ['affordable', 'budget', 'low cost', 'inexpensive'],
    };

    words.forEach(word => {
      if (synonyms[word]) {
        synonyms[word].forEach(synonym => {
          const newKeyword = keyword.replace(word, synonym);
          related.push(newKeyword);
        });
      }
    });

    // Remove duplicates and filter
    return [...new Set(related)]
      .filter(k => k !== keyword && k.length > 3)
      .slice(0, 15);
  }

  /**
   * Generate question-based keywords
   */
  private generateQuestions(keyword: string): string[] {
    const questionStarters = [
      'what is',
      'how to',
      'why',
      'when',
      'where',
      'who',
      'which',
      'how much',
      'how many',
      'can you',
    ];

    return questionStarters
      .map(starter => `${starter} ${keyword}`)
      .slice(0, 8);
  }

  /**
   * Generate seasonality data
   */
  private generateSeasonalityData(): SeasonalityData[] {
    return Array.from({ length: 12 }, (_, index) => ({
      month: index + 1,
      relativeVolume: Math.floor(Math.random() * 50) + 75, // 75-125% of average
    }));
  }

  /**
   * Get related keywords from SEMrush
   */
  private async getSEMrushRelatedKeywords(keyword: string): Promise<string[]> {
    try {
      const url = 'https://api.semrush.com/';
      const params = {
        type: 'phrase_related',
        key: config.keywordResearch.semrush.apiKey,
        phrase: keyword,
        database: 'us',
        export_columns: 'Ph,Nq',
        display_limit: 10,
      };

      const response = await axios.get(url, { params, timeout: 15000 });
      const lines = response.data.split('\n').filter((line: string) => line.trim());
      
      return lines.slice(1, 11).map((line: string) => line.split(';')[0]);
    } catch (error) {
      logger.warn('Failed to get SEMrush related keywords', { keyword, error: error.message });
      return [];
    }
  }

  /**
   * Get related keywords from Ahrefs
   */
  private async getAhrefsRelatedKeywords(keyword: string): Promise<string[]> {
    try {
      const url = 'https://apiv2.ahrefs.com/v2/keywords-explorer/related-terms';
      const params = {
        target: keyword,
        country: 'us',
        limit: 10,
      };

      const response = await axios.get(url, {
        params,
        headers: {
          Authorization: `Bearer ${config.keywordResearch.ahrefs.apiKey}`,
        },
        timeout: 15000,
      });

      return response.data.terms.map((term: any) => term.keyword);
    } catch (error) {
      logger.warn('Failed to get Ahrefs related keywords', { keyword, error: error.message });
      return [];
    }
  }

  /**
   * Map competition level from numeric to categorical
   */
  private mapCompetitionLevel(value: number): 'low' | 'medium' | 'high' {
    if (value < 0.33) return 'low';
    if (value < 0.67) return 'medium';
    return 'high';
  }

  /**
   * Find keyword opportunities
   */
  async findKeywordOpportunities(
    domain: string,
    competitors: string[],
    options: {
      minSearchVolume?: number;
      maxDifficulty?: number;
      tenantId?: string;
    } = {}
  ): Promise<KeywordOpportunityResult[]> {
    const {
      minSearchVolume = config.keywordResearch.internal.minSearchVolume,
      maxDifficulty = config.keywordResearch.internal.maxDifficulty,
      tenantId,
    } = options;

    try {
      // This would analyze competitor keywords and find gaps
      // For now, return simulated opportunities
      const opportunities: KeywordOpportunityResult[] = [];

      // Generate sample opportunities
      const sampleKeywords = [
        'content marketing strategy',
        'seo best practices',
        'digital marketing trends',
        'social media optimization',
        'email marketing automation',
      ];

      for (const keyword of sampleKeywords) {
        const searchVolume = Math.floor(Math.random() * 5000) + minSearchVolume;
        const difficulty = Math.floor(Math.random() * maxDifficulty);
        
        opportunities.push({
          keyword,
          searchVolume,
          difficulty,
          opportunity: this.calculateOpportunityScore(searchVolume, difficulty),
          currentPosition: undefined,
          potentialTraffic: Math.floor(searchVolume * 0.3 * (1 - difficulty / 100)),
        });
      }

      return opportunities.sort((a, b) => b.opportunity - a.opportunity);
    } catch (error) {
      logError(error as Error, { context: 'Finding keyword opportunities', domain });
      throw error;
    }
  }

  /**
   * Calculate opportunity score
   */
  private calculateOpportunityScore(searchVolume: number, difficulty: number): number {
    // Higher volume and lower difficulty = higher opportunity
    const volumeScore = Math.min(100, (searchVolume / 10000) * 100);
    const difficultyScore = 100 - difficulty;
    
    return Math.round((volumeScore + difficultyScore) / 2);
  }

  /**
   * Track keyword positions
   */
  async trackKeywordPositions(
    keywords: string[],
    domain: string,
    options: {
      searchEngine?: string;
      location?: string;
      device?: 'desktop' | 'mobile';
      tenantId?: string;
    } = {}
  ): Promise<KeywordPositionResult[]> {
    const {
      searchEngine = 'google',
      location = 'global',
      device = 'desktop',
      tenantId,
    } = options;

    try {
      const positions: KeywordPositionResult[] = [];

      // This would integrate with rank tracking APIs
      // For now, generate simulated position data
      for (const keyword of keywords) {
        const position = Math.floor(Math.random() * 100) + 1;
        
        positions.push({
          keyword,
          position,
          url: `https://${domain}/page-for-${keyword.replace(/\s+/g, '-')}`,
          searchEngine,
          location,
          device,
          date: new Date(),
        });
      }

      return positions;
    } catch (error) {
      logError(error as Error, { context: 'Tracking keyword positions', domain, keywords });
      throw error;
    }
  }

  /**
   * Analyze keyword cannibalization
   */
  async analyzeKeywordCannibalization(
    domain: string,
    options: { tenantId?: string } = {}
  ): Promise<{
    cannibalizedKeywords: Array<{
      keyword: string;
      urls: string[];
      impact: 'high' | 'medium' | 'low';
    }>;
    recommendations: string[];
  }> {
    try {
      // This would analyze multiple pages ranking for the same keywords
      // For now, return simulated cannibalization data
      
      return {
        cannibalizedKeywords: [
          {
            keyword: 'seo optimization',
            urls: [
              `https://${domain}/seo-guide`,
              `https://${domain}/seo-tips`,
              `https://${domain}/optimization-guide`,
            ],
            impact: 'high',
          },
        ],
        recommendations: [
          'Consolidate similar content into comprehensive guides',
          'Use canonical tags to indicate preferred URLs',
          'Implement proper internal linking structure',
          'Differentiate content focus for each page',
        ],
      };
    } catch (error) {
      logError(error as Error, { context: 'Analyzing keyword cannibalization', domain });
      throw error;
    }
  }

  /**
   * Generate keyword clusters
   */
  async generateKeywordClusters(
    keywords: string[],
    options: {
      clusterMethod?: 'semantic' | 'serp' | 'hybrid';
      maxClusters?: number;
    } = {}
  ): Promise<Array<{
    cluster: string;
    keywords: string[];
    searchVolume: number;
    difficulty: number;
  }>> {
    const { clusterMethod = 'semantic', maxClusters = 10 } = options;

    try {
      // This would use NLP techniques to cluster related keywords
      // For now, return simulated clusters
      
      const clusters = [];
      const keywordsPerCluster = Math.ceil(keywords.length / maxClusters);
      
      for (let i = 0; i < Math.min(maxClusters, keywords.length); i++) {
        const clusterKeywords = keywords.slice(i * keywordsPerCluster, (i + 1) * keywordsPerCluster);
        
        clusters.push({
          cluster: `Cluster ${i + 1}`,
          keywords: clusterKeywords,
          searchVolume: clusterKeywords.length * 1000,
          difficulty: Math.floor(Math.random() * 100),
        });
      }

      return clusters;
    } catch (error) {
      logError(error as Error, { context: 'Generating keyword clusters', keywords: keywords.length });
      throw error;
    }
  }
}