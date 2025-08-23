/**
 * SEO Service Type Definitions
 * Comprehensive types for the ultimate SEO platform
 */

// Core SEO Analysis Types
export interface SEOAnalysisResult {
  id: string;
  url: string;
  domain: string;
  title?: string;
  description?: string;
  keywords?: string[];
  
  // Overall Scores
  overallScore: number;
  technicalScore: number;
  contentScore: number;
  performanceScore: number;
  
  // Analysis Results
  technicalSeo: TechnicalSEOResult;
  contentAnalysis: ContentAnalysisResult;
  performanceMetrics: PerformanceMetricsResult;
  keywordAnalysis: KeywordAnalysisResult;
  competitorAnalysis?: CompetitorAnalysisResult;
  
  // Metadata
  analyzedAt: Date;
  analysisVersion: string;
  tenantId?: string;
  userId?: string;
}

// Technical SEO Analysis
export interface TechnicalSEOResult {
  score: number;
  issues: SEOIssue[];
  recommendations: SEORecommendation[];
  
  // Core Technical Checks
  metaTags: MetaTagsAnalysis;
  headingStructure: HeadingStructureAnalysis;
  urlStructure: URLStructureAnalysis;
  internalLinking: InternalLinkingAnalysis;
  schemaMarkup: SchemaMarkupAnalysis;
  robotsTxt: RobotsTxtAnalysis;
  sitemap: SitemapAnalysis;
  ssl: SSLAnalysis;
  redirects: RedirectAnalysis;
  canonicalization: CanonicalizationAnalysis;
  mobileOptimization: MobileOptimizationAnalysis;
  
  // Advanced Technical Checks
  coreWebVitals: CoreWebVitalsResult;
  accessibility: AccessibilityResult;
  structuredData: StructuredDataResult;
  internationalSeo: InternationalSeoResult;
}

// Content Analysis
export interface ContentAnalysisResult {
  score: number;
  issues: SEOIssue[];
  recommendations: SEORecommendation[];
  
  // Content Metrics
  wordCount: number;
  readabilityScore: number;
  keywordDensity: KeywordDensityResult[];
  semanticAnalysis: SemanticAnalysisResult;
  contentStructure: ContentStructureResult;
  
  // Content Quality
  uniqueness: number;
  relevance: number;
  engagement: number;
  
  // AI-Powered Analysis
  topicCoverage: TopicCoverageResult;
  entityAnalysis: EntityAnalysisResult;
  sentimentAnalysis: SentimentAnalysisResult;
  contentGaps: ContentGapResult[];
}

// Performance Metrics
export interface PerformanceMetricsResult {
  score: number;
  issues: SEOIssue[];
  recommendations: SEORecommendation[];
  
  // Core Web Vitals
  largestContentfulPaint: number;
  firstInputDelay: number;
  cumulativeLayoutShift: number;
  firstContentfulPaint: number;
  timeToInteractive: number;
  
  // Additional Metrics
  pageLoadTime: number;
  domContentLoaded: number;
  resourceLoadTime: ResourceLoadTimeResult[];
  
  // Lighthouse Scores
  lighthousePerformance: number;
  lighthouseSeo: number;
  lighthouseAccessibility: number;
  lighthouseBestPractices: number;
  lighthousePwa: number;
}

// Keyword Analysis
export interface KeywordAnalysisResult {
  score: number;
  primaryKeyword?: string;
  secondaryKeywords: string[];
  keywordDensity: KeywordDensityResult[];
  keywordPositions: KeywordPositionResult[];
  keywordOpportunities: KeywordOpportunityResult[];
  semanticKeywords: string[];
  competitorKeywords: CompetitorKeywordResult[];
}

// Competitor Analysis
export interface CompetitorAnalysisResult {
  competitors: CompetitorResult[];
  competitiveGaps: CompetitiveGapResult[];
  marketShare: MarketShareResult;
  benchmarkScores: BenchmarkScoreResult[];
}

// Supporting Types
export interface SEOIssue {
  id: string;
  type: 'error' | 'warning' | 'info';
  category: 'technical' | 'content' | 'performance' | 'keywords' | 'competitors';
  title: string;
  description: string;
  impact: 'high' | 'medium' | 'low';
  effort: 'high' | 'medium' | 'low';
  priority: number;
  element?: string;
  location?: string;
  value?: any;
}

export interface SEORecommendation {
  id: string;
  category: 'technical' | 'content' | 'performance' | 'keywords' | 'competitors';
  title: string;
  description: string;
  impact: 'high' | 'medium' | 'low';
  effort: 'high' | 'medium' | 'low';
  priority: number;
  implementation: string;
  expectedImprovement: number;
  timeframe: string;
}

export interface MetaTagsAnalysis {
  title: {
    present: boolean;
    length: number;
    optimal: boolean;
    content?: string;
    issues: string[];
  };
  description: {
    present: boolean;
    length: number;
    optimal: boolean;
    content?: string;
    issues: string[];
  };
  keywords: {
    present: boolean;
    count: number;
    content?: string[];
    issues: string[];
  };
  openGraph: {
    present: boolean;
    complete: boolean;
    tags: Record<string, string>;
    issues: string[];
  };
  twitterCards: {
    present: boolean;
    complete: boolean;
    tags: Record<string, string>;
    issues: string[];
  };
}

export interface HeadingStructureAnalysis {
  h1Count: number;
  h1Content?: string[];
  hierarchyIssues: string[];
  missingHeadings: string[];
  structure: HeadingElement[];
}

export interface HeadingElement {
  level: number;
  content: string;
  position: number;
}

export interface URLStructureAnalysis {
  length: number;
  readability: number;
  keywordPresence: boolean;
  structure: 'good' | 'fair' | 'poor';
  issues: string[];
}

export interface InternalLinkingAnalysis {
  totalLinks: number;
  uniqueLinks: number;
  anchorTextAnalysis: AnchorTextResult[];
  linkDepth: number;
  orphanPages: string[];
  issues: string[];
}

export interface AnchorTextResult {
  text: string;
  count: number;
  type: 'exact' | 'partial' | 'branded' | 'generic';
}

export interface SchemaMarkupAnalysis {
  present: boolean;
  types: string[];
  valid: boolean;
  errors: string[];
  warnings: string[];
  coverage: number;
}

export interface RobotsTxtAnalysis {
  present: boolean;
  accessible: boolean;
  valid: boolean;
  directives: RobotsDirective[];
  issues: string[];
}

export interface RobotsDirective {
  userAgent: string;
  directive: string;
  value: string;
}

export interface SitemapAnalysis {
  present: boolean;
  accessible: boolean;
  valid: boolean;
  urlCount: number;
  lastModified?: Date;
  issues: string[];
}

export interface SSLAnalysis {
  enabled: boolean;
  valid: boolean;
  expiryDate?: Date;
  issuer?: string;
  issues: string[];
}

export interface RedirectAnalysis {
  redirectChains: RedirectChain[];
  redirectLoops: string[];
  brokenRedirects: string[];
  issues: string[];
}

export interface RedirectChain {
  startUrl: string;
  endUrl: string;
  hops: RedirectHop[];
  totalHops: number;
}

export interface RedirectHop {
  from: string;
  to: string;
  statusCode: number;
}

export interface CanonicalizationAnalysis {
  canonicalPresent: boolean;
  canonicalUrl?: string;
  selfReferencing: boolean;
  issues: string[];
}

export interface MobileOptimizationAnalysis {
  responsive: boolean;
  viewportMeta: boolean;
  mobileSpeed: number;
  mobileFriendly: boolean;
  issues: string[];
}

export interface CoreWebVitalsResult {
  lcp: {
    value: number;
    rating: 'good' | 'needs-improvement' | 'poor';
  };
  fid: {
    value: number;
    rating: 'good' | 'needs-improvement' | 'poor';
  };
  cls: {
    value: number;
    rating: 'good' | 'needs-improvement' | 'poor';
  };
}

export interface AccessibilityResult {
  score: number;
  violations: AccessibilityViolation[];
  passes: number;
  incomplete: number;
}

export interface AccessibilityViolation {
  id: string;
  impact: 'minor' | 'moderate' | 'serious' | 'critical';
  description: string;
  help: string;
  nodes: number;
}

export interface StructuredDataResult {
  types: string[];
  items: StructuredDataItem[];
  errors: StructuredDataError[];
  warnings: StructuredDataWarning[];
}

export interface StructuredDataItem {
  type: string;
  properties: Record<string, any>;
}

export interface StructuredDataError {
  type: string;
  message: string;
  location?: string;
}

export interface StructuredDataWarning {
  type: string;
  message: string;
  location?: string;
}

export interface InternationalSeoResult {
  hreflangPresent: boolean;
  hreflangTags: HreflangTag[];
  languageDeclaration: boolean;
  issues: string[];
}

export interface HreflangTag {
  lang: string;
  url: string;
  valid: boolean;
}

export interface KeywordDensityResult {
  keyword: string;
  density: number;
  count: number;
  optimal: boolean;
}

export interface SemanticAnalysisResult {
  entities: EntityResult[];
  topics: TopicResult[];
  sentiment: SentimentResult;
  readability: ReadabilityResult;
}

export interface EntityResult {
  name: string;
  type: string;
  salience: number;
  mentions: number;
}

export interface TopicResult {
  topic: string;
  relevance: number;
  coverage: number;
}

export interface SentimentResult {
  score: number;
  magnitude: number;
  label: 'positive' | 'negative' | 'neutral';
}

export interface ReadabilityResult {
  fleschKincaid: number;
  fleschReadingEase: number;
  gunningFog: number;
  smog: number;
  automatedReadability: number;
  grade: string;
}

export interface ContentStructureResult {
  paragraphCount: number;
  averageParagraphLength: number;
  sentenceCount: number;
  averageSentenceLength: number;
  listCount: number;
  imageCount: number;
  videoCount: number;
}

export interface TopicCoverageResult {
  mainTopic: string;
  subtopics: string[];
  coverage: number;
  gaps: string[];
}

export interface EntityAnalysisResult {
  entities: EntityResult[];
  entityDensity: number;
  entityRelevance: number;
}

export interface SentimentAnalysisResult {
  overall: SentimentResult;
  bySection: SectionSentimentResult[];
}

export interface SectionSentimentResult {
  section: string;
  sentiment: SentimentResult;
}

export interface ContentGapResult {
  topic: string;
  importance: number;
  competitorCoverage: number;
  opportunity: number;
}

export interface ResourceLoadTimeResult {
  type: 'css' | 'js' | 'image' | 'font' | 'other';
  url: string;
  loadTime: number;
  size: number;
  blocking: boolean;
}

export interface KeywordPositionResult {
  keyword: string;
  position: number;
  url: string;
  searchEngine: string;
  location: string;
  device: 'desktop' | 'mobile';
  date: Date;
}

export interface KeywordOpportunityResult {
  keyword: string;
  searchVolume: number;
  difficulty: number;
  opportunity: number;
  currentPosition?: number;
  potentialTraffic: number;
}

export interface CompetitorKeywordResult {
  keyword: string;
  competitor: string;
  position: number;
  searchVolume: number;
  gap: boolean;
}

export interface CompetitorResult {
  domain: string;
  name?: string;
  overallScore: number;
  technicalScore: number;
  contentScore: number;
  performanceScore: number;
  backlinks: number;
  organicKeywords: number;
  estimatedTraffic: number;
  domainAuthority: number;
  pageAuthority: number;
}

export interface CompetitiveGapResult {
  category: string;
  gap: string;
  impact: 'high' | 'medium' | 'low';
  opportunity: number;
  competitors: string[];
}

export interface MarketShareResult {
  totalMarket: number;
  yourShare: number;
  competitorShares: CompetitorShareResult[];
}

export interface CompetitorShareResult {
  competitor: string;
  share: number;
  trend: 'up' | 'down' | 'stable';
}

export interface BenchmarkScoreResult {
  metric: string;
  yourScore: number;
  industryAverage: number;
  topCompetitor: number;
  percentile: number;
}

// Keyword Research Types
export interface KeywordResearchResult {
  keyword: string;
  searchVolume: number;
  difficulty: number;
  cpc: number;
  competition: 'low' | 'medium' | 'high';
  trend: number[];
  relatedKeywords: string[];
  questions: string[];
  seasonality?: SeasonalityData[];
}

export interface SeasonalityData {
  month: number;
  relativeVolume: number;
}

// Sitemap Types
export interface SitemapEntry {
  url: string;
  lastModified?: Date;
  changeFrequency?: 'always' | 'hourly' | 'daily' | 'weekly' | 'monthly' | 'yearly' | 'never';
  priority?: number;
  images?: SitemapImage[];
  videos?: SitemapVideo[];
  news?: SitemapNews;
}

export interface SitemapImage {
  url: string;
  caption?: string;
  geoLocation?: string;
  title?: string;
  license?: string;
}

export interface SitemapVideo {
  thumbnailUrl: string;
  title: string;
  description: string;
  contentUrl?: string;
  playerUrl?: string;
  duration?: number;
  expirationDate?: Date;
  rating?: number;
  viewCount?: number;
  publicationDate?: Date;
  familyFriendly?: boolean;
  tags?: string[];
}

export interface SitemapNews {
  publicationName: string;
  publicationLanguage: string;
  title: string;
  publicationDate: Date;
  keywords?: string[];
}

// Meta Tag Generation Types
export interface MetaTagSuggestions {
  title: MetaTitleSuggestion[];
  description: MetaDescriptionSuggestion[];
  keywords: string[];
  openGraph: OpenGraphSuggestions;
  twitterCards: TwitterCardSuggestions;
  jsonLd: JsonLdSuggestions;
}

export interface MetaTitleSuggestion {
  title: string;
  length: number;
  score: number;
  reasoning: string;
}

export interface MetaDescriptionSuggestion {
  description: string;
  length: number;
  score: number;
  reasoning: string;
}

export interface OpenGraphSuggestions {
  title: string;
  description: string;
  image: string;
  type: string;
  url: string;
}

export interface TwitterCardSuggestions {
  card: string;
  title: string;
  description: string;
  image: string;
}

export interface JsonLdSuggestions {
  type: string;
  data: Record<string, any>;
}

// Monitoring Types
export interface SEOMonitoringAlert {
  id: string;
  type: 'performance' | 'ranking' | 'technical' | 'content';
  severity: 'low' | 'medium' | 'high' | 'critical';
  title: string;
  description: string;
  url?: string;
  metric?: string;
  currentValue?: number;
  previousValue?: number;
  threshold?: number;
  createdAt: Date;
  resolvedAt?: Date;
  tenantId?: string;
}

// Express Request Extensions
declare global {
  namespace Express {
    interface Request {
      id: string;
      startTime: number;
      user?: {
        id: string;
        tenantId?: string;
        roles: string[];
        permissions: string[];
      };
    }
  }
}